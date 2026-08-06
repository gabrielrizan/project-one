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

## Camera presets, cycled with C. `pos` is the Camera3D's local offset from the
## rig, which follows the monarch, so these are pure lens-and-angle changes.
## Both aim at the rig origin -- pitch equals the position's elevation, so the
## monarch sits at frame centre.
##
## The list used to hold seven lenses for the D5 framing pass; that question is
## settled (`battle 45` shipped) and the five losers are gone. What is left is the
## one live A/B (**perspective against orthographic**) plus one tool, `map 45`.
##
## A preset carrying `size` is **orthographic**; one carrying `fov` is
## perspective. `iso 30` is the pixel-art isometric projection rebuilt in 3D --
## parallel edges stay parallel, a hut at the top of the frame is the same size as
## one at the bottom. Two things it changes that are easy to miss:
##
## - **The horizon can never enter frame.** Every ortho ray sits at exactly the
##   pitch, so there is no angular spread to catch the sky -- which is why 30° is
##   safe here where a 30° *perspective* pitch would break the `FOG_PALE` seam
##   rule (see CLAUDE.md, "Fog has to differ from the ground in luminance").
## - **Depth fog and shadows are still tuned for the perspective frustum.** The
##   fog band is 22-55 m of slant range and `directional_shadow_max_distance` is
##   48; ortho puts the far edge of the frame at ~42 m along the view axis, so
##   both hold, but neither is *tuned* for this. Retune before shipping it.
##
## `size` is the vertical extent of the view box in metres, so ground coverage is
## `size / sin(pitch)` -- 16 / sin 30° = ~32 m, which is deliberately close to
## `battle 45`'s ~28 m. The A/B is meant to be projection alone, not zoom.
##
## Index 0 must match what `kingdom_demo.tscn` ships, or the readout lies until
## the first press. `battle 45` is the shipped camera.
## **`map 45` is not a lens, it is an inspection tool.** Ortho 150 covers ~212 m of
## ground, which holds the whole island (~188 m coast to coast) in one frame from
## the village -- there to answer "what does the map actually look like" without a
## throwaway screenshot script, which is the only way that question could be asked
## before it existed. Two things are wrong in it *by construction* and neither is a
## bug to fix: depth fog (22-55 m) swallows everything past the monarch's feet the
## moment it rains, and `directional_shadow_max_distance` is 48, so almost nothing
## casts. It is for reading the shape of the land, not for judging how it looks.
const CAM_PRESETS := [
	{"name": "battle 45°  fov40  ~28m", "pos": Vector3(0, 16.5, 16.5), "pitch": 45.0, "fov": 40.0},
	{"name": "iso 30°  ortho16  ~32m", "pos": Vector3(0, 13.00, 22.52), "pitch": 30.0, "size": 16.0},
	{"name": "map 45°  ortho150  ~212m", "pos": Vector3(0, 150.0, 150.0), "pitch": 45.0, "size": 150.0},
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
	{"key": KEY_U, "name": "U", "text": "blood moon now", "fn": "_blood_now"},
	{"key": KEY_V, "name": "V", "text": "cycle tonight's fronts", "fn": "_cycle_fronts"},
	{"key": KEY_G, "name": "G", "text": "fog on / off", "fn": "_toggle_fog"},
	{"key": KEY_O, "name": "O", "text": "dismiss war party", "fn": "_dismiss_party"},
	{"key": KEY_I, "name": "I", "text": "burn nearest camp", "fn": "_burn_camp"},
	{"key": KEY_P, "name": "P", "text": "copy monarch coords", "fn": "_copy_coords"},
]

## Where the panel sits from the top of the window, and how much clear air is left
## under it. Both feed [method _fit_scroll].
const PANEL_TOP := 12.0
const PANEL_BOTTOM_GAP := 16.0
## The list never shrinks below this, even on a very short window -- a scroll area
## two buttons tall is worse than one that overhangs a little.
const MIN_LIST_H := 120.0

var _readout: Label = null
var _box: VBoxContainer = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _rain_step := 0
var _speed_step := 0
var _cam_preset := 0
var _front_step := -1

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Stays readable and usable while the pause menu has the tree frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-268, PANEL_TOP)
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
	# wraps rather than running off the 256 px panel -- the camera line in
	# particular is long enough to lose its zoom figure off the right-hand edge
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_readout)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sep)

	# **The tool list scrolls.** It has outgrown the screen -- at 19 actions the
	# bottom few ran off the window and were simply unreachable, which is a poor
	# showing for the panel whose entire job is "a tool you can see is a tool you
	# remember you have". Only the list scrolls; the readout and the header stay
	# pinned, since those are what you are usually watching.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# STOP so the wheel scrolls this list instead of falling through to
	# `camera_rig.gd` and zooming the game camera behind the panel.
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	box.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	# Clickable as well as keyed. Buttons exist because hotkeys keep colliding
	# with the editor's own (F8 is Stop Project and closes the game outright),
	# and because a tool you can see is a tool you remember you have.
	for a in ACTIONS:
		_list.add_child(_action_button(a))

	var tail := _label("F1   hide  ·  F3   navmesh debug", DIM, 11)
	box.add_child(tail)

	get_viewport().size_changed.connect(_fit_scroll)
	# **And on becoming visible.** Godot does not lay out a hidden Control, so the
	# deferred fit at startup measures a panel of size zero, finds no overflow and
	# does nothing -- the overlay starts hidden, so that is every startup. Re-fitting
	# when it is shown is what actually makes the list fit.
	visibility_changed.connect(_on_shown)
	call_deferred("_fit_scroll")

func _on_shown() -> void:
	if visible:
		_fit_scroll()

## Size the tool list to whatever is left of the window.
##
## **Measures the overflow, rather than modelling the chrome.** The first attempt
## added up the header, readout, separator, tail and panel margins and subtracted
## them from the window height; it came out 130 px short, because an autowrapping
## label's height is not known until it has been laid out at its final width, and
## the readout wraps differently with the map, the weather and the zoom. So instead:
## start the list at its natural height, let two frames go by, then ask the panel
## where its bottom edge actually landed and take the difference off. No model to
## be wrong, and it re-fits itself on any window resize.
##
## Growing back matters as much as shrinking: starting from the natural height each
## time is what lets the list expand again when the window gets taller. When it
## fits, it is sized to its content and there is no scrollbar at all.
func _fit_scroll() -> void:
	if _scroll == null or _box == null or not is_inside_tree():
		return
	_scroll.custom_minimum_size.y = _list.get_combined_minimum_size().y
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var panel := _box.get_parent() as Control
	if panel == null:
		return
	var overflow: float = (panel.global_position.y + panel.size.y) \
		- (get_viewport_rect().size.y - PANEL_BOTTOM_GAP)
	if overflow > 0.0:
		_scroll.custom_minimum_size.y = maxf(MIN_LIST_H, _scroll.size.y - overflow)

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
	b.global_position = MapTerrain.raid_origin() \
		+ Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-1.5, 1.5))
	print("[dev] bandit spawned at the raiding camp")

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

## A blood moon right now (P7) -- skips to night, reddens the sky, horn x3, a big
## wave in pulses with Brutes.
func _blood_now() -> void:
	var dir := _raids()
	if dir and dir.has_method("blood_moon_now"):
		dir.blood_moon_now()

func _raids() -> Node:
	return get_tree().get_first_node_in_group("night_raids")

## Send the whole war party home (P9).
func _dismiss_party() -> void:
	var banner := get_tree().get_first_node_in_group("muster_banner")
	if banner and banner.has_method("dismiss"):
		banner.dismiss()

func _banner() -> Node:
	return get_tree().get_first_node_in_group("muster_banner")

## Burn the camp nearest the monarch right now (P10), skipping the muster/assault --
## so the fire, the wreck and the "map cleared" line can be seen without riding the
## whole loop. Clears that camp's garrison so the wreck reads as abandoned.
func _burn_camp() -> void:
	var camps := get_tree().get_nodes_in_group("bandit_camp")
	if camps.is_empty():
		print("[dev] no camps left to burn")
		return
	var m := get_tree().get_first_node_in_group("monarch")
	var origin: Vector3 = m.global_position if is_instance_valid(m) else Vector3.ZERO
	var best: Node3D = null
	var bd := INF
	for c in camps:
		var d: float = origin.distance_to(c.global_position)
		if d < bd:
			bd = d
			best = c
	if best and best.has_method("dev_burn"):
		best.dev_burn()
		print("[dev] burned a camp")

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

## Cycle the camera preset.
##
## The pose goes through `CameraRig.set_rest_pose`, **not** straight onto
## `Camera3D.position`, because the rig now owns that property: the mouse wheel
## rewrites it every frame, so a preset written directly would survive exactly one
## frame. Handing it over also resets the wheel to 1.0, which is what keeps a
## preset landing on its own numbers and the readout from lying.
func _step_camera() -> void:
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig == null:
		return
	var cam: Camera3D = rig.get_node_or_null("Camera3D")
	if cam == null:
		return
	_cam_preset = (_cam_preset + 1) % CAM_PRESETS.size()
	var p: Dictionary = CAM_PRESETS[_cam_preset]
	cam.rotation_degrees.x = -float(p["pitch"])
	# `size` marks an orthographic preset, `fov` a perspective one. Both are always
	# written, not just the one in use: Godot keeps them as separate properties, so
	# leaving the other stale means cycling back lands on whatever the last preset
	# of that kind set rather than on this preset's own number.
	if p.has("size"):
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = float(p["size"])
		rig.set_rest_pose(p["pos"], float(p["size"]))
	else:
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = float(p["fov"])
		rig.set_rest_pose(p["pos"])
	print("[dev] camera: %s" % p["name"])

## Fog off / on. **Non-destructive**: the mask is untouched, so switching it back on
## puts the frontier exactly where it was rather than wherever the camera has been.
## That is what makes it usable for looking at the map mid-run without spoiling the
## run you are looking at.
func _toggle_fog() -> void:
	var fog := _fog()
	if fog == null:
		return
	fog.set_bypass(not fog.bypassed())
	print("[dev] fog %s" % ("off" if fog.bypassed() else "on"))

## There is deliberately **no second "explore everything permanently" tool.** One
## briefly existed on P; the toggle above does everything it did, because nothing in
## the game reads the mask except visibility -- so a filled mask and a bypassed
## shroud look and play identically, and the toggle has the considerable advantage
## of being undoable. Two tools that cannot be told apart by their effects are one
## tool and a way to be confused.
## Walk tonight's fronts round the map's walls, one bearing at a time (F5).
##
## Rolling them is random by design, which makes "can you read the cue?" awkward to
## test -- you end up re-rolling until the dice give you the wall you wanted to look
## at. This just steps through them, lighting each in turn, so the braziers can be
## checked from every bearing and at both zoom stops.
func _cycle_fronts() -> void:
	var dir := _raids()
	if dir == null:
		return
	var walls := MapTerrain.walls()
	if walls.is_empty():
		return
	_front_step = (_front_step + 1) % walls.size()
	var want: Array = [_front_step]
	if MapTerrain.max_fronts() > 1:
		want.append((_front_step + 1) % walls.size())
	dir.set_fronts(want)

func _fog() -> Node:
	if not FogOfWar.enabled():
		print("[dev] no fog on this map")
		return null
	return get_tree().get_first_node_in_group("fog")

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
	# `place` goes **first** rather than appended at the end, because it is the one
	# line you read repeatedly rather than glance at: laying out a map is ride, read
	# the number, ride again. The lines below it wrap to different heights as the
	# weather and the fronts change, so anything after them moves under the cursor.
	_readout.text = "%s\n%s\n%s\n%s\n%s" % [
		_place_line(), _time_line(), _weather_line(), _raid_line(), _camera_line()]

## Where the monarch is standing, as a coordinate you can paste into
## `map_catalog.gd`.
##
## **This is the map-authoring loop.** A map is data -- camps, walls, reward sites,
## the muster point and the spawn lane are all literal `Vector3`s in one function in
## `map_catalog.gd` -- and the only way to choose one used to be to guess a number,
## relaunch, and go and look at where the thing landed. Ride to the spot instead and
## read it off; **P** copies it to the clipboard in the exact form that file wants.
##
## The ground kind is the other half of it. `open` is ground something can actually
## stand on; `WATER` / `ROCK` / `WOOD` are the three ways a coordinate can look
## perfectly reasonable in the file and put your camp inside a cliff or out at sea,
## which is otherwise only discovered by launching the map and not finding it.
func _place_line() -> String:
	var m := get_tree().get_first_node_in_group("monarch") as Node3D
	if m == null:
		return "place   --"
	var p := m.global_position
	var v := p - MapTerrain.village()
	v.y = 0.0
	return "place   Vector3(%.0f, 0, %.0f)   %s %.0fm  ·  %s" % [
		p.x, p.z, _bearing_name(p), v.length(), _ground_at(p)]

## What kind of ground a point is, in [MapDef]'s own terms -- so the answer here is
## the same one `_plantable` and the spawners will give when they decide whether
## your camp may stand there, rather than a second opinion that can disagree.
func _ground_at(p: Vector3) -> String:
	var kind := MapTerrain.gate_kind_at(p)
	if kind != "":
		return kind.to_upper()      # WATER / ROCK / WOOD -- all of them sealed
	if not MapTerrain.is_open(p):
		return "off-map"
	return "open"

## Copy the monarch's spot to the clipboard, ready to paste.
##
## `y` is forced to **0** rather than taken from the monarch, because the world is
## one flat slab and every coordinate in `map_catalog.gd` sits at zero -- pasting
## his real height would hang a camp a few centimetres in the air for no reason.
func _copy_coords() -> void:
	var m := get_tree().get_first_node_in_group("monarch") as Node3D
	if m == null:
		return
	var p := m.global_position
	var text := "Vector3(%.0f, 0, %.0f)" % [p.x, p.z]
	DisplayServer.clipboard_set(text)
	print("[dev] copied  %s   (%s)" % [text, _ground_at(p)])

func _raid_line() -> String:
	var dir := _raids()
	if dir == null:
		return "raids   --"
	var kind := "BLOOD" if dir.is_blood_tonight() else ("RAID" if dir.is_raid_tonight() else "quiet")
	var party := 0
	var banner := _banner()
	if banner and banner.has_method("party_size"):
		party = banner.party_size()
	var camps := get_tree().get_nodes_in_group("bandit_camp").size()
	var fronts := "-"
	if dir.has_method("front_positions"):
		var fp: Array = dir.front_positions()
		if not fp.is_empty():
			var names := PackedStringArray()
			for p in fp:
				names.append(_bearing_name(p))
			fronts = " ".join(names)
	return "raids   night %d  %s  ·  fronts %s  ·  blood in %d  ·  party %d  ·  camps %d" % [
		dir.night(), kind, fronts, dir.nights_until_blood(), party, camps]

## A wall's bearing as a compass letter, so the readout says "N E" rather than a
## pair of coordinates you have to decode against the map.
func _bearing_name(p: Vector3) -> String:
	var v: Vector3 = p - MapTerrain.village()
	if absf(v.x) > absf(v.z):
		return "E" if v.x > 0.0 else "W"
	return "S" if v.z > 0.0 else "N"

func _camera_line() -> String:
	return "camera  %s   zoom ×%.2f%s" % [
		CAM_PRESETS[_cam_preset]["name"], CameraRig.zoom, _fog_note()]

## Only says anything when the fog is switched **off**, so a bypass you forgot about
## cannot be mistaken for a map you actually explored -- the same reason the speed
## multiplier is only shown when it isn't 1x.
func _fog_note() -> String:
	if not FogOfWar.enabled():
		return ""
	var fog := get_tree().get_first_node_in_group("fog")
	if fog and fog.bypassed():
		return "   FOG OFF"
	return ""

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
