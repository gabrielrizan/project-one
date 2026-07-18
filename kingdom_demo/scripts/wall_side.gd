extends StaticBody3D
## One side of the village palisade. It starts as a lone marker post with a
## "build" prompt at the gate spot; paying BUILD_COST gold raises a run of wooden
## fence with a gate in the middle that swings open when the monarch or a villager
## comes near. Once the Town Hall is built (see [GameManager].raise_castle_age),
## the palisade is rebuilt in Kenney castle stone with swinging castle-door gates.

const BUILD_COST := 5
const HALF := 8.0             # wall runs local x  -HALF .. +HALF
const GATE_HALF := 1.0        # sections stop this far from centre -> gate opening
const STAKE_SPACING := 1.0    # one section wide
const OPEN_ANGLE := 85.0
const DOOR_SCALE := 2.8       # castle door.glb is small -> scale up to gate size

const FENCE_SCENE := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/fence.glb")
const WALL_SCENE := preload("res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/wall.glb")
const DOOR_SCENE := preload("res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/door.glb")

@onready var _marker: Node3D = $MarkerSprite
@onready var _marker_col: CollisionShape3D = $MarkerCollision
@onready var _prompt: Label3D = $Prompt

var built := false
var _busy := false
var _near := 0
var _style_castle := false
var _sections: Array[Node3D] = []
var _left_leaf: Node3D = null
var _right_leaf: Node3D = null
var _left_model: Node3D = null
var _right_model: Node3D = null
var _gate_col: CollisionShape3D = null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("wall_side")

# ---- build interaction ----

func show_prompt() -> void:
	if built or _busy:
		return
	_prompt.text = "Hold E  Build Wall (%d)" % BUILD_COST
	_prompt.visible = true

func hide_prompt() -> void:
	_prompt.visible = false

func interact(who: Node3D) -> void:
	if built or _busy:
		return
	if not GoldFx.can_afford(BUILD_COST):
		return
	_busy = true
	hide_prompt()
	var ok: bool = await GoldFx.pay(who, self, BUILD_COST, 2.2)
	_busy = false
	if ok:
		_build()
	elif is_instance_valid(who) and global_position.distance_to(who.global_position) < 3.0:
		show_prompt()

func _build() -> void:
	built = true
	remove_from_group("interactable")
	hide_prompt()
	_marker.visible = false
	_marker_col.disabled = true
	# walls built after the Town Hall go up as stone straight away
	var gm := get_tree().get_first_node_in_group("game_manager")
	_style_castle = gm != null and gm.castle_age
	_build_sections()
	_build_wall_collision()
	_build_gate()

## Swap an already-built wooden palisade over to castle stone in place. Collision
## and the gate hinge/trigger are reused; only the visible pieces are replaced.
func set_castle_age() -> void:
	if not built or _style_castle:
		return
	_style_castle = true
	for s in _sections:
		if is_instance_valid(s):
			s.queue_free()
	_sections.clear()
	_build_sections()
	if is_instance_valid(_left_model):
		_left_model.queue_free()
	if is_instance_valid(_right_model):
		_right_model.queue_free()
	_left_model = _populate_leaf(_left_leaf, 0.5)
	_right_model = _populate_leaf(_right_leaf, -0.5)

# ---- construction ----

func _build_sections() -> void:
	var x := -HALF
	while x <= HALF + 0.01:
		if absf(x) > GATE_HALF:
			_add_section(x)
		x += STAKE_SPACING

func _make_section() -> Node3D:
	return WALL_SCENE.instantiate() if _style_castle else FENCE_SCENE.instantiate()

func _add_section(x: float) -> void:
	var s := _make_section()
	add_child(s)
	if _style_castle:
		# stone tiles butt together cleanly -- no rough jitter
		s.position = Vector3(x, 0.0, 0.0)
	else:
		# a little jitter keeps the fence looking hand-built rather than prefab
		s.position = Vector3(x + randf_range(-0.05, 0.05), 0.0, randf_range(-0.06, 0.06))
		s.rotation_degrees = Vector3(0, randf_range(-4, 4), 0)
	_sections.append(s)

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
	if _gate_col:
		_gate_col.set_deferred("disabled", open)
	if _left_leaf:
		create_tween().tween_property(_left_leaf, "rotation_degrees:y", (-OPEN_ANGLE if open else 0.0), 0.4).set_trans(Tween.TRANS_SINE)
	if _right_leaf:
		create_tween().tween_property(_right_leaf, "rotation_degrees:y", (OPEN_ANGLE if open else 0.0), 0.4).set_trans(Tween.TRANS_SINE)
