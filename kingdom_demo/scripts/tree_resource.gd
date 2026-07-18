extends StaticBody3D
## A tree the monarch marks for felling with a daub of paint. Marked trees
## advertise themselves through the "marked_tree" group; exactly one idle worker
## claims a tree, chops it down, and carries the GOLD_YIELD coins back to the king.
##
## The marking visuals are shared with berry bushes -- see [MarkFx].

const MARK_COST := 1
const GOLD_YIELD := 2
const CHOPS_TO_FELL := 6

const COIN_SCENE := preload("res://kingdom_demo/scenes/coin.tscn")
const AXE_TEX := preload("res://kingdom_demo/assets/pixel/axe.png")

const TRUNK_Y := 0.95         # height the axe bites at / the blaze is painted at
const TRUNK_BASE_Y := 0.08    # where the trunk meets the grass -- the topple hinge
const BANNER_Y := 2.95
const FALL_TIME := 0.85

@onready var sprite: Sprite3D = $Sprite
@onready var stump: Sprite3D = $Stump
@onready var prompt: Label3D = $Prompt
@onready var collision: CollisionShape3D = $CollisionShape3D

var marked := false
var felled := false

var _cutter: Node3D = null
var _chops := 0
var _busy := false
var _base_x := 0.0
var _blaze: Sprite3D = null
var _banner: Sprite3D = null
var _banner_t := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("tree")
	_base_x = sprite.position.x
	set_process(false)   # only marked trees need per-frame work

func _process(delta: float) -> void:
	if is_instance_valid(_banner):
		_banner_t += delta
		_banner.position.y = BANNER_Y + sin(_banner_t * 2.6) * 0.08
	if is_instance_valid(_blaze):
		MarkFx.face_camera(_blaze, chop_anchor())

# ---------------------------------------------------------------- marking

func show_prompt() -> void:
	if marked or felled or _busy:
		return
	prompt.text = "Hold E  Mark Tree (%d)" % MARK_COST
	prompt.visible = true

func hide_prompt() -> void:
	prompt.visible = false

func interact(who: Node3D) -> void:
	if marked or felled or _busy:
		return
	if not GoldFx.can_afford(MARK_COST):
		return
	_busy = true
	hide_prompt()
	var ok: bool = await GoldFx.pay(who, self, MARK_COST, BANNER_Y)
	_busy = false
	if ok:
		_mark()
	elif is_instance_valid(who) and global_position.distance_to(who.global_position) < 3.5:
		show_prompt()

func _mark() -> void:
	marked = true
	remove_from_group("interactable")
	add_to_group("marked_tree")
	hide_prompt()
	MarkFx.shake(self, sprite, _base_x, 0.09)
	_blaze = MarkFx.blaze(self, TRUNK_Y, 0.013)
	MarkFx.face_camera(_blaze, chop_anchor())
	_banner = MarkFx.banner(self, AXE_TEX, BANNER_Y, 0.012)
	MarkFx.leaves(self, global_position, 7, 2.3, 1.7, 0.6)
	set_process(true)

# ---------------------------------------------------------------- worker claims

func chop_anchor() -> Vector3:
	return global_position + Vector3(0, TRUNK_Y, 0)

func is_open_for_cutting() -> bool:
	return marked and not felled and not is_instance_valid(_cutter)

func claim_cutter(worker: Node3D) -> bool:
	if not is_open_for_cutting():
		return false
	_cutter = worker
	return true

func release_cutter(worker: Node3D) -> void:
	if _cutter == worker:
		_cutter = null

## One axe swing. Returns true on the blow that brings the tree down.
func take_chop(from: Vector3) -> bool:
	if felled:
		return false
	_chops += 1
	MarkFx.shake(self, sprite, _base_x, 0.06)
	MarkFx.hit_flash(self, sprite)
	var back := from - global_position
	back.y = 0.0
	MarkFx.debris(self, chop_anchor(),
		(back.normalized() if back.length() > 0.01 else Vector3.BACK),
		5, Color(1, 1, 1, 1), 0.01, 1.1)
	if _chops < CHOPS_TO_FELL:
		return false
	_fell(from)
	return true

# ---------------------------------------------------------------- felling

func _fell(from: Vector3) -> void:
	felled = true
	marked = false
	remove_from_group("marked_tree")
	remove_from_group("tree")
	if is_in_group("interactable"):
		remove_from_group("interactable")
	hide_prompt()
	collision.set_deferred("disabled", true)
	set_process(false)
	if is_instance_valid(_blaze):
		_blaze.queue_free()
	if is_instance_valid(_banner):
		_banner.queue_free()
	sprite.visible = false
	stump.visible = true
	_topple(from)

func _topple(from: Vector3) -> void:
	# Swap the Y-billboarded trunk for a free-standing copy pinned to the camera's
	# yaw: once it can't spin to face us any more, it can actually rotate and fall.
	var yaw := 0.0
	var right := Vector3.RIGHT
	var cam := get_viewport().get_camera_3d()
	if cam:
		var cz := cam.global_transform.basis.z
		yaw = atan2(cz.x, cz.z)
		right = cam.global_transform.basis.x

	# ...and it falls away from whoever is swinging the axe
	var to_cutter := from - global_position
	to_cutter.y = 0.0
	var side := signf(right.dot(to_cutter))
	if side == 0.0:
		side = 1.0

	var pivot := Node3D.new()
	add_child(pivot)
	pivot.position = Vector3(0, TRUNK_BASE_Y, 0)
	pivot.rotation.y = yaw

	var faller := MarkFx.sprite(sprite.texture, sprite.pixel_size)
	faller.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	faller.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED   # so it can fade out smoothly
	faller.shaded = true
	pivot.add_child(faller)
	faller.position = Vector3(0, sprite.position.y - TRUNK_BASE_Y, 0)

	var t := create_tween()
	t.tween_property(pivot, "rotation:z", side * 0.10, 0.26).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(pivot, "rotation:z", side * deg_to_rad(87.0), FALL_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void: _trunk_landed(pivot, faller, side, right))

func _trunk_landed(pivot: Node3D, faller: Sprite3D, side: float, right: Vector3) -> void:
	if not is_instance_valid(pivot):
		return
	var dir := -right * side
	dir.y = 0.0
	if dir.length() > 0.01:
		MarkFx.debris(self, global_position + dir.normalized() * 2.0 + Vector3(0, 0.1, 0),
			Vector3.ZERO, 8, Color(0.74, 0.70, 0.60, 0.9), 0.014, 1.1)
	var t := pivot.create_tween()
	t.tween_property(pivot, "rotation:z", side * deg_to_rad(81.0), 0.10).set_trans(Tween.TRANS_SINE)
	t.tween_property(pivot, "rotation:z", side * deg_to_rad(88.0), 0.14).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.5)
	t.tween_property(faller, "modulate:a", 0.0, 0.5)
	t.tween_callback(pivot.queue_free)
	_drop_gold()

func _drop_gold() -> void:
	var coins: Array = []
	for i in range(GOLD_YIELD):
		var coin := COIN_SCENE.instantiate()
		get_tree().current_scene.add_child(coin)
		coin.global_position = global_position + Vector3(0, 0.9, 0)
		var a := randf() * TAU
		var landing := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.7, 1.2)
		landing.y = 0.12
		coin.pop(landing)
		coins.append(coin)
	if is_instance_valid(_cutter) and _cutter.has_method("receive_loot"):
		_cutter.receive_loot(coins)
	_cutter = null
