extends StaticBody3D
## A wreck on the beach, and the way off the island (ISLAND_PROMPTS F7 · §10 exit).
##
## Three states, and the model never changes -- **the wreck *is* the ship**, careened
## over on its side with its sails stripped. Paying opens a construction site; the
## crew rights her and bends the sails on; then she waits for the bell.
##
## ## It is a `build_site`, which means it needs no new AI at all
##
## Joining the `build_site` group and answering the same seven duck-typed calls
## `wall_side.gd` and `building.gd` answer (`site_active`, `needs_builders`,
## `claim_builder`, `release_builder`, `builder_ready`, `build_spot`, `face_point`)
## is the entire integration. Idle workers already walk to anything in that group and
## swing at it; `villager.gd` never learns what a wreck is. And it keeps the rule
## that **nothing the monarch pays for is built instantly** -- he commissions, his
## people build (Pillar 1).
##
## ## The bell is the gate, and it is deliberately dead at first
##
## She can be rebuilt from night one. **The bell will not ring until every camp on
## the map has burned** (`ROADMAP.md` R1: destroy all camps to leave), which is what
## stops the boat being an escape hatch from a bad night and makes it the reward for
## finishing the map. A rebuilt ship sitting ready with a silent bell is the whole
## objective stated in one object.
##
## ⚠️ **This is where the island ends.** Map 2 does not exist. Ringing the bell
## stores the R5 carry-over in run state and raises an end-of-map screen -- it does
## not sail anywhere, and inventing somewhere for it to go is not this task's job.

const QS := "res://kingdom_demo/assets/3d/quaternius_ships/"

## PLACEHOLDER, like every cost in the game.
const REPAIR_COST := 20
const BASE_BUILD_TIME := 45.0     # for the whole hull, at a single pair of hands
const SHIP_SCALE := 1.5           # 6.38 m as authored -> a ~9.5 m ship

## How far over she lies as a wreck, and how far into the sand.
const WRECK_ROLL := deg_to_rad(28.0)
const WRECK_SINK := -0.35
## Weathered timber for the wreck: the same hull, greyed by however long it has lain
## there. Repainted rather than tinted, so the ship keeps its own material set.
const WRECK_WOOD := Color(0.42, 0.38, 0.33)
const WRECK_DARK := Color(0.28, 0.25, 0.22)

const PROMPT_Y := 3.4
const GOLD := Color(1, 0.9, 0.4)
const STATIONS: Array[float] = [0.0, -2.6, 2.6]

var _prompt: Label3D = null
var _ship: Node3D = null
var _sails: Array[MeshInstance3D] = []
var _crew: BuildCrew = BuildCrew.new()
var _building := false
var _progress := 0.0
var _ready_to_sail := false
var _sailed := false
var _busy := false

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("wreck")

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.0, 8.0)
	cs.shape = box
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs)

	_build_ship()

	_prompt = Label3D.new()
	_prompt.pixel_size = 0.007
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.modulate = GOLD
	_prompt.outline_modulate = Color(0.1, 0.08, 0.05)
	_prompt.font_size = 46
	_prompt.outline_size = 12
	_prompt.position = Vector3(0, PROMPT_Y, 0)
	_prompt.visible = false
	add_child(_prompt)

	FogOfWar.hide_until_found(self)
	set_process(false)
	NavWorld.rebake(self)

# ---------------------------------------------------------------- the ship

## One model, two states. `Sail ship.fbx` is 6.38 m long as authored, and the canvas
## is three separate meshes (`BackSail`, `Front Sail`, `MidleSail`), which is what
## makes "strip her" a visibility flag rather than a second model.
##
## ⚠️ **Sails are found by node name, not by material.** The first version matched any
## mesh carrying the `Fabric` material -- and the hull, `BigShip`, has a Fabric
## surface among its others (the flags), so careening her hid the entire ship and the
## beach came back empty. `visible` is per *node*; a per-surface test cannot drive it.
func _build_ship() -> void:
	_ship = MarkFx.model(load(QS + "SailShip.fbx"), SHIP_SCALE)
	add_child(_ship)
	for m in MarkFx.meshes(_ship):
		var mi := m as MeshInstance3D
		if "sail" in String(mi.name).to_lower():
			_sails.append(mi)
	_careen(true)

## Lay her over (or right her). A wreck is the ship rolled onto her beam ends and
## half buried, with no canvas on the yards.
func _careen(wrecked: bool) -> void:
	_ship.rotation.z = WRECK_ROLL if wrecked else 0.0
	_ship.position.y = WRECK_SINK if wrecked else 0.0
	for s in _sails:
		if is_instance_valid(s):
			s.visible = not wrecked
	if wrecked:
		MarkFx.repaint(_ship, {"Wood": WRECK_WOOD, "LightWood": WRECK_WOOD,
			"DarkWood": WRECK_DARK})

# ---------------------------------------------------------------- interaction

func show_prompt() -> void:
	if _busy or _sailed:
		return
	_prompt.text = _prompt_text()
	_prompt.visible = true

func hide_prompt() -> void:
	if is_instance_valid(_prompt):
		_prompt.visible = false

func _prompt_text() -> String:
	if _building:
		return "Repairing…  %d%%" % int(_progress * 100.0)
	if not _ready_to_sail:
		return "Hold E  Repair (%d)" % REPAIR_COST
	# She floats. Whether she may leave is the map's business, not hers.
	if _camps_left() > 0:
		return "The bell is silent  ·  %d camp(s) stand" % _camps_left()
	return "E  Ring the bell"

func interact(who: Node3D) -> void:
	if _busy or _sailed or _building:
		return
	if _ready_to_sail:
		if _camps_left() == 0:
			_ring()
		return
	if not GoldFx.can_afford(REPAIR_COST):
		return
	# refused outright when nobody could ever build it, the same way every other
	# crew-built purchase refuses -- gold must not vanish into a site nobody works
	if _idle_workers() == 0:
		return
	_busy = true
	hide_prompt()
	var ok: bool = await GoldFx.pay(who, self, REPAIR_COST, PROMPT_Y - 0.6)
	_busy = false
	if ok:
		_open_site()
	elif is_instance_valid(who) and global_position.distance_to(who.global_position) < 4.0:
		show_prompt()

## Is there anybody who could ever work on this? Workers are the trade that takes
## `build_site` errands (`villager.gd::_look_for_errand`), so a village with no
## worker can never raise her and the sale must be refused rather than swallowing
## the gold -- the same rule every crew-built purchase follows.
func _idle_workers() -> int:
	var n := 0
	for v in get_tree().get_nodes_in_group("villager"):
		if v.has_method("job_name") and v.job_name() == "worker":
			n += 1
	return n

func _camps_left() -> int:
	return get_tree().get_nodes_in_group("bandit_camp").size()

# ---------------------------------------------------------------- construction

func _open_site() -> void:
	_building = true
	_progress = 0.0
	add_to_group("build_site")
	set_process(true)

func _process(delta: float) -> void:
	if not _building:
		return
	var hands := _crew.hands()
	if hands <= 0:
		return
	_progress += delta * _crew.speed() / BASE_BUILD_TIME
	# she rights herself as the work goes on, so progress is legible from across the
	# beach without a bar -- the same idea as a wall's sections going up one by one
	_ship.rotation.z = lerpf(WRECK_ROLL, 0.0, _progress)
	_ship.position.y = lerpf(WRECK_SINK, 0.0, _progress)
	if _progress >= 1.0:
		_finish()

func _finish() -> void:
	_building = false
	_progress = 1.0
	_ready_to_sail = true
	set_process(false)
	remove_from_group("build_site")
	_crew = BuildCrew.new()
	_careen(false)
	# fresh timber again -- `unpaint`, not `untint`: repaint wrote surface overrides
	MarkFx.unpaint(_ship)
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("post_notice"):
		gm.post_notice("She floats. The bell waits on the last camp.")
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("shake"):
		rig.shake(0.35, 0.09)

# ---- the crew (duck-typed, exactly as wall_side.gd answers it) ----

func site_active() -> bool:
	return _building

func needs_builders() -> bool:
	return _building and _crew.needs_more()

func claim_builder(who: Node3D) -> bool:
	return _crew.claim(who) if needs_builders() else false

func release_builder(who: Node3D) -> void:
	if _crew:
		_crew.release(who)

func builder_ready(who: Node3D) -> void:
	if _crew:
		_crew.arrived(who)

## Along the hull, stepped inland so nobody stands in the sea to work.
func build_spot(who: Node3D) -> Vector3:
	var i: int = _crew.station(who) % STATIONS.size()
	var along := global_transform.basis.z.normalized()
	var inland := (MapTerrain.village() - global_position)
	inland.y = 0.0
	inland = inland.normalized() if inland.length() > 0.01 else Vector3.FORWARD
	return global_position + along * STATIONS[i] + inland * 2.2

func face_point(from: Vector3) -> Vector3:
	var along := global_transform.basis.z.normalized()
	var d: float = clampf((from - global_position).dot(along), -3.0, 3.0)
	return global_position + along * d

# ---------------------------------------------------------------- sailing

## Ring the bell: the kingdom walks down to the beach and boards.
##
## Never an order (Pillar 1) -- the bell is a call, and what answers it is everyone
## who can. The same shape as the cauldron drawing wanderers in, run backwards.
func _ring() -> void:
	_sailed = true
	hide_prompt()
	remove_from_group("interactable")
	var gm := get_tree().get_first_node_in_group("game_manager")
	var boarded := 0
	for v in get_tree().get_nodes_in_group("villager"):
		if not is_instance_valid(v):
			continue
		boarded += 1
		var t := v.create_tween()
		t.tween_property(v, "global_position", global_position, randf_range(2.4, 4.6)) \
			.set_trans(Tween.TRANS_SINE)
		t.tween_property(v, "scale", Vector3.ZERO, 0.3)
		t.tween_callback(v.queue_free)
	var king := get_tree().get_first_node_in_group("monarch")
	if is_instance_valid(king):
		var kt := king.create_tween()
		kt.tween_property(king, "global_position", global_position, 4.2).set_trans(Tween.TRANS_SINE)
	if gm and gm.has_method("depart_map"):
		gm.depart_map(boarded)
