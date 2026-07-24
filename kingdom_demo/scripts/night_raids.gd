extends Node3D
## The raid director (COMBAT_PROMPTS P3). One node in the main scene, built like
## wildlife.gd: it owns the night counter, the placeholder wave table, and the
## bandit camp at the corridor mouth.
##
## The counter ticks off darkness() crossing the dusk threshold, **never off the
## clock** -- day/night durations are placeholder, which is why the horn already
## works this way. The director doesn't watch dusk itself: ambience.gd already
## does, for the horn, so it calls [method begin_night] there (one watcher, no
## same-frame race) and blows the count it returns. The director watches *dawn*
## itself, to rout the survivors.

const BANDIT_SCENE := preload("res://kingdom_demo/scenes/bandit.tscn")
const SK := "res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/"

# --- the wave table: PLACEHOLDER, exactly like the flat-5 hall costs (§11). This
#     is a tuning pass waiting to happen, not a design statement. ---
const FIRST_RAID := 3        # nights 1-2 are grace, to teach the horn and the walls
const BASE_WAVE := 2         # bandits on the first raid night
const GROWTH_EVERY := 2      # +1 bandit every couple of nights
const WAVE_CAP := 8
## Seconds between arrivals, so a wave trickles down the corridor rather than
## popping in all at once.
const STAGGER := Vector2(1.1, 2.6)

## darkness() falling past here = first light; survivors turn and run.
const ROUT_AT_DAWN := 0.9

const EMBER := Color(1.0, 0.55, 0.22)
const EMBER_DIM := 0.9       # a camp always smoulders on the horizon
const EMBER_FLARE := 4.5     # ...and the fire is stoked at dusk when a raid is coming

var _night := 0
var _raid_tonight := false
var _last_dark := 1.0
var _queue := 0              # bandits still to trickle in tonight
var _spawn_t := 0.0
var _ember_light: OmniLight3D = null
var _ember_want := EMBER_DIM
var _flicker := 0.0

func _ready() -> void:
	add_to_group("night_raids")
	_build_camp()

func _process(delta: float) -> void:
	_watch_dawn()
	_run_spawns(delta)
	_flicker_ember(delta)

# ---------------------------------------------------------------- the night

## Called by ambience at the dusk crossing. Advances the night, decides the raid,
## flares the camp and queues the wave, and hands back the horn count: **1 quiet,
## 2 a raid**. (P7 adds 3 for the blood moon.)
func begin_night() -> int:
	_night += 1
	var wave := wave_size(_night)
	_raid_tonight = wave > 0
	if _raid_tonight:
		_start_wave(wave)
	return 2 if _raid_tonight else 1

## How many bandits night `n` sends. Zero through the grace period.
func wave_size(n: int) -> int:
	if n < FIRST_RAID:
		return 0
	return mini(WAVE_CAP, BASE_WAVE + (n - FIRST_RAID) / GROWTH_EVERY)

func night() -> int:
	return _night

func is_raid_tonight() -> bool:
	return _raid_tonight

func _start_wave(count: int) -> void:
	_queue += count
	_flare(true)

func _run_spawns(delta: float) -> void:
	if _queue <= 0:
		return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_t = randf_range(STAGGER.x, STAGGER.y)
		_spawn_one()
		_queue -= 1

func _spawn_one() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var b := BANDIT_SCENE.instantiate()
	scene.add_child(b)
	b.global_position = MapTerrain.corridor_mouth() \
		+ Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-2.0, 2.0))

# ---------------------------------------------------------------- dawn / rout

func _watch_dawn() -> void:
	var cycle := get_tree().get_first_node_in_group("day_night_cycle")
	if cycle == null:
		return
	var dark: float = cycle.darkness()
	if _last_dark > ROUT_AT_DAWN and dark <= ROUT_AT_DAWN:
		_rout()
		_flare(false)
	_last_dark = dark

## First light: every bandit turns and runs for the camp, then despawns there.
func _rout() -> void:
	var camp := MapTerrain.corridor_mouth()
	for b in get_tree().get_nodes_in_group("bandit"):
		if b.has_method("rout"):
			b.rout(camp)

# ---------------------------------------------------------------- dev overlay

## Dev: raid immediately, whatever the night -- at least a token wave so the
## button always does something.
func raid_now() -> void:
	_start_wave(maxi(2, wave_size(_night)))
	print("[raids] raid now -- %d marching" % _queue)

## Dev: bump the counter without waiting out a day.
func advance_night() -> void:
	_night += 1
	print("[raids] night -> %d (%s)" % [_night, "raid" if wave_size(_night) > 0 else "quiet"])

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
