extends Node3D
## Keeps the woods stocked with game. Rabbits and stags are put out beyond the
## palisade and quietly restocked as the archers thin them, so hunting stays a
## renewable income rather than something you can strip-mine once.

const ANIMAL_SCENE := preload("res://kingdom_demo/scenes/wild_animal.tscn")
# The animal pack has no hare, so the rabbit is one of ours; the stag is theirs
# and comes rigged, so it keeps its walk cycle.
const RABBIT_MODEL := preload("res://kingdom_demo/assets/3d/characters/rabbit.glb")
const DEER_MODEL := preload("res://kingdom_demo/assets/3d/Ultimate Animated Animals - July 2021-20260718T121948Z-1-001/Ultimate Animated Animals - July 2021/glTF/Stag.gltf")

const RABBITS := 6
const STAGS := 3
const RESTOCK_EVERY := 10.0
const INNER := 10.5      # keep the spawn ring clear of the village
# Pulled in from 17 so the ring stays inside the mountain U's belly; the far edge
# used to spawn game against (and inside) the sealed bearings. See _spawn.
const OUTER := 15.0

# --- winter thins the woods (season visuals, 2026-08-02). Game is much scarcer and
#     trickles back far slower, so hunting through winter is lean. The population
#     tracks the seasonal target both ways: it dwindles as winter sets in and
#     refills once spring comes. Season index 3 mirrors weather.gd's Season.WINTER. ---
const WINTER_RABBITS := 2
const WINTER_STAGS := 1
const WINTER_RESTOCK := 26.0
const _WINTER_SEASON := 3

var _t := 0.0

func _ready() -> void:
	add_to_group("wildlife")
	for i in range(_target_rabbits()):
		_spawn_rabbit()
	for i in range(_target_stags()):
		_spawn_stag()

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = WINTER_RESTOCK if _is_winter() else RESTOCK_EVERY
	# trickle one in or out at a time so the woods fill and thin rather than pop --
	# up toward the summer target, down toward winter's much leaner one
	var rabbits := 0
	var stags := 0
	for a in get_tree().get_nodes_in_group("wild_game"):
		if a.species == "stag":
			stags += 1
		else:
			rabbits += 1
	var tr := _target_rabbits()
	var ts := _target_stags()
	if rabbits < tr:
		_spawn_rabbit()
	elif rabbits > tr:
		_despawn_one("rabbit")
	elif stags < ts:
		_spawn_stag()
	elif stags > ts:
		_despawn_one("stag")

func _is_winter() -> bool:
	var w := get_tree().get_first_node_in_group("weather")
	return w != null and w.season() == _WINTER_SEASON

func _target_rabbits() -> int:
	return WINTER_RABBITS if _is_winter() else RABBITS

func _target_stags() -> int:
	return WINTER_STAGS if _is_winter() else STAGS

## Quietly remove one animal of `species` as winter closes in -- the far end of the
## renewable-game loop, so the woods empty out instead of staying full and unfed.
func _despawn_one(species: String) -> void:
	for a in get_tree().get_nodes_in_group("wild_game"):
		if a.species == species:
			a.queue_free()
			return

func _spawn_rabbit() -> void:
	_spawn("rabbit", RABBIT_MODEL, 1.0, 1, 3.4, 5.0, 2.2)

func _spawn_stag() -> void:
	_spawn("stag", DEER_MODEL, 0.38, 2, 2.7, 7.0, 3.4)

func _spawn(species: String, model: PackedScene, sc: float, gold: int,
		speed: float, roam: float, spook: float) -> void:
	var a := ANIMAL_SCENE.instantiate()
	a.species = species
	a.model_scene = model
	a.model_scale = sc
	a.gold_yield = gold
	a.move_speed = speed
	a.roam_radius = roam
	a.spook_range = spook
	# parented to the spawner rather than the scene root: this runs during _ready,
	# before the tree has a current_scene to hang them off
	add_child(a)
	# Biased onto open ground: the forest belly on the three sealed sides, never in
	# the rock and never up the north corridor -- a stag spawned inside a mountain
	# is stuck forever (COMBAT_PROMPTS P1).
	a.global_position = MapTerrain.random_belly_point(INNER, OUTER)
	# Game in unexplored country is out of sight, like everything else standing on
	# it. It **stays** hidden only until the ground it is on is revealed, not until
	# it is looked at -- the mask is memory of a place, so once a stretch of wood is
	# known the deer in it are simply visible, wherever they wander inside it.
	FogOfWar.hide_until_found(a)
