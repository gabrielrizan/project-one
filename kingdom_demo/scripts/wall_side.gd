extends StaticBody3D
## One side of the village palisade. It starts as a lone marker post with a
## "build" prompt at the gate spot.
##
## Paying does not raise the wall -- the monarch does not build, he commissions.
## It opens a BUILDING SITE: material is dropped along the line, a hammer banner
## goes up, and workers down tools and walk over. Sections rise one at a time
## under their hammers, corners first, closing in on the gap; the gate drops into
## it last. See [BuildCrew] for the pace: up to three workers, each beyond the
## first adding 30% more speed.
##
## **Four levels — twig, wood, stone, fortified stone — and each one needs the
## matching main-building tier.** You cannot ring a tent with a castle wall: the
## kingdom's defences can never outrun the hall they defend, which is what stops
## the walls being a way to skip the ladder. Every rung is a separate purchase
## opening its own site, and nothing ever converts for free; a wall left at twig
## stays twig however grand the hall gets.

## The four levels, and the main-building tier each one needs. **A wall can never
## outrun the hall it defends**: twig comes with the Tent, wood with the Wooden
## Hall, stone with the Stone Hall, fortified with the Castle. So the level index
## *is* the required hall tier, which is why there is no separate "requires"
## field -- the two can't drift apart if only one number exists.
##
## Heights climb 0.75 -> 1.05 -> 1.35 -> 1.64 m against a 1.2 m villager, so each
## upgrade is a silhouette you can read from across the camp: something you step
## over, something you hide behind, something you man.
##
## `yaw` is per level because the kits disagree about which way a panel runs --
## Fantasy Town pieces are 1 m along **Z** with the face on +X, so they turn 90
## degrees to lie along the wall; the castle kit's wall is already 1 m along X.
const NONE := 0
const TWIG := 1
const WOOD := 2
const STONE := 3
const FORT := 4
const TOP_LEVEL := FORT

const TWIG_SCENE := preload("res://kingdom_demo/assets/3d/kenney_fantasy-town-kit/Models/GLB format/poles-horizontal.glb")
const WOODWALL_SCENE := preload("res://kingdom_demo/assets/3d/kenney_fantasy-town-kit/Models/GLB format/wall-wood.glb")
const STONEWALL_SCENE := preload("res://kingdom_demo/assets/3d/kenney_fantasy-town-kit/Models/GLB format/wall.glb")
## The castle kit's wall, and the only one in either kit with battlements on it --
## which is what makes the top tier read as *fortified* rather than just bigger.
const FORT_SCENE := preload("res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/wall.glb")

## PLACEHOLDER COSTS, climbing rather than flat -- unlike the hall tiers, a wall
## you can rebuild on four sides wants to feel like it costs more each time.
const LEVELS := [
	{},   # 0 -- a bare marker post, nothing to describe
	{"name": "Twig Fence", "scene": TWIG_SCENE, "yaw": 90.0, "scale": 0.75, "cost": 3, "stone": false},
	{"name": "Wooden Wall", "scene": WOODWALL_SCENE, "yaw": 90.0, "scale": 1.05, "cost": 5, "stone": false},
	{"name": "Stone Wall", "scene": STONEWALL_SCENE, "yaw": 90.0, "scale": 1.35, "cost": 8, "stone": true},
	{"name": "Fortified Wall", "scene": FORT_SCENE, "yaw": 0.0, "scale": 1.25, "cost": 12, "stone": true},
]

const HALF := 8.0             # wall runs local x  -HALF .. +HALF
const GATE_HALF := 1.0        # sections stop this far from centre -> gate opening
const STAKE_SPACING := 1.0    # one section wide
const OPEN_ANGLE := 85.0
const DOOR_SCALE := 2.8       # castle door.glb is small -> scale up to gate size
const BASE_BUILD_TIME := 30.0 # for either phase, at a single pair of hands

## Gate leaves only -- the wall runs themselves come from LEVELS above.
const FENCE_SCENE := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/fence.glb")
const DOOR_SCENE := preload("res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/door.glb")
const HAMMER_MODEL := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/tool-hammer.glb")
const TIMBER_MODEL := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/tree-log.glb")
const STONE_PILE_MODEL := preload("res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/rocks-small.glb")
const PENNANT_MODEL := preload("res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/flag-pennant.glb")

const BANNER_Y := 2.5
## tool-hammer.glb is a 0.15m handheld tool -- this brings it up to the size the
## axe banner over a marked tree reads at
const BANNER_SCALE := 5.0
const PENNANT_SCALE := 1.6
## the castle kit's pennant is blue, which is nowhere in this game's palette --
## flatten it to the monarch's burgundy so a finished wall reads as his
const PENNANT_COLOR := Color(0.45, 0.12, 0.18)
const DUST := Color(0.78, 0.73, 0.62, 0.95)
## where builders plant their feet along the line -- a lone one works the gap,
## extra hands spread out to the flanks
const STATIONS: Array[float] = [0.0, -3.6, 3.6]

## Six archer perches flanking the gate (COMBAT_PROMPTS P4), ordered **centre-first**
## so the two nearest the opening fill before the flanks -- fire concentrates where
## raiders mass at the gate (§9). Offsets are along the run (local x).
const PERCH_OFFSETS: Array[float] = [1.6, -1.6, 4.0, -4.0, 6.4, -6.4]
## What an archer's feet stand at, per level (none/twig/wood/stone/fort). The wood
## tier's float over its 0.52 m fence visual is accepted placeholder (§9, §12.20).
const PERCH_HEIGHTS: Array[float] = [0.0, 0.75, 1.05, 1.35, 1.64]
## How far inside the wall the climb starts, on the ground.
const PERCH_FOOT_IN := 1.4

# --- HP, damage & repair (COMBAT_PROMPTS P6a) ---
## PLACEHOLDER, scaled by material -- stone is far tougher than wood. Two pools per
## side: the arc (all the sections either side of the gate) and a smaller, separate
## one for the gate itself, which is where raiders mass and hammer.
const ARC_HP: Array[float] = [0.0, 60.0, 120.0, 240.0, 400.0]
const GATE_HP: Array[float] = [0.0, 40.0, 80.0, 160.0, 280.0]
## Stone sections swap to this ready-made ruin at zero; wood just tilts and sinks.
const RUIN_SCENE := preload("res://kingdom_demo/assets/3d/kenney_fantasy-town-kit/Models/GLB format/wall-half.glb")

@onready var _marker: Node3D = $MarkerSprite
@onready var _marker_col: CollisionShape3D = $MarkerCollision
@onready var _prompt: Label3D = $Prompt

var level := NONE             # 0 = marker post only; 1..4 = the ladder above
var building := false         # a site is open, waiting on or worked by hands
var _target := NONE           # the level the open site is working toward
var _busy := false
var _near := 0
var _saluting := false        # the gate is mid-flourish; leave it alone
var _flagged := false         # pennants only ever go up once
var _sections: Array[Node3D] = []
var _left_leaf: Node3D = null
var _right_leaf: Node3D = null
var _left_model: Node3D = null
var _right_model: Node3D = null
var _gate_col: CollisionShape3D = null

var _progress := 0.0          # 0 .. 1 across whichever phase is running
var _plan: Array[float] = []  # section x offsets, in the order they go up / convert
var _raised := 0
var _crew: BuildCrew = null
var _banner: Node3D = null
var _banner_t := 0.0
var _site_props: Array[Node3D] = []
var _perch_taken: Array = []   # index -> claiming archer (or null)

# HP, damage & repair (P6a)
var _arc_hp := 0.0
var _arc_hp_max := 0.0
var _gate_hp := 0.0
var _gate_hp_max := 0.0
var _breached := false          # arc collision gone -- a hole in the run
var _gate_breached := false     # gate collision gone -- the gateway is open
var _repairing := false         # the open site is mending, not raising/upgrading
var _left_col: CollisionShape3D = null
var _right_col: CollisionShape3D = null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("wall_side")
	_perch_taken.resize(PERCH_OFFSETS.size())
	set_process(false)

# ---- build interaction ----

## The next rung, or NONE if there isn't one -- either the wall is already
## fortified, or the hall hasn't earned the next material yet.
func _next_level() -> int:
	if level >= TOP_LEVEL:
		return NONE
	var want := level + 1
	return want if _hall_tier() >= want else NONE

## The main building's tier, 1..4. Walls read this rather than a "stone unlocked"
## flag, because there are now four gates rather than one.
func _hall_tier() -> int:
	var fire := get_tree().get_first_node_in_group("campfire")
	if fire != null and fire.has_method("hall_tier"):
		return fire.hall_tier()
	return NONE

func show_prompt() -> void:
	if building or _busy:
		return
	# a damaged side offers repair before anything else (P6a)
	if _is_damaged():
		_prompt.text = ("Hold E  Repair (%d)" % _repair_cost()) if _workers_exist() \
			else "Repair  needs a worker"
		_prompt.visible = true
		return
	var want := _next_level()
	if want == NONE:
		hide_prompt()
		return
	var d: Dictionary = LEVELS[want]
	# No "Build" / "Upgrade to" verb: the level's own name changes every rung, so
	# the verb added nothing but length. World-space prompts are physically large
	# (see `CLAUDE.md`) and "Hold E  Upgrade to Fortified Wall (12)" was 38
	# characters of 3D text lying across the village.
	_prompt.text = ("Hold E  %s (%d)" % [d["name"], d["cost"]]) if _workers_exist() \
		else "%s  needs a worker" % d["name"]
	_prompt.visible = true

func hide_prompt() -> void:
	_prompt.visible = false

func interact(who: Node3D) -> void:
	if building or _busy:
		return
	# repair a damaged side (P6a) -- same hold-to-pay, at a fraction of the cost
	if _is_damaged():
		var rc: int = _repair_cost()
		if not _workers_exist() or not GoldFx.can_afford(rc):
			return
		_busy = true
		hide_prompt()
		var ok_r: bool = await GoldFx.pay(who, self, rc, 2.2)
		_busy = false
		if ok_r:
			_open_repair()
		elif _near_enough(who):
			show_prompt()
		return
	var want := _next_level()
	if want == NONE:
		return
	var cost: int = LEVELS[want]["cost"]
	if not _workers_exist() or not GoldFx.can_afford(cost):
		return
	_busy = true
	hide_prompt()
	var ok: bool = await GoldFx.pay(who, self, cost, 2.2)
	_busy = false
	if ok:
		_open_site(want)
	elif _near_enough(who):
		show_prompt()

func _near_enough(who: Node3D) -> bool:
	return is_instance_valid(who) and global_position.distance_to(who.global_position) < 3.0

func _workers_exist() -> bool:
	for v in get_tree().get_nodes_in_group("villager"):
		if v.has_method("is_worker") and v.is_worker():
			return true
	return false

# ---- the building site ----

## One site for every rung. Raising the first wall and upgrading an existing one
## differ only in whether a section rises out of the ground or is swapped in
## place, so `_upgrading()` is the single branch rather than two near-identical
## functions -- which is what let the old pair drift into wood-only and
## stone-only assumptions.
func _open_site(want: int) -> void:
	building = true
	_target = want
	remove_from_group("interactable")
	add_to_group("build_site")
	_crew = BuildCrew.new()
	_raised = 0
	_progress = 0.0
	# The same offsets either way: raising walks them empty, upgrading steps
	# through the sections already standing on them.
	_plan = _section_plan()
	_banner = MarkFx.banner(self, HAMMER_MODEL, BANNER_Y, BANNER_SCALE)
	_banner_t = 0.0
	_lay_out_site_props(STONE_PILE_MODEL if LEVELS[want]["stone"] else TIMBER_MODEL)
	set_process(true)

## True when there is already a wall standing that this site is replacing.
func _upgrading() -> bool:
	return level != NONE

## Corners first, working inward a pair at a time, so the run closes on the gap
## and the gate is the last thing to drop in (or, upgrading, the last to convert).
func _section_plan() -> Array[float]:
	var out: Array[float] = []
	var x := HALF
	while x > GATE_HALF + 0.01:
		out.append(-x)
		out.append(x)
		x -= STAKE_SPACING
	return out

## Timber, or a stone pile once upgrading -- material stacked along the line so
## the site reads as a site even before anyone turns up to work it.
func _lay_out_site_props(model: PackedScene) -> void:
	for i in range(4):
		var p := model.instantiate()
		add_child(p)
		var side := -1.0 if i % 2 == 0 else 1.0
		p.position = Vector3(side * randf_range(2.0, 6.0), 0.0, side * randf_range(0.9, 1.4))
		p.rotation.y = randf_range(-PI, PI)
		_site_props.append(p)

func _process(delta: float) -> void:
	if not building:
		return
	# the same float a marked tree's axe banner has -- held off until MarkFx has
	# finished tweening it up, or we would overwrite its entrance
	if is_instance_valid(_banner):
		_banner_t += delta
		if _banner_t > 0.4:
			_banner.position.y = BANNER_Y + sin((_banner_t - 0.4) * 2.6) * 0.08
	var hands := _crew.hands()
	_show_site_status(hands)
	if hands <= 0:
		return
	_progress += delta * _crew.speed() / BASE_BUILD_TIME
	if _repairing:
		if _progress >= 1.0:
			_finish_repair()
	else:
		_advance_construction()
		if _progress >= 1.0:
			_finish_upgrade() if _upgrading() else _finish()

func _show_site_status(hands: int) -> void:
	var verb := "Repairing" if _repairing else ("Upgrading" if _upgrading() else "Building")
	_prompt.text = "Needs workers" if hands == 0 else "%s  %d%%   x%d" % [verb, int(_progress * 100.0), hands]
	_prompt.visible = true

func _advance_construction() -> void:
	# the gate counts as the final step, so every section is standing (or
	# converted) before progress can reach 1.0
	var steps := _plan.size() + 1
	var want: int = clampi(int(_progress * float(steps)), 0, _plan.size())
	while _raised < want:
		if _upgrading():
			_convert_section(_raised)
		else:
			_raise_section(_plan[_raised])
		_raised += 1

# ---- archer perches (asked by villagers, COMBAT_PROMPTS P4) ----

## Reserve the centre-most free perch for `who`; -1 if the wall isn't built or all
## six are taken. Centre-first falls straight out of PERCH_OFFSETS being ordered
## inward, so the same duck-typed claim every errand uses concentrates fire on the
## gate without a player order (§1).
func claim_perch(who: Node) -> int:
	if level < TWIG:
		return -1
	for i in PERCH_OFFSETS.size():
		if _perch_taken[i] == null or not is_instance_valid(_perch_taken[i]):
			_perch_taken[i] = who
			return i
	return -1

func release_perch(who: Node) -> void:
	for i in _perch_taken.size():
		if _perch_taken[i] == who:
			_perch_taken[i] = null

## True if this wall is built and has at least one free perch -- so an archer can
## pick the nearest such wall before committing a claim.
func perch_available() -> bool:
	if level < TWIG:
		return false
	for t in _perch_taken:
		if t == null or not is_instance_valid(t):
			return true
	return false

## Where an archer stands once up: on the wall top, on the line.
func perch_point(i: int) -> Vector3:
	return to_global(Vector3(PERCH_OFFSETS[i], _perch_height(), 0.0))

## Where it walks to first: the inner (village-side) face on the ground below the
## perch. Computed toward the village centre, so it is right whichever way the
## wall faces.
func foot_point(i: int) -> Vector3:
	var ground := to_global(Vector3(PERCH_OFFSETS[i], 0.0, 0.0))
	var inward := _village_center() - ground
	inward.y = 0.0
	if inward.length() < 0.01:
		inward = global_transform.basis.z
	return ground + inward.normalized() * PERCH_FOOT_IN

func _perch_height() -> float:
	return PERCH_HEIGHTS[clampi(level, 0, PERCH_HEIGHTS.size() - 1)]

func _village_center() -> Vector3:
	var fire := get_tree().get_first_node_in_group("campfire")
	return fire.global_position if is_instance_valid(fire) else Vector3.ZERO

# ---- damage, breach & repair (COMBAT_PROMPTS P6a) ----

func _reset_hp() -> void:
	_arc_hp_max = ARC_HP[level]
	_gate_hp_max = GATE_HP[level]
	_arc_hp = _arc_hp_max
	_gate_hp = _gate_hp_max

## A bandit's blow lands (called by bandit.gd when it's wedged against the run). The
## hit goes to the gate if it struck near the opening, otherwise to the arc. At zero
## either breaches: the collision drops, the navmesh re-bakes, and raiders stream
## through the hole -- the breach is real, not cosmetic.
func take_hit(amount: float, at: Vector3) -> void:
	if level == NONE or building:
		return
	var lx: float = to_local(at).x
	if absf(lx) <= GATE_HALF + 0.6:
		if _gate_breached:
			return
		_gate_hp -= amount
		_hit_fx(at)
		if _gate_hp <= 0.0:
			_breach_gate()
	else:
		if _breached:
			return
		_arc_hp -= amount
		_hit_fx(at)
		_show_arc_damage()
		if _arc_hp <= 0.0:
			_breach_arc()

func _hit_fx(at: Vector3) -> void:
	var hit := at
	hit.y = 0.6
	MarkFx.debris(self, hit, Vector3.UP, 4, DUST, 0.016, 0.8)
	for s in _sections:
		if is_instance_valid(s):
			MarkFx.hit_flash(self, s)
			break

func _breach_gate() -> void:
	_gate_breached = true
	_gate_hp = 0.0
	if is_instance_valid(_gate_col):
		_gate_col.disabled = true
	_blow_off_leaves()
	_gate_sound("slam")           # stand-in breach crash until P8 sources a real one
	_became_damaged()
	NavWorld.rebake(self)

func _breach_arc() -> void:
	_breached = true
	_arc_hp = 0.0
	if is_instance_valid(_left_col):
		_left_col.disabled = true
	if is_instance_valid(_right_col):
		_right_col.disabled = true
	_show_arc_damage()            # ruin whatever's left standing
	_became_damaged()
	NavWorld.rebake(self)

## Ruin sections in step with how far the arc HP has fallen: wood tilts and sinks,
## stone swaps for the kit's ready-made half-wall ruin.
func _show_arc_damage() -> void:
	if _arc_hp_max <= 0.0:
		return
	var frac := 1.0 - clampf(_arc_hp / _arc_hp_max, 0.0, 1.0)
	var want := int(round(frac * float(_sections.size())))
	for i in range(want):
		_damage_section(i)

func _damage_section(i: int) -> void:
	if i < 0 or i >= _sections.size():
		return
	var s: Node3D = _sections[i]
	if not is_instance_valid(s) or s.has_meta("ruined"):
		return
	s.set_meta("ruined", true)
	if _material() == "stone":
		var x: float = s.position.x
		var sc: Vector3 = s.scale
		s.queue_free()
		var ruin := RUIN_SCENE.instantiate()
		add_child(ruin)
		ruin.position = Vector3(x, 0.0, 0.0)
		ruin.scale = sc
		ruin.rotation_degrees = Vector3(0, LEVELS[level]["yaw"], 0)
		_sections[i] = ruin
	else:
		var lean := randf_range(0.4, 0.7) * (1.0 if randf() < 0.5 else -1.0)
		var t := create_tween()
		t.tween_property(s, "rotation:z", lean, 0.3).set_trans(Tween.TRANS_QUAD)
		t.parallel().tween_property(s, "position:y", -0.35, 0.3).set_trans(Tween.TRANS_SINE)

func _blow_off_leaves() -> void:
	for leaf in [_left_model, _right_model]:
		if not is_instance_valid(leaf):
			continue
		var away := Vector3(randf_range(-1.0, 1.0), 1.0, randf_range(0.3, 1.0)).normalized() * 2.0
		var t := create_tween()
		t.tween_property(leaf, "position", leaf.position + away, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(leaf, "rotation:z", randf_range(-2.0, 2.0), 0.35)
		t.parallel().tween_property(leaf, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(leaf.queue_free)
	_left_model = null
	_right_model = null

## Damaged walls become interactable so the monarch can pay to mend them, even a
## fortified one that had nothing left to upgrade.
func _became_damaged() -> void:
	if not is_in_group("interactable"):
		add_to_group("interactable")

func _is_damaged() -> bool:
	return level != NONE and (_breached or _gate_breached \
		or _arc_hp < _arc_hp_max or _gate_hp < _gate_hp_max)

## How much of the side is still standing, 0..1 -- capped so even a near-whole wall
## takes a moment of crew work rather than snapping fixed.
func _standing_fraction() -> float:
	var total := _arc_hp_max + _gate_hp_max
	if total <= 0.0:
		return 0.0
	return clampf((_arc_hp + _gate_hp) / total, 0.0, 0.95)

## Repair costs a percentage of the build price -- the fraction that's missing,
## rounded up (house rules), so one rule covers every material.
func _repair_cost() -> int:
	var total := _arc_hp_max + _gate_hp_max
	if total <= 0.0:
		return 0
	var missing := 1.0 - clampf((_arc_hp + _gate_hp) / total, 0.0, 1.0)
	return maxi(1, int(ceil(float(LEVELS[level]["cost"]) * missing)))

## Repair is construction: the damaged side re-enters the build_site flow at the
## progress it still stands at, and a crew mends it. Paying mid-raid is allowed.
func _open_repair() -> void:
	building = true
	_repairing = true
	remove_from_group("interactable")
	add_to_group("build_site")
	_crew = BuildCrew.new()
	_progress = _standing_fraction()
	_banner = MarkFx.banner(self, HAMMER_MODEL, BANNER_Y, BANNER_SCALE)
	_banner_t = 0.0
	set_process(true)

func _finish_repair() -> void:
	_progress = 1.0
	building = false
	_repairing = false
	set_process(false)
	remove_from_group("build_site")
	_prompt.visible = false
	_crew = BuildCrew.new()
	_clear_site_props()
	_restore()
	NavWorld.rebake(self)
	# a mended wall goes back to offering its next upgrade (unless it's the top rung)
	if level < TOP_LEVEL:
		add_to_group("interactable")
	_gate_sound("close")

func _restore() -> void:
	var was_breached := _breached
	var was_gate := _gate_breached
	_breached = false
	_gate_breached = false
	_reset_hp()
	if is_instance_valid(_left_col):
		_left_col.disabled = false
	if is_instance_valid(_right_col):
		_right_col.disabled = false
	if is_instance_valid(_gate_col):
		_gate_col.disabled = false
	if was_breached or _any_section_ruined():
		_rebuild_sections()
	if was_gate:
		_left_model = _populate_leaf(_left_leaf, 0.5)
		_right_model = _populate_leaf(_right_leaf, -0.5)

func _any_section_ruined() -> bool:
	for s in _sections:
		if is_instance_valid(s) and s.has_meta("ruined"):
			return true
	return false

## Tear down the ruined/tilted sections and stand a fresh, whole run in their place.
func _rebuild_sections() -> void:
	for s in _sections:
		if is_instance_valid(s):
			s.queue_free()
	_sections.clear()
	for x in _section_plan():
		_add_section(x, level)

# ---- the crew (asked by villagers) ----

## Duck-typed alongside building.gd's construction sites -- villagers ask this
## rather than reading a phase flag that means something different on each.
func site_active() -> bool:
	return building

func needs_builders() -> bool:
	return building and _crew.needs_more()

func claim_builder(who: Node3D) -> bool:
	if not needs_builders():
		return false
	return _crew.claim(who)

func release_builder(who: Node3D) -> void:
	if _crew:
		_crew.release(who)

## A claimed worker who has actually reached the line and started swinging.
func builder_ready(who: Node3D) -> void:
	if _crew:
		_crew.arrived(who)

## Where a builder stands: their station along the line, stepped back onto the
## village side of it.
func build_spot(who: Node3D) -> Vector3:
	var i: int = _crew.station(who) % STATIONS.size()
	var inward := Vector3(-global_position.x, 0.0, -global_position.z)
	inward = inward.normalized() if inward.length() > 0.01 else Vector3.FORWARD
	return global_position + _right() * STATIONS[i] + inward * 1.1

# ---- gate sound ----
#
## **A gate should sound like what it is made of.** Right now every wall in the
## game is timber, so there is one entry here; when the stone upgrade (and later
## a castle) gets its own recordings, adding a `"stone"` key beside `"wood"` is
## the entire change -- `_gate_sfx()` already picks by material and falls back to
## wood for any tier that has no set of its own. Nothing else needs touching.
##
## The same idea applies to the main building's ladder (Tent -> Wooden Hall ->
## Stone Hall -> Castle); see `GAME_DESIGN.md`.
const GATE_SFX := {
	"wood": {
		"open": [preload("res://kingdom_demo/assets/audio/gate_open.ogg")],
		"close": [preload("res://kingdom_demo/assets/audio/gate_close.ogg")],
		"slam": [
			preload("res://kingdom_demo/assets/audio/gate_slam_1.ogg"),
			preload("res://kingdom_demo/assets/audio/gate_slam_2.ogg"),
		],
	},
	# "stone": { ... }   <- when the castle-kit gate gets its own recordings
}

## PARKED. The creak on every swing was wrong and is off until we find a better
## one -- the gate opens whenever anyone walks near it, so it fires constantly and
## a mediocre creak grates fast. The slam on completion is unaffected. Clips and
## wiring are still here; flip this back on once there is a creak worth using.
const GATE_SWING_SOUND := false

## Swinging is everyday and happens whenever anyone walks up; the slam happens
## once, when the wall is finished, and is meant to carry across camp.
const GATE_DB := {"open": -9.0, "close": -11.0, "slam": -1.0}
const GATE_REACH := {"open": 26.0, "close": 26.0, "slam": 55.0}
const GATE_PITCH := 1.08

static var _gate_pools := {}

## The material this wall currently is, for the raise and gate sounds. Read off
## the level table so a new rung can never sound like the wrong material -- the
## one flag it used to read only knew wood from stone.
func _material() -> String:
	if level == NONE:
		return "wood"
	return "stone" if LEVELS[level]["stone"] else "wood"

func _gate_sfx(kind: String) -> AudioStreamRandomizer:
	var mat := _material()
	var set_for: Dictionary = GATE_SFX.get(mat, GATE_SFX["wood"])
	if not set_for.has(kind):
		set_for = GATE_SFX["wood"]
	var key := "%s/%s" % [mat, kind]
	if not _gate_pools.has(key):
		var pool := AudioStreamRandomizer.new()
		var clips: Array = set_for[kind]
		for i in range(clips.size()):
			pool.add_stream(i, clips[i])
		pool.random_pitch = GATE_PITCH
		pool.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
		_gate_pools[key] = pool
	return _gate_pools[key]

func _gate_sound(kind: String) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _gate_sfx(kind)
	p.bus = &"SFX"
	p.volume_db = GATE_DB[kind]
	p.unit_size = 14.0
	p.max_distance = GATE_REACH[kind]
	add_child(p)
	p.global_position = global_position + Vector3(0, 1.0, 0)
	p.finished.connect(p.queue_free)
	p.play()

## The point on the wall line nearest `from` -- what a builder faces and swings at.
func face_point(from: Vector3) -> Vector3:
	var d: float = clampf((from - global_position).dot(_right()), -HALF, HALF)
	return global_position + _right() * d

func _right() -> Vector3:
	return global_transform.basis.x.normalized()

## The box that fills the gateway while the gate is shut. [NavWorld] lifts it for
## the bake so the gap stays walkable -- see there for why.
func gate_collision() -> CollisionShape3D:
	return _gate_col

# ---- raising / converting sections ----

## A section heaves up out of the ground and thumps into place, throwing dirt.
func _raise_section(x: float) -> void:
	var s := _add_section(x, _target)
	var at := s.global_position
	at.y = 0.06
	s.position.y = -1.3
	var t := create_tween()
	t.tween_property(s, "position:y", 0.07, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
	MarkFx.debris(self, at, Vector3.UP, 3, DUST, 0.013, 0.35)

## A standing section is swapped for the next material in place -- a slab dropping
## the last little way down and settling, rather than heaving from underground.
func _convert_section(i: int) -> void:
	var old: Node3D = _sections[i]
	var x: float = old.position.x if is_instance_valid(old) else _plan[i]
	if is_instance_valid(old):
		old.queue_free()
	var s := _add_section(x, _target, i)
	var at := s.global_position
	at.y = 0.06
	s.position.y = -0.4
	var t := create_tween()
	t.tween_property(s, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	MarkFx.debris(self, at, Vector3.UP, 3, DUST, 0.013, 0.3)

func _finish() -> void:
	_progress = 1.0
	building = false
	level = _target
	set_process(false)
	remove_from_group("build_site")
	# Higher tiers unlock later, so a finished wall stays interactable -- the
	# prompt asks _next_level() live each time and simply goes quiet at the top.
	add_to_group("interactable")
	_prompt.visible = false
	_marker.visible = false
	_marker_col.disabled = true
	_crew = BuildCrew.new()
	_clear_site_props()
	_build_wall_collision()
	_build_gate()
	_reset_hp()
	# the run is solid now and the only way through is the gate -- villagers find
	# it themselves once the navmesh knows the wall is there
	NavWorld.rebake(self)
	_celebrate()

func _finish_upgrade() -> void:
	_progress = 1.0
	building = false
	level = _target
	set_process(false)
	remove_from_group("build_site")
	# Only the top of the ladder has nothing left to sell.
	if level >= TOP_LEVEL:
		remove_from_group("interactable")
	else:
		add_to_group("interactable")
	_prompt.visible = false
	_crew = BuildCrew.new()
	_clear_site_props()
	# every section is already converted by now -- only the gate leaves are left
	if is_instance_valid(_left_model):
		_left_model.queue_free()
	if is_instance_valid(_right_model):
		_right_model.queue_free()
	_left_model = _populate_leaf(_left_leaf, 0.5)
	_right_model = _populate_leaf(_right_leaf, -0.5)
	_reset_hp()
	_celebrate()

func _clear_site_props() -> void:
	if is_instance_valid(_banner):
		var b := _banner
		var t := create_tween()
		t.tween_property(b, "position:y", BANNER_Y + 0.7, 0.3).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(b, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(b.queue_free)
		_banner = null
	for p in _site_props:      # the material went into the wall
		if not is_instance_valid(p):
			continue
		var t2 := create_tween()
		t2.tween_property(p, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t2.tween_callback(p.queue_free)
	_site_props.clear()

# ---- the pay-off ----

## Everything lands at once: the gate drops into the gap and thumps the camera, a
## wave of dust rolls out along the whole run, the sections settle in a ripple
## spreading from the middle, and the new gate swings wide once before closing
## for good. Pennants only ever go up the first time a side is finished.
func _celebrate() -> void:
	_slam_gate()
	_dust_wave()
	_settle_ripple()
	if not _flagged:
		_flagged = true
		_raise_pennants()

func _slam_gate() -> void:
	_saluting = true
	for pivot in [_left_leaf, _right_leaf]:
		pivot.position.y = 2.4
		var t := create_tween()
		t.tween_interval(0.12)
		t.tween_property(pivot, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var s := create_tween()
	s.tween_interval(0.38)
	s.tween_callback(_gate_landed)
	s.tween_interval(1.1)
	s.tween_callback(func() -> void:
		_saluting = false
		_set_gate_open(_near > 0)
	)

func _gate_landed() -> void:
	var at := global_position
	at.y = 0.06
	MarkFx.debris(self, at, Vector3.UP, 14, DUST, 0.02, 1.6)
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig and rig.has_method("shake"):
		rig.shake(0.3, 0.1)
	# on the same frame as the shake and the dust -- the thump you feel and the
	# thump you hear have to be the same event or the wall never lands properly
	_gate_sound("slam")
	# swing wide in salute, then fall shut
	for pair in [[_left_leaf, -OPEN_ANGLE], [_right_leaf, OPEN_ANGLE]]:
		var leaf: Node3D = pair[0]
		if not is_instance_valid(leaf):
			continue
		var t := create_tween()
		t.tween_property(leaf, "rotation_degrees:y", float(pair[1]), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_interval(0.16)
		t.tween_property(leaf, "rotation_degrees:y", 0.0, 0.42).set_trans(Tween.TRANS_SINE)

func _dust_wave() -> void:
	var right := _right()
	var t := create_tween()
	for i in range(9):
		var off := (float(i) / 8.0) * HALF
		t.tween_callback(func() -> void:
			_puff(global_position + right * off)
			_puff(global_position - right * off)
		)
		t.tween_interval(0.045)

func _puff(at: Vector3) -> void:
	at.y = 0.06
	MarkFx.debris(self, at, Vector3.UP, 4, DUST, 0.018, 0.9)

func _settle_ripple() -> void:
	for s in _sections:
		if not is_instance_valid(s):
			continue
		var base: Vector3 = s.scale
		var t := create_tween()
		t.tween_interval(0.38 + absf(s.position.x) * 0.045)
		t.tween_property(s, "scale", base * Vector3(1.12, 0.86, 1.12), 0.09).set_trans(Tween.TRANS_SINE)
		t.tween_property(s, "scale", base, 0.34).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _raise_pennants() -> void:
	for sgn in [-1.0, 1.0]:
		var f := MarkFx.model(PENNANT_MODEL, PENNANT_SCALE)
		add_child(f)
		MarkFx.tint(f, PENNANT_COLOR)
		f.position = Vector3(sgn * (GATE_HALF + 0.2), 0.0, 0.0)
		f.scale = Vector3.ZERO
		var t := create_tween()
		t.tween_interval(0.55)
		t.tween_property(f, "scale", Vector3.ONE * PENNANT_SCALE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ---- construction ----

func _add_section(x: float, lvl: int, at_index := -1) -> Node3D:
	var d: Dictionary = LEVELS[lvl]
	var s: Node3D = (d["scene"] as PackedScene).instantiate()
	add_child(s)
	var sc: float = d["scale"]
	s.scale = Vector3(sc, sc, sc)
	var yaw: float = d["yaw"]
	if d["stone"]:
		# stone tiles butt together cleanly -- no rough jitter
		s.position = Vector3(x, 0.0, 0.0)
		s.rotation_degrees = Vector3(0, yaw, 0)
	else:
		# a little jitter keeps timber looking hand-built rather than prefab
		s.position = Vector3(x + randf_range(-0.05, 0.05), 0.0, randf_range(-0.06, 0.06))
		s.rotation_degrees = Vector3(0, yaw + randf_range(-4, 4), 0)
	if at_index >= 0:
		_sections[at_index] = s
	else:
		_sections.append(s)
	return s

func _build_wall_collision() -> void:
	var seg := HALF - GATE_HALF
	var cx := (HALF + GATE_HALF) * 0.5
	# kept as refs so a breach can switch them off (P6a)
	_left_col = _add_box_col(-cx, seg)
	_right_col = _add_box_col(cx, seg)

func _add_box_col(cx: float, width: float) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 1.5, 0.5)
	cs.shape = box
	cs.position = Vector3(cx, 0.75, 0)
	add_child(cs)
	return cs

func _build_gate() -> void:
	_left_leaf = _make_pivot(-GATE_HALF)
	_left_model = _populate_leaf(_left_leaf, 0.5)
	_right_leaf = _make_pivot(GATE_HALF)
	_right_model = _populate_leaf(_right_leaf, -0.5)

	_gate_col = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GATE_HALF * 2.0, 1.5, 0.5)
	_gate_col.shape = box
	_gate_col.position = Vector3(0, 0.75, 0)
	add_child(_gate_col)

	var area := Area3D.new()
	var acs := CollisionShape3D.new()
	var abox := BoxShape3D.new()
	abox.size = Vector3(GATE_HALF * 2.0 + 3.0, 2.0, 4.0)
	acs.shape = abox
	acs.position = Vector3(0, 1.0, 0)
	area.add_child(acs)
	add_child(area)
	area.body_entered.connect(_on_gate_body)
	area.body_exited.connect(_on_gate_body_exit)

func _make_pivot(hinge_x: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(hinge_x, 0, 0)
	add_child(pivot)
	return pivot

## Adds the swinging leaf model (fence or castle door) to a hinge pivot. The gate
## follows the wall's material, so the timber rungs get a fence leaf and the two
## stone rungs get a castle door.
func _populate_leaf(pivot: Node3D, dir: float) -> Node3D:
	var s: Node3D
	if level != NONE and LEVELS[level]["stone"]:
		s = DOOR_SCENE.instantiate()
		s.rotation_degrees = Vector3(0, 90, 0)   # face the door across the opening
		s.scale = Vector3(DOOR_SCALE, DOOR_SCALE, DOOR_SCALE)
	else:
		s = FENCE_SCENE.instantiate()
	s.position = Vector3(dir * 0.5, 0.0, 0)   # leaf extends from the hinge toward centre
	pivot.add_child(s)
	return s

# ---- gate open / close ----

func _on_gate_body(body: Node3D) -> void:
	if body.is_in_group("monarch") or body.is_in_group("villager"):
		_near += 1
		if _near == 1:
			_set_gate_open(true)

func _on_gate_body_exit(body: Node3D) -> void:
	if body.is_in_group("monarch") or body.is_in_group("villager"):
		_near = max(0, _near - 1)
		if _near == 0:
			_set_gate_open(false)

func _set_gate_open(open: bool) -> void:
	if _saluting:
		return
	if GATE_SWING_SOUND:
		_gate_sound("open" if open else "close")
	if _gate_col:
		_gate_col.set_deferred("disabled", open)
	if _left_leaf:
		create_tween().tween_property(_left_leaf, "rotation_degrees:y", (-OPEN_ANGLE if open else 0.0), 0.4).set_trans(Tween.TRANS_SINE)
	if _right_leaf:
		create_tween().tween_property(_right_leaf, "rotation_degrees:y", (OPEN_ANGLE if open else 0.0), 0.4).set_trans(Tween.TRANS_SINE)
