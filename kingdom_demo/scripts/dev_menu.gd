extends Control
## The dev overlay: live weather/time readout, and hotkeys to jump straight to
## whatever you need to look at.
##
## This exists because the things it controls are otherwise **slow and random**
## to reach. Waiting two minutes for nightfall, or several minutes for a storm
## the season might not even roll, makes tuning the look impossible. Every key
## here reaches into a system directly rather than nudging the simulation toward
## a state -- the same principle as the test guidance in `CLAUDE.md`.
##
## F3 is deliberately skipped: `nav_world.gd` already owns it for path debugging.
##
## ⚠️ This is a **developer tool, not a player feature**. It is always available
## in the current build because there is no release/debug split yet. Gate it on
## `OS.is_debug_build()` before shipping anything.
##
## Layout is built in code, the same way `menu.gd` builds its pages.

const PANEL_BG := Color(0.05, 0.07, 0.06, 0.82)
const GOLD := Color(0.85, 0.72, 0.38)
const PARCHMENT := Color(0.92, 0.89, 0.80)
const DIM := Color(0.62, 0.66, 0.60)

## The steps F4 walks through. "Off" stops the rain but deliberately leaves the
## ground wet, so you can watch the pools dry on their own -- F7 clears those.
const RAIN_STEPS := [0.0, 0.35, 0.70, 1.0]
const RAIN_NAMES := ["off", "light", "steady", "downpour"]

var _readout: Label = null
var _rain_step := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Stays readable and usable while the pause menu has the tree frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-268, 12)
	panel.custom_minimum_size = Vector2(256, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = Color(0.85, 0.72, 0.38, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	box.add_child(_label("DEV  ·  F1 to hide", GOLD, 13))
	_readout = _label("", PARCHMENT, 12)
	box.add_child(_readout)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sep)

	box.add_child(_label(
		"F2   skip to night / day\n"
		+ "F4   rain step\n"
		+ "F5   lightning now\n"
		+ "F6   next season\n"
		+ "F7   dry the ground\n"
		+ "F3   navmesh debug", DIM, 12))

func _label(text: String, col: Color, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ---------------------------------------------------------------- keys

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F1:
			visible = not visible
		KEY_F2:
			_skip_phase()
		KEY_F4:
			_step_rain()
		KEY_F5:
			if _weather():
				_weather().strike_lightning()
		KEY_F6:
			_next_season()
		KEY_F7:
			if _weather():
				_weather().dry_out()

## Jump to the start of the next phase -- night if it's day, dawn if it's night.
func _skip_phase() -> void:
	var cycle := _cycle()
	if cycle == null:
		return
	cycle.set_time_of_day(0.0 if cycle.is_night() else cycle.DAY_DURATION)

func _step_rain() -> void:
	var w := _weather()
	if w == null:
		return
	_rain_step = (_rain_step + 1) % RAIN_STEPS.size()
	var target: float = RAIN_STEPS[_rain_step]
	if target <= 0.0:
		w.stop_rain(true)
	else:
		# Forced storms are always thundery: if you asked for rain from a dev
		# key you almost certainly want to see the lightning too.
		w.force_rain(target, true, true)

## Steps the season *and* reports it, because seasons have no visual identity
## yet -- without the readout there would be no way to tell it had worked.
func _next_season() -> void:
	var w := _weather()
	if w == null:
		return
	w.next_season()
	print("[dev] season -> %s (rain %s)"
		% [w.season_name(), "yes" if w.rains_this_season() else "no"])

# ---------------------------------------------------------------- readout

func _process(_delta: float) -> void:
	if not visible or _readout == null:
		return
	_readout.text = "%s\n%s" % [_time_line(), _weather_line()]

func _time_line() -> String:
	var cycle := _cycle()
	if cycle == null:
		return "time    --"
	var t: float = cycle.time_of_day()
	var night: bool = cycle.is_night()
	var phase_t: float = t - cycle.DAY_DURATION if night else t
	var phase_len: float = cycle.NIGHT_DURATION if night else cycle.DAY_DURATION
	return "time    %s  %.0f/%.0fs  (dark %.2f)" % [
		"night" if night else "day", phase_t, phase_len, cycle.darkness()]

func _weather_line() -> String:
	var w := _weather()
	if w == null:
		return "weather --"
	return "season  %s%s\nweather %s  rain %.2f  wet %.2f" % [
		w.season_name(),
		"" if w.rains_this_season() else "  (dry season)",
		w.state_name(), w.intensity(), w.wetness()]

func _cycle() -> Node:
	return get_tree().get_first_node_in_group("day_night_cycle")

func _weather() -> Node:
	return get_tree().get_first_node_in_group("weather")
