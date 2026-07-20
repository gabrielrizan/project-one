extends Node
## The outdoor sound of the map: two looping beds crossfaded by the day/night
## cycle, with sparse one-shots fired over the top.
##
## The split matters. A bed is deliberately featureless and loops forever -- if
## you can pick out an event in it, that event repeats until the end of time and
## the loop becomes obvious. All the character lives in the **one-shots**, which
## fire at randomised intervals from randomised positions, so there is no rhythm
## for the ear to latch onto. That is what stops ambience sounding looped, and it
## is why beds and one-shots are sourced against opposite criteria (see
## `ASSETS.md`, "What to listen for").
##
## Players are built in code rather than sat in the scene, the same way `menu.gd`
## builds its layout and `wall_side.gd` builds its collision.

const DAY_BED := preload("res://kingdom_demo/assets/audio/ambience_day.ogg")
const NIGHT_BED := preload("res://kingdom_demo/assets/audio/ambience_night.ogg")
const OWL := preload("res://kingdom_demo/assets/audio/owl_hoot.ogg")
## Three lengths on purpose -- a tick, a creak and a long groan -- so the pool
## has real variety rather than one recognisable noise at random intervals.
const CREAKS := [
	preload("res://kingdom_demo/assets/audio/tree_creak_a.ogg"),
	preload("res://kingdom_demo/assets/audio/tree_creak_b.ogg"),
	preload("res://kingdom_demo/assets/audio/tree_creak_c.ogg"),
]
## Long drawn-out calls only. A short clipped "cah" reads as a different bird
## entirely and stuck out badly against these.
const CROWS := [
	preload("res://kingdom_demo/assets/audio/crow_a.ogg"),
	preload("res://kingdom_demo/assets/audio/crow_b.ogg"),
	preload("res://kingdom_demo/assets/audio/crow_c.ogg"),
]

const BED_DB := -2.0
## far enough down to be inaudible without the cost of stopping and restarting
const BED_OFF_DB := -45.0
## dB per second -- dusk eases the beds across rather than snapping
const FADE_RATE := 3.0

## An owl should be noticed, then forgotten, then surprise you again. That needs a
## gap wide enough that you stop expecting it: anywhere from half a minute to over
## a minute and a half, redrawn every time.
const OWL_GAP := Vector2(30.0, 100.0)
## Pitch and volume are jittered per hoot, so the same clip never lands twice the
## same way, and it is thrown somewhere out in the dark rather than played flat --
## direction is most of what makes it feel like an owl and not a sound effect.
const OWL_PITCH := 1.14
const OWL_VOL_JITTER := 5.0
const OWL_DISTANCE := Vector2(14.0, 30.0)

## Timber groans by day. Unlike the owl this is not thrown to a random bearing --
## it comes out of an actual trunk near the monarch, so it only ever happens where
## there are trees to make the noise. Ride into open ground and the woods go quiet.
const CREAK_GAP := Vector2(11.0, 34.0)
const CREAK_PITCH := 1.2
const CREAK_VOL_JITTER := 4.0
const CREAK_RANGE := 17.0     # how close a trunk has to be to be worth creaking

## PARKED. The day bed already has crows in it, distant and behind the wind, and
## those sound right. Anything we add on top arrives closer and sharper than the
## ones already in the recording, and reads as a second, wrong bird -- three
## different clip sets all failed the same way. Flip this to re-enable; the
## assets and the burst logic are all still here.
const CROWS_ENABLED := false

## A crow is the loudest thing in the daytime mix, so it is the rarest -- roughly
## once or twice across a two-minute day. Thrown to a bearing like the owl rather
## than pinned to a trunk: the bird is somewhere out there, not in a specific tree.
const CROW_GAP := Vector2(45.0, 130.0)
const CROW_PITCH := 1.12
const CROW_VOL_JITTER := 4.0
const CROW_DISTANCE := Vector2(12.0, 34.0)
## A real crow rarely calls just once, but it doesn't rattle off ten either.
## Weighted so one call is the common case, two is second, three is uncommon --
## and never more, so it can't turn into a racket.
const CROW_CALL_WEIGHTS := [60, 28, 12]      # 1x, 2x, 3x
## Pause between calls in a burst. Has to clear the clip length -- the calls are
## drawn-out (0.8-1.3s), and a shorter gap stacks them into a racket.
const CROW_CALL_GAP := Vector2(1.15, 1.9)

var _day: AudioStreamPlayer = null
var _night: AudioStreamPlayer = null
var _owl: AudioStreamPlayer3D = null
var _creak: AudioStreamPlayer3D = null
var _crow: AudioStreamPlayer3D = null
var _owl_t := 0.0
var _creak_t := 0.0
var _crow_t := 0.0

func _ready() -> void:
	_day = _make_bed(DAY_BED, BED_DB)
	_night = _make_bed(NIGHT_BED, BED_OFF_DB)
	_owl = _make_voice([OWL], OWL_PITCH, OWL_VOL_JITTER, 18.0, 60.0)
	_creak = _make_voice(CREAKS, CREAK_PITCH, CREAK_VOL_JITTER, 6.0, 28.0)
	_crow = _make_voice(CROWS, CROW_PITCH, CROW_VOL_JITTER, 16.0, 60.0)
	_owl_t = randf_range(OWL_GAP.x, OWL_GAP.y)
	_creak_t = randf_range(CREAK_GAP.x, CREAK_GAP.y)
	_crow_t = randf_range(CROW_GAP.x, CROW_GAP.y)

func _process(delta: float) -> void:
	var night := _is_night()
	_fade(_day, BED_OFF_DB if night else BED_DB, delta)
	_fade(_night, BED_DB if night else BED_OFF_DB, delta)

	if night:
		_owl_t -= delta
		if _owl_t <= 0.0:
			_owl_t = randf_range(OWL_GAP.x, OWL_GAP.y)
			_call_from_a_bearing(_owl, OWL_DISTANCE)
	else:
		_creak_t -= delta
		if _creak_t <= 0.0:
			_creak_t = randf_range(CREAK_GAP.x, CREAK_GAP.y)
			_creak_from_a_tree()
		if CROWS_ENABLED:
			_crow_t -= delta
			if _crow_t <= 0.0:
				_crow_t = randf_range(CROW_GAP.x, CROW_GAP.y)
				_crow_burst()

# ---- beds ----

func _make_bed(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = &"Ambience"
	p.volume_db = db
	add_child(p)
	p.play()
	return p

func _fade(p: AudioStreamPlayer, want: float, delta: float) -> void:
	p.volume_db = move_toward(p.volume_db, want, FADE_RATE * delta)

# ---- one-shots ----

## An [AudioStreamRandomizer] wrapping a clip pool. It picks a clip at random and
## jitters pitch and volume per play, so nothing ever lands twice the same way.
## Growing a pool later is one more entry in the array, nothing else.
func _make_voice(streams: Array, pitch: float, vol_jitter: float,
		unit_size: float, max_distance: float) -> AudioStreamPlayer3D:
	var pool := AudioStreamRandomizer.new()
	for i in range(streams.size()):
		pool.add_stream(i, streams[i])
	pool.random_pitch = pitch
	pool.random_volume_offset_db = vol_jitter
	pool.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	var p := AudioStreamPlayer3D.new()
	p.stream = pool
	p.bus = &"Ambience"
	p.unit_size = unit_size
	p.max_distance = max_distance
	add_child(p)
	return p

## Throw the voice to a random bearing at a random distance from the monarch, so
## it arrives from somewhere new each time. Used by anything that is "out there
## somewhere" rather than attached to a thing you can see -- owl, crow.
func _call_from_a_bearing(p: AudioStreamPlayer3D, distance: Vector2) -> void:
	var king := get_tree().get_first_node_in_group("monarch")
	var from: Vector3 = king.global_position if king else Vector3.ZERO
	var angle := randf() * TAU
	var r := randf_range(distance.x, distance.y)
	p.global_position = from + Vector3(cos(angle), 0.0, sin(angle)) * r
	p.play()

## One crow, calling once, twice or (rarely) three times from the same spot --
## the bird doesn't move between calls, so the bearing is picked once and the
## repeats come from there. Awaits between calls rather than queueing timers.
func _crow_burst() -> void:
	_call_from_a_bearing(_crow, CROW_DISTANCE)
	var calls := _weighted_pick(CROW_CALL_WEIGHTS) + 1
	for i in range(calls - 1):
		await get_tree().create_timer(randf_range(CROW_CALL_GAP.x, CROW_CALL_GAP.y)).timeout
		if not is_instance_valid(_crow) or _is_night():
			return                      # dusk landed mid-burst; let it drop
		_crow.play()

## Index into `weights`, chosen in proportion to them.
func _weighted_pick(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += int(w)
	var roll := randi() % maxi(total, 1)
	for i in range(weights.size()):
		roll -= int(weights[i])
		if roll < 0:
			return i
	return weights.size() - 1

## Pick a standing trunk within earshot and groan out of that one. Nothing plays
## when there is no tree near enough -- the sound has to have a source.
func _creak_from_a_tree() -> void:
	var king := get_tree().get_first_node_in_group("monarch")
	if king == null:
		return
	var near: Array[Node3D] = []
	for t in get_tree().get_nodes_in_group("tree"):
		if king.global_position.distance_to(t.global_position) <= CREAK_RANGE:
			near.append(t)
	if near.is_empty():
		return
	_creak.global_position = near[randi() % near.size()].global_position + Vector3(0, 1.6, 0)
	_creak.play()

func _is_night() -> bool:
	var cycle := get_tree().get_first_node_in_group("day_night_cycle")
	return cycle != null and cycle.is_night()
