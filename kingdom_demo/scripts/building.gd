extends StaticBody3D
## A village building. The Tent is decorative; the Workers and Archers huts are
## workplaces: the monarch pays gold to create jobs (shown as hammer / bow icons
## above the roof, up to MAX_JOBS), and loyal villagers walk over to fill them.

@export var sprite_texture: Texture2D
@export var display_name: String = ""
@export var sprite_pixel_size: float = 0.035
@export var job_type: String = ""      # "worker" | "archer" | "" (no jobs)

const MAX_JOBS := 4
const JOB_COST := 3
const HAMMER_TEX := preload("res://kingdom_demo/assets/pixel/hammer.png")
const BOW_TEX := preload("res://kingdom_demo/assets/pixel/bow.png")

@onready var sprite: Sprite3D = $Sprite
@onready var label: Label3D = $Label
@onready var _prompt: Label3D = $Prompt
@onready var _icons: Node3D = $Icons

var jobs := 0          # jobs created (paid for)
var filled := 0        # jobs taken by loyal villagers
var _height := 1.5
var _busy := false

func _ready() -> void:
	add_to_group("building")
	if sprite_texture:
		sprite.texture = sprite_texture
	sprite.pixel_size = sprite_pixel_size
	_height = (sprite.texture.get_height() if sprite.texture else 40) * sprite_pixel_size
	sprite.position.y = _height * 0.5
	label.position.y = _height + 0.25
	label.text = display_name
	_icons.position.y = _height + 0.55
	if job_type != "":
		add_to_group("interactable")
		add_to_group("workplace")

# ---- job slots (queried by villagers) ----

func open_jobs() -> int:
	return jobs - filled

func has_open_job() -> bool:
	return job_type != "" and open_jobs() > 0

func claim_job() -> bool:
	if not has_open_job():
		return false
	filled += 1
	_refresh_prompt()
	return true

func work_point() -> Vector3:
	# a spot just in front of the building for workers to stand
	return global_position + Vector3(0, 0, 1.4)

# ---- interaction (create jobs) ----

func _prompt_text() -> String:
	if job_type == "":
		return ""
	if jobs >= MAX_JOBS:
		return "%s  (full)" % display_name
	return "E  Add Job (%d)   %d/%d" % [JOB_COST, jobs, MAX_JOBS]

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
	if _busy or job_type == "" or jobs >= MAX_JOBS:
		return
	if not GoldFx.can_afford(JOB_COST):
		return
	_busy = true
	hide_prompt()
	var ok: bool = await GoldFx.pay(who, self, JOB_COST, _height + 0.9)
	_busy = false
	if ok:
		jobs += 1
		_add_job_icon()
	if is_in_group("interactable") and is_instance_valid(who) and global_position.distance_to(who.global_position) < 3.5:
		show_prompt()

func _add_job_icon() -> void:
	var s := Sprite3D.new()
	s.texture = BOW_TEX if job_type == "archer" else HAMMER_TEX
	s.pixel_size = 0.014
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.no_depth_test = true
	_icons.add_child(s)
	_layout_icons()
	var t := create_tween()
	s.scale = Vector3.ZERO
	t.tween_property(s, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _layout_icons() -> void:
	var n := _icons.get_child_count()
	var spacing := 0.32
	var start_x := -spacing * (n - 1) * 0.5
	for i in range(n):
		_icons.get_child(i).position = Vector3(start_x + i * spacing, 0, 0)
