extends StaticBody3D
## One side of the village palisade. It starts as a lone marker stick with a
## "build" prompt at the gate spot; paying BUILD_COST gold raises a run of rough,
## crooked wooden stakes along this side with a gate in the middle that swings
## open whenever the monarch or a villager comes near.

const BUILD_COST := 5
const HALF := 8.0             # wall runs local x  -HALF .. +HALF
const GATE_HALF := 1.0        # stakes stop this far from centre -> gate opening
const STAKE_SPACING := 0.55
const OPEN_ANGLE := 85.0

const STAKE_TEX := preload("res://kingdom_demo/assets/pixel/stake.png")
const LEAF_TEX := preload("res://kingdom_demo/assets/pixel/gate_leaf.png")

@onready var _marker: Sprite3D = $MarkerSprite
@onready var _marker_col: CollisionShape3D = $MarkerCollision
@onready var _prompt: Label3D = $Prompt

var built := false
var _busy := false
var _near := 0
var _left_leaf: Node3D = null
var _right_leaf: Node3D = null
var _gate_col: CollisionShape3D = null

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("wall_side")

# ---- build interaction ----

func show_prompt() -> void:
	if built or _busy:
		return
	_prompt.text = "E  Build Wall (%d)" % BUILD_COST
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
	_build_stakes()
	_build_wall_collision()
	_build_gate()

# ---- construction ----

func _build_stakes() -> void:
	var x := -HALF
	while x <= HALF + 0.01:
		if absf(x) > GATE_HALF:
			_add_stake(x)
		x += STAKE_SPACING

func _add_stake(x: float) -> void:
	var s := Sprite3D.new()
	s.texture = STAKE_TEX
	s.pixel_size = 0.05
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var sink := randf() * 0.22
	s.position = Vector3(x + randf_range(-0.06, 0.06), 0.8 - sink, randf_range(-0.06, 0.06))
	# heavy random tilt so the palisade looks rough / not vertically aligned
	s.rotation_degrees = Vector3(randf_range(-4, 4), randf_range(-8, 8), randf_range(-15, 15))
	add_child(s)

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
	_left_leaf = _make_leaf(-GATE_HALF, 0.5)
	_right_leaf = _make_leaf(GATE_HALF, -0.5)

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

func _make_leaf(hinge_x: float, dir: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(hinge_x, 0, 0)
	add_child(pivot)
	var s := Sprite3D.new()
	s.texture = LEAF_TEX
	s.pixel_size = 0.0625
	s.shaded = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.position = Vector3(dir * 0.5, 0.8, 0)   # leaf extends from the hinge toward centre
	pivot.add_child(s)
	return pivot

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
