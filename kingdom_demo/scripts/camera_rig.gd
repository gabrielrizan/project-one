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
	_setup_listener()
	call_deferred("_find_target")

## The 3D audio listener is pinned to the rig, NOT left on the camera. Godot uses
## the current Camera3D as the listener by default, so when the camera was pulled
## back to ~26m for the diorama look (commit 9826645, 8.6m -> 26m) every
## short-range positional sound fell past its `max_distance` and went silent --
## the horse (22/26m) and cauldron feed (18m) first, then coin/clink/mark/berry.
## A dedicated listener sitting where the camera used to be keeps every emitter's
## tuning intact while the camera is free to frame from anywhere. It hangs off the
## rig, so the Z / X spin still pans the field; only its distance is decoupled.
## Position matches the camera transform from before the pull-back, so the mix is
## exactly what the SFX were tuned against.
func _setup_listener() -> void:
	var listener := AudioListener3D.new()
	listener.position = Vector3(0.0, 6.645, 5.503)
	add_child(listener)
	listener.make_current()

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
		# At rest the camera's own position *is* the rest pose -- adopt it, don't force it
		# back to whatever `_ready()` cached. Forcing it re-wrote the camera every frame and
		# so silently ate anything else that moved it: the editor's live scene sync (change
		# Position with the game running and it snapped straight back, looking like live
		# edit was broken) and any future dynamic zoom. Nothing is lost by adopting, because
		# the shake below fades `a` to exactly 0 on its last frame and therefore always
		# lands back on `_cam_base` on its own; and `_shake_t <= 0.0` keeps a mid-shake
		# offset from being baked in as the new base.
		_cam_base = _camera.position
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
