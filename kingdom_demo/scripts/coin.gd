extends Area3D
## A loose gold coin. Pops out of whatever dropped it, then sits bobbing and lazily
## spinning until the monarch strays near enough to snap it up -- or a worker
## scoops it into their purse to carry home.

const RISE_HEIGHT := 0.7
const POP_DURATION := 0.4
const BOB_SPEED := 3.0
const BOB_HEIGHT := 0.07
const SPIN_SPEED := 1.9   # radians/sec; a real turn now that it's a model
const MAGNET_RANGE := 1.5
const MAGNET_TIME := 0.16
const SCOOP_TIME := 0.2
const VALUE := 1

## The same coins-in-cloth takes the tally spends out of -- see `_purse_sound`.
const PURSE_CLIPS := [
	preload("res://kingdom_demo/assets/audio/coin_1.ogg"),
	preload("res://kingdom_demo/assets/audio/coin_2.ogg"),
	preload("res://kingdom_demo/assets/audio/coin_3.ogg"),
	preload("res://kingdom_demo/assets/audio/coin_4.ogg"),
	preload("res://kingdom_demo/assets/audio/coin_5.ogg"),
]
const PURSE_DB := -12.0
## Lower than any note in the tally's rising ramp (0.80 .. 1.22), so gold coming
## in never gets mistaken for gold going out.
const PURSE_PITCH := 0.74
const PURSE_PITCH_JITTER := 1.07

static var _purse_pool: AudioStreamRandomizer = null

@onready var model: Node3D = $Model

var _settled := false
var _taken := false
var _base_y := 0.0
var _time := 0.0
var _pop: Tween = null
var _base_scale := Vector3.ONE   # the scene sets the coin's size; flourishes scale off it

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_base_scale = model.scale
	# stagger the spin/bob so a handful dropped at once doesn't pulse in lockstep
	_time = randf() * TAU

func pop(landing_position: Vector3) -> void:
	var start := global_position
	var apex := Vector3(landing_position.x, start.y + RISE_HEIGHT, landing_position.z)
	_pop = create_tween()
	_pop.tween_property(self, "global_position", apex, POP_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pop.tween_property(self, "global_position", landing_position, POP_DURATION * 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_pop.finished.connect(func():
		_base_y = global_position.y
		_settled = true
	)

func _process(delta: float) -> void:
	if _taken:
		return
	# an actual turn, rather than the squash a billboard needed
	_time += delta
	model.rotation.y = _time * SPIN_SPEED
	if not _settled:
		return
	var king := get_tree().get_first_node_in_group("monarch")
	if king and global_position.distance_to(king.global_position) < MAGNET_RANGE:
		_fly_to(king, MAGNET_TIME, true)
		return
	global_position.y = _base_y + sin(_time * BOB_SPEED) * BOB_HEIGHT

## Scooped up by a worker: no gold banked yet, they carry it to the monarch first.
func collect_to(carrier: Node3D) -> void:
	_fly_to(carrier, SCOOP_TIME, false)

func _fly_to(target: Node3D, duration: float, bank: bool) -> void:
	if _taken or not is_instance_valid(target):
		return
	_taken = true
	set_deferred("monitoring", false)
	if _pop and _pop.is_valid():
		_pop.kill()
	var dest: Vector3 = target.global_position + Vector3(0, (0.9 if bank else 1.25), 0)
	var t := create_tween()
	t.tween_property(self, "global_position", dest, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(model, "scale", (_base_scale * 1.4 if bank else Vector3.ZERO), duration)
	t.tween_callback(_bank_it if bank else queue_free)

func _bank_it() -> void:
	var game_manager := get_tree().get_first_node_in_group("game_manager")
	if game_manager:
		game_manager.add_coins(VALUE)
	_purse_sound()
	queue_free()

## Gold going *into* the purse, using the same coins-in-cloth clips the tally
## spends out of -- one material for one substance. Pitched down and quieter than
## a tally pip so taking and paying stay distinguishable.
##
## Needs its own emitter parented to the scene: the coin queue_frees on this very
## frame and would take a child player with it.
func _purse_sound() -> void:
	if _purse_pool == null:
		_purse_pool = AudioStreamRandomizer.new()
		for i in range(PURSE_CLIPS.size()):
			_purse_pool.add_stream(i, PURSE_CLIPS[i])
		_purse_pool.random_pitch = PURSE_PITCH_JITTER
		_purse_pool.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	var p := AudioStreamPlayer3D.new()
	p.stream = _purse_pool
	p.bus = &"SFX"
	p.volume_db = PURSE_DB
	p.pitch_scale = PURSE_PITCH
	p.unit_size = 3.0
	p.max_distance = 18.0
	get_tree().current_scene.add_child(p)
	p.global_position = global_position
	p.finished.connect(p.queue_free)
	p.play()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("monarch"):
		_fly_to(body, MAGNET_TIME, true)
