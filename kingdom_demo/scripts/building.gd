extends StaticBody3D
## A village building. The Tent is decorative but can be rebuilt into the Town
## Hall; the Workers and Archers huts are workplaces: the monarch pays gold to
## create jobs and loyal villagers walk over to fill them. The hammer / bow icons
## over the roof count the positions still *open*, so they tick down as villagers
## take work.

@export var model_scene: PackedScene            # the 3D model this building shows
@export var display_name: String = ""
@export var model_scale: float = 1.0
@export var model_height: float = 1.5           # used to seat prompts / label / collision
@export var job_type: String = ""              # "worker" | "archer" | "" (no jobs)

@export var upgrade_model_scene: PackedScene    # set to make this building upgradeable
@export var upgrade_display_name: String = ""
@export var upgrade_scale: float = 1.0
@export var upgrade_height: float = 0.0
@export var upgrade_cost: int = 0
@export var upgrade_raises_castle: bool = false # Town Hall: turns the palisade to stone

const MAX_JOBS := 4
const JOB_COST := 3
# despite the filenames, these two are a log and an arrow
const LOG_TEX := preload("res://kingdom_demo/assets/pixel/hammer.png")
const ARROW_TEX := preload("res://kingdom_demo/assets/pixel/bow.png")
const DUST_TEX := preload("res://kingdom_demo/assets/pixel/wood_chip.png")

@onready var model_root: Node3D = $Model
@onready var label: Label3D = $Label
@onready var _prompt: Label3D = $Prompt
@onready var _icons: Node3D = $Icons
@onready var _collision: CollisionShape3D = $CollisionShape3D

var jobs := 0          # positions created (paid for)
var filled := 0        # positions taken by loyal villagers
var upgraded := false
var _model: Node3D = null
var _height := 1.5
var _busy := false

func _ready() -> void:
	add_to_group("building")
	_show_model(model_scene, model_scale)
	_fit(model_height)
	label.text = display_name
	if job_type != "":
		add_to_group("workplace")
	if job_type != "" or _can_upgrade():
		add_to_group("interactable")

# ---- layout ----

func _show_model(scene: PackedScene, sc: float) -> void:
	if is_instance_valid(_model):
		_model.queue_free()
	_model = null
	if scene == null:
		return
	_model = scene.instantiate()
	model_root.add_child(_model)
	_model.scale = Vector3(sc, sc, sc)

## Seats the label / prompt / job icons above the building and rebuilds a
## collision box that matches the requested height.
func _fit(height: float) -> void:
	_height = maxf(0.4, height)
	# stacked clear of each other: prompt over the roof, then name, then job icons
	_prompt.position.y = _height + 0.15
	label.position.y = _height + 0.55
	_icons.position.y = _height + 1.05
	# a fresh shape per building -- the one in the scene is shared between instances
	var box := BoxShape3D.new()
	var w := maxf(0.9, _height * 0.7)
	box.size = Vector3(w, _height, w)
	_collision.shape = box
	_collision.position.y = _height * 0.5

# ---- job positions (queried by villagers) ----

func open_jobs() -> int:
	return jobs - filled

func has_open_job() -> bool:
	return job_type != "" and open_jobs() > 0

func claim_job() -> bool:
	if not has_open_job():
		return false
	filled += 1
	_take_job_icon()
	_refresh_prompt()
	return true

func work_point() -> Vector3:
	# a spot just in front of the building for workers to stand
	return global_position + Vector3(0, 0, 1.4)

# ---- interaction ----

func _can_upgrade() -> bool:
	return upgrade_cost > 0 and upgrade_model_scene != null and not upgraded

func _prompt_text() -> String:
	if _can_upgrade():
		return "Hold E  %s (%d)" % [upgrade_display_name, upgrade_cost]
	if job_type == "":
		return ""
	if jobs >= MAX_JOBS:
		return "%s  (full)" % display_name
	return "Hold E  Add Job (%d)   %d/%d" % [JOB_COST, jobs, MAX_JOBS]

func show_prompt() -> void:
	if _busy or _prompt_text() == "":
		return
	_prompt.text = _prompt_text()
	_prompt.visible = true

func hide_prompt() -> void:
	_prompt.visible = false

func _refresh_prompt() -> void:
	if _prompt.visible:
		_prompt.text = _prompt_text()

func interact(who: Node3D) -> void:
	if _busy:
		return
	if _can_upgrade():
		await _buy(who, upgrade_cost, _raise_upgrade)
	elif job_type != "" and jobs < MAX_JOBS:
		await _buy(who, JOB_COST, _add_job)

func _buy(who: Node3D, cost: int, on_paid: Callable) -> void:
	if not GoldFx.can_afford(cost):
		return
	_busy = true
	hide_prompt()
	var ok: bool = await GoldFx.pay(who, self, cost, _height + 0.9)
	_busy = false
	if ok:
		on_paid.call()
	if is_in_group("interactable") and is_instance_valid(who) and global_position.distance_to(who.global_position) < 3.5:
		show_prompt()

# ---- jobs ----

func _add_job() -> void:
	jobs += 1
	_add_job_icon()

func _add_job_icon() -> void:
	var s := Sprite3D.new()
	s.texture = ARROW_TEX if job_type == "archer" else LOG_TEX
	s.pixel_size = 0.0075
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.no_depth_test = true
	_icons.add_child(s)
	_layout_icons()
	var t := create_tween()
	s.scale = Vector3.ZERO
	t.tween_property(s, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## A villager just took this post, so its icon lifts off the roof and the row
## closes up -- what's left is the count of vacancies.
func _take_job_icon() -> void:
	var n := _icons.get_child_count()
	if n == 0:
		return
	var icon: Node3D = _icons.get_child(n - 1)
	var world := icon.global_position
	_icons.remove_child(icon)
	get_tree().current_scene.add_child(icon)
	icon.global_position = world
	_layout_icons()
	var t := icon.create_tween()
	t.tween_property(icon, "global_position", world + Vector3(0, 0.45, 0), 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(icon, "scale", Vector3.ZERO, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_callback(icon.queue_free)

func _layout_icons() -> void:
	var n := _icons.get_child_count()
	var spacing := 0.52     # wide enough that the tools never pile into each other
	var start_x := -spacing * (n - 1) * 0.5
	for i in range(n):
		_icons.get_child(i).position = Vector3(start_x + i * spacing, 0, 0)

# ---- upgrade ----

func _raise_upgrade() -> void:
	upgraded = true
	display_name = upgrade_display_name
	_show_model(upgrade_model_scene, upgrade_scale)
	_fit(upgrade_height if upgrade_height > 0.0 else _height)
	label.text = display_name
	if job_type == "":
		remove_from_group("interactable")
	if upgrade_raises_castle:
		var gm := get_tree().get_first_node_in_group("game_manager")
		if gm and gm.has_method("raise_castle_age"):
			gm.raise_castle_age()
	_dust()
	# the new hall heaves up out of the ground, the grass hiding the join
	_model.position.y = -_height * 0.7
	_model.scale = Vector3(upgrade_scale * 1.1, upgrade_scale * 0.4, upgrade_scale * 1.1)
	var t := create_tween()
	t.tween_property(_model, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_model, "scale", Vector3(upgrade_scale, upgrade_scale, upgrade_scale), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _dust() -> void:
	for i in range(10):
		var p := Sprite3D.new()
		p.texture = DUST_TEX
		p.pixel_size = 0.016
		p.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		p.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		p.modulate = Color(0.76, 0.72, 0.62, 0.95)
		get_tree().current_scene.add_child(p)
		var a := randf() * TAU
		p.global_position = global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.3, 1.0) + Vector3(0, 0.1, 0)
		var to := p.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 1.0)
		to.y += randf_range(0.4, 0.9)
		var t := p.create_tween()
		t.tween_property(p, "global_position", to, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(p, "scale", Vector3(2.0, 2.0, 2.0), 0.6)
		t.parallel().tween_property(p, "modulate:a", 0.0, 0.6)
		t.tween_callback(p.queue_free)
