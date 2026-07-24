extends Node3D
## The mountains that gate map 1 (COMBAT_PROMPTS P1).
##
## Reads [MapTerrain.MOUNTAINS] and, per box, stamps one **invisible box collider**
## (the thing that actually seals the bearing and gives the navmesh a single clean
## edge) and raises a ridge of **tall flat-shaded low-poly stone peaks that carry
## no collider of their own** -- so the look is a mountain range but the navmesh
## only ever sees five clean boxes. The world stays one flat slab; these are rock
## walls standing on flat ground, not elevation.
##
## Placeholder-then-pack, in the spirit of the bandit art (GAME_DESIGN §11): the
## peaks are generated so nothing has to be downloaded to unblock the map. A
## bought low-poly mountain pack can replace [method _peak] later without touching
## the layout, which lives entirely in [MapTerrain].
##
## Built in code from the one terrain definition rather than hand-placed in the
## scene, so the colliders, the peaks, the wanderer walk-in and the wildlife ring
## can't fall out of step -- they all read [MapTerrain].

## Stone / charcoal greys, all in palette. Shared so the range isn't one material
## per peak; picked at random for a little variation across the ridge.
const STONE_COLORS := [
	Color(0.44, 0.45, 0.49), Color(0.36, 0.37, 0.42),
	Color(0.52, 0.50, 0.48), Color(0.40, 0.42, 0.45),
]

var _rng := RandomNumberGenerator.new()
var _mats: Array[StandardMaterial3D] = []

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
	for box in MapTerrain.MOUNTAINS:
		_seal(box.c, box.s)
		peaks += _range(box.c, box.s)
	print("[mountains] sealed the U (%d boxes), raised %d peaks" % [MapTerrain.MOUNTAINS.size(), peaks])
	# The colliders were just added, so make the navmesh account for them. If this
	# node readied before NavWorld it's a harmless no-op (the region isn't in its
	# group yet and bakes with the colliders present anyway); if after, this folds
	# them in. Either way nothing walks before the first wanderer, seconds in.
	NavWorld.rebake(self)

## One invisible StaticBody box. No mesh -- the peaks are the only thing you see.
func _seal(centre: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = centre
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)

## A ridgeline down the box's long axis: a front row seated on the collider's
## inner face (so it hides the invisible wall and reads as where the ground stops)
## and a taller row set back behind it for a jagged silhouette against the sky.
func _range(centre: Vector3, size: Vector3) -> int:
	var horizontal := size.x >= size.z          # long axis is x, else z
	var long_len := maxf(size.x, size.z)
	var base_r := minf(size.x, size.z) * 0.5     # fills the width; inner edge ~ collider face
	# push the back row away from the village (down the box's dominant bearing)
	var outward := Vector3(signf(centre.x), 0, 0) if absf(centre.x) > absf(centre.z) \
		else Vector3(0, 0, signf(centre.z))
	var n := maxi(2, int(long_len / (base_r * 1.35)))
	var made := 0
	for i in n + 1:
		var along := lerpf(-long_len * 0.5, long_len * 0.5, float(i) / n)
		var pos := centre + (Vector3(along, 0, 0) if horizontal else Vector3(0, 0, along))
		pos.y = 0.0
		_peak(pos, base_r * _rng.randf_range(0.95, 1.2), _rng.randf_range(11.0, 17.0))
		_peak(pos + outward * base_r * 0.7, base_r * _rng.randf_range(0.7, 1.0),
			_rng.randf_range(16.0, 24.0))
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
