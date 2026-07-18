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

const TOWN_HALL_COST := 15

const BUILDING_SCENE := preload("res://kingdom_demo/scenes/building.tscn")
const VILLAGER_SCENE := preload("res://kingdom_demo/scenes/villager.tscn")
const TENT_MODEL := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/tent.glb")
const WORKER_MODEL := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/tent-canvas.glb")
const ARCHER_MODEL := preload("res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/tower-base.glb")
const TOWN_HALL_MODEL := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/structure.glb")

@onready var _out: Node3D = $Extinguished
@onready var _lit: Node3D = $Lit
@onready var _liquid: Sprite3D = $Lit/Liquid
@onready var _prompt: Label3D = $Prompt

var lit := false
var fill := 0
var cauldron_full := false

var _busy := false
var _village_spawned := false

func _ready() -> void:
	add_to_group("campfire")
	add_to_group("interactable")
	_apply_state()

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
			_update_liquid()
			if fill >= CAULDRON_MAX:
				cauldron_full = true
				remove_from_group("interactable")
				_bubble()
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

func _update_liquid() -> void:
	var t := clampf(float(fill) / float(CAULDRON_MAX), 0.0, 1.0)
	_liquid.visible = fill > 0
	_liquid.scale = Vector3(1.0, 0.4 + 0.6 * t, 1.0)
	_liquid.modulate = Color(1, 1, 1, 1)

func _bubble() -> void:
	var t := create_tween().set_loops()
	t.tween_property(_liquid, "scale:y", _liquid.scale.y * 1.12, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(_liquid, "scale:y", _liquid.scale.y, 0.5).set_trans(Tween.TRANS_SINE)

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
	# the tent is where the village grows from -- 15 gold turns it into the hall,
	# which also raises the palisade into castle stone
	_spawn_building(TENT_MODEL, "Tent", Vector3(-3.6, 0, -2.6), 1.8, 1.3, "",
		TOWN_HALL_MODEL, "Town Hall", 1.4, 2.0, TOWN_HALL_COST, true)
	_spawn_building(WORKER_MODEL, "Workers", Vector3(3.6, 0, -2.6), 1.8, 1.4, "worker")
	_spawn_building(ARCHER_MODEL, "Archers", Vector3(0, 0, -4.6), 1.2, 2.4, "archer")

func _spawn_building(scene: PackedScene, bname: String, pos: Vector3, sc: float, height: float, job: String,
		up_scene: PackedScene = null, up_name := "", up_scale := 1.0, up_height := 0.0, up_cost := 0,
		raises_castle := false) -> void:
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
	b.upgrade_raises_castle = raises_castle
	get_tree().current_scene.add_child(b)
	b.global_position = pos

# ---------------------------------------------------------------- state

func _apply_state() -> void:
	_out.visible = not lit
	_lit.visible = lit
	_liquid.visible = lit and fill > 0
