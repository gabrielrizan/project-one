extends Node3D
## Keeps the woods stocked with game. Rabbits and stags are put out beyond the
## palisade and quietly restocked as the archers thin them, so hunting stays a
## renewable income rather than something you can strip-mine once.

const ANIMAL_SCENE := preload("res://kingdom_demo/scenes/wild_animal.tscn")
const RABBIT_MODEL := preload("res://kingdom_demo/assets/3d/Ultimate Animated Animals - July 2021-20260718T121948Z-1-001/Ultimate Animated Animals - July 2021/glTF/Fox.gltf")
const DEER_MODEL := preload("res://kingdom_demo/assets/3d/Ultimate Animated Animals - July 2021-20260718T121948Z-1-001/Ultimate Animated Animals - July 2021/glTF/Stag.gltf")

const RABBITS := 6
const STAGS := 3
const RESTOCK_EVERY := 10.0
const INNER := 10.5      # keep the spawn ring clear of the village
const OUTER := 17.0

var _t := 0.0

func _ready() -> void:
	add_to_group("wildlife")
	for i in range(RABBITS):
		_spawn_rabbit()
	for i in range(STAGS):
		_spawn_stag()

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = RESTOCK_EVERY
	# trickle one back in at a time so the woods refill rather than pop
	var rabbits := 0
	var stags := 0
	for a in get_tree().get_nodes_in_group("wild_game"):
		if a.species == "stag":
			stags += 1
		else:
			rabbits += 1
	if rabbits < RABBITS:
		_spawn_rabbit()
	elif stags < STAGS:
		_spawn_stag()

func _spawn_rabbit() -> void:
	_spawn("rabbit", RABBIT_MODEL, 0.22, 1, 3.4, 5.0, 2.2)

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
	var ang := randf() * TAU
	var r := randf_range(INNER, OUTER)
	a.global_position = Vector3(cos(ang) * r, 0, sin(ang) * r)
