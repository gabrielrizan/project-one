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
const SK := "res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/"

# --- the wave table: PLACEHOLDER, exactly like the flat-5 hall costs (§11). ---
const FIRST_RAID := 3        # nights 1-2 are grace, to teach the horn and the walls
const BASE_WAVE := 2         # bandits on the first raid night
const GROWTH_EVERY := 2      # +1 bandit every couple of nights
const WAVE_CAP := 8
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

const EMBER := Color(1.0, 0.55, 0.22)
const EMBER_DIM := 0.9       # a camp always smoulders on the horizon
const EMBER_FLARE := 4.5     # ...and the fire is stoked at dusk when a raid is coming

var _night := 0
var _raid_tonight := false
var _blood := false
var _night_started := false  # true from dusk until the next full daylight
var _last_dark := 0.0
var _queue: Array[String] = []   # archetypes still to trickle in tonight, in order
var _spawn_t := 0.0
var _since_pulse := 0
var _pulse_size := 0         # 0 = steady stagger; >0 = spawn in blood-moon pulses
var _ember_light: OmniLight3D = null
var _ember_want := EMBER_DIM
var _flicker := 0.0

func _ready() -> void:
	add_to_group("night_raids")
	_build_camp()

func _process(delta: float) -> void:
	_watch_clock()
	_drive_blood(delta)
	_run_spawns(delta)
	_flicker_ember(delta)

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
	var wave := wave_size(_night)
	_raid_tonight = _blood or wave > 0
	if _blood:
		_start_wave(_blood_wave_size(), true)
	elif wave > 0:
		_start_wave(wave, false)
	print("[raids] night %d -- %s" % [_night, _night_kind()])

## How many blasts the dusk horn gets, and the trigger ambience uses: 1 quiet,
## 2 a raid, 3 a blood moon.
func blasts_tonight() -> int:
	_ensure_night_started()
	if _blood:
		return 3
	return 2 if _raid_tonight else 1

## How many bandits night `n` sends on an ordinary raid. Zero through the grace.
func wave_size(n: int) -> int:
	if n < FIRST_RAID:
		return 0
	return mini(WAVE_CAP, BASE_WAVE + (n - FIRST_RAID) / GROWTH_EVERY)

func _blood_wave_size() -> int:
	return mini(BLOOD_CAP, int(ceil(maxi(wave_size(_night), BASE_WAVE) * BLOOD_MULT)))

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
	for i in range(count):
		var brute := blood and (i % BRUTE_EVERY == BRUTE_EVERY - 1)
		_queue.append("brute" if brute else "thug")
	_flare(true)
	_pulse_size = int(ceil(count / 3.0)) if blood else 0
	_since_pulse = 0
	_spawn_t = 0.0   # first raider of a fresh wave arrives promptly, not after a leftover gap

func _run_spawns(delta: float) -> void:
	if _queue.is_empty():
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

func _spawn_one(archetype: String = "thug") -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var b := BANDIT_SCENE.instantiate()
	b.archetype = archetype
	scene.add_child(b)
	b.global_position = MapTerrain.corridor_mouth() \
		+ Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-2.0, 2.0))

# ---------------------------------------------------------------- dawn / rout

## First light: every bandit turns and runs for the camp, then despawns there.
func _rout() -> void:
	var camp := MapTerrain.corridor_mouth()
	for b in get_tree().get_nodes_in_group("bandit"):
		if b.has_method("rout"):
			b.rout(camp)

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

## Dev: raid immediately, whatever the night -- at least a token wave.
func raid_now() -> void:
	_start_wave(maxi(2, wave_size(_night)), false)
	print("[raids] raid now")

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
	_start_wave(_blood_wave_size(), true)
	var amb := get_tree().current_scene.get_node_or_null("Ambience")
	if amb and amb.has_method("blow_horn"):
		amb.blow_horn(3)
	print("[raids] BLOOD MOON now")

# ---------------------------------------------------------------- the camp

func _build_camp() -> void:
	var camp := Node3D.new()
	add_child(camp)
	camp.position = MapTerrain.corridor_mouth()
	_place(camp, "tent.glb", Vector3(0, 0, -2.8), 2.0, 0.0)          # behind the fire, mouth to the village
	_place(camp, "campfire-pit.glb", Vector3.ZERO, 1.6, 0.0)
	_place(camp, "bedroll.glb", Vector3(-2.4, 0, -1.4), 1.6, 0.6)
	_place(camp, "bedroll.glb", Vector3(2.3, 0, -1.7), 1.6, -0.5)
	_place(camp, "barrel.glb", Vector3(2.0, 0, 0.9), 1.3, 0.0)
	_ember_light = OmniLight3D.new()
	camp.add_child(_ember_light)
	_ember_light.position = Vector3(0, 0.8, 0)
	_ember_light.light_color = EMBER
	_ember_light.light_energy = EMBER_DIM
	_ember_light.omni_range = 16.0
	_ember_light.shadow_enabled = false

func _place(parent: Node3D, file: String, pos: Vector3, sc: float, yaw: float) -> void:
	var n: Node3D = (load(SK + file) as PackedScene).instantiate()
	parent.add_child(n)
	n.position = pos
	n.scale = Vector3.ONE * sc
	n.rotation.y = yaw

func _flare(on: bool) -> void:
	_ember_want = EMBER_FLARE if on else EMBER_DIM

## A little life in the fire, and it eases toward whatever _flare last asked for.
func _flicker_ember(delta: float) -> void:
	if not is_instance_valid(_ember_light):
		return
	_flicker += delta * 9.0
	var jitter := 0.85 + 0.15 * sin(_flicker) * sin(_flicker * 1.73)
	_ember_light.light_energy = move_toward(
		_ember_light.light_energy, _ember_want * jitter, delta * 6.0)
