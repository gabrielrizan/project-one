extends CharacterBody3D
## A rabbit or a stag roaming the wild. It grazes its way around a home patch and
## bolts if something gets too close. Archers hunt it for gold: exactly one hunter
## claims an animal, and an arrow drops it for GOLD_YIELD coins.

enum State { GRAZE, BOLT, DEAD }

const ACCEL := 30.0
const ARRIVE := 0.45
const COIN_SCENE := preload("res://kingdom_demo/scenes/coin.tscn")

## The body hitting the ground. **One clip pitched by size** rather than a set
## per species -- a rabbit lands light and high, a stag heavy and low, and that
## is most of the difference between them. Same trick as `villager.gd::JOB_PITCH`.
## Anything not listed falls back to 1.0, so adding a boar costs one entry.
const DROP_SFX := preload("res://kingdom_demo/assets/audio/animal_drop_1.ogg")
const DROP_DB := -9.0
const DROP_PITCH := {"rabbit": 1.38, "stag": 0.84}

@export var species: String = "rabbit"
@export var model_scene: PackedScene
@export var model_scale: float = 0.3
@export var gold_yield: int = 1
@export var move_speed: float = 3.0
@export var roam_radius: float = 6.0
@export var spook_range: float = 2.4

@onready var model_root: Node3D = $Model
@onready var _agent: NavigationAgent3D = $NavAgent

var dead := false
var _nav: NavMover = null

var _model: Node3D = null
var _anim: AnimationPlayer = null
var _state: int = State.GRAZE
var _hunter: Node3D = null
var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _pause := 0.0
var _bolt_t := 0.0
var _spook_t := 0.0
var _bob := 0.0
var _base_y := 0.0
var _facing := 0.0

func _ready() -> void:
	add_to_group("wild_game")
	if model_scene:
		_model = model_scene.instantiate()
		model_root.add_child(_model)
		_model.scale = Vector3(model_scale, model_scale, model_scale)
		_anim = _find_anim(_model)
		_play_anim(["Idle", "idle"])
	_base_y = 0.0
	_home = global_position
	_nav = NavMover.new(_agent, self)
	_pick_spot()

func _exit_tree() -> void:
	if _nav:
		_nav.cleanup()

func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_anim(c)
		if found:
			return found
	return null

## Matches by substring and does nothing if that clip is already playing --
## called every frame from `_move_to`/`_idle` now that Walk/Gallop/Idle switch
## with state, so restarting it each frame would never let a cycle finish.
func _play_anim(prefer: Array) -> void:
	if _anim == null:
		return
	var list := _anim.get_animation_list()
	if list.is_empty():
		return
	for want in prefer:
		for a in list:
			if String(a).findn(want) != -1:
				if _anim.current_animation != a:
					_anim.play(a)
				return
	if _anim.current_animation != list[0]:
		_anim.play(list[0])

func _physics_process(delta: float) -> void:
	match _state:
		State.GRAZE:
			_spook_t -= delta
			if _spook_t <= 0.0:
				_spook_t = 0.2      # no need to sweep the whole village every frame
				_check_spook()
			if _pause > 0.0:
				_pause -= delta
				_idle(delta)
				return
			var d := _move_to(_target, delta, move_speed * 0.35)
			if d < ARRIVE:
				_pause = randf_range(1.2, 3.5)
				_pick_spot()
		State.BOLT:
			_bolt_t -= delta
			if _bolt_t <= 0.0:
				_state = State.GRAZE
				_pause = randf_range(0.4, 1.2)
				_pick_spot()
			else:
				_move_to(_target, delta, move_speed)
		State.DEAD:
			pass

# ---- hunting API ----

func is_open_for_hunting() -> bool:
	return not dead and not is_instance_valid(_hunter)

func claim_hunter(who: Node3D) -> bool:
	if not is_open_for_hunting():
		return false
	_hunter = who
	return true

func release_hunter(who: Node3D) -> void:
	if _hunter == who:
		_hunter = null

## An arrow found its mark. Drops the gold and hands it to whoever loosed it.
func take_arrow(from: Vector3) -> void:
	if dead:
		return
	dead = true
	_state = State.DEAD
	remove_from_group("wild_game")
	set_deferred("collision_layer", 0)
	velocity = Vector3.ZERO
	_die(from)

# ---- behaviour ----

## Anything closing in sends it running -- archers shoot from beyond this.
func _check_spook() -> void:
	for who in get_tree().get_nodes_in_group("monarch") + get_tree().get_nodes_in_group("villager"):
		if global_position.distance_to(who.global_position) < spook_range:
			_flee_from(who.global_position)
			return

func _flee_from(threat: Vector3) -> void:
	var away := global_position - threat
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3(randf() - 0.5, 0, randf() - 0.5)
	_target = global_position + away.normalized() * randf_range(3.0, 5.5)
	_bolt_t = randf_range(0.9, 1.6)
	_state = State.BOLT

func _pick_spot() -> void:
	var a := randf() * TAU
	_target = _home + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, roam_radius)

## Returns how far off `p` still is, which is what the caller watches for arrival.
func _move_to(p: Vector3, delta: float, speed: float) -> float:
	var to := p - global_position
	to.y = 0.0
	var d := to.length()
	var tv := Vector3.ZERO
	if d > 0.05:
		var dir := _nav.direction_to(p, delta)
		# Grazing spots and bolt-to points are picked blind, so plenty of them sit
		# inside a tree. The navmesh walks us as close as it can and then has
		# nothing more; call that arrived rather than leave the animal shoving at
		# a trunk until something else interrupts it.
		if dir == Vector3.ZERO:
			d = 0.0
		else:
			tv = dir * speed
	velocity.x = move_toward(velocity.x, tv.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, tv.z, ACCEL * delta)
	move_and_slide()
	var moving := Vector2(velocity.x, velocity.z).length() > 0.25
	if moving:
		_face(velocity)
		if _anim != null:
			_play_anim(["Gallop", "gallop"] if _state == State.BOLT else ["Walk", "walk"])
		elif is_instance_valid(_model):
			# No rig (the rabbit) -- the old sine bob is all it has.
			_bob += delta * (14.0 if _state == State.BOLT else 8.0)
			_model.position.y = _base_y + absf(sin(_bob)) * 0.05
	elif _anim != null:
		_play_anim(["Idle", "idle"])
	elif is_instance_valid(_model):
		_model.position.y = move_toward(_model.position.y, _base_y, delta * 0.4)
	return d

## Turn the model to face the way it's walking.
func _face(vel: Vector3) -> void:
	if not is_instance_valid(_model):
		return
	var flat := Vector2(vel.x, vel.z)
	if flat.length() < 0.1:
		return
	var want := atan2(vel.x, vel.z)
	_facing = lerp_angle(_facing, want, 0.25)
	_model.rotation.y = _facing

func _idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
	move_and_slide()
	if _anim != null:
		_play_anim(["Idle", "idle"])
	elif is_instance_valid(_model):
		_model.position.y = move_toward(_model.position.y, _base_y, delta * 0.4)

# ---- death ----

func _die(from: Vector3) -> void:
	_play_anim(["Death", "death", "Die"])
	_drop_sound()
	var knock := global_position - from
	knock.y = 0.0
	if knock.length() < 0.01:
		knock = Vector3(0, 0, 1)
	knock = knock.normalized() * 0.35

	# knocked back, then it drops
	var k := create_tween()
	k.tween_property(self, "global_position", global_position + knock, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var target := _model if is_instance_valid(_model) else self
	var f := create_tween()
	f.tween_interval(0.18)
	f.tween_property(target, "scale", Vector3(model_scale * 1.2, model_scale * 0.15, model_scale * 1.2), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	f.tween_callback(_drop_gold)
	f.tween_interval(0.5)
	f.tween_property(target, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	f.tween_callback(queue_free)

func _drop_gold() -> void:
	var coins: Array = []
	for i in range(gold_yield):
		var coin := COIN_SCENE.instantiate()
		get_tree().current_scene.add_child(coin)
		coin.global_position = global_position + Vector3(0, 0.4, 0)
		var a := randf() * TAU
		var landing := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.4, 0.9)
		landing.y = 0.12
		coin.pop(landing)
		coins.append(coin)
	if is_instance_valid(_hunter) and _hunter.has_method("receive_loot"):
		_hunter.receive_loot(coins)
	_hunter = null

## The drop, on a throwaway emitter parented to the scene -- this body frees
## itself a moment later once its death tween finishes, and a child player
## would be cut off mid-thud.
func _drop_sound() -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = DROP_SFX
	p.bus = &"SFX"
	p.volume_db = DROP_DB
	p.pitch_scale = float(DROP_PITCH.get(species, 1.0)) * randf_range(0.94, 1.06)
	p.unit_size = 5.0
	p.max_distance = 30.0
	get_tree().current_scene.add_child(p)
	p.global_position = global_position
	p.finished.connect(p.queue_free)
	p.play()
