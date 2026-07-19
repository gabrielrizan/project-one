extends Node3D
## Follows the monarch and can be spun around them with Z / X for a Thronefall-ish
## high, steep view. `yaw` is read by the monarch so movement stays camera-relative.

const FOLLOW_LERP := 10.0
const ROT_SPEED := 1.9      # radians / second

@onready var _camera: Camera3D = $Camera3D

var target: Node3D = null
var yaw := 0.0

var _cam_base := Vector3.ZERO
var _shake_t := 0.0
var _shake_len := 0.0
var _shake_amp := 0.0

func _ready() -> void:
	add_to_group("camera_rig")
	_cam_base = _camera.position
	call_deferred("_find_target")

## A thump the player feels -- something heavy landing, e.g. a gate dropping into
## a finished wall. It shakes the camera, not the rig, so following the monarch
## and the Z / X spin are untouched.
func shake(duration: float, strength: float) -> void:
	if _shake_t > 0.0 and strength < _shake_amp:
		return    # a small thump doesn't cut a big one short
	_shake_len = duration
	_shake_t = duration
	_shake_amp = strength

func _shake_camera(delta: float) -> void:
	if _shake_t <= 0.0:
		if _camera.position != _cam_base:
			_camera.position = _cam_base
		return
	_shake_t -= delta
	var fade: float = clampf(_shake_t / _shake_len, 0.0, 1.0)
	var a := _shake_amp * fade * fade
	_camera.position = _cam_base + Vector3(randf_range(-a, a), randf_range(-a, a), 0.0)

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
	_shake_camera(delta)

	if target:
		var goal := Vector3(target.global_position.x, 0.0, target.global_position.z)
		global_position = global_position.lerp(goal, clamp(FOLLOW_LERP * delta, 0.0, 1.0))
