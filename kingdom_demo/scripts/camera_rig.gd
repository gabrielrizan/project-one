extends Node3D
## Follows the monarch and can be spun around them with Z / X for a Thronefall-ish
## high, steep view. `yaw` is read by the monarch so movement stays camera-relative.

const FOLLOW_LERP := 10.0
const ROT_SPEED := 1.9      # radians / second

var target: Node3D = null
var yaw := 0.0

func _ready() -> void:
	add_to_group("camera_rig")
	call_deferred("_find_target")

func _find_target() -> void:
	target = get_tree().get_first_node_in_group("monarch")

func _physics_process(delta: float) -> void:
	var r := 0.0
	if Input.is_key_pressed(KEY_Z):
		r += 1.0
	if Input.is_key_pressed(KEY_X):
		r -= 1.0
	yaw += r * ROT_SPEED * delta
	rotation.y = yaw

	if target:
		var goal := Vector3(target.global_position.x, 0.0, target.global_position.z)
		global_position = global_position.lerp(goal, clamp(FOLLOW_LERP * delta, 0.0, 1.0))
