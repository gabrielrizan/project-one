class_name CameraRig
extends Node3D
## Follows the monarch, spins with Z / X, and zooms with the mouse wheel, for a
## Thronefall-ish high, steep view. `yaw` is read by the monarch so movement stays
## camera-relative.
##
## ## Zoom (ISLAND_PROMPTS F2)
##
## The wheel slides the camera along **its own back-vector**, which is the one
## motion that changes how much ground you see without changing anything else --
## the pitch, the aim point and the framing of the monarch are all preserved, so
## there is no "the camera is looking somewhere different now" moment. Steps are
## multiplicative ([constant ZOOM_STEP]) because a fixed metre step feels coarse
## zoomed in and useless zoomed out, and the current level eases toward the target
## rather than snapping.
##
## The level lives in the **static [member zoom]** rather than being fetched
## through the `camera_rig` group, because three separate systems read it every
## frame and all of them have to agree with the picture in the same frame:
##
## * `gold_fx.gd` — the tally is measured in **metres**, so zooming out shrinks it.
##   That is not cosmetic: at 0.63x apparent size a pip once fell to ~14 px and you
##   could no longer tell a paid pip from an unpaid one, which is the whole readout.
## * this file's [method _scale_prompts] — `Label3D` prompts are metres too.
## * `day_night_cycle.gd` — the fog band and `directional_shadow_max_distance` are
##   tuned for the shipped frustum, so zoomed out the fog lands on the grass under
##   the monarch's feet and shadows pop off at the frame edge.
##
## ⚠️ **Zoom must never move the `AudioListener3D`.** It is pinned to the rig at a
## fixed offset (see [method _setup_listener]) precisely so that camera distance and
## audio distance are separate things; everything here writes `_camera.position` and
## nothing else, which is what keeps that true.

const FOLLOW_LERP := 10.0
const ROT_SPEED := 1.9      # radians / second

## Zoom stops, as a multiple of the shipped camera's distance (26 m along the
## back-vector, i.e. 18.38 m up at 45 degrees). At 1.0 the view is exactly what
## `kingdom_demo.tscn` ships, which is what keeps `dev_menu.gd`'s preset 0 honest.
##
## The range covers ~15 m of ground at the near stop and ~84 m at the far one.
## Deliberately **not** enough to hold the whole island (~188 m across): reading the
## map from above is the dev overlay's `map 45` preset, not something the player
## does mid-run.
const ZOOM_MIN := 0.55
const ZOOM_MAX := 3.00
## Per wheel notch, multiplicative. A fixed metre step is coarse zoomed in and does
## nothing zoomed out; a ratio is the same perceived step everywhere.
const ZOOM_STEP := 1.13
## Eased, not stepped. Exponential smoothing so it is frame-rate independent.
const ZOOM_LERP := 9.0

## The current zoom, shared. See the class notes for who reads it and why it is
## static rather than looked up through the group.
static var zoom := 1.0

@onready var _camera: Camera3D = $Camera3D

var target: Node3D = null
var yaw := 0.0

## The camera's pose at zoom 1.0 -- taken from the scene, so the shipped framing is
## the scene's business and not a constant in here. `dev_menu.gd`'s presets replace
## it through [method set_rest_pose].
var _rest_pose := Vector3.ZERO
## Orthographic size at zoom 1.0, or 0 for a perspective rig. Ortho has to zoom by
## scaling `size`: sliding an orthographic camera back changes nothing at all,
## because parallel rays do not converge.
var _rest_size := 0.0

var _zoom_target := 1.0
var _cam_base := Vector3.ZERO
var _shake_t := 0.0
var _shake_len := 0.0
var _shake_amp := 0.0
## Label3D -> its authored `pixel_size`, so prompts can be scaled against zoom
## without any scene having to record what its own baseline was.
var _prompt_base := {}
var _prompt_zoom := 0.0

func _ready() -> void:
	add_to_group("camera_rig")
	_rest_pose = _camera.position
	_rest_size = _camera.size if _camera.projection == Camera3D.PROJECTION_ORTHOGONAL else 0.0
	_cam_base = _rest_pose
	zoom = 1.0
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
##
## ⚠️ This is also what makes **zoom** free: the wheel changes how far the camera
## is, and the listener does not move with it, so nothing about the mix changes as
## you scroll. Moving this offset re-tunes every positional sound in the game at
## once.
func _setup_listener() -> void:
	var listener := AudioListener3D.new()
	listener.position = Vector3(0.0, 6.645, 5.503)
	add_child(listener)
	listener.make_current()

# ---------------------------------------------------------------- zoom

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cam_zoom_in"):
		_nudge_zoom(1.0 / ZOOM_STEP)
	elif event.is_action_pressed("cam_zoom_out"):
		_nudge_zoom(ZOOM_STEP)

func _nudge_zoom(factor: float) -> void:
	_zoom_target = clampf(_zoom_target * factor, ZOOM_MIN, ZOOM_MAX)

## What the player currently sees, 1.0 being the shipped framing.
func zoom_level() -> float:
	return zoom

## Replace the zoom-1.0 pose, for `dev_menu.gd`'s camera presets. Resets the level,
## so a preset lands on exactly its own numbers rather than on whatever the wheel
## happened to be at -- otherwise the overlay's readout lies.
func set_rest_pose(pos: Vector3, ortho_size := 0.0) -> void:
	_rest_pose = pos
	_rest_size = ortho_size
	_zoom_target = 1.0
	zoom = 1.0

func _apply_zoom(delta: float) -> void:
	zoom = lerpf(zoom, _zoom_target, 1.0 - exp(-ZOOM_LERP * delta))
	if absf(zoom - _zoom_target) < 0.001:
		zoom = _zoom_target
	_cam_base = _rest_pose * zoom
	if _rest_size > 0.0:
		_camera.size = _rest_size * zoom
	if _shake_t <= 0.0:
		_camera.position = _cam_base
	_scale_prompts()

## Counter-scale the world-space `Label3D` prompts so they hold their size on
## screen as the camera pulls back.
##
## They are authored in **metres** in half a dozen scenes, so there is no single
## number to change; instead each label's authored `pixel_size` is remembered the
## first time it is seen and scaled from there. Prompts hang off `interactable`
## nodes, which is the group that already wires every buyable thing in the game, so
## nothing has to join a new one.
##
## Only runs when the level has actually moved -- while you are not scrolling this
## costs one float comparison a frame.
func _scale_prompts() -> void:
	if absf(zoom - _prompt_zoom) < 0.005:
		return
	_prompt_zoom = zoom
	for node in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(node):
			continue
		for label in _labels_of(node):
			var id := label.get_instance_id()
			if not _prompt_base.has(id):
				_prompt_base[id] = label.pixel_size
			label.pixel_size = float(_prompt_base[id]) * zoom

func _labels_of(node: Node) -> Array[Label3D]:
	var out: Array[Label3D] = []
	for child in node.get_children():
		if child is Label3D:
			out.append(child)
	return out

# ---------------------------------------------------------------- shake

## A thump the player feels -- something heavy landing, e.g. a gate dropping into
## a finished wall. It shakes the camera, not the rig, so following the monarch
## and the Z / X spin are untouched.
func shake(duration: float, strength: float) -> void:
	if _shake_t > 0.0 and strength < _shake_amp:
		return    # a small thump doesn't cut a big one short
	_shake_len = duration
	_shake_t = duration
	_shake_amp = strength

## Offsets from `_cam_base`, which [method _apply_zoom] owns.
##
## This used to *adopt* `_camera.position` as its rest pose, so that an external
## writer -- the editor's live scene sync, or "any future dynamic zoom" -- would not
## be stomped. The future arrived: zoom is that writer, and it now sets `_cam_base`
## directly, which is both simpler and correct while a shake is in flight (adopting
## mid-shake would have baked the shake offset in as the new rest).
func _shake_camera(delta: float) -> void:
	if _shake_t <= 0.0:
		return
	_shake_t -= delta
	var fade: float = clampf(_shake_t / _shake_len, 0.0, 1.0)
	var a := _shake_amp * fade * fade
	_camera.position = _cam_base + Vector3(randf_range(-a, a), randf_range(-a, a), 0.0)
	if _shake_t <= 0.0:
		_camera.position = _cam_base

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
	_apply_zoom(delta)
	_shake_camera(delta)

	if target:
		var goal := Vector3(target.global_position.x, 0.0, target.global_position.z)
		global_position = global_position.lerp(goal, clamp(FOLLOW_LERP * delta, 0.0, 1.0))
