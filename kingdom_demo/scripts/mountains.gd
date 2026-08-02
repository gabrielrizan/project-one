extends Node3D
## The terrain gates that seal the map's closed bearings (COMBAT_PROMPTS P1).
##
## Reads [method MapTerrain.gates] and, per box, stamps one **invisible box
## collider** -- the thing that actually seals the bearing and gives the navmesh a
## single clean edge -- then dresses it according to the box's `kind`:
##
## * [constant MapDef.ROCK] raises a ridge of tall flat-shaded low-poly stone peaks.
## * [constant MapDef.WOOD] plants a dense band of trees instead, for maps whose
##   walls are forest rather than cliff (GAME_DESIGN §9 lists "a wood too dense to
##   pass" as a terrain gate in its own right).
##
## **Neither dressing carries a collider.** The look is a mountain range or a deep
## wood; the navmesh only ever sees the boxes. That is what keeps a bearing free to
## seal with no per-prop bookkeeping, and it is why the wood can be drawn far wider
## than the box it stands on -- visual depth costs nothing.
##
## The one exception is a **carve lane**: a gap deliberately left in a wood gate and
## plugged with *harvestable* trees, which do carry colliders. Those are planted by
## `map_forest.gd`, not here, because they are resources rather than scenery.
##
## Placeholder-then-pack, in the spirit of the bandit art (§11): the peaks are
## generated so nothing has to be downloaded. A bought low-poly mountain pack can
## replace [method _peak] later without touching any layout, which lives entirely
## in [MapDef].

const SK := "res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/"
const CK := "res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/"
const COLORMAP := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/Textures/colormap.png")

## Stone / charcoal greys, all in palette. Shared so the range isn't one material
## per peak; picked at random for a little variation across the ridge.
const STONE_COLORS := [
	Color(0.44, 0.45, 0.49), Color(0.36, 0.37, 0.42),
	Color(0.52, 0.50, 0.48), Color(0.40, 0.42, 0.45),
]

## Deep, slightly darker greens for the wall-of-forest -- a shade below the
## harvestable trees so a gate reads as depth rather than as more timber.
const WOOD_TINTS := [
	Color(0.62, 0.78, 0.52), Color(0.54, 0.70, 0.46),
	Color(0.70, 0.84, 0.58), Color(0.48, 0.64, 0.42),
]

## One tree per this many square metres of gate footprint. Dense enough that you
## cannot see daylight through it from the village, which is the whole point of a
## wood you are told you cannot pass.
const WOOD_DENSITY := 7.0
## How far the dressing spills past the collider, so the wood has visible depth
## behind the line that actually stops you.
const WOOD_SPILL := 7.0

var _rng := RandomNumberGenerator.new()
var _mats: Array[StandardMaterial3D] = []
var _wood_mats: Array[StandardMaterial3D] = []
var _trees: Array = []

func _ready() -> void:
	_rng.seed = 1917
	for c in STONE_COLORS:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		# no bottom cap on the cones -- don't cull, so nothing shows through at a
		# grazing angle; the 45 deg camera never sees the open base anyway.
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats.append(m)

	var peaks := 0
	var trees := 0
	for box in MapTerrain.gates():
		_seal(box.c, box.s)
		if String(box.get("kind", MapDef.ROCK)) == MapDef.WOOD:
			trees += _wood(box.c, box.s)
		else:
			peaks += _ridge(box.c, box.s)
	print("[terrain] %s: sealed %d boxes, %d peaks, %d gate trees"
		% [MapTerrain.map().id, MapTerrain.gates().size(), peaks, trees])

	# The colliders were just added, so make the navmesh account for them. If this
	# node readied before NavWorld it's a harmless no-op (the region isn't in its
	# group yet and bakes with the colliders present anyway); if after, this folds
	# them in. Either way nothing walks before the first wanderer, seconds in.
	NavWorld.rebake(self)

## One invisible StaticBody box. No mesh -- the dressing is the only thing you see.
func _seal(centre: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = centre
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)

# ---------------------------------------------------------------- rock

## A ridgeline down the box's long axis: a front row seated on the collider's
## inner face (so it hides the invisible wall and reads as where the ground stops)
## and a taller row set back behind it for a jagged silhouette against the sky.
func _ridge(centre: Vector3, size: Vector3) -> int:
	var horizontal := size.x >= size.z          # long axis is x, else z
	var long_len := maxf(size.x, size.z)
	var base_r := minf(size.x, size.z) * 0.5     # fills the width; inner edge ~ collider face
	# push the back row away from the village (down the box's dominant bearing)
	var outward := Vector3(signf(centre.x), 0, 0) if absf(centre.x) > absf(centre.z) \
		else Vector3(0, 0, signf(centre.z))
	# **More peaks, only a little taller.** The count is the part that matters for the
	# look: a range built from a handful of 12 m-radius cones reads as scattered
	# boulders rather than terrain, and packing them tighter makes a continuous ridge.
	#
	# Height was pushed to 16-34 m first, to force the camps beyond to be occluded.
	# That was the wrong lever and it broke something better: a 16 m corridor flanked
	# by 30 m cones is a grey slot canyon, and riding out of the gate meant staring
	# at rock with no sky and barely any ground in frame. Hiding a camp is **distance
	# and route** (a camp sits 50 m out and the way to it bends), not wall height.
	var n := maxi(3, int(long_len / (base_r * 0.8)))
	var made := 0
	for i in n + 1:
		var along := lerpf(-long_len * 0.5, long_len * 0.5, float(i) / n)
		var pos := centre + (Vector3(along, 0, 0) if horizontal else Vector3(0, 0, along))
		pos.y = 0.0
		_peak(pos, base_r * _rng.randf_range(0.78, 1.0), _rng.randf_range(12.0, 17.0))
		_peak(pos + outward * base_r * 0.62, base_r * _rng.randf_range(0.62, 0.9),
			_rng.randf_range(17.0, 24.0))
		made += 2
	return made

## One flat-shaded low-poly peak: a jagged 5-7 sided cone, base sunk a little into
## the slab so the open bottom never shows.
func _peak(pos: Vector3, base_radius: float, height: float) -> void:
	var sides := _rng.randi_range(5, 7)
	var apex := Vector3(_rng.randf_range(-1.2, 1.2), height, _rng.randf_range(-1.2, 1.2))
	var ring: Array[Vector3] = []
	for i in sides:
		var a := TAU * i / sides + _rng.randf_range(-0.18, 0.18)
		var r := base_radius * _rng.randf_range(0.8, 1.18)
		ring.append(Vector3(cos(a) * r, _rng.randf_range(-0.4, 0.7), sin(a) * r))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)   # -1 => flat per-face normals from generate_normals()
	for i in sides:
		# winding (apex, next, cur) faces the normals outward and up (verified)
		st.add_vertex(apex)
		st.add_vertex(ring[(i + 1) % sides])
		st.add_vertex(ring[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mats[_rng.randi() % _mats.size()]
	# non-casting: a 20 m peak at a low sun would rake a shadow clean across the
	# map and plunge the village into dark half the day. Its own flat-shaded faces
	# still read as 3-D from the sun. Revisit if it wants shadows (GAME_DESIGN).
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = Vector3(pos.x, -0.5, pos.z)
	mi.rotation.y = _rng.randf() * TAU

# ---------------------------------------------------------------- wood

## A band of dense trees over (and spilling past) the box. Scenery only: the box
## underneath is what stops anyone, so the trees can be as sparse or as thick as
## the look needs without ever changing what is walkable.
func _wood(centre: Vector3, size: Vector3) -> int:
	_load_trees()
	var hx := size.x * 0.5 + WOOD_SPILL
	var hz := size.z * 0.5 + WOOD_SPILL
	var n := int((hx * 2.0) * (hz * 2.0) / WOOD_DENSITY)
	var made := 0
	for i in n:
		var p := centre + Vector3(
			_rng.randf_range(-hx, hx), 0.0, _rng.randf_range(-hz, hz))
		# Never spill onto ground the player walks. The gate's own footprint is
		# fine, and so is everything past the map edge (that is where the wood
		# gets its visible depth), but a trunk standing in the trail would look
		# solid and not be -- the exact contradiction the carve lanes exist to
		# make honest.
		if MapTerrain.is_open(p):
			continue
		# ...and never onto a neighbouring rock gate, where the spill from a wood
		# would come out as trees growing up a cliff face
		if MapTerrain.gate_kind_at(p) == MapDef.ROCK:
			continue
		_plant(p)
		made += 1
	return made

func _plant(pos: Vector3) -> void:
	var scene: PackedScene = _trees[_rng.randi() % _trees.size()]
	var t: Node3D = scene.instantiate()
	add_child(t)
	t.position = Vector3(pos.x, 0.0, pos.z)
	var s := _rng.randf_range(2.4, 4.2)
	t.scale = Vector3(s, s * _rng.randf_range(0.9, 1.25), s)
	t.rotation.y = _rng.randf() * TAU
	_tint(t, _wood_mats[_rng.randi() % _wood_mats.size()])
	# scenery trees carry no script, so `wind.gd` rocks them from the outside
	t.add_to_group("wind_sway")

func _load_trees() -> void:
	if not _trees.is_empty():
		return
	_trees = [
		load(SK + "tree.glb"), load(SK + "tree-tall.glb"),
		load(SK + "tree-autumn-tall.glb"), load(CK + "tree-large.glb"),
	]
	for c in WOOD_TINTS:
		var m := StandardMaterial3D.new()
		m.albedo_texture = COLORMAP
		m.albedo_color = c
		m.roughness = 1.0
		# mipmaps + linear so the tiny colour atlas doesn't bleed between swatches
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_wood_mats.append(m)

func _tint(n: Node, mat: StandardMaterial3D) -> void:
	if n is MeshInstance3D:
		n.material_override = mat
	for c in n.get_children():
		_tint(c, mat)
