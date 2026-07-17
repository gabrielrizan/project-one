extends Node3D

const FOLLOW_LERP := 12.0

var target: Node3D = null

func _ready() -> void:
	call_deferred("_find_target")

func _find_target() -> void:
	target = get_tree().get_first_node_in_group("monarch")

func _process(delta: float) -> void:
	if target == null:
		return
	var goal := Vector3(target.global_position.x, global_position.y, target.global_position.z)
	global_position = global_position.lerp(goal, clamp(FOLLOW_LERP * delta, 0.0, 1.0))
