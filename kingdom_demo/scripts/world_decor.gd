extends Node3D
## Dresses the world beyond the village: gentle hills, and a lively ring of forest --
## trees, rocks, bushes and ground detail -- all from the imported nature-pack via
## [NaturePack].
##
## ⚠️ **Two things this file used to draw and deliberately no longer does** (2026-08-04),
## both flat quads lying on the slab, and both removed for the same reason: on a wooded
## island they read as *maintenance*, not as wilderness.
##
## * **Dirt roads out of each gate and on to the nearest camp.** The argument for them
##   was that a road is the cheapest direction-giver on a 120 m map -- it says "the way
##   out is here, and it leads somewhere" with no marker and no HUD. What it actually
##   drew was a mown strip pointing straight at the thing the player is supposed to
##   discover, which is the same mistake the island's `keep_clear` camp lanes made and
##   were removed for. What leads outward now: the smoke columns, the lit wall lanterns
##   on a raid bearing, and the fog frontier itself.
## * **Scattered colour patches** -- 15 tan and green sheets 3.5-8 m across, meant as
##   ground variation. From the map camera they are unmistakably rectangles, because
##   that is what they are, and no amount of recolouring fixes a shape. `_scatter_detail`
##   (grass, flowers, stumps, logs) is what dresses the floor now; it is *models*, so it
##   never has an edge to give itself away.
##
## Don't re-add either as a flat quad. If the ground needs variation, it wants to come
## from the ground material or from more scattered models, not from sheets laid on top.
##
## **Two layers, one seed.** The colliding, unchanging things (the hills) are built once
## at _ready. The vegetation lives under a `_veg` holder and
## is **re-grown whenever the season changes** (weather.gd's `season_changed`): the
## layout rng is reset to the same seed every time, so the forest keeps its exact
## shape and only its *coat* changes -- green in spring/summer, autumn colours in
## autumn, snow-laden in winter. Because vegetation carries no collider, re-skinning
## never touches the navmesh.
##
## Sizes come from [NaturePack.spawn], which auto-scales each raw FBX to a target
## height by its own bounding box -- so the numbers below are heights in metres, and
## that is the only size knob.
##
## ## Two rules this file has to obey, both learned the hard way
##
## **1. No decorative tree may stand on open, reachable ground.** The forest here
## carries no script and cannot be marked; `map_forest.gd`'s trees can. Since the
## nature-pack swap the two are drawn from the *same models* -- `tree_resource.gd`
## spawns `NaturePack.tree()` exactly like `_plant()` below -- so there is no longer
## any visual tell at all. Interleave them and the player rides tree to tree
## discovering which is which, and the marking verb turns into a guessing game. So
## scenery trees go on the sealed wood gates and out past the map edge, and
## everything you can actually walk to is harvestable. *Reachable means markable* --
## see the note in `map_forest.gd`. Scenery bushes obey the same gate, for the same
## reason against `berry_bush.gd`.
##
## **2. Nothing with a collider goes in the playfield.** The hills used to be
## hand-placed `StaticBody3D`s at four fixed spots, which was harmless on the one
## prototype map and is a trap on three: a hill dropped in a 16 m corridor is an
## obstacle the navmesh bakes and no map definition knows about. They are backdrop
## now, placed only where the ground is already sealed.
##
## Rocks and small detail (grass, flowers, stumps, logs) are exempt from rule 1 --
## neither is markable, so neither can be mistaken for something the monarch could buy
## -- and they are what keeps the village clearing from reading as bare
## billiard-table green.

@export var tree_count := 420        # scattered woodland (rejected samples are cheap)
@export var grove_count := 10        # dense clumps that read as forest
@export var rock_count := 42         # lots of rock for a lived-in, varied floor
@export var bush_count := 16
@export var detail_count := 60       # grass, flowers, plants, the odd stump/log
@export var hill_count := 5
@export var inner_radius := 13.0     # keep the ring clear of the village
@export var world_seed := 7

## How far past the map's own extent the scenery keeps going. The slab is 180 m
## across and a map is ~110-120 m of it, so the surplus is filled with forest
## rather than left as bare green -- from a 45 deg camera the horizon is the top
## of the frame, and an empty one reads as the world running out.
const BACKDROP_PAD := 34.0

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

## Tries a rejection-sampled placement gets before it gives up. Trees can afford to
## skip outright -- there are hundreds of samples -- but the low-count categories
## (hills, bushes) would come out visibly short, so they retry.
const PLACE_TRIES := 24

var _rng := RandomNumberGenerator.new()   # one-time layout: the hills
var _vrng := RandomNumberGenerator.new()  # vegetation layout, reset every re-skin
var _veg: Node3D = null
var _season := SPRING
var _variant := "___"                     # NaturePack variant currently planted
var _ground_mat: StandardMaterial3D = null
var _ground_base := Color(1, 1, 1)

func _ready() -> void:
	_rng.seed = world_seed
	_build_hills()
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
##
## Rejection sampling does not break that: what a sample is tested against is the
## map's geometry, which never changes mid-run, so accepted and rejected draws fall
## in exactly the same places every re-skin.
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
	# open scattered woodland across the ring. Most samples land on ground the
	# player can walk and are thrown away, which is why the count is generous --
	# a rejected sample costs a bounds test, not a model.
	for i in range(tree_count):
		_plant(_ring_point(_vrng))
	# dense groves so parts of it read as proper forest
	for g in range(grove_count):
		var centre := _ring_point(_vrng)
		if not _backdrop(centre):
			continue
		var n := _vrng.randi_range(9, 16)
		for j in range(n):
			var a := _vrng.randf() * TAU
			var r := sqrt(_vrng.randf()) * _vrng.randf_range(3.0, 5.5)
			_plant(centre + Vector3(cos(a) * r, 0, sin(a) * r))

func _plant(pos: Vector3) -> void:
	# the one gate keeping every reachable tree harvestable (rule 1, file header).
	# Tested before any model is drawn, so a rejected sample costs nothing.
	if not _backdrop(pos):
		return
	var fam: String = NaturePack.TREE_FAMILIES[_vrng.randi() % NaturePack.TREE_FAMILIES.size()]
	var idx := _vrng.randi_range(1, NaturePack.TREE_MEMBERS)
	var h := _vrng.randf_range(TREE_H.x, TREE_H.y)
	var t := NaturePack.spawn(NaturePack.tree(fam, _variant, idx), h)
	if t == null:
		return
	_veg.add_child(t)
	var lim := _outer()
	t.position = Vector3(clampf(pos.x, -lim, lim), 0.0, clampf(pos.z, -lim, lim))
	t.rotation.y = _vrng.randf() * TAU
	# scenery trees carry no script, so `wind.gd` rocks them from the outside
	t.add_to_group("wind_sway")
	FogOfWar.hide_until_found(t)

func _scatter_rocks() -> void:
	for i in range(rock_count):
		var r := NaturePack.spawn(NaturePack.random_rock(_variant, _vrng), _vrng.randf_range(ROCK_H.x, ROCK_H.y))
		_place_veg(r, _near_point(_vrng))

## Scenery bushes are backdrop-only, like the trees: `berry_bush.gd`'s bushes are
## markable, and a shrub you cannot buy standing next to one you can is rule 1 all
## over again in miniature.
func _scatter_bushes() -> void:
	for i in range(bush_count):
		var b := NaturePack.spawn(NaturePack.random_bush(_variant, _vrng), _vrng.randf_range(BUSH_H.x, BUSH_H.y))
		var p := _backdrop_point(_vrng)
		# `_backdrop_point` falls back to its last draw when every try was rejected,
		# which on a map with no backdrop at all (an island) is every time -- so the
		# gate has to be re-checked here or the fallback plants a shrub in the sea.
		if not _backdrop(p):
			continue
		_place_veg(b, p, true)

## Grass, flowers and plants in the green seasons; in winter the ground detail is
## snow-covered stumps and logs, sparse, so the floor reads as frozen over.
##
## None of it is markable, so unlike the trees it is welcome on open ground -- this
## is what dresses the playfield the monarch actually rides across.
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
		_place_veg(node, _near_point(_vrng))

## Drop a scenery node at an already-chosen point; `sway` marks it for the wind.
func _place_veg(node: Node3D, pos: Vector3, sway := false) -> void:
	if node == null:
		return
	_veg.add_child(node)
	node.position = Vector3(pos.x, 0.0, pos.z)
	node.rotation.y = _vrng.randf() * TAU
	if sway:
		node.add_to_group("wind_sway")
	FogOfWar.hide_until_found(node)

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

## How far out the scenery reaches -- the map's own extent plus the backdrop pad.
func _outer() -> float:
	return MapTerrain.extent() + BACKDROP_PAD

## A point in the clearing-free ring around the village. The caller passes which rng
## to draw from (one-time layout vs. the vegetation that re-seeds every season).
func _ring_point(rng: RandomNumberGenerator) -> Vector3:
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf()) * (_outer() - inner_radius) + inner_radius
	return MapTerrain.village() + Vector3(cos(a) * r, 0, sin(a) * r)

## A point anywhere across the playable ground, including close in.
##
## Used for the things that are safe on open ground -- ground patches, loose rocks
## and small detail, which carry no collider and, crucially, are **not markable**,
## so they cannot be mistaken for something the monarch could buy.
##
## It draws off [method MapTerrain.extent], which on an island reaches well out
## past the coast -- so it resamples until it finds land. Without that, a third of
## the rocks and grass tufts on the island map end up bobbing on the sea.
func _near_point(rng: RandomNumberGenerator) -> Vector3:
	var p := _near_draw(rng)
	if not MapTerrain.has_shore():
		return p
	for tries in PLACE_TRIES:
		if not MapTerrain.beyond_shore(p):
			return p
		p = _near_draw(rng)
	return MapTerrain.village()

func _near_draw(rng: RandomNumberGenerator) -> Vector3:
	var a := rng.randf() * TAU
	var r := rng.randf_range(4.0, MapTerrain.extent() * 0.9)
	return MapTerrain.village() + Vector3(cos(a) * r, 0, sin(a) * r)

## A ring point that has passed the rule-1 gate, for the low-count categories that
## cannot afford to simply skip a rejected sample. Falls back to the last draw.
func _backdrop_point(rng: RandomNumberGenerator) -> Vector3:
	var p := _ring_point(rng)
	for tries in PLACE_TRIES:
		if _backdrop(p):
			return p
		p = _ring_point(rng)
	return p

## Ground the scenery is allowed to stand on.
##
## Two exclusions, for two different reasons:
## * **Open ground is out** — see rule 1 in the file header. This is the single check
##   that keeps every reachable tree harvestable.
## * **Rock gates are out** — a tree planted inside a mountain box stands halfway up
##   a stone face, and where the cone geometry does not happen to cover it you get a
##   pine sprouting out of a cliff. Wood gates are exactly where trees belong, and
##   past the map edge is the true backdrop.
## * **The sea is out.** This test permits anything `is_open` calls false, and since
##   the shore landed that means the entire ocean -- so on the island every one of
##   these samples was a tree, bush or hill floating on the water. An island map
##   therefore has *no* backdrop scenery at all, which is correct: every square metre
##   of it is reachable, so every tree on it has to be one you can fell. What stands
##   in for the lost backdrop is `sea.gd`'s ring of distant islands.
func _backdrop(p: Vector3) -> bool:
	if MapTerrain.is_open(p):
		return false
	var kind := MapTerrain.gate_kind_at(p)
	return kind != MapDef.ROCK and kind != MapDef.WATER

# ---------------------------------------------------------------- hills

## Backdrop only -- see rule 2 in the file header. A hill carries a collider, so it
## is placed by rejection sampling onto ground that is already sealed; a hill that
## cannot be reached cannot become an obstacle nobody planned.
func _build_hills() -> void:
	var mat := _flat_mat(Color(0.4, 0.56, 0.3))
	for i in hill_count:
		for tries in PLACE_TRIES:
			var spot := _ring_point(_rng)
			if not _backdrop(spot):
				continue
			var r := _rng.randf_range(5.0, 8.0)
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
	# No trees crowning the hill any more: hills are built once at _ready, and a
	# permanent green canopy sitting on one through winter would contradict the
	# season re-skin going on around it. The forest pass plants around them instead.
