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
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("monarch"):
		_fly_to(body, MAGNET_TIME, true)
