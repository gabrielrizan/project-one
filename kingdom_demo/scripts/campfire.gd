extends StaticBody3D
## Heart of the village. Flow:
##   extinguished --(spend 3 gold)--> lit  (also raises tent + worker + archer huts)
##   lit --(feed gold to the cauldron)--> fills; full cauldron bubbles and draws
##   hungry villagers in from the wild.
## All gold spends raise the shared GoldFx tally.

const LIGHT_COST := 3
const CAULDRON_MAX := 3
const FEED_COST := 1
const VILLAGER_COUNT := 5
## How far out wanderers walk in from, as a ring around the fire. One number to
## retune per map: on a terrain-gated map some bearings will be inside rock, and a
## wanderer spawned there is stranded for good (`COMBAT_PROMPTS.md` P1). Biasing
## the *angle* onto open ground is the map's job; this is just the distance.
const WANDER_IN := Vector2(15.0, 19.0)   # min .. max metres

## How many souls the main building can house, by tier: L1 Tent, L2 Wooden Hall,
## L3 Stone Hall. Room to grow is what an upgrade buys -- the hall is the reason
## more people can live here, so the cap reads off its tier rather than sitting
## in the game manager.
##
## Note this counts everyone drawn in, wanderers included, not just citizens who
## have eaten and taken a job.
const TIER_CAPS: Array[int] = [6, 9, 12, 16]

# PLACEHOLDER COSTS -- flat 5 so play-testing isn't gated behind grinding gold. These
# want a real progression curve later; don't read "all tiers cost the same" as intent.
const WOODEN_HALL_COST := 5   # L2
const STONE_HALL_COST := 5    # L3
const CASTLE_COST := 5        # L4

## The main-building ladder, as **cells-x, cells-z, storeys, target height in
## metres**. Composed at runtime from kit modules ([HallBuilder]) rather than
## loaded, because the Fantasy Town Kit has no house model in it -- see
## `ASSETS.md`.
##
## A module is 1 m and a storey is therefore a whole metre, so integer storeys
## land on 1.63 / 2.63 / 3.63 m and **cannot hit 2.0 / 2.5 / 3.0 directly**. Each
## tier is built at the proportions that look right and then scaled to its target
## height (`_hall_scale`), which is why they are all 2 storeys: the tiers stay
## structurally identical and read as one building growing.
##
## **The footprint carries the progression, not the height.** Only 0.5 m separates
## the tiers, which is not a silhouette you would notice; the width goes
## 2.3 -> 2.9 -> 4.6 m, which is. Sizes are held where the current spawn positions
## still clear each other -- growing them further needs the village laid out
## again, which is D2 in `DEPTH_PROMPTS.md` and not done yet.
const HALL_L2 := [3, 2, 2, 2.0]    # Wooden Hall -- timber
const HALL_L3 := [3, 3, 2, 2.5]    # Stone Hall
const HALL_L4 := [4, 3, 2, 3.0]    # Castle
const WORKER_HUT := [2, 2, 1, 1.4]  # a shed, deliberately shorter than any hall

## L1. The raw tent model is 0.88 m -- shorter than the villager who sleeps in it.
const TENT_SCALE := 3.075
const TENT_HEIGHT := 1.5
## Kept just under the L3 hall: a watchtower may out-top a tent, but it should not
## out-top the stone hall it stands next to.
const ARCHER_SCALE := 1.525
const ARCHER_HEIGHT := 2.0

const BUILDING_SCENE := preload("res://kingdom_demo/scenes/building.tscn")
const VILLAGER_SCENE := preload("res://kingdom_demo/scenes/villager.tscn")
## L1 is the **canvas** tent. `tent.glb` is a bare timber A-frame with no cover on
## it, which read as an unfinished building rather than somewhere anyone lives.
const TENT_MODEL := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/tent-canvas.glb")
const ARCHER_MODEL := preload("res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/tower-base.glb")

const SOUP_BASE_Y := 0.07     # inner floor of the pot, in cauldron-local space
const SOUP_FULL_H := 0.44     # matches the CylinderMesh height in the scene

@onready var _out: Node3D = $Extinguished
@onready var _lit: Node3D = $Lit
@onready var _flame: Node3D = $Lit/Flame
@onready var _soup: MeshInstance3D = $Lit/Cauldron/Soup
@onready var _prompt: Label3D = $Prompt
@onready var _crackle: AudioStreamPlayer3D = $Crackle

## The fire is the centre of the camp after dark and just a cooking fire by day,
## so it pulls back when the sun is up rather than roaring through the birdsong.
## These are node gain on top of the Ambience bus. That bus just came up 5 dB to
## rescue the beds and one-shots, so the night figure drops by the same 5 to
## leave the fire sounding exactly as it did -- only the daytime level changes.
const CRACKLE_NIGHT_DB := -9.0
const CRACKLE_DAY_DB := -18.0
const CRACKLE_FADE := 3.0    # dB per second, eased across dusk with everything else

## Broth going into the pot. **Deliberately unobtrusive**: it is confirmation
## that the gold landed, not an event. Rolled off at 2.2 kHz before it got here
## so the splash doesn't sizzle -- a bright pour draws the ear, and this fires
## three times per cauldron, several cauldrons a night.
const FEED_CLIP := preload("res://kingdom_demo/assets/audio/cauldron_feed.ogg")
const FEED_DB := -15.0
const FEED_PITCH := Vector2(0.94, 1.06)

## REMOVED -- the catch/whoosh on lighting the fire. Andrei's call: the crackle
## loop starting is enough of an event on its own, and the whoosh on top read as
## a sound effect rather than a fire. `fire_light.ogg` and its licence entry are
## kept so this can be reinstated without re-sourcing anything.

var lit := false
var fill := 0
var cauldron_full := false

var _busy := false
var _village_spawned := false
var _flicker := 0.0
var _hall: Node3D = null      # the main building, whose tier sets the population cap

func _ready() -> void:
	add_to_group("campfire")
	add_to_group("interactable")
	_set_soup_level(0.0)
	_apply_state()
	set_process(false)

func _process(delta: float) -> void:
	# the fire never sits still
	_flicker += delta * 9.0
	var s := 1.0 + sin(_flicker) * 0.06 + sin(_flicker * 2.7) * 0.03
	_flame.scale = Vector3(1.0, s, 1.0) * 0.5
	_flame.rotation.y += delta * 0.6
	var want := CRACKLE_NIGHT_DB if _is_night() else CRACKLE_DAY_DB
	_crackle.volume_db = move_toward(_crackle.volume_db, want, CRACKLE_FADE * delta)

func _is_night() -> bool:
	var cycle := get_tree().get_first_node_in_group("day_night_cycle")
	return cycle != null and cycle.is_night()

# ---------------------------------------------------------------- interaction

func _prompt_text() -> String:
	if not lit:
		return "Hold E  Light Fire (%d)" % LIGHT_COST
	if not cauldron_full:
		# say when the hall is out of beds, so a full pot that draws nobody isn't
		# a mystery -- the soup still feeds whoever is already here
		if village_full():
			return "Hold E  Fill Cauldron (%d)   village full %d" % [FEED_COST, villager_cap()]
		return "Hold E  Fill Cauldron (%d)   %d/%d" % [FEED_COST, fill, CAULDRON_MAX]
	return ""

func show_prompt() -> void:
	if _busy or _prompt_text() == "":
		return
	_prompt.text = _prompt_text()
	_prompt.visible = true

func hide_prompt() -> void:
	_prompt.visible = false

func interact(who: Node3D) -> void:
	if _busy:
		return
	if not lit:
		if not GoldFx.can_afford(LIGHT_COST):
			return
		_busy = true
		hide_prompt()
		var ok: bool = await GoldFx.pay(who, self, LIGHT_COST, 1.9)
		_busy = false
		if ok:
			light()
		_reshow_prompt(who)
	elif not cauldron_full:
		if not GoldFx.can_afford(FEED_COST):
			return
		_busy = true
		hide_prompt()
		var ok: bool = await GoldFx.pay(who, self, FEED_COST, 1.9)
		_busy = false
		if ok:
			fill += 1
			_pour()
			if fill >= CAULDRON_MAX:
				cauldron_full = true
				remove_from_group("interactable")
				_attract_villagers()
		_reshow_prompt(who)

func _reshow_prompt(who: Node3D) -> void:
	if is_in_group("interactable") and is_instance_valid(who) and global_position.distance_to(who.global_position) < 3.0:
		show_prompt()

# ---------------------------------------------------------------- lighting

func light() -> void:
	if lit:
		return
	lit = true
	_apply_state()
	_spawn_village()

# ---------------------------------------------------------------- cauldron

## Level, 0..1, as a height-scaled cylinder whose base stays on the pot's floor.
func _set_soup_level(t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	_soup.visible = t > 0.001
	_soup.scale.y = maxf(t, 0.001)
	_soup.position.y = SOUP_BASE_Y + SOUP_FULL_H * t * 0.5

func _level() -> float:
	return clampf(float(fill) / float(CAULDRON_MAX), 0.0, 1.0)

## A ladle goes in: the level swells past its mark and settles.
##
## **The two halves are timed to the pour clip, not picked by feel.** They used
## to run 0.22 + 0.18 = 0.40s against a 1.9s sound that did not peak until 1.34s,
## so the cauldron finished filling a full second before the pour was at its
## loudest -- which reads as the sound arriving after the animation. The clip is
## now 0.62s and these add up to it, so they start, peak and end together.
## If the clip is ever replaced, re-match these to its length.
const POUR_SWELL := 0.34
const POUR_SETTLE := 0.28

func _pour() -> void:
	_pour_sound()
	var t := _level()
	_soup.visible = true
	var tw := create_tween()
	tw.tween_method(_set_soup_level, _soup.scale.y, t * 1.12, POUR_SWELL).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_soup_level, t * 1.12, t, POUR_SETTLE).set_trans(Tween.TRANS_SINE)

## One villager takes their supper. Emptying the pot re-opens it for refilling,
## which is what lets the camp grow past its first five wanderers.
func take_serving() -> bool:
	if not lit or fill <= 0:
		return false
	fill -= 1
	var t := _level()
	var tw := create_tween()
	tw.tween_method(_set_soup_level, _soup.scale.y, maxf(t - 0.06, 0.0), 0.16).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_set_soup_level, maxf(t - 0.06, 0.0), t, 0.20).set_trans(Tween.TRANS_SINE)
	# anything short of a full pot takes another ladle -- you don't have to let it
	# run dry before topping it up
	if fill < CAULDRON_MAX:
		cauldron_full = false
		if not is_in_group("interactable"):
			add_to_group("interactable")
	return true

# ---------------------------------------------------------------- population

## What the main building can house right now. Falls back to the Tent's figure
## before the village exists at all.
func villager_cap() -> int:
	if not is_instance_valid(_hall):
		return TIER_CAPS[0]
	# Read top-down: each flag implies the ones below it, so the first hit wins.
	if _hall.upgraded3:
		return TIER_CAPS[3]
	if _hall.upgraded2:
		return TIER_CAPS[2]
	return TIER_CAPS[1] if _hall.upgraded else TIER_CAPS[0]

## The main building's tier, 1..4, or 0 before the village exists. `wall_side.gd`
## gates each of its four levels on this, so a wall can never outrun the hall.
func hall_tier() -> int:
	if not is_instance_valid(_hall):
		return 0
	if _hall.upgraded3:
		return 4
	if _hall.upgraded2:
		return 3
	return 2 if _hall.upgraded else 1

func population() -> int:
	return get_tree().get_nodes_in_group("villager").size()

func village_full() -> bool:
	return population() >= villager_cap()

## A full pot draws people out of the wild -- but only as many as there is room
## for. Note this caps *drawing new wanderers*, not filling the pot: wanderers
## already on their way in still have to eat before they will take a job, and a
## batch of five outnumbers the three servings the cauldron holds. Refusing the
## sale at cap would leave those last arrivals hungry for good.
func _attract_villagers() -> void:
	var room: int = villager_cap() - population()
	if room <= 0:
		return
	var scene := get_tree().current_scene
	for i in range(mini(VILLAGER_COUNT, room)):
		var v := VILLAGER_SCENE.instantiate()
		var a := randf() * TAU
		var spawn := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(WANDER_IN.x, WANDER_IN.y)
		spawn.y = 0.0
		v.target = global_position
		scene.add_child(v)
		v.global_position = spawn

# ---------------------------------------------------------------- village

func _spawn_village() -> void:
	if _village_spawned:
		return
	_village_spawned = true
	# The main building's ladder: L0 unlit campfire -> L1 Tent -> L2 Wooden Hall
	# -> L3 Stone Hall -> L4 Castle (not built yet). Lighting the fire raises the
	# Tent for free; every tier after that is paid for AND raised by a crew, and
	# reaching the Stone Hall is what opens the walls' own stone upgrade.
	# Positions are **offsets from the campfire** (see `_spawn_building`), not world
	# coordinates -- so the whole village follows wherever the fire is placed on a
	# new map, instead of always spawning around the world origin. The fire sits at
	# origin today, so these read the same as the old absolute numbers.
	_hall = _spawn_building(TENT_MODEL, "Tent", Vector3(-3.6, 0, -2.6), TENT_SCALE, TENT_HEIGHT, "",
		_hall_tier(HALL_L2, false), "Wooden Hall", _hall_scale(HALL_L2), HALL_L2[3], WOODEN_HALL_COST,
		_hall_tier(HALL_L3, true), "Stone Hall", _hall_scale(HALL_L3), HALL_L3[3], STONE_HALL_COST, true,
		_hall_tier(HALL_L4, true), "Castle", _hall_scale(HALL_L4), HALL_L4[3], CASTLE_COST)
	_spawn_building(_hall_tier(WORKER_HUT, false), "Workers", Vector3(3.6, 0, -2.6),
		_hall_scale(WORKER_HUT), WORKER_HUT[3], "worker")
	_spawn_building(ARCHER_MODEL, "Archers", Vector3(0, 0, -4.6), ARCHER_SCALE, ARCHER_HEIGHT, "archer")

## Builds one tier from a `[cells_x, cells_z, storeys, height]` spec and packs it,
## since `building.gd` takes a PackedScene per tier.
func _hall_tier(spec: Array, stone: bool) -> PackedScene:
	return HallBuilder.packed(HallBuilder.build(spec[0], spec[1], spec[2], stone))

## What the composed metres have to be multiplied by to reach the tier's target
## height. Derived rather than written down, so changing a target height moves the
## footprint with it and the two can't fall out of step.
func _hall_scale(spec: Array) -> float:
	return float(spec[3]) / HallBuilder.height(spec[2])

func _spawn_building(scene: PackedScene, bname: String, pos: Vector3, sc: float, height: float, job: String,
		up_scene: PackedScene = null, up_name := "", up_scale := 1.0, up_height := 0.0, up_cost := 0,
		up2_scene: PackedScene = null, up2_name := "", up2_scale := 1.0, up2_height := 0.0, up2_cost := 0,
		up2_unlocks_stone := false,
		up3_scene: PackedScene = null, up3_name := "", up3_scale := 1.0, up3_height := 0.0, up3_cost := 0) -> Node3D:
	var b := BUILDING_SCENE.instantiate()
	b.model_scene = scene
	b.display_name = bname
	b.model_scale = sc
	b.model_height = height
	b.job_type = job
	b.upgrade_model_scene = up_scene
	b.upgrade_display_name = up_name
	b.upgrade_scale = up_scale
	b.upgrade_height = up_height
	b.upgrade_cost = up_cost
	b.upgrade2_model_scene = up2_scene
	b.upgrade2_display_name = up2_name
	b.upgrade2_scale = up2_scale
	b.upgrade2_height = up2_height
	b.upgrade2_cost = up2_cost
	b.upgrade2_unlocks_stone = up2_unlocks_stone
	b.upgrade3_model_scene = up3_scene
	b.upgrade3_display_name = up3_name
	b.upgrade3_scale = up3_scale
	b.upgrade3_height = up3_height
	b.upgrade3_cost = up3_cost
	get_tree().current_scene.add_child(b)
	# `pos` is an offset from the fire, so the village travels with it. Translation
	# only, not rotation -- a rotated campfire isn't a real case and turning the
	# offsets by its basis would be speculative complexity.
	b.global_position = global_position + pos
	return b

# ---------------------------------------------------------------- state

func _apply_state() -> void:
	_out.visible = not lit
	_lit.visible = lit
	_soup.visible = lit and fill > 0
	set_process(lit)   # only a burning fire needs a flicker
	# The crackle is positional, so it grows as the monarch rides in and the fire
	# becomes something you can hear from across the camp -- the village has an
	# audible centre, not just a visual one.
	if lit and not _crackle.playing:
		_crackle.play()
	elif not lit and _crackle.playing:
		_crackle.stop()

## Broth going in. Its own throwaway emitter rather than the crackle player, so
## it lays over the fire instead of interrupting it.
func _pour_sound() -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = FEED_CLIP
	p.bus = &"SFX"
	p.volume_db = FEED_DB
	p.pitch_scale = randf_range(FEED_PITCH.x, FEED_PITCH.y)
	p.unit_size = 4.0
	p.max_distance = 18.0
	get_tree().current_scene.add_child(p)
	p.global_position = global_position + Vector3(0, 1.0, 0)
	p.finished.connect(p.queue_free)
	p.play()
