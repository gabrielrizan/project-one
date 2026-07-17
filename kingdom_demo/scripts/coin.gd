extends Area3D

const RISE_HEIGHT := 0.6
const POP_DURATION := 0.35
const BOB_SPEED := 3.0
const BOB_HEIGHT := 0.08

var _settled := false
var _base_y := 0.0
var _time := 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func pop(landing_position: Vector3) -> void:
	var start := global_position
	var apex := Vector3(landing_position.x, start.y + RISE_HEIGHT, landing_position.z)
	var tween := create_tween()
	tween.tween_property(self, "global_position", apex, POP_DURATION * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", landing_position, POP_DURATION * 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		_base_y = global_position.y
		_settled = true
	)

func _process(delta: float) -> void:
	if not _settled:
		return
	_time += delta
	global_position.y = _base_y + sin(_time * BOB_SPEED) * BOB_HEIGHT

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("monarch"):
		var game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager:
			game_manager.add_coins(1)
		queue_free()
