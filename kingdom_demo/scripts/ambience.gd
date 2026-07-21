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
## `tree_creak_a` (0.4s) is **deliberately not in this pool**. It was a tick: you
## noticed it and it was gone, which is the opposite of what a creak should do.
## What is left are the two long ones -- a groan should arrive slowly, hold long
## enough to be worth turning your head for, and leave without a clear end.
const CREAKS := [
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

## Rain is **two** beds, not one turned up. A drizzle and a downpour are
## different sounds, not the same sound at different volumes: the light bed is a
## thin hiss, the heavy one carries roughly twice the low-end weight. They layer
## rather than crossfade -- at full intensity both are up, which is what gives a
## downpour its body.
const RAIN_LIGHT := preload("res://kingdom_demo/assets/audio/rain_light.ogg")
const RAIN_HEAVY := preload("res://kingdom_demo/assets/audio/rain_heavy.ogg")
## Distant thunder, four cuts from one long recording so they all sit in the
## same weather. Lengths vary on purpose (5.9s / 6.3s / 7.6s / 13s) -- one deep
## roll among shorter rumbles, the same reasoning as the tree creaks.
const THUNDER := [
	preload("res://kingdom_demo/assets/audio/thunder_1.ogg"),
	preload("res://kingdom_demo/assets/audio/thunder_2.ogg"),
	preload("res://kingdom_demo/assets/audio/thunder_3.ogg"),
	preload("res://kingdom_demo/assets/audio/thunder_4.ogg"),
]
## The near strike, cut from the same recording. It is not in the pool above --
## it is chosen by *distance*, so the one clip with a real crack in it only ever
## plays when the flash was close. Picking it at random would put a nearby
## thunderclap on a storm sitting on the horizon.
##
## Distance low-passes thunder, so "close" is a measurable thing rather than a
## louder version of the same sound: this cut carries several times the 1-6 kHz
## content of the rolling ones. Every clip is normalised, so level is set at
## playback, not baked in.
const THUNDER_NEAR := preload("res://kingdom_demo/assets/audio/thunder_near.ogg")

## The watch horn. **Meaning is carried by the number of blasts, not by
## different sounds**: one for nightfall, two for an attack, three for a blood
## moon. Combat therefore needs no new clip and no new vocabulary to teach.
##
## At nightfall the player is listening to find out *which kind of night this
## is*, so the blasts must be countable -- see `ALARM_GAP`.
const HORN_NIGHT := preload("res://kingdom_demo/assets/audio/horn_night.ogg")

## **Daybreak is a cockerel, not a horn.** That split is the point: the horn only
## ever means danger, so the count never has to compete with a "good news" call.
## `horn_dawn.ogg` is the superseded higher-register horn -- kept, not wired.
##
## Deep on purpose -- its fundamental is ~662 Hz against the ~930 Hz of the first
## bird tried, which read as shrill.
##
## **The whole crow, never a slice of one.** A rooster's call is "er-er-er-ERRRR":
## a build, a snatched breath, then the finish. An earlier version cut 0.74s out
## of a farmyard recording and landed mid-build, which was heard as "sped up" --
## the same mistake made with the horn. This is the complete 1.6s call, pitched
## down (which lengthens it to 2.3s, and a deep crow is genuinely slower).
## `rooster_alt_b/c.ogg` are other candidates from the audition, kept, not wired.
const ROOSTER := preload("res://kingdom_demo/assets/audio/rooster.ogg")
## On its own voice rather than the horn's. The horn carries deliberately
## (unit_size 34, reach 200) because it is a signal meant to reach the whole map;
## a cockerel borrowing those settings arrived enormous and right on top of you.
## The brief was "not astonishingly loud", not "distant" -- so this is a normal
## village sound, present and clear, just not a blast.
const ROOSTER_DB := -14.0
const ROOSTER_UNIT := 7.0
const ROOSTER_REACH := 40.0
## **The same spot every morning.** A bird lives somewhere; it does not move
## round the camp overnight. Fixed north-east of the fire so it becomes a place
## you know rather than a noise from nowhere -- and once there is a coop or a
## hall to hang it on, this should read its position off that instead.
const ROOSTER_AT := Vector3(11.0, 1.4, -7.0)
const HORN_DB := -12.0
## **Longer than the blast, so there is real silence between them.** The count is
## the message -- one for nightfall, two for an attack -- and at nightfall the
## player is listening to find out which kind of night this is. If the blasts
## run together you cannot count them, and the signal says nothing. An earlier
## version overlapped them deliberately and that was the mistake: 1.5s of gap
## under a 3.25s blast meant the second landed while the first was still at full
## voice. The blast is 2.0s now -- lengthened for gravitas, since a short one had
## no room to breathe -- and its last quarter is decay, so a 2.5s gap leaves half
## a second of real air plus a fading tail. **Lengthen this whenever the blast is
## lengthened**, or the count stops being readable.
const ALARM_GAP := 2.5
## Two voices, so a blast's tail can still ring under the next attack.
const HORN_VOICES := 2

## How many blasts each signal is. **The number is the whole vocabulary**, so
## these must stay distinct and countable.
const HORN_NIGHTFALL := 1
const HORN_ATTACK := 2
## 🔮 Concept only, borrowed from Kingdom Two Crowns -- a worse night than a
## normal raid. Nothing raises it yet; it exists so the vocabulary has room and
## so it can be heard from the dev overlay.
const HORN_BLOODMOON := 3

## **Fired off how dark it actually is, never off the clock.** The day and night
## durations are placeholder and will be retuned; `darkness()` crossing a
## threshold means the horn keeps landing at the right moment whatever they
## become. Dusk is darkness rising off the floor, dawn is it coming back off
## the ceiling.
const HORN_AT_DUSK := 0.04
const HORN_AT_DAWN := 0.96

const BED_DB := -2.0
## far enough down to be inaudible without the cost of stopping and restarting
const BED_OFF_DB := -45.0
## dB per second -- dusk eases the beds across rather than snapping
const FADE_RATE := 3.0

const RAIN_DB := -3.0
## Rain fades faster than the day/night beds. Those cross over a 20s dusk and
## want to be imperceptible; rain has to keep up with weather that ramps 0..1 in
## about seven seconds, and at the beds' 3 dB/s it was still climbing out of the
## silent floor long after the downpour was on screen.
const RAIN_FADE_RATE := 10.0
## Where each rain bed comes in. The light one is most of the way up before the
## heavy one starts, so intensifying rain thickens rather than swaps.
const RAIN_LIGHT_IN := Vector2(0.02, 0.30)
const RAIN_HEAVY_IN := Vector2(0.35, 0.95)
## How far the day/night bed is pushed down under a downpour. Heavy rain really
## does drown out birdsong and insects; without this the two layers just pile up
## and the mix turns to mush.
const RAIN_DUCK := 9.0

## Thunder is thrown to a bearing like the owl -- the storm is somewhere out
## there rather than overhead. Distances are large and `unit_size` with it, so
## it reads as far away without becoming inaudible.
const THUNDER_DB := -5.0
const THUNDER_PITCH := 1.1
const THUNDER_VOL_JITTER := 3.0
const THUNDER_DISTANCE := Vector2(26.0, 48.0)

## A strike whose sound arrives within this many seconds was close, so it gets
## the near clip and a nearer position. **The pick is driven by the delay rather
## than rolled separately** -- a sharp crack arriving nine seconds after the
## flash would put the strike miles away and sound wrong for what you saw.
const NEAR_DELAY := 4.0
## Noticeably closer, not deafening -- a few dB up and from half the distance,
## which is plenty when it also carries far more treble than the rolling cuts.
const THUNDER_NEAR_DB := -1.5
const THUNDER_NEAR_DISTANCE := Vector2(12.0, 22.0)

## Deer, out in the woods. Like the tree creak this comes **out of a real animal**
## rather than a bearing -- if there is nothing alive within earshot the woods
## stay quiet, so it can never contradict what you can see.
##
## **Held to "subtle or not at all".** The calls were rolled off at 3.2 kHz before
## they got here, which reads as distance rather than merely quiet, and the gap
## is very wide. If you can tell it apart from the bed it is already too loud.
const DEER := [
	preload("res://kingdom_demo/assets/audio/deer_1.ogg"),
	preload("res://kingdom_demo/assets/audio/deer_2.ogg"),
	preload("res://kingdom_demo/assets/audio/deer_3.ogg"),
]
const DEER_GAP := Vector2(28.0, 85.0)
const DEER_PITCH := 1.1
const DEER_VOL_JITTER := 3.0
const DEER_DB := -19.0
## Far enough that the animal is usually off-screen -- something out there, not
## the stag you are looking at.
const DEER_RANGE := 34.0

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
const CREAK_GAP := Vector2(14.0, 40.0)
const CREAK_PITCH := 1.2
const CREAK_VOL_JITTER := 4.0
const CREAK_RANGE := 17.0     # how close a trunk has to be to be worth creaking
## Sat well back. This should be something you half-hear and glance toward, not
## an event announcing itself over the bed.
const CREAK_DB := -9.0
## **Faded in rather than started.** A creak that begins at full level has an
## onset, and an onset is what makes the ear file it as an event and then lose
## interest once it stops. Easing up out of the bed over the best part of a
## second means it emerges instead -- present, but never quite starting.
const CREAK_FADE_IN := 0.9
const CREAK_FADE_FROM := 16.0    # dB below its level to open at

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
var _rain_light: AudioStreamPlayer = null
var _rain_heavy: AudioStreamPlayer = null
var _thunder: AudioStreamPlayer3D = null
var _thunder_near: AudioStreamPlayer3D = null
var _horns: Array[AudioStreamPlayer3D] = []
var _horn_voice := 0
var _rooster: AudioStreamPlayer3D = null
var _last_dark := 0.0
var _owl: AudioStreamPlayer3D = null
var _creak: AudioStreamPlayer3D = null
var _crow: AudioStreamPlayer3D = null
var _deer: AudioStreamPlayer3D = null
var _owl_t := 0.0
var _creak_t := 0.0
var _crow_t := 0.0
var _deer_t := 0.0

func _ready() -> void:
	_day = _make_bed(DAY_BED, BED_DB)
	_night = _make_bed(NIGHT_BED, BED_OFF_DB)
	_rain_light = _make_bed(RAIN_LIGHT, BED_OFF_DB)
	_rain_heavy = _make_bed(RAIN_HEAVY, BED_OFF_DB)
	_thunder = _make_voice(THUNDER, THUNDER_PITCH, THUNDER_VOL_JITTER, 45.0, 140.0)
	# A one-clip pool, so it still gets the randomiser's pitch and volume jitter
	# and never lands twice the same way.
	_thunder_near = _make_voice([THUNDER_NEAR], THUNDER_PITCH, THUNDER_VOL_JITTER, 30.0, 120.0)
	for i in range(HORN_VOICES):
		_horns.append(_make_voice([HORN_NIGHT], 1.0, 0.0, 34.0, 200.0))
	_rooster = _make_voice([ROOSTER], 1.03, 1.5, ROOSTER_UNIT, ROOSTER_REACH)
	_rooster.volume_db = ROOSTER_DB
	# Weather may not have run `_ready` yet, so the hookup waits a frame.
	call_deferred("_hook_weather")
	_owl = _make_voice([OWL], OWL_PITCH, OWL_VOL_JITTER, 18.0, 60.0)
	_creak = _make_voice(CREAKS, CREAK_PITCH, CREAK_VOL_JITTER, 6.0, 28.0)
	_crow = _make_voice(CROWS, CROW_PITCH, CROW_VOL_JITTER, 16.0, 60.0)
	_deer = _make_voice(DEER, DEER_PITCH, DEER_VOL_JITTER, 9.0, 46.0)
	_owl_t = randf_range(OWL_GAP.x, OWL_GAP.y)
	_creak_t = randf_range(CREAK_GAP.x, CREAK_GAP.y)
	_crow_t = randf_range(CROW_GAP.x, CROW_GAP.y)
	_deer_t = randf_range(DEER_GAP.x, DEER_GAP.y)

func _process(delta: float) -> void:
	var night := _is_night()
	var rain := _rain_intensity()
	# Rain sits on top of whichever bed is playing, and pushes it down as it
	# gets heavier -- so a downpour at night is rain over a hint of insects,
	# not rain and insects at equal weight.
	var duck := RAIN_DUCK * clampf(rain, 0.0, 1.0)
	_fade(_day, BED_OFF_DB if night else BED_DB - duck, delta)
	_fade(_night, BED_DB - duck if night else BED_OFF_DB, delta)
	_fade(_rain_light, _rain_db(rain, RAIN_LIGHT_IN), delta, RAIN_FADE_RATE)
	_fade(_rain_heavy, _rain_db(rain, RAIN_HEAVY_IN), delta, RAIN_FADE_RATE)
	_watch_the_light()

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

	# Deer call day or night -- the woods are inhabited around the clock, and at
	# this level it never competes with the owl.
	_deer_t -= delta
	if _deer_t <= 0.0:
		_deer_t = randf_range(DEER_GAP.x, DEER_GAP.y)
		_call_from_an_animal()

# ---- beds ----

func _make_bed(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = &"Ambience"
	p.volume_db = db
	add_child(p)
	p.play()
	return p

func _fade(p: AudioStreamPlayer, want: float, delta: float, rate: float = FADE_RATE) -> void:
	p.volume_db = move_toward(p.volume_db, want, rate * delta)

# ---- rain ----

func _rain_intensity() -> float:
	var wx := get_tree().get_first_node_in_group("weather")
	return wx.intensity() if wx else 0.0

## Where one rain bed should sit for the current intensity. `band` is the window
## it fades up across; below it the bed is parked at the silent floor rather
## than stopped, so it never has to restart mid-storm.
func _rain_db(rain: float, band: Vector2) -> float:
	var gain := smoothstep(band.x, band.y, rain)
	if gain <= 0.001:
		return BED_OFF_DB
	return RAIN_DB + linear_to_db(gain)

# ---- thunder ----

func _hook_weather() -> void:
	var wx := get_tree().get_first_node_in_group("weather")
	if wx and not wx.lightning.is_connected(_on_lightning):
		wx.lightning.connect(_on_lightning)

## The flash has already happened -- `weather.gd` hands us how long the sound
## takes to arrive and how loud it should be when it does, both derived from the
## same distance. Waiting out the gap is the whole effect: seeing a storm light
## up and *then* hearing it is what puts it on the horizon rather than overhead.
func _on_lightning(delay: float, loudness: float) -> void:
	# Which clip is decided *before* the wait, off the same delay that sets how
	# long the wait is -- a short gap means the strike was close, so it gets the
	# clip with the crack on it and a nearer bearing.
	var near := delay <= NEAR_DELAY
	await get_tree().create_timer(delay).timeout
	var voice: AudioStreamPlayer3D = _thunder_near if near else _thunder
	if not is_instance_valid(voice):
		return
	var base := THUNDER_NEAR_DB if near else THUNDER_DB
	voice.volume_db = base + linear_to_db(clampf(loudness, 0.05, 1.0))
	_call_from_a_bearing(voice, THUNDER_NEAR_DISTANCE if near else THUNDER_DISTANCE)

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
	_creak.volume_db = CREAK_DB - CREAK_FADE_FROM
	_creak.play()
	var t := create_tween()
	t.tween_property(_creak, "volume_db", CREAK_DB, CREAK_FADE_IN).set_trans(Tween.TRANS_SINE)

## Out of an actual animal within earshot, the same way a creak comes out of an
## actual trunk. **Nothing plays when there is nothing alive nearby** -- so a
## call can never come from a wood you have already hunted empty, and the map
## going quiet as you strip it is a real thing you can hear.
func _call_from_an_animal() -> void:
	var king := get_tree().get_first_node_in_group("monarch")
	if king == null or not is_instance_valid(_deer):
		return
	var near: Array[Node3D] = []
	for a in get_tree().get_nodes_in_group("wild_game"):
		if king.global_position.distance_to(a.global_position) <= DEER_RANGE:
			near.append(a)
	if near.is_empty():
		return
	_deer.volume_db = DEER_DB
	_deer.global_position = near[randi() % near.size()].global_position + Vector3(0, 0.6, 0)
	_deer.play()

func _is_night() -> bool:
	var cycle := get_tree().get_first_node_in_group("day_night_cycle")
	return cycle != null and cycle.is_night()

# ---- the watch horn ----

## Watches the light rather than the clock and blows the horn as it turns.
func _watch_the_light() -> void:
	var cycle := get_tree().get_first_node_in_group("day_night_cycle")
	if cycle == null:
		return
	var dark: float = cycle.darkness()
	# Before the fire is lit there is no village and nobody to blow it, so the
	# threshold is still tracked -- just never acted on. Otherwise lighting the
	# fire at dusk would fire a horn for a crossing that already happened.
	if _village_exists():
		if _last_dark < HORN_AT_DUSK and dark >= HORN_AT_DUSK:
			blow_horn(HORN_NIGHTFALL)
		elif _last_dark > HORN_AT_DAWN and dark <= HORN_AT_DAWN:
			crow_daybreak()
	_last_dark = dark

func _village_exists() -> bool:
	var fire := get_tree().get_first_node_in_group("campfire")
	return fire != null and fire.lit

## Two blasts: the attack signal. **Public because combat will raise it** -- for
## now only the dev overlay does, since there is nothing to be attacked by.
func sound_alarm() -> void:
	blow_horn(2)

## `blasts` of the deep horn. One is nightfall, two an attack, three a blood moon;
## the dev overlay fires each so they can be counted against each other.
func blow_horn(blasts: int) -> void:
	_blow(HORN_NIGHT, blasts)

## Daybreak. One crow -- the relief answer to the night's horn.
## Public so the dev overlay can fire it without waiting out a night.
##
## Named `crow_daybreak` rather than `_crow` because `_crow` is already the
## carrion-crow player: the two birds would collide.
func crow_daybreak() -> void:
	if not is_instance_valid(_rooster):
		return
	var fire := get_tree().get_first_node_in_group("campfire")
	var at: Vector3 = fire.global_position if fire else Vector3.ZERO
	_rooster.global_position = at + ROOSTER_AT
	_rooster.play()

## `times` blasts from the camp, spread across the voices so they overlap rather
## than cut each other off.
func _blow(stream: AudioStream, times: int) -> void:
	var fire := get_tree().get_first_node_in_group("campfire")
	var at: Vector3 = fire.global_position + Vector3(0, 2.0, 0) if fire else Vector3.ZERO
	for i in range(times):
		if i > 0:
			await get_tree().create_timer(ALARM_GAP).timeout
		if _horns.is_empty():
			return
		var p := _horns[_horn_voice]
		_horn_voice = (_horn_voice + 1) % _horns.size()
		if not is_instance_valid(p):
			return
		p.stream = stream
		p.volume_db = HORN_DB
		p.global_position = at
		p.play()
