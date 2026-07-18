extends Node
## Autoload. The shared "count out gold" interaction.
##
## Walking up to something buyable and holding the interact key raises a TALLY
## above it -- a row of coin PIPS, one per gold it costs -- and flies coins in
## from the payer one at a time, filling a pip each. Let go before the tally is
## full and the deal is off: the gold already handed over spills onto the grass
## as loose, re-collectable coins.
##
## Only one payment can run at a time, so there is never more than one tally on
## screen; the monarch stays locked on its target until it resolves.
## `await GoldFx.pay(...)` returns true only once fully paid.

const COIN_TEX := preload("res://kingdom_demo/assets/pixel/coin.png")
const COIN_SCENE := preload("res://kingdom_demo/scenes/coin.tscn")
const HOLD_ACTION := "interact"
const PIP_SPACING := 0.44
const PIP_ROW_SPACING := 0.42
const PIPS_PER_ROW := 8      # bigger asks stack into rows instead of one long line
const PIP_UNPAID := Color(0.24, 0.23, 0.26, 1.0)
const COIN_FLIGHT := 0.34
const COIN_GAP := 0.1
const MAX_RANGE := 4.0       # step further than this from the anchor and the deal is off

var _paying := false
var _target: Node3D = null
var _payer: Node3D = null

func can_afford(cost: int) -> bool:
	var gm = _gm()
	return gm != null and gm.coins >= cost

## True while a tally is up. The monarch reads this to stay locked on target.
func is_paying() -> bool:
	return _paying

## What is currently being paid for, if anything.
func target() -> Node3D:
	return _target

func pay(payer: Node3D, anchor: Node3D, cost: int, tally_y := 1.9) -> bool:
	var gm = _gm()
	if _paying or gm == null or gm.coins < cost:
		return false
	_paying = true
	_target = anchor
	_payer = payer

	var pips := _spawn_tally(anchor, cost, tally_y)
	var paid := 0
	while paid < cost:
		if not await _fly_coin(payer, anchor, tally_y):
			break
		gm.spend_coins(1)
		_fill_pip(pips[paid])
		paid += 1
		if paid < cost and not await _hold_for(COIN_GAP):
			break

	var ok := paid == cost
	if ok:
		await get_tree().create_timer(0.18).timeout
	else:
		_spill(pips, paid, anchor)
	for p in pips:
		if is_instance_valid(p):
			p.queue_free()

	_paying = false
	_target = null
	_payer = null
	return ok

func _gm() -> Node:
	return get_tree().get_first_node_in_group("game_manager")

# ---------------------------------------------------------------- holding

## Waits `seconds`, bailing out the moment the payer stops committing to the deal
## -- either the interact key comes up or they wander off. Returns false if so.
func _hold_for(seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if not _committed():
			return false
		await get_tree().process_frame
		left -= get_process_delta_time()
	return true

func _committed() -> bool:
	if not Input.is_action_pressed(HOLD_ACTION):
		return false
	if not is_instance_valid(_payer) or not is_instance_valid(_target):
		return false
	return _payer.global_position.distance_to(_target.global_position) <= MAX_RANGE

## Gold already handed over when the player let go: it hits the dirt in front of
## the anchor as loose coins rather than quietly vanishing.
func _spill(pips: Array, paid: int, anchor: Node3D) -> void:
	for i in range(paid):
		var p: Sprite3D = pips[i]
		if not is_instance_valid(p):
			continue
		var coin := COIN_SCENE.instantiate()
		get_tree().current_scene.add_child(coin)
		coin.global_position = p.global_position
		var a := randf() * TAU
		var landing := anchor.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.9, 1.5)
		landing.y = 0.12
		coin.pop(landing)

# ---------------------------------------------------------------- tally

func _spawn_tally(anchor: Node3D, n: int, tally_y: float) -> Array:
	var pips: Array = []
	# world-space so the rows always read horizontally, regardless of how the
	# anchor (e.g. a rotated wall side) is oriented. Rows fill bottom-up, so a
	# 15-coin ask reads as a stack filling rather than a banner across the screen.
	var base := anchor.global_position + Vector3(0, tally_y, 0)
	var rows := int(ceil(float(n) / float(PIPS_PER_ROW)))
	for r in range(rows):
		var count: int = mini(PIPS_PER_ROW, n - r * PIPS_PER_ROW)
		var start_x := -PIP_SPACING * (count - 1) * 0.5
		for c in range(count):
			var p := _coin_sprite(0.011)
			p.modulate = PIP_UNPAID
			get_tree().current_scene.add_child(p)
			p.global_position = base + Vector3(start_x + c * PIP_SPACING, r * PIP_ROW_SPACING, 0)
			pips.append(p)
	return pips

func _fill_pip(p: Sprite3D) -> void:
	if not is_instance_valid(p):
		return
	p.modulate = Color(1, 1, 1, 1)
	var t := create_tween()
	t.tween_property(p, "scale", Vector3(1.5, 1.5, 1.5), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(p, "scale", Vector3.ONE, 0.1)

func _fly_coin(payer: Node3D, anchor: Node3D, tally_y: float) -> bool:
	var coin := _coin_sprite(0.014)
	get_tree().current_scene.add_child(coin)
	var start: Vector3 = payer.global_position + Vector3(0, 1.0, 0)
	var target_pos: Vector3 = anchor.global_position + Vector3(0, tally_y * 0.7, 0)
	var peak := start.lerp(target_pos, 0.5) + Vector3(0, 0.7, 0)
	coin.global_position = start
	var t := create_tween()
	t.tween_method(
		func(p: float) -> void:
			coin.global_position = start.lerp(peak, p).lerp(peak.lerp(target_pos, p), p),
		0.0, 1.0, COIN_FLIGHT
	).set_trans(Tween.TRANS_SINE)
	var held := await _hold_for(COIN_FLIGHT)
	if not held and t.is_valid():
		t.kill()
	coin.queue_free()
	return held

func _coin_sprite(px: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = COIN_TEX
	s.pixel_size = px
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.no_depth_test = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	return s
