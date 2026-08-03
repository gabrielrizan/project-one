class_name MarkFx
extends RefCounted
## The shared visual language for anything the monarch marks for his people to
## work: the paint blaze daubed onto it, the floating banner saying which crew it
## is waiting on, and the debris that flies while it is being worked.
##
## Used by trees (workers, axe banner) and berry bushes (archers, basket banner).
## All helpers take the marked node as `owner` since statics have no scene tree.

const MARK_TEX := preload("res://kingdom_demo/assets/pixel/mark_x.png")
const CHIP_TEX := preload("res://kingdom_demo/assets/pixel/wood_chip.png")

const BLAZE_LIFT := 0.16

## The daub of paint going on. It lives here rather than in `tree_resource.gd`
## and `berry_bush.gd` separately because **the monarch is doing the same thing
## to both** -- marking is one verb, so it gets one sound, exactly like the
## blaze and the banner it goes with.
const MARK_SFX := [
	preload("res://kingdom_demo/assets/audio/mark_1.ogg"),
	preload("res://kingdom_demo/assets/audio/mark_2.ogg"),
	preload("res://kingdom_demo/assets/audio/mark_3.ogg"),
]
const MARK_DB := -7.0
const MARK_PITCH := 1.12
const MARK_VOL_JITTER := 3.0

## Built once and shared by every marked thing on the map -- there is only ever
## one monarch, so one pool is enough.
static var _mark_pool: AudioStreamRandomizer = null

## Instantiate a model at a uniform scale.
static func model(scene: PackedScene, scale: float) -> Node3D:
	var n: Node3D = scene.instantiate()
	n.scale = Vector3.ONE * scale
	return n

## Force every mesh under `node` to one flat colour. 3D has no `modulate`, so
## this is how a model is greyed out -- fine for single-colour props like a coin
## pip, wrong for anything whose own palette matters.
static func tint(node: Node3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	for m in meshes(node):
		m.material_override = mat

static func untint(node: Node3D) -> void:
	for m in meshes(node):
		m.material_override = null

## Undo [method repaint], putting every surface back to the material the model
## shipped with.
##
## ⚠️ It is **not** [method untint]: `tint` writes `material_override` on the mesh,
## `repaint` writes `set_surface_override_material` per surface, and clearing one
## does nothing to the other. The wreck came back from being repaired still weathered
## grey because of exactly this.
static func unpaint(node: Node3D) -> void:
	for m in meshes(node):
		var mi := m as MeshInstance3D
		for s in mi.get_surface_override_material_count():
			mi.set_surface_override_material(s, null)

## Recolour **individual named materials** on a model, leaving the rest alone.
##
## This is the palette tool [method tint] is not. `tint` flattens a whole model to
## one colour, which is right for a coin pip and destructive for anything with its
## own material set. `repaint` takes a `{material_name: Color}` map and swaps only
## those, so a house keeps its plaster, timber and stonework and only its roof
## changes — which is what "bring an off-palette asset into the palette" actually
## means.
##
## It works because the Quaternius packs **name their materials** (`RoofTiles`,
## `Plaster`, `Wood`, `Stone_Dark`...) rather than baking everything into one
## texture atlas. No image editing and no external tool: reskinning here is a
## dictionary.
##
## ⚠️ The material is **duplicated** before it is written to. FBX materials are
## shared resources, so editing one in place would repaint every other instance in
## the map — and every other model in the pack that uses the same material.
static func repaint(node: Node3D, swaps: Dictionary) -> int:
	var done := 0
	for m in meshes(node):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s)
			if mat == null or not swaps.has(mat.resource_name):
				continue
			var dup: StandardMaterial3D = mat.duplicate()
			dup.albedo_color = swaps[mat.resource_name]
			mi.set_surface_override_material(s, dup)
			done += 1
	return done

static func meshes(n: Node) -> Array:
	var out: Array = []
	var stack: Array = [n]
	while not stack.is_empty():
		var c = stack.pop_back()
		if c is MeshInstance3D:
			out.append(c)
		for k in c.get_children():
			stack.append(k)
	return out

static func sprite(tex: Texture2D, px: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	return s

## Alpha cutting off, so debris can fade out instead of popping.
static func particle(tex: Texture2D, px: float) -> Sprite3D:
	var s := sprite(tex, px)
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	return s

## Daubs the felling/foraging mark on, in one wet slap.
## A brush stroke where the blaze just landed. On a throwaway emitter parented
## to the scene rather than to `owner`, because a felled tree frees itself
## immediately and would cut its own sound off.
static func mark_sound(owner: Node3D) -> void:
	if owner == null or not owner.is_inside_tree():
		return
	if _mark_pool == null:
		_mark_pool = AudioStreamRandomizer.new()
		for i in range(MARK_SFX.size()):
			_mark_pool.add_stream(i, MARK_SFX[i])
		_mark_pool.random_pitch = MARK_PITCH
		_mark_pool.random_volume_offset_db = MARK_VOL_JITTER
		_mark_pool.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	var p := AudioStreamPlayer3D.new()
	p.stream = _mark_pool
	p.bus = &"SFX"
	p.volume_db = MARK_DB
	p.unit_size = 5.0
	p.max_distance = 26.0
	owner.get_tree().current_scene.add_child(p)
	p.global_position = owner.global_position + Vector3(0, 1.0, 0)
	p.finished.connect(p.queue_free)
	p.play()

static func blaze(owner: Node3D, local_y: float, px: float) -> Sprite3D:
	var b := sprite(MARK_TEX, px)
	owner.add_child(b)
	b.position = Vector3(0, local_y, 0)
	b.scale = Vector3(0.2, 0.2, 1.0)
	b.modulate = Color(2.2, 2.2, 2.2, 1.0)
	var t := owner.create_tween()
	t.tween_property(b, "scale", Vector3(1.25, 1.25, 1.0), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(b, "modulate", Color(1, 1, 1, 1), 0.3)
	t.tween_property(b, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	return b

## Marked things are Y-billboarded sprites, so the blaze has to be nudged toward
## the camera every frame or it vanishes inside them when the view swings round.
static func face_camera(b: Sprite3D, anchor: Vector3) -> void:
	var cam := b.get_viewport().get_camera_3d()
	if cam == null:
		return
	var to_cam := cam.global_position - anchor
	to_cam.y = 0.0
	if to_cam.length() < 0.01:
		return
	b.global_position = anchor + to_cam.normalized() * BLAZE_LIFT

## The floating marker that says which crew a marked thing is waiting on. It
## rises and pops in -- a model can't fade, so scale carries the entrance.
static func banner(owner: Node3D, scene: PackedScene, y: float, scale: float) -> Node3D:
	var s := model(scene, scale)
	owner.add_child(s)
	s.position = Vector3(0, y - 0.4, 0)
	s.scale = Vector3.ZERO
	var t := owner.create_tween().set_parallel(true)
	t.tween_property(s, "position:y", y, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "scale", Vector3.ONE * scale, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return s

static func shake(owner: Node3D, s: Node3D, base_x: float, amount: float) -> void:
	var t := owner.create_tween()
	t.tween_property(s, "position:x", base_x + amount, 0.04)
	t.tween_property(s, "position:x", base_x - amount, 0.06)
	t.tween_property(s, "position:x", base_x, 0.05)

## Sprites flash bright; 3D models (no `modulate`) get a quick squash-pulse instead.
static func hit_flash(owner: Node3D, s: Node3D) -> void:
	var t := owner.create_tween()
	if s is Sprite3D:
		t.tween_property(s, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.04)
		t.tween_property(s, "modulate", Color(1, 1, 1, 1), 0.14)
	else:
		var base: Vector3 = s.scale
		t.tween_property(s, "scale", base * Vector3(1.06, 0.94, 1.06), 0.04)
		t.tween_property(s, "scale", base, 0.14)

## Foliage shaken loose, fluttering down.
static func leaves(owner: Node3D, at: Vector3, n: int, high: float, low: float, spread: float) -> void:
	for i in range(n):
		var leaf := particle(CHIP_TEX, 0.012)
		leaf.modulate = Color(0.34 + randf() * 0.24, 0.52 + randf() * 0.26, 0.24, 1.0)
		owner.get_tree().current_scene.add_child(leaf)
		var a := randf() * TAU
		var start := at + Vector3(cos(a), 0, sin(a)) * randf_range(0.2, spread)
		start.y = randf_range(low, high)
		leaf.global_position = start
		var land := start + Vector3(cos(a), 0, sin(a)) * 0.45
		land.y = 0.08
		var t := leaf.create_tween()
		t.tween_property(leaf, "global_position", land, randf_range(1.0, 1.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(leaf, "modulate:a", 0.0, 1.5)
		t.tween_callback(leaf.queue_free)

## Chips / dust thrown out from a point, biased along `dir`.
static func debris(owner: Node3D, at: Vector3, dir: Vector3, n: int, color: Color, px: float, reach: float) -> void:
	for i in range(n):
		var p := particle(CHIP_TEX, px)
		p.modulate = color
		owner.get_tree().current_scene.add_child(p)
		p.global_position = at
		var d := (dir + Vector3(randf_range(-0.7, 0.7), 0, randf_range(-0.7, 0.7))).normalized()
		var apex := at + d * 0.3 + Vector3(0, 0.35, 0)
		var land := at + d * randf_range(reach * 0.5, reach)
		land.y = 0.08
		var t := p.create_tween()
		t.tween_property(p, "global_position", apex, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(p, "global_position", land, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(p, "modulate:a", 0.0, 0.4)
		t.tween_callback(p.queue_free)
