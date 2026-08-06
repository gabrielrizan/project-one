extends Node3D
## The raid director (COMBAT_PROMPTS P3, P7). One node in the main scene, built like
## wildlife.gd: it owns the night counter, the placeholder wave table, the blood
## moon, and the bandit camp at the corridor mouth.
##
## **The night begins off darkness() crossing the dusk threshold, never off the
## clock** -- durations are placeholder. The director watches the clock *itself* and
## begins the night idempotently ([method _ensure_night_started]); ambience.gd, when
## it blows the dusk horn, asks [method blasts_tonight], which begins the night too
## if the director hasn't yet. Whoever gets there first wins, so the raid fires
## whether or not the horn's own crossing lands on the same frame -- it no longer
## depends on ambience's timing at all.

const BANDIT_SCENE := preload("res://kingdom_demo/scenes/bandit.tscn")

# --- the wave table: PLACEHOLDER, exactly like the flat-5 hall costs (§11). ---
## Night 0 is the only grace night now, down from two (F5). The old three-night wait
## was teaching a lesson the walls now teach better: with the bearing rolled fresh
## each night there is something to *read* from night one, so silence buys less.
const FIRST_RAID := 1
## **One camp's worth** -- the unit a single front arrives in. Waves are counted in
## these rather than in bodies, so "two fronts" is literally twice one front, which
## is the thing the player is being asked to feel.
const CAMP_WAVE := 3
const GROWTH_EVERY := 2      # +1 bandit per front every couple of nights
const FRONT_CAP := 6         # ...up to this many per front
## Seconds between arrivals, so a wave trickles down the corridor rather than
## popping in all at once.
const STAGGER := Vector2(1.1, 2.6)

# --- the blood moon (P7). Every 15th night: horn x3, red sky, a wave 2.5x in
#     pulses, mixed with Brutes. Cadence is Andrei's fixed constant (§11). ---
const BLOOD_EVERY := 15
const BLOOD_MULT := 2.5
const BLOOD_CAP := 14
const BRUTE_EVERY := 4       # roughly one raider in four is a Brute
const PULSE_GAP := 8.0       # the breather between blood-moon pulses

## Matches ambience's HORN_AT_DUSK: darkness this high means dusk has begun.
const NIGHTFALL_DARK := 0.04
## darkness() falling past here = first light; survivors turn and run.
const ROUT_AT_DAWN := 0.9

var _night := 0
var _raid_tonight := false
var _blood := false
var _night_started := false  # true from dusk until the next full daylight
var _last_dark := 0.0
## Still to trickle in tonight, in order: `{archetype, front}` where `front` indexes
## [member _fronts].
var _queue: Array[Dictionary] = []
## Tonight's fronts, as indices into `MapTerrain.walls()`. Rolled fresh each night
## and **independent of where the camps are** -- see [method _roll_fronts].
var _fronts: Array[int] = []
var _spawn_t := 0.0
var _since_pulse := 0
var _pulse_size := 0         # 0 = steady stagger; >0 = spawn in blood-moon pulses

func _ready() -> void:
	add_to_group("night_raids")
	_spawn_camps()

func _process(delta: float) -> void:
	_watch_clock()
	_drive_blood(delta)
	_run_spawns(delta)

# ---------------------------------------------------------------- the night

## The director's own clock watch. Begins the night at dusk (idempotently) and
## routs the survivors at dawn. Re-arms in full daylight for the next dusk.
func _watch_clock() -> void:
	var cycle := get_tree().get_first_node_in_group("day_night_cycle")
	if cycle == null:
		return
	var dark: float = cycle.darkness()
	if dark >= NIGHTFALL_DARK:
		_ensure_night_started()
	else:
		_night_started = false          # full daylight -- ready for the next dusk
	if _last_dark > ROUT_AT_DAWN and dark <= ROUT_AT_DAWN:
		_rout()
		_flare(false)
		# the watch is stood down with the light. Braziers only ever mean "tonight,
		# at this wall", so one left burning into the morning would be a lie.
		_douse_all()
	_last_dark = dark

## Begins tonight exactly once: advances the counter, decides the raid, queues the
## wave and flares the camp. Safe to call from the clock watch or from ambience
## asking for the horn count -- whichever happens first, the other is a no-op.
func _ensure_night_started() -> void:
	if _night_started or not _village_exists():
		return
	_night_started = true
	_night += 1
	_decide_night()

func _decide_night() -> void:
	_blood = is_blood_moon(_night)
	var per := per_front(_night)
	_raid_tonight = _blood or per > 0
	_roll_fronts(fronts_tonight(_night) if _raid_tonight else 0)
	if _blood:
		_start_wave(_blood_wave_size(), true)
	elif per > 0:
		_start_wave(per * maxi(1, _fronts.size()), false)
	_light_fronts()
	print("[raids] night %d -- %s, %d front(s): %s"
		% [_night, _night_kind(), _fronts.size(), _front_names()])

# ---------------------------------------------------------------- the fronts

## Pick tonight's threatened walls, **at random and with no regard for where the
## camps are** (ISLAND_PROMPTS F5).
##
## That decoupling is the whole task. While waves marched out of the raiding camp,
## the bearing was fixed by map layout and the camp's smoke forecast it; on a map
## walled all the way round, a fixed bearing makes three of the four walls decoration.
## Rolling it fresh means every wall you bought can matter on any given night -- and
## it is what lets the lit braziers become the warning, which is better than the
## smoke was: precise, visible from the fire, and free of any need to explore.
##
## Deliberately drawn from the map's **wall offers**, not from the walls actually
## built. A front on a bearing you have not walled yet is a front that walks
## straight in, and that is the lesson, not an edge case to special-case away.
func _roll_fronts(count: int) -> void:
	_fronts.clear()
	var walls := MapTerrain.walls()
	if walls.is_empty() or count <= 0:
		return
	var pool: Array[int] = []
	for i in walls.size():
		pool.append(i)
	pool.shuffle()
	for i in mini(count, pool.size()):
		_fronts.append(pool[i])

## How many fronts night `n` comes at: none, then one, then the map's ceiling.
func fronts_tonight(n: int) -> int:
	if n < FIRST_RAID:
		return 0
	return mini(MapTerrain.max_fronts(), n)

## Light the braziers on tonight's fronts and only those. A wall that is not built
## has nothing to light, which is exactly right -- there is nothing there to man.
func _light_fronts() -> void:
	var walls := MapTerrain.walls()
	for w in get_tree().get_nodes_in_group("wall_side"):
		if not w.has_method("light_torches"):
			continue
		var threatened := false
		for i in _fronts:
			if i < walls.size() and w.global_position.distance_to(walls[i].pos) < 2.0:
				threatened = true
				break
		w.light_torches(threatened)

func _douse_all() -> void:
	for w in get_tree().get_nodes_in_group("wall_side"):
		if w.has_method("light_torches"):
			w.light_torches(false)

func _front_names() -> String:
	var walls := MapTerrain.walls()
	var out := PackedStringArray()
	for i in _fronts:
		if i < walls.size():
			var p: Vector3 = walls[i].pos
			out.append("%.0f,%.0f" % [p.x, p.z])
	return ", ".join(out) if out.size() > 0 else "-"

## Tonight's fronts, as world positions -- what the dev overlay reports.
func front_positions() -> Array[Vector3]:
	var walls := MapTerrain.walls()
	var out: Array[Vector3] = []
	for i in _fronts:
		if i < walls.size():
			out.append(walls[i].pos)
	return out

## How many blasts the dusk horn gets, and the trigger ambience uses: 1 quiet,
## 2 a raid, 3 a blood moon.
func blasts_tonight() -> int:
	_ensure_night_started()
	if _blood:
		return 3
	return 2 if _raid_tonight else 1

## How many bandits arrive **per front** on night `n`. Zero through the grace.
func per_front(n: int) -> int:
	if n < FIRST_RAID:
		return 0
	return mini(FRONT_CAP, CAMP_WAVE + (n - FIRST_RAID) / GROWTH_EVERY)

## The whole night's bodies, across every front. Kept as the public name because
## it is what the readouts and the dev tools ask for.
func wave_size(n: int) -> int:
	return per_front(n) * fronts_tonight(n)

func _blood_wave_size() -> int:
	return mini(BLOOD_CAP, int(ceil(maxi(wave_size(_night), CAMP_WAVE) * BLOOD_MULT)))

func is_blood_moon(n: int) -> bool:
	return n > 0 and n % BLOOD_EVERY == 0

func night() -> int:
	return _night

func is_raid_tonight() -> bool:
	return _raid_tonight

func is_blood_tonight() -> bool:
	return _blood

## Nights until the next blood moon; 0 means tonight is one.
func nights_until_blood() -> int:
	if _blood or is_blood_moon(_night):
		return 0
	return ((_night / BLOOD_EVERY) + 1) * BLOOD_EVERY - _night

func _night_kind() -> String:
	if _blood:
		return "BLOOD MOON"
	return "raid" if _raid_tonight else "quiet"

func _village_exists() -> bool:
	var fire := get_tree().get_first_node_in_group("campfire")
	return fire != null and fire.lit

# ---------------------------------------------------------------- the wave

## Queue `count` raiders. A blood moon salts in Brutes and spawns in pulses; an
## ordinary raid trickles them in steadily.
func _start_wave(count: int, blood: bool) -> void:
	if _fronts.is_empty():
		_roll_fronts(maxi(1, fronts_tonight(maxi(_night, FIRST_RAID))))
	for i in range(count):
		var brute := blood and (i % BRUTE_EVERY == BRUTE_EVERY - 1)
		# dealt round-robin, so two fronts arrive together rather than one wall
		# taking the whole wave while the other waits its turn
		_queue.append({archetype = "brute" if brute else "thug", front = i % maxi(1, _fronts.size())})
	_flare(true)
	_pulse_size = int(ceil(count / 3.0)) if blood else 0
	_since_pulse = 0
	_spawn_t = 0.0   # first raider of a fresh wave arrives promptly, not after a leftover gap

func _run_spawns(delta: float) -> void:
	if _queue.is_empty():
		return
	# The raiding camp is burned -- there is nowhere left for a wave to come from,
	# so drop what's queued (P10). Note this is the *raiding* camp, not every camp:
	# burning the front ends the nights even while the dormant camp still stands,
	# which is the reward for taking the fight to the right one.
	if _live_camp() == null:
		_queue.clear()
		return
	_spawn_t -= delta
	if _spawn_t > 0.0:
		return
	_spawn_one(_queue.pop_front())
	_since_pulse += 1
	# a longer breather at pulse boundaries (blood moons only); steady otherwise
	if _pulse_size > 0 and _since_pulse >= _pulse_size and not _queue.is_empty():
		_since_pulse = 0
		_spawn_t = PULSE_GAP
	else:
		_spawn_t = randf_range(STAGGER.x, STAGGER.y)

## Put one raider on the ground, on its own front.
##
## **Where a front lands is the map's business.** On a map with a shore they wade in
## off the sea on that bearing, which reads perfectly and needs no camp on that side
## to justify it -- that is what makes a random bearing honest. On a landlocked map
## `front_landing` says so by answering the village, and they march out of a camp
## exactly as they always have, so the three land prototypes are untouched.
func _spawn_one(order: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var walls := MapTerrain.walls()
	var at := Vector3.ZERO
	var idx := int(order.get("front", 0))
	if idx < _fronts.size() and _fronts[idx] < walls.size():
		at = MapTerrain.front_landing(walls[_fronts[idx]])
	if at == MapTerrain.village():
		# landlocked, or no wall offer to march on: the classic camp march
		var camp := _live_camp()
		if camp == null:
			return   # every camp on this front is burned (P10) -- nowhere to come from
		at = camp.spawn_point()
	else:
		# spread arrivals along the beach so a front is a landing, not a conga line
		var side := Vector3(-at.z, 0.0, at.x).normalized()
		at += side * randf_range(-5.0, 5.0)
	var b := BANDIT_SCENE.instantiate()
	b.archetype = String(order.get("archetype", "thug"))
	scene.add_child(b)
	b.global_position = at

## A random live (unburned) **raiding** camp to send a wave from -- read straight
## from the group, so a burned camp (which leaves it) never spawns again (P10).
## A dormant camp is filtered out here rather than never being built: it is a real
## camp with a real garrison, it just isn't a front.
func _live_camp() -> Node3D:
	var out: Array[Node3D] = []
	for c in get_tree().get_nodes_in_group("bandit_camp"):
		if is_instance_valid(c) and c.raiding:
			out.append(c)
	if out.is_empty():
		return null
	return out[randi() % out.size()]

# ---------------------------------------------------------------- dawn / rout

## First light: every bandit turns and runs for the nearest camp, then despawns
## there. Nearest rather than one fixed point, because a map's camps can sit on
## opposite bearings and a raider jogging the length of the map past a closer fire
## would read as pathfinding rather than a rout.
func _rout() -> void:
	for b in get_tree().get_nodes_in_group("bandit"):
		if b.has_method("rout"):
			b.rout(MapTerrain.nearest_camp(b.global_position, get_tree()))

# ---------------------------------------------------------------- the red sky

## Drives day_night_cycle's `blood` factor (P7), the mirror of how weather drives
## `storm`. Tracks the darkness on a blood-moon night, so the red deepens as night
## falls and clears at dawn; eased to zero otherwise.
func _drive_blood(delta: float) -> void:
	var cycle := get_tree().get_first_node_in_group("day_night_cycle")
	if cycle == null:
		return
	var want: float = cycle.darkness() if (_blood and _night_started) else 0.0
	cycle.blood = move_toward(cycle.blood, want, delta * 0.8)

# ---------------------------------------------------------------- dev overlay

## Dev: raid immediately, whatever the night -- at least a token wave, on freshly
## rolled fronts with their braziers lit, so the whole cue is exercised.
func raid_now() -> void:
	_roll_fronts(maxi(1, fronts_tonight(maxi(_night, FIRST_RAID))))
	_light_fronts()
	_start_wave(maxi(CAMP_WAVE, wave_size(maxi(_night, FIRST_RAID))), false)
	print("[raids] raid now -- %d front(s): %s" % [_fronts.size(), _front_names()])

## Dev: force tonight's fronts onto specific walls, by index into
## `MapTerrain.walls()`. The one tool that makes "does the cue read?" testable
## without rerolling until the dice cooperate.
func set_fronts(indices: Array) -> void:
	_fronts.clear()
	for i in indices:
		_fronts.append(int(i))
	_light_fronts()
	print("[raids] fronts forced to %s" % _front_names())

## Dev: bump the counter without waiting out a day.
func advance_night() -> void:
	_night += 1
	print("[raids] night -> %d (%s next dusk)" % [_night, _night_kind()])

## Dev: a blood moon right now. Skips to night so the red and the wave both show,
## sounds the three-blast horn, and sends a full blood wave.
func blood_moon_now() -> void:
	var cycle := get_tree().get_first_node_in_group("day_night_cycle")
	if cycle and not cycle.is_night():
		cycle.set_time_of_day(cycle.SUNSET_AT + cycle.DUSK)
	_night_started = true
	_blood = true
	_raid_tonight = true
	_roll_fronts(maxi(1, fronts_tonight(maxi(_night, FIRST_RAID))))
	_light_fronts()
	_start_wave(_blood_wave_size(), true)
	var amb := get_tree().current_scene.get_node_or_null("Ambience")
	if amb and amb.has_method("blow_horn"):
		amb.blow_horn(3)
	print("[raids] BLOOD MOON now")

# ---------------------------------------------------------------- the camps

## Stamp the selected map's camps. A [BanditCamp] is an object with a lifecycle
## (P10): it owns its own look, ember fire and garrison, joins the `bandit_camp`
## group, and can burn -- so the director only ever reads camps *from the group*.
##
## Every map carries **two camps, and only one of them raids**. The dormant one is
## a full camp in every other respect: it garrisons, it smokes, it has to be burned
## before the map is clear. It simply never sends a wave and never flares at dusk,
## so the map keeps a single defensive front (`ROADMAP.md` R4 wants map 1 short and
## single-front) while the *objective* is still two expeditions long.
func _spawn_camps() -> void:
	var raiders := 0
	for c in MapTerrain.camps():
		var camp := BanditCamp.new()
		camp.raiding = bool(c.get("raiding", false))
		camp.position = c.pos
		# **Face the village.** `bandit_camp.gd::_build` puts the tent behind the fire
		# with its mouth at local +Z, and `MapDef.camp_clearing_centre` now pushes the
		# clearing that way too -- so an unturned camp has its back to its own fighting
		# ground. It read as intended only by luck, on the one camp that happened to sit
		# due north of the village; the southern one faced out to sea.
		var home: Vector3 = MapTerrain.village() - (c.pos as Vector3)
		home.y = 0.0
		if home.length() > 0.01:
			camp.rotation.y = atan2(home.x, home.z)
		add_child(camp)
		if camp.raiding:
			raiders += 1
	print("[raids] %s: %d camps (%d raiding)"
		% [MapTerrain.map().id, MapTerrain.camps().size(), raiders])

## Stoke (or bank) every live camp's fire. Called with true when a wave starts, and
## false at dawn -- the camp does the easing itself (BanditCamp::flare).
func _flare(on: bool) -> void:
	for c in get_tree().get_nodes_in_group("bandit_camp"):
		if c.has_method("flare"):
			c.flare(on)
