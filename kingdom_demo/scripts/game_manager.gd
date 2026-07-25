extends Node3D

signal coins_changed(total: int)
## Every bandit camp on the map is burned -- the map objective is met (P10). The
## §10 exit (actually leaving for the next map) is a separate future task; for now
## this just posts a line.
signal map_cleared

const STARTING_COINS := 100

var coins: int = STARTING_COINS

func _ready() -> void:
	add_to_group("game_manager")
	coins_changed.emit(coins)

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)

func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true

# ---- the run ends (COMBAT_PROMPTS P6b) ----

const MENU_SCENE := "res://kingdom_demo/scenes/menu.tscn"
const END_GOLD := Color(0.85, 0.72, 0.38)
const END_BURGUNDY := Color(0.09, 0.03, 0.05, 0.97)

var _ended := false

## The hall has fallen -- the run is over. Freezes the night and raises an end
## screen (built the way menu.gd builds its pages), back to the title. The Crown as
## a lose condition stays reserved for the Stealer; bandits ignore the monarch (§11).
func end_run() -> void:
	if _ended:
		return
	_ended = true
	_show_end_screen()
	get_tree().paused = true

func _show_end_screen() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS   # stays live while the tree is paused
	add_child(layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(END_BURGUNDY.r, END_BURGUNDY.g, END_BURGUNDY.b, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	dim.create_tween().tween_property(dim, "color", END_BURGUNDY, 1.6)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	layer.add_child(box)

	var title := Label.new()
	title.text = "THE KINGDOM HAS FALLEN"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", END_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var sub := Label.new()
	sub.text = "The hall is lost, and with it the crown's seat."
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.82, 0.78, 0.7))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	box.add_child(spacer)

	var btn := Button.new()
	btn.text = "Return to the title"
	btn.add_theme_font_size_override("font_size", 26)
	btn.custom_minimum_size = Vector2(260, 52)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_to_title)
	box.add_child(btn)

func _to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

# ---- the map is won (COMBAT_PROMPTS P10) ----

const CLEARED_LINE := "The last camp burns. The valley falls quiet."

var _cleared := false

## A [BanditCamp] reports in once it has burned and left the `bandit_camp` group.
## When the last one is gone the map objective is met: fire [signal map_cleared] and
## post a modest line. Unlike the hall falling, this does **not** end anything or
## pause -- leaving the map (the §10 exit) is its own future task.
func report_camp_burned() -> void:
	if _cleared:
		return
	if not get_tree().get_nodes_in_group("bandit_camp").is_empty():
		return
	_cleared = true
	map_cleared.emit()
	_show_cleared_line()

func _show_cleared_line() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.offset_top = 88
	label.text = CLEARED_LINE
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", END_GOLD)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03))
	label.add_theme_constant_override("outline_size", 8)
	label.modulate = Color(END_GOLD.r, END_GOLD.g, END_GOLD.b, 0.0)
	layer.add_child(label)

	var t := label.create_tween()
	t.tween_property(label, "modulate:a", 1.0, 1.2)
	t.tween_interval(3.5)
	t.tween_property(label, "modulate:a", 0.0, 1.6)
	t.tween_callback(layer.queue_free)
