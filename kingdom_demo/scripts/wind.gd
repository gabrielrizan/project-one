extends Node
## The wind you can see: every tree leans and rocks with it, and now and then a
## handful of leaves blows through camp.
##
## One node drives the lot. Trees don't animate themselves -- there are well over
## a hundred once `world_decor.gd` has grown the forest, and a hundred `_process`
## callbacks to set one rotation each is a waste. Anything that should sway joins
## the `wind_sway` group and this sweeps them.
##
## **Join the group with the node you want *rotated*.** For a scripted tree that
## is its `Model` child (the `StaticBody3D` must not move, or its collider and the
## navmesh baked from it would drift); for `world_decor`'s scenery trees it is the
## tree itself. A felled tree leaves the group -- see `tree_resource.gd::_fell()`.
##
## No new art was needed for any of this: the leaves reuse `MarkFx`'s particle,
## which is the same chip texture the axe throws.

const GROUP := "wind_sway"

## Radians. Small on purpose -- this should read as weather, not a storm.
const SWAY := 0.030
## A second, faster rocking on top of the first, so the motion isn't a clean sine.
const SWAY_FAST := 0.011
const SWAY_SPEED := 0.55
const SWAY_FAST_SPEED := 1.7

## Strength drifts between these over ~20s, so the wind lulls and picks up again
## instead of blowing at one constant rate forever.
const GUST_MIN := 0.55
const GUST_MAX := 1.0
const GUST_SPEED := 0.31

## The bearing everything agrees on: trees lean along it, leaves travel down it.
## It swings slowly rather than sitting still.
const DIR_DRIFT := 0.08

const LEAF_GAP := Vector2(6.0, 16.0)
const LEAF_COUNT := Vector2i(7, 14)
const LEAF_SPAWN_BACK := 11.0    # upwind of the monarch, so they blow *past* him
const LEAF_SPREAD := 7.0
const LEAF_TRAVEL := Vector2(16.0, 26.0)
const LEAF_RISE := Vector2(0.4, 2.6)
## The camera sits high and steep, so a leaf has to be bigger than it sounds to
## register at all -- at 0.011 they were invisible specks from up there.
const LEAF_SIZE := 0.026
const LEAF_TINTS: Array[Color] = [
	Color(0.42, 0.52, 0.26), Color(0.55, 0.58, 0.30),
	Color(0.62, 0.50, 0.24), Color(0.38, 0.46, 0.22),
]

var _t := 0.0
var _angle := 0.0          # wind bearing, radians
var _leaf_t := 0.0

func _ready() -> void:
	# `weather.gd` leans the rain along this same bearing, so the group is how it
	# finds us -- a storm blowing across the wind would read as two weathers.
	add_to_group("wind")
	_angle = randf() * TAU
	_leaf_t = randf_range(LEAF_GAP.x, LEAF_GAP.y)

func _process(delta: float) -> void:
	_t += delta
	_angle += DIR_DRIFT * delta
	_sway_trees()
	_leaf_t -= delta
	if _leaf_t <= 0.0:
		_leaf_t = randf_range(LEAF_GAP.x, LEAF_GAP.y)
		_blow_leaves()

## 0.55 .. 1.0, easing back and forth. Shared by the sway and the leaves so the
## trees are visibly leaning hardest when the leaves are moving fastest.
func gust() -> float:
	var w := (sin(_t * GUST_SPEED) + sin(_t * GUST_SPEED * 0.37)) * 0.5   # 2 rates -> no obvious period
	return lerpf(GUST_MIN, GUST_MAX, (w + 1.0) * 0.5)

func wind_dir() -> Vector3:
	return Vector3(cos(_angle), 0.0, sin(_angle))

# ---- the trees ----

func _sway_trees() -> void:
	var g := gust()
	var dir := wind_dir()
	# A tree pushed along the wind tips about the axis across it.
	var axis := Vector3(dir.z, 0.0, -dir.x)
	for n in get_tree().get_nodes_in_group(GROUP):
		var tree := n as Node3D
		if tree == null:
			continue
		# Phase from position, so neighbours are out of step without anything
		# being stored per tree. A whole wood swaying in lockstep looks fake.
		var p: Vector3 = tree.global_position
		var phase := p.x * 0.7 + p.z * 0.9
		var a := (sin(_t * SWAY_SPEED + phase) * SWAY
			+ sin(_t * SWAY_FAST_SPEED + phase * 1.7) * SWAY_FAST) * g
		# Scenery trees are each spun to a random heading, and euler x/z are applied
		# *inside* that heading -- so the tilt axis has to be carried into the
		# tree's own frame first, or every tree would lean a different way and the
		# wind would have no direction at all. `rotation.y` is never written here,
		# so it can be read back as the tree's base heading every frame.
		var local := axis.rotated(Vector3.UP, -tree.rotation.y)
		tree.rotation.x = a * local.x
		tree.rotation.z = a * local.z

# ---- the leaves ----

## A gust's worth of leaves, spawned upwind and tweened past the monarch. They
## are the same billboard particle `MarkFx` throws for wood chips, so there is no
## new art and they already sit in the palette.
func _blow_leaves() -> void:
	var king := get_tree().get_first_node_in_group("monarch")
	if king == null:
		return
	var dir := wind_dir()
	var side := Vector3(-dir.z, 0.0, dir.x)
	var origin: Vector3 = king.global_position - dir * LEAF_SPAWN_BACK
	var n := randi_range(LEAF_COUNT.x, LEAF_COUNT.y)
	for i in range(n):
		var leaf := MarkFx.particle(MarkFx.CHIP_TEX, LEAF_SIZE)
		leaf.modulate = LEAF_TINTS[randi() % LEAF_TINTS.size()]
		get_tree().current_scene.add_child(leaf)
		var start := origin + side * randf_range(-LEAF_SPREAD, LEAF_SPREAD)
		start.y = randf_range(LEAF_RISE.x, LEAF_RISE.y)
		leaf.global_position = start
		var travel := randf_range(LEAF_TRAVEL.x, LEAF_TRAVEL.y)
		var land := start + dir * travel + side * randf_range(-2.5, 2.5)
		land.y = randf_range(0.15, 1.4)
		var secs := travel / randf_range(5.5, 9.0)
		var t := leaf.create_tween()
		t.tween_property(leaf, "global_position", land, secs).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(leaf, "modulate:a", 0.0, secs).set_ease(Tween.EASE_IN)
		t.tween_callback(leaf.queue_free)
