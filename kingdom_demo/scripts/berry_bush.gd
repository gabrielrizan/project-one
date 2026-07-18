extends StaticBody3D
## A berry bush the monarch marks for foraging. Marked bushes advertise themselves
## through the "marked_bush" group; the single nearest free archer claims one,
## strips it, and carries the gold home. A stripped bush fruits again in time, so
## the woods keep paying out.

const MARK_COST := 1
const GOLD_YIELD := 2
const REGROW_TIME := 45.0     # the archer owns how long picking takes

const COIN_SCENE := preload("res://kingdom_demo/scenes/coin.tscn")
const BASKET_TEX := preload("res://kingdom_demo/assets/pixel/basket.png")
const RIPE_TEX := preload("res://kingdom_demo/assets/pixel/berry_bush.png")
const PICKED_TEX := preload("res://kingdom_demo/assets/pixel/bush_picked.png")

const BLAZE_Y := 0.45
const BANNER_Y := 1.35

@onready var sprite: Sprite3D = $Sprite
@onready var prompt: Label3D = $Prompt

var marked := false
var picked := false

var _picker: Node3D = null
var _busy := false
var _base_x := 0.0
var _blaze: Sprite3D = null
var _banner: Sprite3D = null
var _banner_t := 0.0
var _regrow := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("bush")
	_base_x = sprite.position.x
	set_process(false)

func _process(delta: float) -> void:
	if is_instance_valid(_banner):
		_banner_t += delta
		_banner.position.y = BANNER_Y + sin(_banner_t * 2.6) * 0.07
	if is_instance_valid(_blaze):
		MarkFx.face_camera(_blaze, global_position + Vector3(0, BLAZE_Y, 0))
	if picked:
		_regrow -= delta
		if _regrow <= 0.0:
			_fruit()

# ---------------------------------------------------------------- marking

func show_prompt() -> void:
	if marked or picked or _busy:
		return
	prompt.text = "Hold E  Mark Berries (%d)" % MARK_COST
	prompt.visible = true

func hide_prompt() -> void:
	prompt.visible = false

func interact(who: Node3D) -> void:
	if marked or picked or _busy:
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
	add_to_group("marked_bush")
	hide_prompt()
	MarkFx.shake(self, sprite, _base_x, 0.07)
	_blaze = MarkFx.blaze(self, BLAZE_Y, 0.011)
	MarkFx.face_camera(_blaze, global_position + Vector3(0, BLAZE_Y, 0))
	_banner = MarkFx.banner(self, BASKET_TEX, BANNER_Y, 0.013)
	MarkFx.leaves(self, global_position, 5, 0.9, 0.4, 0.4)
	set_process(true)

# ---------------------------------------------------------------- archer claims

func pick_point() -> Vector3:
	return global_position

func is_open_for_picking() -> bool:
	return marked and not picked and not is_instance_valid(_picker)

func claim_picker(who: Node3D) -> bool:
	if not is_open_for_picking():
		return false
	_picker = who
	return true

func release_picker(who: Node3D) -> void:
	if _picker == who:
		_picker = null

## An archer rummaging through the leaves -- called once per beat while foraging.
func rustle(from: Vector3) -> void:
	if picked:
		return
	MarkFx.shake(self, sprite, _base_x, 0.05)
	var out := global_position - from
	out.y = 0.0
	MarkFx.debris(self, global_position + Vector3(0, BLAZE_Y, 0),
		(out.normalized() if out.length() > 0.01 else Vector3.FORWARD),
		3, Color(0.42, 0.62, 0.28, 1.0), 0.009, 0.6)

## Stripped bare. Drops its gold and hands it to whoever picked it.
func strip() -> void:
	if picked:
		return
	picked = true
	marked = false
	remove_from_group("marked_bush")
	hide_prompt()
	_clear_marks()
	sprite.texture = PICKED_TEX
	_regrow = REGROW_TIME
	set_process(true)

	var t := create_tween()
	t.tween_property(sprite, "scale", Vector3(1.15, 0.85, 1.0), 0.1)
	t.tween_property(sprite, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	MarkFx.leaves(self, global_position, 6, 0.9, 0.35, 0.45)
	_drop_gold()

func _clear_marks() -> void:
	if is_instance_valid(_blaze):
		_blaze.queue_free()
	if is_instance_valid(_banner):
		_banner.queue_free()

func _drop_gold() -> void:
	var coins: Array = []
	for i in range(GOLD_YIELD):
		var coin := COIN_SCENE.instantiate()
		get_tree().current_scene.add_child(coin)
		coin.global_position = global_position + Vector3(0, 0.5, 0)
		var a := randf() * TAU
		var landing := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 0.9)
		landing.y = 0.12
		coin.pop(landing)
		coins.append(coin)
	if is_instance_valid(_picker) and _picker.has_method("receive_loot"):
		_picker.receive_loot(coins)
	_picker = null

# ---------------------------------------------------------------- regrowth

func _fruit() -> void:
	picked = false
	sprite.texture = RIPE_TEX
	add_to_group("interactable")
	set_process(false)
	sprite.scale = Vector3(0.7, 0.7, 1.0)
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
