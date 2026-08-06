extends CharacterBody3D

const SPEED := 5.0
const ACCEL := 60.0

## The body's rise and fall, and its fore-aft pitch, driven off the **same**
## per-stride footfall data (`GAITS[gait]["at"]`) that already drives the
## hoofbeats -- so picture and sound finally share one clock, which is exactly
## what `stride_phase()` below was built to make possible. A gallop's shape is
## "sink, sink, SINK, float": the body drops into each landing and lifts clear
## during the suspension, so the curve is built the same way -- a dip pulse
## centred on every entry in `at`, and a lift that grows with distance from the
## nearest one. It generalises to any gait in the table, not just the one in use.
const SURGE_DIP := 0.075        # how far the body sinks into a landing, in metres
const SURGE_DIP_WIDTH := 0.10   # fraction of a stride a landing's sink spans
const SURGE_LOFT := 0.11        # how far the body lifts clear of every landing
const SURGE_LOFT_EASE := 0.24   # fraction of a stride to ease from a landing into full loft
## Degrees. Small on purpose -- the hoofbeat mix keeps every accent shallow for
## the same reason (see `GAITS`' own comment): a strong cue gives the eye
## something to lock onto, and a subtle one reads as weight rather than cartoon.
const PITCH_DIVE := 5.0         # nose-down, reaching into a landing
const PITCH_RISE := 3.0         # nose-up, through the loft
const SETTLE_RATE := 3.0        # how fast pitch eases back to level once stopped

## **A gallop is not an even tick.** Hoof-falls come bunched, and then all four
## feet leave the ground -- the suspension -- and there is silence until the next
## stride. That gap is the whole rhythm: evenly spaced strikes read as
## "T T T T T", the bunch-then-gap reads as "da-da-da-DUM ... da-da-da-DUM".
##
## A gallop lands **two feet close together, then the other two close together**,
## then all four leave the ground and there is silence until the next stride --
## "ta-TAM ta-TAM ... ta-TAM ta-TAM". Spacing the four falls evenly was the first
## attempt and read as a tick; the pairing is the whole thing.
##
## Each gait is:
##   at      where each hoof falls, as a fraction of one stride
##   gain    that fall's level relative to HOOF_DB. A gallop builds toward the
##           lead hoof, so the second of each pair is the louder
##   stride  seconds for one full stride at top speed, scaled by real speed --
##           which is why a faster gallop later needs no second set of numbers
## Anything after the last `at` entry is suspension.
##
## **Only "gallop" is used today**; the horse has one speed. The rest are here so
## that adding a walk later is a `set_gait()` call and a tuning pass rather than
## a rewrite. Their numbers are textbook footfalls, **never heard in this game** --
## a starting point, not a setting.
const GAITS := {
	"gallop": {                                  # <- in use
		"at": [0.00, 0.09, 0.30, 0.39],
		# Shallow on purpose. A strong accent gives the ear a beat to lock onto,
		# and a rhythm you can lock onto is a rhythm you attend to. The pairing
		# in `at` is what carries the gait; the accents only shade it.
		"gain": [-3.5, -2.0, -1.5, 0.0],
		"stride": 0.62,
	},
	"canter": {                                  # UNTUNED, unused
		"at": [0.00, 0.18, 0.30],
		"gain": [-4.0, -2.0, 0.0],
		"stride": 0.70,
	},
	"trot": {                                    # UNTUNED, unused
		"at": [0.00, 0.50],
		"gain": [-1.0, -1.0],
		"stride": 0.78,
	},
	"walk": {                                    # UNTUNED, unused
		"at": [0.00, 0.25, 0.50, 0.75],
		"gain": [-2.0, -2.0, -2.0, -2.0],
		"stride": 1.10,
	},
}
const DEFAULT_GAIT := "gallop"

## The stride clock drives the hoofbeats *and* the body's motion (`_gait_pose`)
## off the same `_stride` value, via `stride_phase()` -- picture and sound share
## one clock, rather than a decorative bounce running on its own timer next to it.
const HOOF_CLIPS := [
	preload("res://kingdom_demo/assets/audio/hoof_1.ogg"),
	preload("res://kingdom_demo/assets/audio/hoof_2.ogg"),
	preload("res://kingdom_demo/assets/audio/hoof_3.ogg"),
	preload("res://kingdom_demo/assets/audio/hoof_4.ogg"),
	preload("res://kingdom_demo/assets/audio/hoof_5.ogg"),
	preload("res://kingdom_demo/assets/audio/hoof_6.ogg"),
]
## Six clips, more than any other pool in the game, because this is far and away
## the most repeated sound in it: about four a second, and the player is rarely
## not riding. Quiet for the same reason -- it should sit under everything.
const HOOF_PITCH := 1.1
## Small. Level that jumps about between strikes is itself a thing to notice, and
## the point of this sound is not to be noticed.
const HOOF_VOL_JITTER := 2.0
## **Deliberately almost too quiet.** This should tell you that you are moving
## without ever becoming something you listen to -- you hear it for an hour, and
## anything you can pick out of the mix at that rate turns into nagging. If it
## feels like it has vanished, this is the one number to raise; every accent in
## GAITS is relative to it, so they all move together.
const HOOF_DB := -25.0
## The two falls of a pair are ~56 ms apart and the clips run 206 ms, so several
## are always sounding at once -- which is how a gallop sounds. One player would
## cut each strike off to start the next and the whole thing would come out
## clipped, so strikes are spread round a ring of voices and left to ring out.
## Raise this if the clips are ever lengthened again.
const HOOF_VOICES := 6

## The horse while you stand still: snorts, a blow, the occasional soft nicker.
## **A standing horse is not a silent object**, and the pauses are when the
## player is reading the camp and deciding what to buy -- this is what stops
## those moments going dead.
##
## The gap is wide on purpose. Too regular and it becomes a metronome telling
## you how long you have been idle; it should feel like the animal happening to
## do something, not a timer expiring.
const IDLE_CLIPS := [
	preload("res://kingdom_demo/assets/audio/horse_snort_1.ogg"),
	preload("res://kingdom_demo/assets/audio/horse_snort_2.ogg"),
	preload("res://kingdom_demo/assets/audio/horse_snort_3.ogg"),
	preload("res://kingdom_demo/assets/audio/horse_snort_4.ogg"),
	preload("res://kingdom_demo/assets/audio/horse_nicker.ogg"),
]
const IDLE_GAP := Vector2(6.0, 18.0)
const IDLE_PITCH := 1.08
const IDLE_VOL_JITTER := 3.5
const IDLE_DB := -13.0

@onready var interact_area: Area3D = $InteractArea
@onready var model: Node3D = $Model

var _nearby: Array = []
var _highlighted: Node3D = null
var _base_y := 0.0
var _yaw := 0.0
var _hooves: Array[AudioStreamPlayer3D] = []
var _voice := 0
## 0..1 through the current stride, and the next hoof-fall due within it.
var _stride := 0.0
var _fall := 0
var _gait := DEFAULT_GAIT
var _idle_voice: AudioStreamPlayer3D = null
var _idle_t := 0.0

func _ready() -> void:
	add_to_group("monarch")
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	_base_y = model.position.y
	for i in range(HOOF_VOICES):
		_hooves.append(_make_hoof())
	_idle_voice = _make_voice(IDLE_CLIPS, IDLE_PITCH, IDLE_VOL_JITTER, IDLE_DB, 6.0, 22.0)
	_idle_t = randf_range(IDLE_GAP.x, IDLE_GAP.y)

func _physics_process(delta: float) -> void:
	var input_dir := Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		input_dir.z -= 1.0
	if Input.is_action_pressed("move_back"):
		input_dir.z += 1.0
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1.0
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1.0
	input_dir = input_dir.normalized()

	# move relative to where the camera is looking (Thronefall-style)
	var rig = get_tree().get_first_node_in_group("camera_rig")
	if rig:
		input_dir = input_dir.rotated(Vector3.UP, rig.yaw)

	var target_velocity := input_dir * SPEED
	velocity.x = move_toward(velocity.x, target_velocity.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, ACCEL * delta)
	move_and_slide()

	_animate(delta, input_dir.length() > 0.1)
	_update_highlight()

	if Input.is_action_just_pressed("interact"):
		_try_interact()

func _animate(delta: float, moving: bool) -> void:
	if moving:
		# the horse's gait, plus turning to face the way we ride
		_advance_stride(delta)
		var pose := _gait_pose(_stride)
		model.position.y = _base_y + pose.x
		model.rotation.x = deg_to_rad(pose.y)
		# Re-armed every frame under way, so the clock only ever starts once you
		# have actually stopped -- never mid-ride.
		_idle_t = randf_range(IDLE_GAP.x, IDLE_GAP.y)
		if Vector2(velocity.x, velocity.z).length() > 0.1:
			_yaw = lerp_angle(_yaw, atan2(velocity.x, velocity.z), 0.2)
			model.rotation.y = _yaw
	else:
		model.position.y = move_toward(model.position.y, _base_y, delta * 0.6)
		model.rotation.x = move_toward(model.rotation.x, 0.0, delta * SETTLE_RATE)
		# Park the stride at its start so pulling away again opens on the first
		# hoof of a stride rather than halfway through one.
		_stride = 0.0
		_fall = 0
		_idle_t -= delta
		if _idle_t <= 0.0:
			_idle_t = randf_range(IDLE_GAP.x, IDLE_GAP.y)
			if is_instance_valid(_idle_voice):
				_idle_voice.play()

## The body's vertical offset and fore-aft pitch (degrees) for `stride`, built off
## the current gait's footfall table: a dip pulse centred on every entry in `at`
## (the harder the fall's accent in `gain`, the deeper the dip), and a lift that
## grows with distance from the nearest one, peaking through the suspension.
## Returns (height, pitch) so `_animate` only ever has one place to read from.
func _gait_pose(stride: float) -> Vector2:
	var at: Array = GAITS[_gait]["at"]
	var gain: Array = GAITS[_gait]["gain"]
	var dip := 0.0
	var min_gap := INF
	for i in range(at.size()):
		var d := absf(stride - float(at[i]))
		d = minf(d, 1.0 - d)               # wrap around the stride
		min_gap = minf(min_gap, d)
		if d < SURGE_DIP_WIDTH:
			var w := 1.0 - d / SURGE_DIP_WIDTH
			w *= w                          # ease in toward the landing
			# a louder fall (gain closer to 0 dB) hits harder -- same accent the
			# ear gets, now something the eye gets too
			var accent := inverse_lerp(-4.0, 0.0, float(gain[i]))
			dip += w * lerpf(0.6, 1.0, clampf(accent, 0.0, 1.0))
	dip = clampf(dip, 0.0, 1.0)
	var loft := smoothstep(0.0, SURGE_LOFT_EASE, min_gap)
	var height := SURGE_LOFT * loft - SURGE_DIP * dip
	var pitch := PITCH_RISE * loft - PITCH_DIVE * dip
	return Vector2(height, pitch)

## 0..1 through the current stride -- what `_gait_pose` reads, and what the
## hoofbeats step through, so picture and sound never drift apart.
func stride_phase() -> float:
	return _stride

## Swap gait. Restarts the stride so the change lands on a whole beat rather than
## halfway through the old pattern.
func set_gait(name: String) -> void:
	if not GAITS.has(name) or name == _gait:
		return
	_gait = name
	_stride = 0.0
	_fall = 0

func gait() -> String:
	return _gait

## Walks the stride clock forward and fires whichever hoof-falls it passed.
## Scaled by real speed, so pulling away and a future faster gallop both change
## the rhythm without a second set of numbers.
func _advance_stride(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length() / SPEED
	if speed <= 0.01:
		return
	var at: Array = GAITS[_gait]["at"]
	var gain: Array = GAITS[_gait]["gain"]
	_stride += delta * speed / float(GAITS[_gait]["stride"])
	while _stride >= 1.0:
		_stride -= 1.0
		_fall = 0
	# `while`, not `if` -- a long frame can step past more than one hoof-fall,
	# and skipping them would drop beats out of the rhythm.
	while _fall < at.size() and _stride >= float(at[_fall]):
		_step(float(gain[_fall]))
		_fall += 1

func _make_hoof() -> AudioStreamPlayer3D:
	return _make_voice(HOOF_CLIPS, HOOF_PITCH, HOOF_VOL_JITTER, HOOF_DB, 7.0, 26.0)

## One randomiser wrapping a clip pool, on its own positional player. Same shape
## as `ambience.gd::_make_voice`; kept local because the monarch's voices hang
## off him rather than off the ambience node.
func _make_voice(clips: Array, pitch: float, jitter: float, db: float,
		unit: float, reach: float) -> AudioStreamPlayer3D:
	var pool := AudioStreamRandomizer.new()
	for i in range(clips.size()):
		pool.add_stream(i, clips[i])
	pool.random_pitch = pitch
	pool.random_volume_offset_db = jitter
	pool.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	var p := AudioStreamPlayer3D.new()
	p.stream = pool
	p.bus = &"SFX"
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = reach
	add_child(p)
	return p

## One hoof, on the next voice round the ring so it can ring out over the last.
## Positional rather than flat, so spinning the camera with Z / X pans the horse
## under you instead of leaving it glued to the centre of the mix.
func _step(gain: float) -> void:
	if _hooves.is_empty():
		return
	var p := _hooves[_voice]
	_voice = (_voice + 1) % _hooves.size()
	if is_instance_valid(p):
		p.volume_db = HOOF_DB + gain
		p.play()

## A subject kneeling to present their take -- the king rises in the saddle and a
## glint of gold goes up as he accepts it.
func receive_tribute() -> void:
	_punch()
	MarkFx.debris(self, global_position + Vector3(0, 1.5, 0), Vector3.ZERO,
		6, Color(0.86, 0.70, 0.32, 1.0), 0.012, 0.7)

func _punch() -> void:
	var t := create_tween()
	t.tween_property(model, "position:y", _base_y + 0.14, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(model, "position:y", _base_y, 0.14).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("interactable") and body not in _nearby:
		_nearby.append(body)

func _on_body_exited(body: Node3D) -> void:
	_nearby.erase(body)

func _closest_interactable() -> Node3D:
	var closest: Node3D = null
	var closest_dist := INF
	for body in _nearby:
		if not is_instance_valid(body) or not body.is_in_group("interactable"):
			continue
		var dist := global_position.distance_to(body.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = body
	return closest

func _update_highlight() -> void:
	# Mid-payment the king stays locked on whatever he is counting gold into:
	# walking past something else neither switches the highlight nor lights up a
	# second prompt, so only ever one tally is on screen.
	if GoldFx.is_paying():
		return
	var closest := _closest_interactable()
	if closest == _highlighted:
		return
	if is_instance_valid(_highlighted) and _highlighted.has_method("hide_prompt"):
		_highlighted.hide_prompt()
	_highlighted = closest
	if is_instance_valid(_highlighted) and _highlighted.has_method("show_prompt"):
		_highlighted.show_prompt()

func _try_interact() -> void:
	if GoldFx.is_paying():
		return
	if not is_instance_valid(_highlighted) or not _highlighted.has_method("interact"):
		return
	_highlighted.interact(self)
	_punch()

