extends CharacterBody3D

enum State { WANDER, FOLLOWING, ARCHER, BUILDER }

const RECRUIT_COST := 1
const MOVE_SPEED := 4.2
const ACCEL := 50.0
const FOLLOW_DISTANCE := 1.4
const WANDER_RADIUS := 4.0
const ARCHER_RADIUS := 5.0
const ARRIVE := 0.6

const ARCHER_TEX := preload("res://kingdom_demo/assets/pixel/archer.png")
const BUILDER_TEX := preload("res://kingdom_demo/assets/pixel/builder.png")

@onready var sprite: Sprite3D = $Sprite
@onready var prompt: Label3D = $Prompt

var state: int = State.WANDER
var monarch: Node3D = null
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _pause := 0.0
var _bob := 0.0
var _sprite_base_y := 0.0
var _patrol_angle := 0.0
var _build_tick := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("peasant")
	_home = global_position
	_sprite_base_y = sprite.position.y
	_patrol_angle = randf() * TAU
	_pick_wander_target()

func show_prompt() -> void:
	if state == State.WANDER:
		prompt.visible = true

func hide_prompt() -> void:
	prompt.visible = false

func can_take_job() -> bool:
	return state == State.FOLLOWING

func interact(who: Node3D) -> void:
	if state != State.WANDER:
		return
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.spend_coins(RECRUIT_COST):
		monarch = who
		state = State.FOLLOWING
		who.add_follower(self)
		remove_from_group("interactable")
		hide_prompt()

func assign_job(job: String) -> void:
	if state != State.FOLLOWING:
		return
	if monarch and monarch.has_method("remove_follower"):
		monarch.remove_follower(self)
	monarch = null
	if job == "archer":
		state = State.ARCHER
		sprite.texture = ARCHER_TEX
		sprite.modulate = Color(1, 1, 1)
	else:
		state = State.BUILDER
		sprite.texture = BUILDER_TEX
		sprite.modulate = Color(1.0, 0.82, 0.55)

func _physics_process(delta: float) -> void:
	match state:
		State.WANDER:
			_do_wander(delta)
		State.FOLLOWING:
			_do_follow(delta)
		State.ARCHER:
			_do_archer(delta)
		State.BUILDER:
			_do_builder(delta)

func _move_to(p: Vector3, delta: float, speed := MOVE_SPEED) -> float:
	var to := p - global_position
	to.y = 0.0
	var d := to.length()
	var tv := Vector3.ZERO
	if d > 0.05:
		tv = to.normalized() * speed
	velocity.x = move_toward(velocity.x, tv.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, tv.z, ACCEL * delta)
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length() > 0.3)
	return d

func _animate(delta: float, moving: bool) -> void:
	if moving:
		_bob += delta * 11.0
		sprite.position.y = _sprite_base_y + abs(sin(_bob)) * 0.07
		if absf(velocity.x) > 0.1:
			sprite.flip_h = velocity.x < 0.0
	else:
		sprite.position.y = move_toward(sprite.position.y, _sprite_base_y, delta * 0.6)

func _pick_wander_target() -> void:
	var a := randf() * TAU
	var r := randf() * WANDER_RADIUS
	_target = _home + Vector3(cos(a) * r, 0, sin(a) * r)

func _do_wander(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		_animate(delta, false)
		return
	var d := _move_to(_target, delta, MOVE_SPEED * 0.45)
	if d < ARRIVE:
		_pause = randf_range(0.8, 2.5)
		_pick_wander_target()

func _do_follow(delta: float) -> void:
	if monarch == null:
		state = State.WANDER
		return
	var leader: Node3D = monarch.get_leader_for(self)
	var to := leader.global_position - global_position
	to.y = 0.0
	if to.length() > FOLLOW_DISTANCE:
		_move_to(leader.global_position, delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
		move_and_slide()
		_animate(delta, false)

func _do_archer(delta: float) -> void:
	var base = get_tree().get_first_node_in_group("base")
	if base == null:
		return
	var center: Vector3 = base.global_position
	var wp := center + Vector3(cos(_patrol_angle) * ARCHER_RADIUS, 0, sin(_patrol_angle) * ARCHER_RADIUS)
	var d := _move_to(wp, delta)
	if d < ARRIVE:
		_patrol_angle += 0.8

func _do_builder(delta: float) -> void:
	var base = get_tree().get_first_node_in_group("base")
	if base == null:
		return
	var d := _move_to(base.global_position, delta)
	if d < 3.2:
		_build_tick += delta
		if _build_tick >= 1.0:
			_build_tick = 0.0
			if base.has_method("add_construction"):
				base.add_construction(1)
