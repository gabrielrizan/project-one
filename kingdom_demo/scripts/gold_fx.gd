extends Node
## Autoload. Reusable "spend gold" animation: shows <cost> coin slots above an
## anchor and flies one coin at a time in from the payer, spending 1 gold and
## filling a slot per coin. `await GoldFx.pay(...)` returns true once fully paid,
## or false immediately if the player can't afford it.

const COIN_TEX := preload("res://kingdom_demo/assets/pixel/coin.png")
const SLOT_SPACING := 0.34
const SLOT_EMPTY := Color(0.15, 0.15, 0.18, 0.65)
const COIN_FLIGHT := 0.34
const COIN_GAP := 0.1

func can_afford(cost: int) -> bool:
	var gm = _gm()
	return gm != null and gm.coins >= cost

func pay(payer: Node3D, anchor: Node3D, cost: int, slot_y := 1.9) -> bool:
	var gm = _gm()
	if gm == null or gm.coins < cost:
		return false
	var slots := _spawn_slots(anchor, cost, slot_y)
	for i in range(cost):
		await _fly_coin(payer, anchor, slot_y)
		gm.spend_coins(1)
		_fill_slot(slots[i])
		await get_tree().create_timer(COIN_GAP).timeout
	await get_tree().create_timer(0.18).timeout
	for s in slots:
		if is_instance_valid(s):
			s.queue_free()
	return true

func _gm() -> Node:
	return get_tree().get_first_node_in_group("game_manager")

func _spawn_slots(anchor: Node3D, n: int, slot_y: float) -> Array:
	var arr: Array = []
	# world-space so the row always reads horizontally, regardless of how the
	# anchor (e.g. a rotated wall side) is oriented
	var base := anchor.global_position + Vector3(0, slot_y, 0)
	var start_x := -SLOT_SPACING * (n - 1) * 0.5
	for i in range(n):
		var s := _coin_sprite(0.006)
		s.modulate = SLOT_EMPTY
		get_tree().current_scene.add_child(s)
		s.global_position = base + Vector3(start_x + i * SLOT_SPACING, 0, 0)
		arr.append(s)
	return arr

func _fill_slot(s: Sprite3D) -> void:
	if not is_instance_valid(s):
		return
	s.modulate = Color(1, 1, 1, 1)
	var t := create_tween()
	t.tween_property(s, "scale", Vector3(1.5, 1.5, 1.5), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(s, "scale", Vector3.ONE, 0.1)

func _fly_coin(payer: Node3D, anchor: Node3D, slot_y: float) -> void:
	var coin := _coin_sprite(0.009)
	get_tree().current_scene.add_child(coin)
	var start: Vector3 = payer.global_position + Vector3(0, 1.0, 0)
	var target: Vector3 = anchor.global_position + Vector3(0, slot_y * 0.7, 0)
	var peak := start.lerp(target, 0.5) + Vector3(0, 0.7, 0)
	coin.global_position = start
	var t := create_tween()
	t.tween_method(
		func(p: float) -> void:
			coin.global_position = start.lerp(peak, p).lerp(peak.lerp(target, p), p),
		0.0, 1.0, COIN_FLIGHT
	).set_trans(Tween.TRANS_SINE)
	await t.finished
	coin.queue_free()

func _coin_sprite(px: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = COIN_TEX
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.no_depth_test = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	return s
