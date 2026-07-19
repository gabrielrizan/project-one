extends StaticBody3D
## One side of the village palisade. It starts as a lone marker post with a
## "build" prompt at the gate spot.
##
## Paying BUILD_COST does not raise the wall -- the monarch does not build, he
## commissions. It opens a BUILDING SITE: timber is dropped along the line, a
## hammer banner goes up, and workers down tools and walk over. Sections rise
## one at a time under their hammers, corners first, closing in on the gap; the
## gate drops into it last. See [BuildCrew] for the pace: up to three workers,
## each beyond the first adding 30% more speed.
##
## Once built, a second and separate upgrade is on offer: paying STONE_COST
## opens the same kind of site again, this time converting the standing wood
## sections to Kenney castle stone in place and re-skinning the gate leaves as
## castle doors. It is only on the table once the L3 Stone Hall has
## gone up ([GameManager].stone_unlocked) -- a wall built before or after that
## point is wood until someone pays to upgrade it; nothing converts for free.

const BUILD_COST := 5
const STONE_COST := 8
const HALF := 8.0             # wall runs local x  -HALF .. +HALF
const GATE_HALF := 1.0        # sections stop this far from centre -> gate opening
const STAKE_SPACING := 1.0    # one section wide
const OPEN_ANGLE := 85.0
const DOOR_SCALE := 2.8       # castle door.glb is small -> scale up to gate size
const BASE_BUILD_TIME := 30.0 # for either phase, at a single pair of hands

const FENCE_SCENE := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/fence.glb")
const WALL_SCENE := preload("res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/wall.glb")
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

@onready var _marker: Node3D = $MarkerSprite
@onready var _marker_col: CollisionShape3D = $MarkerCollision
@onready var _prompt: Label3D = $Prompt

var built := false
var building := false         # a site is open, waiting on or worked by hands
var _stone_upgrading := false # which phase `building` is: wood raise or stone upgrade
var _busy := false
var _near := 0
var _saluting := false        # the gate is mid-flourish; leave it alone
var _flagged := false         # pennants only ever go up once
var _style_castle := false
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

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("wall_side")
	set_process(false)

# ---- build interaction ----

func show_prompt() -> void:
	if building or _busy:
		return
	if not built:
		_prompt.text = ("Hold E  Build Wall (%d)" % BUILD_COST) if _workers_exist() else "Build Wall  needs a worker"
		_prompt.visible = true
		return
	if not _style_castle and _stone_unlocked():
		_prompt.text = ("Hold E  Upgrade to Stone (%d)" % STONE_COST) if _workers_exist() else "Upgrade to Stone  needs a worker"
		_prompt.visible = true
		return
	hide_prompt()

func hide_prompt() -> void:
	_prompt.visible = false

func interact(who: Node3D) -> void:
	if building or _busy:
		return
	if not built:
		if not _workers_exist() or not GoldFx.can_afford(BUILD_COST):
			return
		_busy = true
		hide_prompt()
		var ok: bool = await GoldFx.pay(who, self, BUILD_COST, 2.2)
		_busy = false
		if ok:
			_open_site()
		elif _near_enough(who):
			show_prompt()
		return
	if not _style_castle and _stone_unlocked():
		if not _workers_exist() or not GoldFx.can_afford(STONE_COST):
			return
		_busy = true
		hide_prompt()
		var ok: bool = await GoldFx.pay(who, self, STONE_COST, 2.2)
		_busy = false
		if ok:
			_open_stone_upgrade()
		elif _near_enough(who):
			show_prompt()

func _near_enough(who: Node3D) -> bool:
	return is_instance_valid(who) and global_position.distance_to(who.global_position) < 3.0

func _workers_exist() -> bool:
	for v in get_tree().get_nodes_in_group("villager"):
		if v.has_method("is_worker") and v.is_worker():
			return true
	return false

func _stone_unlocked() -> bool:
	var gm := get_tree().get_first_node_in_group("game_manager")
	return gm != null and gm.stone_unlocked

# ---- the building site ----

func _open_site() -> void:
	building = true
	_stone_upgrading = false
	remove_from_group("interactable")
	add_to_group("build_site")
	_crew = BuildCrew.new()
	_raised = 0
	_progress = 0.0
	_plan = _section_plan()
	_banner = MarkFx.banner(self, HAMMER_MODEL, BANNER_Y, BANNER_SCALE)
	_banner_t = 0.0
	_lay_out_site_props(TIMBER_MODEL)
	set_process(true)

func _open_stone_upgrade() -> void:
	building = true
	_stone_upgrading = true
	remove_from_group("interactable")
	add_to_group("build_site")
	_crew = BuildCrew.new()
	_raised = 0
	_progress = 0.0
	_plan = _section_plan()   # same offsets -- stepping through the sections already standing
	_banner = MarkFx.banner(self, HAMMER_MODEL, BANNER_Y, BANNER_SCALE)
	_banner_t = 0.0
	_lay_out_site_props(STONE_PILE_MODEL)
	set_process(true)

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
	_advance_construction()
	if _progress >= 1.0:
		_finish_stone() if _stone_upgrading else _finish()

func _show_site_status(hands: int) -> void:
	var verb := "Upgrading" if _stone_upgrading else "Building"
	_prompt.text = "Needs workers" if hands == 0 else "%s  %d%%   x%d" % [verb, int(_progress * 100.0), hands]
	_prompt.visible = true

func _advance_construction() -> void:
	# the gate counts as the final step, so every section is standing (or
	# converted) before progress can reach 1.0
	var steps := _plan.size() + 1
	var want: int = clampi(int(_progress * float(steps)), 0, _plan.size())
	while _raised < want:
		if _stone_upgrading:
			_convert_section(_raised)
		else:
			_raise_section(_plan[_raised])
		_raised += 1

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

## The point on the wall line nearest `from` -- what a builder faces and swings at.
func face_point(from: Vector3) -> Vector3:
	var d: float = clampf((from - global_position).dot(_right()), -HALF, HALF)
	return global_position + _right() * d

func _right() -> Vector3:
	return global_transform.basis.x.normalized()

# ---- raising / converting sections ----

## A section heaves up out of the ground and thumps into place, throwing dirt.
func _raise_section(x: float) -> void:
	var s := _add_section(x, false)
	var at := s.global_position
	at.y = 0.06
	s.position.y = -1.3
	var t := create_tween()
	t.tween_property(s, "position:y", 0.07, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
	MarkFx.debris(self, at, Vector3.UP, 3, DUST, 0.013, 0.35)

## A standing wood section is swapped for stone in place -- a slab dropping the
## last little way down and settling, rather than heaving from underground.
func _convert_section(i: int) -> void:
	var old: Node3D = _sections[i]
	var x: float = old.position.x if is_instance_valid(old) else _plan[i]
	if is_instance_valid(old):
		old.queue_free()
	var s := _add_section(x, true, i)
	var at := s.global_position
	at.y = 0.06
	s.position.y = -0.4
	var t := create_tween()
	t.tween_property(s, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	MarkFx.debris(self, at, Vector3.UP, 3, DUST, 0.013, 0.3)

func _finish() -> void:
	_progress = 1.0
	building = false
	built = true
	set_process(false)
	remove_from_group("build_site")
	# stone may unlock later, so a finished wood wall stays interactable -- the
	# stone-upgrade prompt just checks _stone_unlocked() live each time
	add_to_group("interactable")
	_prompt.visible = false
	_marker.visible = false
	_marker_col.disabled = true
	_crew = BuildCrew.new()
	_clear_site_props()
	_build_wall_collision()
	_build_gate()
	_celebrate()

func _finish_stone() -> void:
	_progress = 1.0
	building = false
	_style_castle = true
	set_process(false)
	remove_from_group("build_site")
	remove_from_group("interactable")   # fully upgraded -- nothing left to offer
	_prompt.visible = false
	_crew = BuildCrew.new()
	_clear_site_props()
	# every section is already stone by now -- only the gate leaves are left
	if is_instance_valid(_left_model):
		_left_model.queue_free()
	if is_instance_valid(_right_model):
		_right_model.queue_free()
	_left_model = _populate_leaf(_left_leaf, 0.5)
	_right_model = _populate_leaf(_right_leaf, -0.5)
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

func _add_section(x: float, stone: bool, at_index := -1) -> Node3D:
	var s: Node3D = WALL_SCENE.instantiate() if stone else FENCE_SCENE.instantiate()
	add_child(s)
	if stone:
		# stone tiles butt together cleanly -- no rough jitter
		s.position = Vector3(x, 0.0, 0.0)
	else:
		# a little jitter keeps the fence looking hand-built rather than prefab
		s.position = Vector3(x + randf_range(-0.05, 0.05), 0.0, randf_range(-0.06, 0.06))
		s.rotation_degrees = Vector3(0, randf_range(-4, 4), 0)
	if at_index >= 0:
		_sections[at_index] = s
	else:
		_sections.append(s)
	return s

func _build_wall_collision() -> void:
	var seg := HALF - GATE_HALF
	var cx := (HALF + GATE_HALF) * 0.5
	_add_box_col(-cx, seg)
	_add_box_col(cx, seg)

func _add_box_col(cx: float, width: float) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 1.5, 0.5)
	cs.shape = box
	cs.position = Vector3(cx, 0.75, 0)
	add_child(cs)

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

## Adds the swinging leaf model (fence or castle door) to a hinge pivot.
func _populate_leaf(pivot: Node3D, dir: float) -> Node3D:
	var s: Node3D
	if _style_castle:
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
	if _gate_col:
		_gate_col.set_deferred("disabled", open)
	if _left_leaf:
		create_tween().tween_property(_left_leaf, "rotation_degrees:y", (-OPEN_ANGLE if open else 0.0), 0.4).set_trans(Tween.TRANS_SINE)
	if _right_leaf:
		create_tween().tween_property(_right_leaf, "rotation_degrees:y", (OPEN_ANGLE if open else 0.0), 0.4).set_trans(Tween.TRANS_SINE)
