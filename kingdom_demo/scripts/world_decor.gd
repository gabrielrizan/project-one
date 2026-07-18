extends Node3D
## Dresses the world beyond the village: a dirt path out the north gate, patches of
## varied ground, a few gentle hills, scattered rocks, and a ring of mixed forest
## with several tree shapes and shades. Everything here is decorative -- it spawns
## at _ready() from a fixed seed so the layout is stable between runs.

const S := "res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/"
const C := "res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/"
const COLORMAP := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/Textures/colormap.png")

@export var tree_count := 120        # scattered woodland
@export var grove_count := 6         # dense clumps that read as forest
@export var patch_count := 22
@export var rock_count := 18
@export var inner_radius := 13.0     # keep the ring clear of the village
@export var outer_radius := 48.0
@export var world_seed := 7

# green shades pines are tinted with -- kept close to white so trunks stay natural
const PINE_TINTS := [
	Color(1, 1, 1), Color(0.82, 0.98, 0.72), Color(0.7, 0.9, 0.6),
	Color(0.92, 1.0, 0.82), Color(0.6, 0.82, 0.5), Color(0.78, 0.86, 0.66),
]
const PATCH_COLORS := [
	Color(0.33, 0.5, 0.24), Color(0.3, 0.55, 0.28), Color(0.44, 0.34, 0.2),
	Color(0.5, 0.42, 0.26), Color(0.72, 0.66, 0.42),
]

var _pines: Array = []
var _autumn: Array = []
var _bigtrees: Array = []
var _rocks: Array = []
var _pine_mats: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = world_seed
	_pines = [load(S + "tree.glb"), load(S + "tree-tall.glb")]
	_autumn = [load(S + "tree-autumn.glb"), load(S + "tree-autumn-tall.glb")]
	_bigtrees = [load(C + "tree-large.glb"), load(C + "tree-small.glb")]
	_rocks = [load(S + "rock-a.glb"), load(S + "rock-b.glb"), load(S + "rock-c.glb")]
	for c in PINE_TINTS:
		_pine_mats.append(_tex_mat(COLORMAP, c))
	_build_paths()
	_build_hills()
	_scatter_patches()
	_scatter_rocks()
	_grow_forest()

# ---------------------------------------------------------------- helpers

func _flat_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _tex_mat(tex: Texture2D, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = 1.0
	# mipmaps + linear so the tiny colour atlas doesn't bleed between swatches at range
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return m

## A point in the clearing-free ring around the village.
func _ring_point() -> Vector3:
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * (outer_radius - inner_radius) + inner_radius
	return Vector3(cos(a) * r, 0, sin(a) * r)

func _tint_model(n: Node, mat: StandardMaterial3D) -> void:
	if n is MeshInstance3D:
		n.material_override = mat
	for c in n.get_children():
		_tint_model(c, mat)

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
	# crown the hill with a couple of trees
	for i in range(_rng.randi_range(1, 3)):
		var a := _rng.randf() * TAU
		var rr := _rng.randf() * radius * 0.5
		var t := _make_tree()
		body.add_child(t)
		t.position = Vector3(cos(a) * rr, height * 0.85, sin(a) * rr)

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
		var p := _ring_point()
		mi.position = Vector3(p.x, 0.02, p.z)
		mi.rotation.y = _rng.randf() * TAU

# ---------------------------------------------------------------- rocks

func _scatter_rocks() -> void:
	for i in range(rock_count):
		var rock: Node3D = (_rocks[_rng.randi() % _rocks.size()] as PackedScene).instantiate()
		add_child(rock)
		var p := _ring_point()
		rock.position = p
		var s := _rng.randf_range(0.6, 1.7)
		rock.scale = Vector3(s, s, s)
		rock.rotation.y = _rng.randf() * TAU

# ---------------------------------------------------------------- forest

func _grow_forest() -> void:
	# open scattered woodland across the ring
	for i in range(tree_count):
		_plant(_ring_point())
	# dense groves so parts of it read as proper forest
	for g in range(grove_count):
		var centre := _ring_point()
		var n := _rng.randi_range(9, 16)
		for j in range(n):
			var a := _rng.randf() * TAU
			var r := sqrt(_rng.randf()) * _rng.randf_range(3.0, 5.5)
			_plant(centre + Vector3(cos(a) * r, 0, sin(a) * r))

func _plant(pos: Vector3) -> void:
	var t := _make_tree()
	add_child(t)
	t.position = Vector3(clampf(pos.x, -48.0, 48.0), 0.0, clampf(pos.z, -48.0, 48.0))
	t.rotation.y = _rng.randf() * TAU

## Builds one tree with random shape / size / colour.
func _make_tree() -> Node3D:
	var roll := _rng.randf()
	var tree: Node3D
	if roll < 0.6:
		tree = (_pines[_rng.randi() % _pines.size()] as PackedScene).instantiate()
		var s := _rng.randf_range(1.0, 1.7)
		tree.scale = Vector3(s, s * _rng.randf_range(0.9, 1.2), s)
		_tint_model(tree, _pine_mats[_rng.randi() % _pine_mats.size()])
	elif roll < 0.82:
		tree = (_autumn[_rng.randi() % _autumn.size()] as PackedScene).instantiate()
		var s := _rng.randf_range(1.0, 1.6)
		tree.scale = Vector3(s, s, s)
	else:
		tree = (_bigtrees[_rng.randi() % _bigtrees.size()] as PackedScene).instantiate()
		var s := _rng.randf_range(1.1, 1.9)
		tree.scale = Vector3(s, s, s)
	return tree
