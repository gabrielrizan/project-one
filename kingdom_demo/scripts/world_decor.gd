extends Node3D
## Dresses the world beyond the village: roads out of the gates, patches of varied
## ground, scattered rocks, and mixed forest filling the horizon. Everything here is
## decorative -- it spawns at _ready() from a fixed seed so the layout is stable
## between runs.
##
## ## Two rules this file has to obey, both learned the hard way
##
## **1. No decorative tree may stand on open, reachable ground.** The forest here
## carries no script and cannot be marked; `map_forest.gd`'s trees can. If the two
## are interleaved, the player rides tree to tree discovering which is which, and
## the marking verb turns into a guessing game. So scenery trees go on the sealed
## gates and out past the map edge, and everything you can actually walk to is
## harvestable. *Reachable means markable* -- see the note in `map_forest.gd`.
##
## **2. Nothing with a collider goes in the playfield.** The hills used to be
## hand-placed `StaticBody3D`s at four fixed spots, which was harmless on the one
## prototype map and is a trap on three: a hill dropped in a 16 m corridor is an
## obstacle the navmesh bakes and no map definition knows about. They are backdrop
## now, placed only where the ground is already sealed.

const S := "res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/"
const C := "res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/"
const COLORMAP := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/Textures/colormap.png")

@export var tree_count := 420        # scattered woodland (rejected samples are cheap)
@export var grove_count := 10        # dense clumps that read as forest
# Scaled up with the map -- the playable belly is roughly 5x the prototype's area,
# so the old counts spread that thin read as a bare field. Patches are raised far
# less than rocks: they are 4-8 m sheets, so their *coverage* grows much faster
# than their count, and at 85 the ground came out a brown patchwork quilt instead
# of grass with some wear in it.
# Patches went down again once the forest filled the playfield: with trees carrying
# the ground detail, big tan sheets stopped being welcome variation and started
# reading as bald dirt.
@export var patch_count := 15
@export var rock_count := 42
@export var hill_count := 5
@export var inner_radius := 13.0     # keep the ring clear of the village
@export var world_seed := 7

## How far past the map's own extent the scenery keeps going. The slab is 180 m
## across and a map is ~110-120 m of it, so the surplus is filled with forest
## rather than left as bare green -- from a 45 deg camera the horizon is the top
## of the frame, and an empty one reads as the world running out.
const BACKDROP_PAD := 34.0

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

## How far out the scenery reaches -- the map's own extent plus the backdrop pad.
func _outer() -> float:
	return MapTerrain.extent() + BACKDROP_PAD

## A point in the clearing-free ring around the village.
func _ring_point() -> Vector3:
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * (_outer() - inner_radius) + inner_radius
	return MapTerrain.village() + Vector3(cos(a) * r, 0, sin(a) * r)

## A point anywhere across the playable ground, including close in.
##
## Used for the things that are safe on open ground -- ground patches and loose
## rocks, which carry no collider and, crucially, are **not trees**, so they cannot
## be mistaken for something markable. They are what keeps the village clearing
## from reading as bare billiard-table green now that the scenery forest has been
## pushed out to the gates.
func _near_point() -> Vector3:
	var a := _rng.randf() * TAU
	var r := _rng.randf_range(4.0, MapTerrain.extent() * 0.9)
	return MapTerrain.village() + Vector3(cos(a) * r, 0, sin(a) * r)

## Ground the scenery is allowed to stand on.
##
## Two exclusions, for two different reasons:
## * **Open ground is out** — see rule 1 in the file header. This is the single check
##   that keeps every reachable tree harvestable.
## * **Rock gates are out** — a tree planted inside a mountain box stands halfway up
##   a stone face, and where the cone geometry does not happen to cover it you get a
##   pine sprouting out of a cliff. Wood gates are exactly where trees belong, and
##   past the map edge is the true backdrop.
func _backdrop(p: Vector3) -> bool:
	if MapTerrain.is_open(p):
		return false
	return MapTerrain.gate_kind_at(p) != MapDef.ROCK

func _tint_model(n: Node, mat: StandardMaterial3D) -> void:
	if n is MeshInstance3D:
		n.material_override = mat
	for c in n.get_children():
		_tint_model(c, mat)

# ---------------------------------------------------------------- path

## Roads drawn from the map rather than hand-plotted: one out of every gate, and
## one on from each gate toward the camp that lies beyond it.
##
## This is doing more than dressing. On a 120 m map a camp is over the horizon from
## the fire, and a road is the cheapest possible direction-giver -- it says "the
## way out is here, and it leads somewhere" without a marker, an arrow or a minimap.
## The camp's own smoke column (`bandit_camp.gd`) takes over once you are moving.
func _build_paths() -> void:
	var dirt := _flat_mat(Color(0.46, 0.34, 0.21))
	var village := MapTerrain.village()
	var camps := MapTerrain.camps()
	for w in MapTerrain.walls():
		var gate: Vector3 = w.pos
		# Start clear of the village, not at its centre. Drawn from the origin the
		# strip runs straight under the campfire and out through the Archers hut,
		# and the first thing the player sees is a dirt slab across their camp.
		var out := (gate - village).normalized()
		_add_strip(village + out * 7.0, gate, 3.0, dirt)
		# and on from the gate to whichever camp lies that way
		var best := Vector3.ZERO
		var best_d := INF
		for c in camps:
			var d: float = (c.pos as Vector3).distance_to(gate)
			if d < best_d:
				best_d = d
				best = c.pos
		if best_d < INF:
			# stop short of the camp -- a road running into the fire pit reads as
			# something the bandits built, and the last stretch wants to feel wild
			var stop := best + (gate - best).normalized() * 6.0
			_add_strip(gate, stop, 3.0, dirt)

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
	# clear of the whole staggered patch stack, so a road always reads on top of
	# the ground variation rather than flickering through it
	mi.position = Vector3(mid.x, 0.09, mid.z)
	var dir := to - from
	mi.rotation.y = atan2(dir.x, dir.z)

# ---------------------------------------------------------------- hills

## Backdrop only -- see rule 2 in the file header. A hill carries a collider, so it
## is placed by rejection sampling onto ground that is already sealed; a hill that
## cannot be reached cannot become an obstacle nobody planned.
func _build_hills() -> void:
	var mat := _flat_mat(Color(0.4, 0.56, 0.3))
	for i in hill_count:
		for tries in 30:
			var spot := _ring_point()
			var r := _rng.randf_range(5.0, 8.0)
			if not _backdrop(spot):
				continue
			var h := r * _rng.randf_range(0.28, 0.4)
			_add_hill(spot, r, h, mat)
			break

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
		var w := _rng.randf_range(3.0, 5.5)
		plane.size = Vector2(w, w * _rng.randf_range(0.7, 1.3))
		mi.mesh = plane
		mi.material_override = _flat_mat(PATCH_COLORS[_rng.randi() % PATCH_COLORS.size()])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var p := _near_point()
		# stagger the height a hair per patch: they are flat sheets on a flat slab,
		# and two coplanar sheets that overlap z-fight into stripes
		mi.position = Vector3(p.x, 0.02 + float(i) * 0.0012, p.z)
		mi.rotation.y = _rng.randf() * TAU

# ---------------------------------------------------------------- rocks

func _scatter_rocks() -> void:
	for i in range(rock_count):
		var rock: Node3D = (_rocks[_rng.randi() % _rocks.size()] as PackedScene).instantiate()
		add_child(rock)
		var p := _near_point()
		rock.position = p
		var s := _rng.randf_range(0.6, 1.7)
		rock.scale = Vector3(s, s, s)
		rock.rotation.y = _rng.randf() * TAU

# ---------------------------------------------------------------- forest

func _grow_forest() -> void:
	# open scattered woodland across the ring. Most samples land on ground the
	# player can walk and are thrown away, which is why the count is generous --
	# a rejected sample costs a bounds test, not a model.
	for i in range(tree_count):
		_plant(_ring_point())
	# dense groves so parts of it read as proper forest
	for g in range(grove_count):
		var centre := _ring_point()
		if not _backdrop(centre):
			continue
		var n := _rng.randi_range(9, 16)
		for j in range(n):
			var a := _rng.randf() * TAU
			var r := sqrt(_rng.randf()) * _rng.randf_range(3.0, 5.5)
			_plant(centre + Vector3(cos(a) * r, 0, sin(a) * r))

func _plant(pos: Vector3) -> void:
	# the one gate keeping every reachable tree harvestable (rule 1, file header)
	if not _backdrop(pos):
		return
	var lim := _outer()
	var t := _make_tree()
	add_child(t)
	t.position = Vector3(clampf(pos.x, -lim, lim), 0.0, clampf(pos.z, -lim, lim))
	t.rotation.y = _rng.randf() * TAU
	# scenery trees carry no script, so `wind.gd` rocks them from the outside
	t.add_to_group("wind_sway")

## Builds one tree with random shape / size / colour.
##
## **Roughly doubled** so the woodland towers over a village whose tallest tier is
## a 3 m castle: mature trees now land around 3-6.5 m against a 1.2 m villager, so
## the clearing reads as cut *into* a forest rather than sitting beside a hedge.
## The ranges are what stop the treeline looking like a comb, so they were widened
## with the scale rather than replaced by one size.
func _make_tree() -> Node3D:
	var roll := _rng.randf()
	var tree: Node3D
	if roll < 0.6:
		tree = (_pines[_rng.randi() % _pines.size()] as PackedScene).instantiate()
		var s := _rng.randf_range(2.0, 3.4)
		tree.scale = Vector3(s, s * _rng.randf_range(0.9, 1.2), s)
		_tint_model(tree, _pine_mats[_rng.randi() % _pine_mats.size()])
	elif roll < 0.82:
		tree = (_autumn[_rng.randi() % _autumn.size()] as PackedScene).instantiate()
		var s := _rng.randf_range(2.0, 3.2)
		tree.scale = Vector3(s, s, s)
	else:
		tree = (_bigtrees[_rng.randi() % _bigtrees.size()] as PackedScene).instantiate()
		var s := _rng.randf_range(2.2, 3.8)
		tree.scale = Vector3(s, s, s)
	return tree
