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

const BANDIT_SCENE := preload("res://kingdom_demo/scenes/bandit.tscn")

## The steps F4 walks through. "Off" stops the rain but deliberately leaves the
## ground wet, so you can watch the pools dry on their own -- F7 clears those.
const RAIN_STEPS := [0.0, 0.35, 0.70, 1.0]
const RAIN_NAMES := ["off", "light", "steady", "downpour"]

## Fast-forward, for when you want to watch a whole 6-minute day without living
## through it. `Engine.time_scale` is the whole mechanism -- it scales the day
## clock, the walk to the trees and the build timers together, so what you watch
## is the real game, just quicker.
##
## Two things it does *not* scale, both of which are why this is a dev tool and
## not a game feature: audio keeps its own clock, so at 8x the beds and hoofbeats
## stack up into a mess; and physics steps are capped per frame, so without the
## `max_physics_steps_per_frame` line below anything past 8x quietly runs slower
## than it claims to.
const SPEED_STEPS := [1.0, 2.0, 4.0, 8.0, 16.0]

## Camera presets, for play-testing the lens (D5 in `DEPTH_PROMPTS.md`). Cycled
## with C; `pos` is the Camera3D's local offset from the rig, which follows the
## monarch, so these are pure lens-and-angle changes.
##
## **Every preset but `stock` aims at the rig origin** -- pitch equals the
## position's elevation, so the monarch sits at frame centre. `stock` deliberately
## does not: the shipped camera sits at 50.4 degrees of elevation but is pitched
## only 40, so it looks *past* the monarch and puts him low in frame with the
## ground ahead opened up. That is worth keeping as the baseline to A/B against
## rather than quietly correcting.
##
## The trailing metres are the ground visible across frame centre at 16:9, and
## they are the point of the list: **the first four are all ~18-20 m.** Distance
## and field of view cancel, so a longer lens further back buys the diorama look
## and *no extra coverage at all*. Only the two `battle` presets genuinely show
## you more -- which is a separate decision from the lens, and the one that
## matters once there is something to fight (see D6).
## Index 0 must match what `kingdom_demo.tscn` ships, or the readout lies until
## the first press. `battle 45` is now the shipped camera.
const CAM_PRESETS := [
	{"name": "battle 45°  fov34  ~28m", "pos": Vector3(0, 18.38, 18.38), "pitch": 45.0, "fov": 34.0},
	{"name": "battle 60°  fov32  ~29m", "pos": Vector3(0, 24.25, 14.00), "pitch": 60.0, "fov": 32.0},
	{"name": "diorama 45°  fov34  ~18m", "pos": Vector3(0, 12.02, 12.02), "pitch": 45.0, "fov": 34.0},
	{"name": "diorama 60°  fov32  ~19m", "pos": Vector3(0, 16.45, 9.50), "pitch": 60.0, "fov": 32.0},
	{"name": "tabletop 75° fov30  ~20m", "pos": Vector3(0, 20.28, 5.44), "pitch": 75.0, "fov": 30.0},
	{"name": "close  50°  fov45  ~18m", "pos": Vector3(0, 9.19, 7.71), "pitch": 50.0, "fov": 45.0},
	{"name": "stock  40°  fov60  ~18m", "pos": Vector3(0, 6.645, 5.503), "pitch": 40.0, "fov": 60.0},
]

## One list drives both the buttons and the hotkeys, so the two can never drift
## apart -- adding a tool is one entry here and one method.
##
## ⚠️ **Do not use F8.** It is Godot's "Stop Project" shortcut and the editor
## honours it even while the game window has focus, so binding anything to it
## just closes the game. F5 and F6 are Run shortcuts and are best left alone for
## the same reason. Plain letters are safest -- avoid W/A/S/D, E, Z, X and B,
## which the game itself uses.
const ACTIONS := [
	{"key": KEY_F2, "name": "F2", "text": "skip to night / day", "fn": "_skip_phase"},
	{"key": KEY_T, "name": "T", "text": "speed ×1 → ×16", "fn": "_step_speed"},
	{"key": KEY_C, "name": "C", "text": "camera preset", "fn": "_step_camera"},
	{"key": KEY_F4, "name": "F4", "text": "rain step", "fn": "_step_rain"},
	{"key": KEY_F5, "name": "F5", "text": "lightning now", "fn": "_strike"},
	{"key": KEY_F6, "name": "F6", "text": "next season", "fn": "_next_season"},
	{"key": KEY_F7, "name": "F7", "text": "dry the ground", "fn": "_dry"},
	{"key": KEY_J, "name": "J", "text": "horn ×1  — nightfall", "fn": "_horn_night"},
	{"key": KEY_H, "name": "H", "text": "horn ×2  — attack", "fn": "_alarm"},
	{"key": KEY_K, "name": "K", "text": "horn ×3  — blood moon", "fn": "_bloodmoon"},
	{"key": KEY_L, "name": "L", "text": "rooster (daybreak)", "fn": "_rooster"},
	{"key": KEY_N, "name": "N", "text": "spawn bandit (mouth)", "fn": "_spawn_bandit"},
	{"key": KEY_M, "name": "M", "text": "clear bandits", "fn": "_clear_bandits"},
	{"key": KEY_R, "name": "R", "text": "raid now", "fn": "_raid_now"},
	{"key": KEY_Y, "name": "Y", "text": "advance night counter", "fn": "_advance_night"},
]

var _readout: Label = null
var _box: VBoxContainer = null
var _rain_step := 0
var _speed_step := 0
var _cam_preset := 0

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
	# STOP, not IGNORE: the panel has to swallow clicks so pressing a button
	# doesn't also land on whatever is behind it.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_box = box

	box.add_child(_label("DEV  ·  F1 to hide", GOLD, 13))
	_readout = _label("", PARCHMENT, 12)
	box.add_child(_readout)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sep)

	# Clickable as well as keyed. Buttons exist because hotkeys keep colliding
	# with the editor's own (F8 is Stop Project and closes the game outright),
	# and because a tool you can see is a tool you remember you have.
	for a in ACTIONS:
		box.add_child(_action_button(a))

	var tail := _label("F1   hide  ·  F3   navmesh debug", DIM, 11)
	box.add_child(tail)

func _action_button(a: Dictionary) -> Button:
	var b := Button.new()
	b.text = "  %-3s %s" % [a["name"], a["text"]]
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE     # never steal keyboard focus from the game
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", PARCHMENT)
	b.pressed.connect(Callable(self, a["fn"]))
	return b

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
	if event.keycode == KEY_F1:
		visible = not visible
		return
	for a in ACTIONS:
		if event.keycode == a["key"]:
			call(a["fn"])
			return

## Spawns one bandit at the corridor mouth, marching on the hall. Press again for
## more -- with a wall built they line up at the shut gate (COMBAT_PROMPTS P2).
## No spawner yet; the raid director (P3) will send them in waves.
func _spawn_bandit() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var b := BANDIT_SCENE.instantiate()
	scene.add_child(b)
	b.global_position = MapTerrain.corridor_mouth() \
		+ Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-1.5, 1.5))
	print("[dev] bandit spawned at the corridor mouth")

func _clear_bandits() -> void:
	var n := 0
	for b in get_tree().get_nodes_in_group("bandit"):
		b.queue_free()
		n += 1
	print("[dev] cleared %d bandit%s" % [n, "" if n == 1 else "s"])

## Send a wave right now, without waiting for dusk.
func _raid_now() -> void:
	var dir := _raids()
	if dir:
		dir.raid_now()

## Bump the night counter, to reach a raid night (or the blood moon, P7) fast.
func _advance_night() -> void:
	var dir := _raids()
	if dir:
		dir.advance_night()

func _raids() -> Node:
	return get_tree().get_first_node_in_group("night_raids")

func _strike() -> void:
	if _weather():
		_weather().strike_lightning()

func _dry() -> void:
	if _weather():
		_weather().dry_out()

## One blast -- what you hear at nightfall. Here so the two can be compared back
## to back, which is the whole point of a signal that counts.
func _horn_night() -> void:
	_blow_horn(1)

func _alarm() -> void:
	_blow_horn(2)

## 🔮 Three blasts. Nothing raises this in game -- the blood moon is a concept
## borrowed from Kingdom Two Crowns and isn't implemented. It is here so the
## count can be heard against one and two, which is the only way to know whether
## three is still distinguishable by ear.
func _bloodmoon() -> void:
	_blow_horn(3)

## Daybreak, so the relief answer can be heard next to the horn without waiting
## out a night.
func _rooster() -> void:
	var amb := get_tree().current_scene.get_node_or_null("Ambience")
	if amb == null or not amb.has_method("crow_daybreak"):
		return
	amb.crow_daybreak()
	print("[dev] rooster")

## Jump to the next phase, landing on a moment you can actually *see* rather than
## on the phase boundary. Sunset and dawn are both still fully lit -- jumping to
## `SUNSET_AT` used to look like nothing had happened -- so night lands once dusk
## has finished falling, and day lands at sunrise with the light already up.
func _skip_phase() -> void:
	var cycle := _cycle()
	if cycle == null:
		return
	if cycle.is_night():
		cycle.set_time_of_day(cycle.SUNRISE_AT)
	else:
		cycle.set_time_of_day(cycle.SUNSET_AT + cycle.DUSK)

## Cycle the fast-forward. `max_physics_steps_per_frame` has to move with it or
## the engine runs out of physics budget and the world silently drops below the
## speed on the label -- it defaults to 8, which is exactly ×8, so ×16 would look
## like the setting simply stopped working.
func _step_speed() -> void:
	_speed_step = (_speed_step + 1) % SPEED_STEPS.size()
	var s: float = SPEED_STEPS[_speed_step]
	Engine.time_scale = s
	Engine.max_physics_steps_per_frame = maxi(8, int(ceil(s)))
	print("[dev] speed x%.0f" % s)

## Cycle the camera preset. Writes `Camera3D.position` directly, which the rig
## supports: it adopts the camera's position as its rest pose whenever it isn't
## mid-shake, so a preset survives the next thump instead of being snapped back.
func _step_camera() -> void:
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig == null:
		return
	var cam: Camera3D = rig.get_node_or_null("Camera3D")
	if cam == null:
		return
	_cam_preset = (_cam_preset + 1) % CAM_PRESETS.size()
	var p: Dictionary = CAM_PRESETS[_cam_preset]
	cam.position = p["pos"]
	cam.rotation_degrees.x = -float(p["pitch"])
	cam.fov = p["fov"]
	print("[dev] camera: %s" % p["name"])

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

## Blows the horn from the camp. There are no bandits yet, so this is the only
## way to hear the two-blast alarm -- and it wants hearing next to the one-blast
## nightfall call, because the difference between them is the whole message.
##
## Needs the fire lit: the horn comes from the camp, and before that there is no
## camp. Says so rather than failing silently.
func _blow_horn(blasts: int) -> void:
	var amb := get_tree().current_scene.get_node_or_null("Ambience")
	if amb == null or not amb.has_method("blow_horn"):
		return
	var fire := get_tree().get_first_node_in_group("campfire")
	if fire == null or not fire.lit:
		print("[dev] no horn -- light the campfire first, it is blown from the camp")
		return
	amb.blow_horn(blasts)
	print("[dev] horn: %d blast%s" % [blasts, "" if blasts == 1 else "s"])

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
	_readout.text = "%s\n%s\n%s\n%s" % [_time_line(), _weather_line(), _raid_line(), _camera_line()]

func _raid_line() -> String:
	var dir := _raids()
	if dir == null:
		return "raids   --"
	return "raids   night %d  ·  %s" % [dir.night(), "RAID" if dir.is_raid_tonight() else "quiet"]

func _camera_line() -> String:
	return "camera  %s" % CAM_PRESETS[_cam_preset]["name"]

func _time_line() -> String:
	var cycle := _cycle()
	if cycle == null:
		return "time    --"
	var t: float = cycle.time_of_day()
	var night: bool = cycle.is_night()
	var phase_t: float = t - cycle.DAY_DURATION if night else t
	var phase_len: float = cycle.NIGHT_DURATION if night else cycle.DAY_DURATION
	# Only shown when it isn't 1x, so a fast-forward you forgot about can't be
	# mistaken for the day suddenly running short.
	var speed := "" if Engine.time_scale == 1.0 else "  ×%.0f" % Engine.time_scale
	return "time    %s  %.0f/%.0fs  (dark %.2f)%s" % [
		"night" if night else "day", phase_t, phase_len, cycle.darkness(), speed]

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
