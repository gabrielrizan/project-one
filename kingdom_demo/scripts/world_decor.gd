extends Node3D
## Dresses the world beyond the village: dirt paths, ground patches, a few gentle
## hills, and a lively ring of forest -- trees, rocks, bushes and ground detail --
## all from the imported nature-pack via [NaturePack].
##
## **Two layers, one seed.** The colliding, unchanging things (paths, hills, colour
## patches) are built once at _ready. The vegetation lives under a `_veg` holder and
## is **re-grown whenever the season changes** (weather.gd's `season_changed`): the
## layout rng is reset to the same seed every time, so the forest keeps its exact
## shape and only its *coat* changes -- green in spring/summer, autumn colours in
## autumn, snow-laden in winter. Because vegetation carries no collider, re-skinning
## never touches the navmesh.
##
## Sizes come from [NaturePack.spawn], which auto-scales each raw FBX to a target
## height by its own bounding box -- so the numbers below are heights in metres, and
## that is the only size knob.

@export var tree_count := 120        # scattered woodland
@export var grove_count := 6         # dense clumps that read as forest
@export var rock_count := 34         # lots of rock for a lived-in, varied floor
@export var bush_count := 16
@export var detail_count := 60       # grass, flowers, plants, the odd stump/log
@export var patch_count := 22
@export var inner_radius := 13.0     # keep the ring clear of the village
@export var outer_radius := 48.0
@export var world_seed := 7

# Season indices -- mirror weather.gd's Season enum (SPRING/SUMMER/AUTUMN/WINTER).
const SPRING := 0
const SUMMER := 1
const AUTUMN := 2
const WINTER := 3

# Target heights in metres (NaturePack auto-scales each model to fit).
const TREE_H := Vector2(4.0, 7.5)
const ROCK_H := Vector2(0.5, 2.2)
const BUSH_H := Vector2(0.7, 1.4)
const DETAIL_H := Vector2(0.28, 0.7)
const STUMP_H := Vector2(0.5, 0.95)
const LOG_H := Vector2(0.35, 0.6)

## The ground reads as snowfield in winter: its albedo lerps toward this. The mesh
## material is world_decor's to tint -- day_night_cycle only writes the environment,
## never the ground, so there is no second writer to fight (see its gotcha note).
const SNOW_GROUND := Color(0.86, 0.89, 0.95)

const PATCH_COLORS := [
	Color(0.33, 0.5, 0.24), Color(0.3, 0.55, 0.28), Color(0.44, 0.34, 0.2),
	Color(0.5, 0.42, 0.26), Color(0.72, 0.66, 0.42),
]

var _rng := RandomNumberGenerator.new()   # one-time layout: hills, paths, patches
var _vrng := RandomNumberGenerator.new()  # vegetation layout, reset every re-skin
var _veg: Node3D = null
var _season := SPRING
var _variant := "___"                     # NaturePack variant currently planted
var _ground_mat: StandardMaterial3D = null
var _ground_base := Color(1, 1, 1)

func _ready() -> void:
	_rng.seed = world_seed
	_build_paths()
	_build_hills()
	_scatter_patches()
	_veg = Node3D.new()
	add_child(_veg)
	_cache_ground()
	# Follow the season clock. Deferred so it doesn't matter whether Weather has
	# joined its group yet; the first grow happens here off the current season.
	call_deferred("_hook_weather")

func _hook_weather() -> void:
	var w := get_tree().get_first_node_in_group("weather")
	if w and w.has_signal("season_changed"):
		if not w.season_changed.is_connected(_on_season_changed):
			w.season_changed.connect(_on_season_changed)
		_on_season_changed(w.season())
	else:
		_on_season_changed(SPRING)   # no weather -- dress it as spring and stand still

func _on_season_changed(season: int) -> void:
	_season = season
	_apply_ground_snow()
	var variant := _variant_for(season)
	# Spring and summer are both green: only re-grow when the coat actually changes,
	# so an ordinary spring->summer tick costs nothing.
	if variant != _variant:
		_variant = variant
		_grow_vegetation()

func _variant_for(season: int) -> String:
	if season == AUTUMN:
		return NaturePack.AUTUMN
	if season == WINTER:
		return NaturePack.SNOW
	return NaturePack.GREEN

# ---------------------------------------------------------------- vegetation

## Rebuild the forest for the current variant. Same seed every time, so the layout
## is identical season to season and only the models' coats differ.
func _grow_vegetation() -> void:
	var old := _veg
	_veg = Node3D.new()
	add_child(_veg)
	_vrng.seed = world_seed
	# Fixed-count phases first, so their layout is byte-identical every season and
	# only the models' coats change. `_scatter_detail` draws a season-dependent number
	# of rng values (winter is sparser), so it must come LAST or it would shift every
	# tree that follows it.
	_scatter_rocks()
	_scatter_bushes()
	_grow_forest()
	_scatter_detail()
	if is_instance_valid(old):
		old.queue_free()

func _grow_forest() -> void:
	for i in range(tree_count):
		_plant(_ring_point(_vrng))
	for g in range(grove_count):
		var centre := _ring_point(_vrng)
		var n := _vrng.randi_range(9, 16)
		for j in range(n):
			var a := _vrng.randf() * TAU
			var r := sqrt(_vrng.randf()) * _vrng.randf_range(3.0, 5.5)
			_plant(centre + Vector3(cos(a) * r, 0, sin(a) * r))

func _plant(pos: Vector3) -> void:
	var fam: String = NaturePack.TREE_FAMILIES[_vrng.randi() % NaturePack.TREE_FAMILIES.size()]
	var idx := _vrng.randi_range(1, NaturePack.TREE_MEMBERS)
	var h := _vrng.randf_range(TREE_H.x, TREE_H.y)
	var t := NaturePack.spawn(NaturePack.tree(fam, _variant, idx), h)
	if t == null:
		return
	_veg.add_child(t)
	t.position = Vector3(clampf(pos.x, -48.0, 48.0), 0.0, clampf(pos.z, -48.0, 48.0))
	t.rotation.y = _vrng.randf() * TAU
	# scenery trees carry no script, so `wind.gd` rocks them from the outside
	t.add_to_group("wind_sway")

func _scatter_rocks() -> void:
	for i in range(rock_count):
		var r := NaturePack.spawn(NaturePack.random_rock(_variant, _vrng), _vrng.randf_range(ROCK_H.x, ROCK_H.y))
		_place_veg(r)

func _scatter_bushes() -> void:
	for i in range(bush_count):
		var b := NaturePack.spawn(NaturePack.random_bush(_variant, _vrng), _vrng.randf_range(BUSH_H.x, BUSH_H.y))
		_place_veg(b, true)

## Grass, flowers and plants in the green seasons; in winter the ground detail is
## snow-covered stumps and logs, sparse, so the floor reads as frozen over.
func _scatter_detail() -> void:
	var winter := _variant == NaturePack.SNOW
	var n := int(detail_count * 0.3) if winter else detail_count
	for i in range(n):
		var roll := _vrng.randf()
		var node: Node3D = null
		if winter:
			if roll < 0.5:
				node = NaturePack.spawn(NaturePack.random_stump(_variant, _vrng), _vrng.randf_range(STUMP_H.x, STUMP_H.y))
			else:
				node = NaturePack.spawn(NaturePack.random_log(_variant, _vrng), _vrng.randf_range(LOG_H.x, LOG_H.y))
		elif roll < 0.72:
			node = NaturePack.spawn(NaturePack.random_detail(_vrng), _vrng.randf_range(DETAIL_H.x, DETAIL_H.y))
		elif roll < 0.88:
			node = NaturePack.spawn(NaturePack.random_stump(_variant, _vrng), _vrng.randf_range(STUMP_H.x, STUMP_H.y))
		else:
			node = NaturePack.spawn(NaturePack.random_log(_variant, _vrng), _vrng.randf_range(LOG_H.x, LOG_H.y))
		_place_veg(node)

## Drop a scenery node on an open belly point; `sway` marks bushes for the wind.
func _place_veg(node: Node3D, sway := false) -> void:
	if node == null:
		return
	_veg.add_child(node)
	var p := _ring_point(_vrng)
	node.position = Vector3(p.x, 0.0, p.z)
	node.rotation.y = _vrng.randf() * TAU
	if sway:
		node.add_to_group("wind_sway")

# ---------------------------------------------------------------- ground snow

func _cache_ground() -> void:
	var mesh := get_node_or_null("../Ground/Mesh")
	if mesh and mesh.material_override is StandardMaterial3D:
		_ground_mat = mesh.material_override
		_ground_base = _ground_mat.albedo_color

func _apply_ground_snow() -> void:
	if _ground_mat == null:
		return
	if _season == WINTER:
		_ground_mat.albedo_color = _ground_base.lerp(SNOW_GROUND, 0.78)
	else:
		_ground_mat.albedo_color = _ground_base

# ---------------------------------------------------------------- helpers

func _flat_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

## A point in the clearing-free ring around the village. Scenery carries no
## collider, so it may sit against or beyond the mountains as backdrop -- the ring
## reaches past the play area on purpose. The caller passes which rng to draw from
## (one-time layout vs. the vegetation that re-seeds every season).
func _ring_point(rng: RandomNumberGenerator) -> Vector3:
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf()) * (outer_radius - inner_radius) + inner_radius
	return Vector3(cos(a) * r, 0, sin(a) * r)

# ---------------------------------------------------------------- path

func _build_paths() -> void:
	var dirt := _flat_mat(Color(0.46, 0.34, 0.21))
	# main road leaving the north gate, then bending north-east into the woods
	_add_strip(Vector3(0, 0, -8), Vector3(0, 0, -24), 3.4, dirt)
	_add_strip(Vector3(0, 0, -24), Vector3(16, 0, -40), 3.0, dirt)
	# a shorter spur heading west
	_add_strip(Vector3(0, 0, -22), Vector3(-20, 0, -30), 2.6, dirt)

func _add_strip(from: Vector3, to: Vector3, width: float, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var length := from.distance_to(to)
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.08, length + width)   # overlap ends so joins don't gap
	mi.mesh = box
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var mid := (from + to) * 0.5
	mi.position = Vector3(mid.x, 0.04, mid.z)
	var dir := to - from
	mi.rotation.y = atan2(dir.x, dir.z)

# ---------------------------------------------------------------- hills

func _build_hills() -> void:
	var mat := _flat_mat(Color(0.4, 0.56, 0.3))
	# distant scenery mounds, out past the mountains -- their colliders sit beyond the
	# navmesh bake extent, so they never affect pathing; they just break the skyline.
	var spots := [Vector3(-30, 0, 8), Vector3(26, 0, 20), Vector3(-14, 0, -34), Vector3(34, 0, -6)]
	for spot in spots:
		var r := _rng.randf_range(5.0, 8.0)
		var h := r * _rng.randf_range(0.28, 0.4)
		_add_hill(spot, r, h, mat)

func _add_hill(pos: Vector3, radius: float, height: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = pos
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mi.mesh = sphere
	mi.material_override = mat
	mi.scale = Vector3(1.0, height / radius, 1.0)
	body.add_child(mi)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius * 0.82
	cyl.height = height
	cs.shape = cyl
	cs.position = Vector3(0, height * 0.5, 0)
	body.add_child(cs)

# ---------------------------------------------------------------- ground patches

func _scatter_patches() -> void:
	for i in range(patch_count):
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		var w := _rng.randf_range(3.5, 8.0)
		plane.size = Vector2(w, w * _rng.randf_range(0.7, 1.3))
		mi.mesh = plane
		mi.material_override = _flat_mat(PATCH_COLORS[_rng.randi() % PATCH_COLORS.size()])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var p := _ring_point(_rng)
		mi.position = Vector3(p.x, 0.02, p.z)
		mi.rotation.y = _rng.randf() * TAU
