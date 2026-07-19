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

# PLACEHOLDER COSTS -- flat 5 so play-testing isn't gated behind grinding gold. These
# want a real progression curve later; don't read "all tiers cost the same" as intent.
const WOODEN_HALL_COST := 5   # L2
const STONE_HALL_COST := 5    # L3
const STONE_HALL_SCALE := 2.2
const STONE_HALL_HEIGHT := 3.4

const BUILDING_SCENE := preload("res://kingdom_demo/scenes/building.tscn")
const VILLAGER_SCENE := preload("res://kingdom_demo/scenes/villager.tscn")
const TENT_MODEL := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/tent.glb")
const WORKER_MODEL := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/tent-canvas.glb")
const ARCHER_MODEL := preload("res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/tower-base.glb")
const WOODEN_HALL_MODEL := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/structure.glb")
const STONE_HALL_MODEL := preload("res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/tower-square.glb")

const SOUP_BASE_Y := 0.07     # inner floor of the pot, in cauldron-local space
const SOUP_FULL_H := 0.44     # matches the CylinderMesh height in the scene

@onready var _out: Node3D = $Extinguished
@onready var _lit: Node3D = $Lit
@onready var _flame: Node3D = $Lit/Flame
@onready var _soup: MeshInstance3D = $Lit/Cauldron/Soup
@onready var _prompt: Label3D = $Prompt

var lit := false
var fill := 0
var cauldron_full := false

var _busy := false
var _village_spawned := false
var _flicker := 0.0

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

# ---------------------------------------------------------------- interaction

func _prompt_text() -> String:
	if not lit:
		return "Hold E  Light Fire (%d)" % LIGHT_COST
	if not cauldron_full:
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
func _pour() -> void:
	var t := _level()
	_soup.visible = true
	var tw := create_tween()
	tw.tween_method(_set_soup_level, _soup.scale.y, t * 1.12, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_soup_level, t * 1.12, t, 0.18).set_trans(Tween.TRANS_SINE)

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

func _attract_villagers() -> void:
	var scene := get_tree().current_scene
	for i in range(VILLAGER_COUNT):
		var v := VILLAGER_SCENE.instantiate()
		var a := randf() * TAU
		var spawn := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(15.0, 19.0)
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
	_spawn_building(TENT_MODEL, "Tent", Vector3(-3.6, 0, -2.6), 1.8, 1.3, "",
		WOODEN_HALL_MODEL, "Wooden Hall", 1.4, 2.0, WOODEN_HALL_COST,
		STONE_HALL_MODEL, "Stone Hall", STONE_HALL_SCALE, STONE_HALL_HEIGHT, STONE_HALL_COST, true)
	_spawn_building(WORKER_MODEL, "Workers", Vector3(3.6, 0, -2.6), 1.8, 1.4, "worker")
	_spawn_building(ARCHER_MODEL, "Archers", Vector3(0, 0, -4.6), 1.2, 2.4, "archer")

func _spawn_building(scene: PackedScene, bname: String, pos: Vector3, sc: float, height: float, job: String,
		up_scene: PackedScene = null, up_name := "", up_scale := 1.0, up_height := 0.0, up_cost := 0,
		up2_scene: PackedScene = null, up2_name := "", up2_scale := 1.0, up2_height := 0.0, up2_cost := 0,
		up2_unlocks_stone := false) -> void:
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
	get_tree().current_scene.add_child(b)
	b.global_position = pos

# ---------------------------------------------------------------- state

func _apply_state() -> void:
	_out.visible = not lit
	_lit.visible = lit
	_soup.visible = lit and fill > 0
	set_process(lit)   # only a burning fire needs a flicker
