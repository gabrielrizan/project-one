class_name FogOfWar
extends Node3D
## Black fog of war (ISLAND_PROMPTS F3). **Explored ground stays explored forever.**
##
## This is memory of a place, not line of sight: nothing ever re-shrouds behind you,
## there is no "visible but remembered" middle state, and riding away from somewhere
## costs you nothing. A kingdom does not forget where its own coast is.
##
## ## Two halves, because one plane cannot do it at a 45 degree pitch
##
## 1. **The ground** is darkened by a flat quad reading a CPU-painted mask
##    (`fog_of_war.gdshader`). `gl_compatibility` has no decals and no volumetric
##    fog, so a mask plus a quad is the whole toolbox.
## 2. **Anything that stands up** is hidden by its own `visible` flag, through the
##    [constant GROUP] group. A single plane above the world occludes the ground
##    *in front of* it, never the ground under it, so a tree at the frame's far edge
##    would stand clear of its own fog. There is no shader answer to that.
##
## A hidden node keeps its colliders and its group memberships -- hiding is
## **cosmetic only**. That matters: a bandit camp's garrison still counts as
## defenders while unseen, exactly as it did under the old distance check.
##
## ## The mask
##
## One [constant RES] square R8 image over the map's own extent, held as a raw
## [PackedByteArray] and written by index. `Image.set_pixel` is a method call per
## pixel and a monarch's brush is ~6 400 of them; indexing a byte array is free by
## comparison. Brushes are precomputed per radius and **max-blended**, which is what
## makes the mask monotonic -- there is no code path that can un-reveal anything.
##
## Repainted and uploaded at [constant TICK] Hz, and only for revealers that have
## actually moved a pixel's worth since last time. A villager standing at a
## workbench costs nothing at all, and a 256² upload every frame would be pure
## waste for something that changes at walking pace.
##
## ## What is *not* fogged, and why
##
## **The sea.** Fog covers the map's extent, so the island and its coast are hidden
## until walked; the open water past it is not. The sea is not explorable -- there
## is nothing out there to find and no way to go and find it -- so shrouding it
## would only delete the horizon, the distant islands and the whole reading of "you
## are on an island", in exchange for no information the player could ever act on.
## What you get instead is rather better: a dark island lying in a bright sea, whose
## outline you can see and whose contents you cannot.

const GROUP := "fog_hideable"
const FOG_SHADER := preload("res://kingdom_demo/assets/shaders/fog_of_war.gdshader")

## Mask resolution. Over the island's 216 m square this is ~0.84 m a pixel, which
## is finer than the softest part of any brush edge -- raising it buys nothing you
## can see and costs the upload quadratically.
const RES := 256

## Sits above the water (0.10) and the beach (0.06) so unexplored sea and sand go
## black with the grass, and below anything that stands up, which the group hides.
const FOG_Y := 0.35

## Repaint/upload rate. ~7x a second: fine enough that riding into the frontier
## melts it away smoothly rather than in visible steps, still a fraction of doing it
## per frame. The animated shader edge hides what stepping remains.
const TICK := 0.14

## How far each kind of revealer sees.
##
## The monarch's is large because riding out to look is the verb the whole map is
## built around. **Villagers reveal too, and that is the important one**: archers
## hunt and forage across the map by daylight, so the island opens up as the economy
## grows rather than only when the player personally goes sightseeing. It also means
## a bigger kingdom knows more of its own land, which is the right thing for it to
## mean.
## Tightened again to 18/12 (Andrei, 2026-08-04): 25 pushed the frontier out near
## the edge of frame, where it read as a distant wall you could never quite reach --
## "too far to interact with". At 18 the dark sits close in front of the monarch, so
## riding toward it visibly rolls it back and the map opens right where you are
## looking. The soft, wafting shader edge (`fog_of_war.gdshader`) is what keeps that
## close frontier from looking like a hard stamped circle.
const R_MONARCH := 18.0
const R_VILLAGER := 12.0

## A revealer has to move this far before its brush is stamped again. Small, so the
## reveal keeps up with a gallop and dissipates smoothly rather than in 2.5 m jumps.
const REPAINT_AFTER := 1.2

## True on maps that carry fog. Read straight off the map rather than off a node,
## so spawners can ask before this node has readied -- scene order stops mattering.
static func enabled() -> bool:
	return MapTerrain.map().fog

## Hide `node` until the ground under it has been explored. A no-op on a map
## without fog, so every caller is one unconditional line.
##
## Joining the group *is* the registration; there is no list to keep. When the mask
## catches up the node is shown and **leaves the group**, which is both how it stops
## being sampled and the codebase's usual idiom for a thing that is done.
static func hide_until_found(node: Node3D) -> void:
	if not enabled() or node == null:
		return
	node.visible = false
	node.add_to_group(GROUP)

var _half := 108.0
var _mask := PackedByteArray()
var _img: Image = null
var _tex: ImageTexture = null
var _mat: ShaderMaterial = null
var _brush := {}                 # radius in pixels -> precomputed falloff bytes
var _last_paint := {}            # revealer instance id -> where it last stamped
var _t := 0.0
var _dirty := false
var _shroud: MeshInstance3D = null
## Fog switched off for looking at things (dev). A *view* override -- see
## [method set_bypass].
var _bypass := false

func _ready() -> void:
	add_to_group("fog")
	if not enabled():
		set_process(false)
		return
	_half = MapTerrain.extent()
	_mask.resize(RES * RES)
	_mask.fill(0)
	_img = Image.create_from_data(RES, RES, false, Image.FORMAT_R8, _mask)
	_tex = ImageTexture.create_from_image(_img)
	_build_quad()
	# **Deferred, not immediate.** This node readies before the Monarch does (it is
	# higher in the scene), so a paint here finds nobody in the `monarch` group and
	# the player spends the first quarter-second staring at a black village. A
	# deferred call lands after the whole tree has readied.
	call_deferred("_first_paint")

## The starting reveal.
##
## Seeds the **village** as well as painting whoever is standing about, and does so
## unconditionally: you begin there, your fire is lit there and your walls are
## there, so blacking it out would be fog of war telling the player they have not
## discovered their own home. It also makes the opening frame independent of scene
## order, which is worth having on its own.
func _first_paint() -> void:
	_paint(MapTerrain.village(), R_MONARCH)
	_repaint()
	_upload()
	_sweep_hideables()

## How far past the coast the shroud reaches, so the waterline is covered rather
## than leaving a lit rim of surf around an unexplored island.
const SHROUD_MARGIN := 1.5
## Angular resolution of the island-shaped shroud. The coast's fastest harmonic is
## k = 7, so 128 chords follow it to well under a centimetre.
const SHROUD_SEGMENTS := 128

## The mesh the fog is painted on.
##
## **Island-shaped, not a square.** A plane over the map's extent is the obvious
## build and it is wrong on sight: the island reaches 94 m and the extent is 108, so
## it hangs a hard-edged black rectangle out over open water, and the first thing
## the player sees is a rectangle. Cutting it to [method MapDef.shore_at] -- the same
## curve the collider ring, the beach and the water mesh are all cut from -- makes
## the shroud exactly the shape of the land, which is also what makes the thing this
## file's header claims literally true: a dark island lying in a bright sea, whose
## outline you can see and whose contents you cannot.
func _build_quad() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = FOG_SHADER
	_mat.set_shader_parameter("mask", _tex)
	_mat.set_shader_parameter("half_extent", _half)
	_shroud = MeshInstance3D.new()
	_shroud.mesh = _shroud_mesh()
	_shroud.material_override = _mat
	_shroud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shroud)
	_shroud.position.y = FOG_Y

func _shroud_mesh() -> Mesh:
	if not MapTerrain.has_shore():
		# landlocked: the map's sealed bearings hide their own far side, so a plain
		# square over the extent is both correct and all there is to cut to
		var plane := PlaneMesh.new()
		plane.size = Vector2(_half * 2.0, _half * 2.0)
		return plane
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SHROUD_SEGMENTS:
		var t0 := TAU * float(i) / float(SHROUD_SEGMENTS)
		var t1 := TAU * float(i + 1) / float(SHROUD_SEGMENTS)
		var r0 := MapTerrain.shore_at(t0) + SHROUD_MARGIN
		var r1 := MapTerrain.shore_at(t1) + SHROUD_MARGIN
		# counter-clockwise seen from above, so the fan faces up -- the same winding
		# rule `sea.gd` learned the hard way
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(t0) * r0, 0.0, sin(t0) * r0))
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(cos(t1) * r1, 0.0, sin(t1) * r1))
	return st.commit()

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = TICK
	_repaint()
	_sweep_hideables()
	if _dirty:
		_upload()

# ---------------------------------------------------------------- painting

func _repaint() -> void:
	var king := get_tree().get_first_node_in_group("monarch")
	if is_instance_valid(king):
		_stamp(king, R_MONARCH)
	for v in get_tree().get_nodes_in_group("villager"):
		if is_instance_valid(v):
			_stamp(v, R_VILLAGER)

## Paint one revealer's brush, unless it has barely moved since last time.
func _stamp(who: Node3D, radius: float) -> void:
	var id := who.get_instance_id()
	var at := who.global_position
	if _last_paint.has(id) and _last_paint[id].distance_to(at) < REPAINT_AFTER:
		return
	_last_paint[id] = at
	_paint(at, radius)

## Max-blend a soft disc into the mask. The only writer, and it only ever raises a
## byte -- which is what makes "explored stays explored" a property of the data
## rather than a rule someone has to remember.
func _paint(at: Vector3, radius: float) -> void:
	var scale := float(RES) / (_half * 2.0)
	var cx := int((at.x + _half) * scale)
	var cy := int((at.z + _half) * scale)
	var pr := maxi(1, int(radius * scale))
	var b: PackedByteArray = _brush_for(pr)
	var span := pr * 2 + 1
	for by in span:
		var y := cy - pr + by
		if y < 0 or y >= RES:
			continue
		var row := y * RES
		var brow := by * span
		for bx in span:
			var x := cx - pr + bx
			if x < 0 or x >= RES:
				continue
			var v := b[brow + bx]
			if v > _mask[row + x]:
				_mask[row + x] = v
				_dirty = true

## A disc of falloff bytes, cached per pixel radius.
##
## Solid only to 30% of the radius then eased out over the remaining 70%, so the
## frontier is a wide, soft gradient the shader can waft -- overlapping brushes merge
## into one rolling shape instead of reading as a chain of coins, and riding toward
## the edge dissipates it gradually rather than snapping a hard disc clear.
func _brush_for(pr: int) -> PackedByteArray:
	if _brush.has(pr):
		return _brush[pr]
	var span := pr * 2 + 1
	var b := PackedByteArray()
	b.resize(span * span)
	for y in span:
		for x in span:
			var dx := float(x - pr)
			var dy := float(y - pr)
			var d := sqrt(dx * dx + dy * dy) / float(pr)
			var v := 1.0 - smoothstep(0.30, 1.0, d)
			b[y * span + x] = int(clampf(v, 0.0, 1.0) * 255.0)
	_brush[pr] = b
	return b

func _upload() -> void:
	_dirty = false
	_img.set_data(RES, RES, false, Image.FORMAT_R8, _mask)
	_tex.update(_img)

# ---------------------------------------------------------------- the standing world

## Show anything the mask has caught up with, and drop it from the group so it is
## never looked at again. The sweep therefore gets cheaper as the map opens, and
## costs nothing at all once it is fully explored.
func _sweep_hideables() -> void:
	for node in get_tree().get_nodes_in_group(GROUP):
		if not is_instance_valid(node):
			continue
		if not (node is Node3D):
			node.remove_from_group(GROUP)
			continue
		if revealed(node.global_position):
			node.visible = true
			node.remove_from_group(GROUP)

## Has the ground at `p` been explored? Everything off the mask counts as explored,
## because the mask covers the map and what lies past it is the sea (see the class
## notes) -- a distant island must not be shrouded for want of a texel.
func revealed(p: Vector3) -> bool:
	if _mask.is_empty():
		return true
	var scale := float(RES) / (_half * 2.0)
	var x := int((p.x + _half) * scale)
	var y := int((p.z + _half) * scale)
	if x < 0 or x >= RES or y < 0 or y >= RES:
		return true
	return _mask[y * RES + x] > 96

# ---------------------------------------------------------------- dev

## Switch the fog off to look at something, and back on again (`dev_menu.gd`).
##
## **A view override, not a reveal.** The mask is not touched, so what has actually
## been explored is exactly what it was before — switch it back on and the frontier
## is where you left it, not wherever you happened to fly the camera. That is the
## whole difference between this and [method reveal_all], and it is why both exist:
## this one answers "what does the map look like", that one answers "what does a
## fully explored run look like", and neither can be mistaken for the other.
##
## Hidden nodes are shown but **kept in the group**, so switching back re-hides
## everything the mask still does not cover. The ordinary sweep carries on
## underneath and is unaffected — it only ever shows and drops genuinely revealed
## nodes, which stays true whichever way this is set.
func set_bypass(on: bool) -> void:
	_bypass = on
	if not is_inside_tree():
		return
	if is_instance_valid(_shroud):
		_shroud.visible = not on
	for node in get_tree().get_nodes_in_group(GROUP):
		if node is Node3D:
			(node as Node3D).visible = on or revealed((node as Node3D).global_position)

func bypassed() -> bool:
	return _bypass

## Explore the whole map, permanently. **Not wired to anything** -- kept because it
## is the only way to get a genuinely-explored mask, which a save/carry-over or a
## test might one day want, and because it is four lines.
##
## It is deliberately *not* a dev tool: [method set_bypass] does everything it did
## from the player's side (nothing in the game reads the mask except visibility, so
## a filled mask and a hidden shroud are indistinguishable) and can be undone.
func reveal_all() -> void:
	if _mask.is_empty():
		return
	_mask.fill(255)
	_upload()
	_sweep_hideables()
