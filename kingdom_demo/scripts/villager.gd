extends CharacterBody3D
## A villager drawn in by a full cauldron. It walks to the cauldron, eats, becomes
## a loyal citizen (blue tint), then walks to the nearest building with an open job
## and takes it -- swapping into a builder or archer outfit.

enum State { SEEK_FOOD, EAT, LOYAL, GO_WORK, WORK }

const SPEED := 3.2
const ACCEL := 40.0
const ARRIVE := 1.8
const WORK_ARRIVE := 0.7
const EAT_TIME := 2.5
const WALL_HALF := 8.0     # matches the palisade square

const VILLAGER_TEX := preload("res://kingdom_demo/assets/pixel/villager.png")
const BUILDER_TEX := preload("res://kingdom_demo/assets/pixel/builder.png")
const ARCHER_TEX := preload("res://kingdom_demo/assets/pixel/archer.png")
const LOYAL_TINT := Color(0.55, 0.75, 1.0)

@onready var sprite: Sprite3D = $Sprite

var target := Vector3.ZERO          # cauldron position, set by spawner

var _state: int = State.SEEK_FOOD
var _workplace: Node3D = null
var _eat_t := 0.0
var _recheck_t := 0.0
var _mill := Vector3.ZERO
var _mill_t := 0.0
var _bob := 0.0
var _base_y := 0.0
var _route_gate := Vector3.ZERO
var _has_gate := false

func _ready() -> void:
	add_to_group("villager")
	_base_y = sprite.position.y
	_mill = target

func _physics_process(delta: float) -> void:
	match _state:
		State.SEEK_FOOD:
			var g := _route(target)
			_seek(delta, g, (ARRIVE if g == target else 0.4))
			if global_position.distance_to(target) < ARRIVE:
				_state = State.EAT
				_eat_t = EAT_TIME
		State.EAT:
			_mill_near(delta, target, 1.6)
			_eat_t -= delta
			if _eat_t <= 0.0:
				_become_loyal()
		State.LOYAL:
			_mill_near(delta, target, 2.2)
			_recheck_t -= delta
			if _recheck_t <= 0.0:
				_recheck_t = 1.2
				_try_take_job()
		State.GO_WORK:
			if not is_instance_valid(_workplace):
				_become_loyal()
			else:
				var wp: Vector3 = _workplace.work_point()
				var g := _route(wp)
				_seek(delta, g, (WORK_ARRIVE if g == wp else 0.4))
				if global_position.distance_to(wp) < WORK_ARRIVE:
					_start_working()
		State.WORK:
			_mill_near(delta, _work_anchor(), 1.6)

# ---- transitions ----

func _become_loyal() -> void:
	_state = State.LOYAL
	_recheck_t = 0.0
	sprite.texture = VILLAGER_TEX
	sprite.modulate = LOYAL_TINT

func _try_take_job() -> void:
	var best: Node3D = null
	var best_d := INF
	for b in get_tree().get_nodes_in_group("workplace"):
		if b.has_method("has_open_job") and b.has_open_job():
			var d := global_position.distance_to(b.global_position)
			if d < best_d:
				best_d = d
				best = b
	if best and best.claim_job():
		_workplace = best
		_state = State.GO_WORK

func _start_working() -> void:
	_state = State.WORK
	sprite.modulate = Color(1, 1, 1)
	sprite.texture = ARCHER_TEX if _workplace.job_type == "archer" else BUILDER_TEX

func _work_anchor() -> Vector3:
	return _workplace.work_point() if is_instance_valid(_workplace) else global_position

# ---- routing (steer through gates instead of into walls) ----

func _route(final: Vector3) -> Vector3:
	# Same side of the palisade (or no walls yet) -> head straight there.
	if not _walls_exist() or _inside(global_position) == _inside(final):
		_has_gate = false
		return final
	# Crossing the wall: commit to one gate (cached so we don't dither at corners)
	# and aim for a point just past it, so we walk THROUGH rather than stop on it.
	if not _has_gate:
		_route_gate = _pick_gate(final)
		_has_gate = true
	var inward := final - _route_gate
	inward.y = 0.0
	if inward.length() < 0.01:
		inward = Vector3(0, 0, 1)
	return _route_gate + inward.normalized() * 2.5

func _inside(p: Vector3) -> bool:
	return absf(p.x) < WALL_HALF and absf(p.z) < WALL_HALF

func _pick_gate(final: Vector3) -> Vector3:
	var gates: Array[Vector3] = [
		Vector3(0, 0, -WALL_HALF), Vector3(0, 0, WALL_HALF),
		Vector3(WALL_HALF, 0, 0), Vector3(-WALL_HALF, 0, 0),
	]
	var best: Vector3 = gates[0]
	var bd := INF
	for gp in gates:
		var d := global_position.distance_to(gp) + gp.distance_to(final)
		if d < bd:
			bd = d
			best = gp
	return best

func _walls_exist() -> bool:
	for w in get_tree().get_nodes_in_group("wall_side"):
		if w.built:
			return true
	return false

# ---- movement helpers ----

func _seek(delta: float, goal: Vector3, stop: float) -> void:
	var to := goal - global_position
	to.y = 0.0
	var tv := Vector3.ZERO
	if to.length() > stop:
		tv = to.normalized() * SPEED
	velocity.x = move_toward(velocity.x, tv.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, tv.z, ACCEL * delta)
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length() > 0.3)

func _mill_near(delta: float, center: Vector3, radius: float) -> void:
	_mill_t -= delta
	if _mill_t <= 0.0:
		_mill_t = randf_range(1.0, 2.5)
		var a := randf() * TAU
		_mill = center + Vector3(cos(a), 0, sin(a)) * randf_range(0.6, radius)
	_seek(delta, _mill, 0.25)

func _animate(delta: float, moving: bool) -> void:
	if moving:
		_bob += delta * 10.0
		sprite.position.y = _base_y + abs(sin(_bob)) * 0.06
		if absf(velocity.x) > 0.1:
			sprite.flip_h = velocity.x < 0.0
	else:
		sprite.position.y = move_toward(sprite.position.y, _base_y, delta * 0.5)
