extends Control
## One menu doing two jobs: the title screen, and the in-game pause menu.
## `pause_mode` swaps the wording and makes it pause/unpause the tree; the
## How to Play and Options pages are shared so there's only one of each to keep
## up to date.
##
## The layout is built in code rather than in the scene: it's a handful of
## buttons, and this keeps the whole menu readable in one file.

@export var pause_mode := false

const GAME_SCENE := "res://kingdom_demo/kingdom_demo.tscn"
const MENU_SCENE := "res://kingdom_demo/scenes/menu.tscn"

const CROWN_TEX := preload("res://kingdom_demo/assets/pixel/crown_title.png")
const GOLD := Color(0.85, 0.72, 0.38)
const PARCHMENT := Color(0.92, 0.89, 0.80)
const BTN_MIN := Vector2(300, 46)

var _pages: Dictionary = {}      # name -> Control
var _open := "main"

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# a pause menu has to keep running while the tree is frozen
	process_mode = Node.PROCESS_MODE_ALWAYS

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.07, 0.06, 0.72 if pause_mode else 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_pages["main"] = _build_main()
	_pages["howto"] = _build_howto()
	_pages["options"] = _build_options()
	for p in _pages.values():
		center.add_child(p)

	if pause_mode:
		visible = false
	_show_page("main")

# ---------------------------------------------------------------- pages

func _build_main() -> Control:
	var box := _column()
	if not pause_mode:
		# the crown is rendered on the menu's own background colour, so it sits
		# here with no visible edge
		var crown := TextureRect.new()
		crown.texture = CROWN_TEX
		crown.custom_minimum_size = Vector2(280, 200)
		crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(crown)

	var title := Label.new()
	title.text = "THE LAST MONARCH"
	title.add_theme_font_size_override("font_size", 72 if not pause_mode else 46)
	title.add_theme_color_override("font_color", GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	if not pause_mode:
		var sub := Label.new()
		sub.text = "a small realm, and a long night coming"
		sub.add_theme_font_size_override("font_size", 18)
		sub.add_theme_color_override("font_color", Color(0.70, 0.74, 0.62))
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(sub)

	box.add_child(_spacer(24))
	box.add_child(_button("Play" if not pause_mode else "Resume", _on_primary))
	if pause_mode:
		box.add_child(_button("Restart", _on_restart))
	box.add_child(_button("How to Play", func() -> void: _show_page("howto")))
	box.add_child(_button("Options", func() -> void: _show_page("options")))
	box.add_child(_button("Quit to Menu" if pause_mode else "Quit", _on_quit))
	return box

func _build_howto() -> Control:
	var box := _column()
	box.add_child(_heading("How to Play"))
	# the body scrolls inside a fixed height, so the Back button can never be
	# pushed off the bottom of the screen no matter how long this text gets
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.add_child(_body(
		"You are the monarch. You never build anything yourself —\n" +
		"you pay gold, and your people do the work.\n\n" +
		"    W A S D          ride around\n" +
		"    Z  /  X          spin the camera\n" +
		"    Hold  E          pay for whatever you're stood next to\n" +
		"    Esc              pause\n\n" +
		"Holding E raises a tally of coins above the thing you're buying.\n" +
		"Keep holding until it fills. Let go, or walk away, and the gold\n" +
		"already handed over spills on the grass — walk back over it to\n" +
		"pick it up again.\n\n" +
		"Light the campfire to raise the village, then fill the cauldron\n" +
		"to draw wanderers in. They eat from the pot and take up a trade,\n" +
		"so keep it topped up.\n\n" +
		"    Workers   fell the trees you mark\n" +
		"    Archers   hunt game and strip the berry bushes you mark,\n" +
		"              by daylight only\n\n" +
		"Everything they earn, they carry back to you."))
	box.add_child(scroll)
	box.add_child(_spacer(14))
	box.add_child(_button("Back", func() -> void: _show_page("main")))
	return box

func _build_options() -> Control:
	var box := _column()
	box.add_child(_heading("Options"))
	box.add_child(_spacer(10))

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 16)
	var vol_label := Label.new()
	vol_label.text = "Volume"
	vol_label.custom_minimum_size = Vector2(120, 0)
	vol_label.add_theme_color_override("font_color", PARCHMENT)
	vol_row.add_child(vol_label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = Settings.volume
	slider.custom_minimum_size = Vector2(220, 24)
	slider.value_changed.connect(func(v: float) -> void: Settings.set_volume(v))
	vol_row.add_child(slider)
	box.add_child(vol_row)

	var fs := CheckBox.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Settings.fullscreen
	fs.add_theme_color_override("font_color", PARCHMENT)
	fs.toggled.connect(func(on: bool) -> void: Settings.set_fullscreen(on))
	box.add_child(fs)

	box.add_child(_spacer(18))
	box.add_child(_button("Back", func() -> void: _show_page("main")))
	return box

# ---------------------------------------------------------------- actions

func _on_primary() -> void:
	if pause_mode:
		_close()
	else:
		get_tree().change_scene_to_file(GAME_SCENE)

func _on_restart() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_quit() -> void:
	if pause_mode:
		get_tree().paused = false
		get_tree().change_scene_to_file(MENU_SCENE)
	else:
		get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# Escape always backs out of a sub-page -- on the title screen too, where
	# there is otherwise no way out but the mouse
	if visible and _open != "main":
		get_viewport().set_input_as_handled()
		_show_page("main")
		return
	if not pause_mode:
		return
	get_viewport().set_input_as_handled()
	if visible:
		_close()
	else:
		_open_menu()

func _open_menu() -> void:
	_show_page("main")
	visible = true
	get_tree().paused = true

func _close() -> void:
	visible = false
	get_tree().paused = false

func _show_page(page: String) -> void:
	_open = page
	for key in _pages:
		_pages[key].visible = (key == page)

# ---------------------------------------------------------------- widgets

func _column() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	return v

func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 42)
	l.add_theme_color_override("font_color", GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _body(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", PARCHMENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = BTN_MIN
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(on_press)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
