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

const COIN_MODEL := preload("res://kingdom_demo/assets/3d/props/coin.glb")
const COIN_SCENE := preload("res://kingdom_demo/scenes/coin.tscn")
const HOLD_ACTION := "interact"
const PIP_SPACING := 0.55
const PIP_ROW_SPACING := 0.53
const PIPS_PER_ROW := 8      # bigger asks stack into rows instead of one long line
const PIP_UNPAID := Color(0.24, 0.23, 0.26)   # a coin not yet handed over
const PIP_SCALE := 0.69
const FLYING_SCALE := 0.94
const COIN_FLIGHT := 0.34
const COIN_GAP := 0.1
const MAX_RANGE := 4.0       # step further than this from the anchor and the deal is off

## Coins landing in cloth, not ringing on marble. Bright metallic pings read as
## arcade -- this is a medieval purse, so the take is muted and low.
const COIN_CLIPS := [
	preload("res://kingdom_demo/assets/audio/coin_1.ogg"),
	preload("res://kingdom_demo/assets/audio/coin_2.ogg"),
	preload("res://kingdom_demo/assets/audio/coin_3.ogg"),
	preload("res://kingdom_demo/assets/audio/coin_4.ogg"),
	preload("res://kingdom_demo/assets/audio/coin_5.ogg"),
]

## The tally climbs as it fills: the first coin lands low and each one after sits
## a little higher, so a long purchase builds instead of rattling along flat. Kept
## narrow on purpose -- a wide sweep is the Mario coin run, which is exactly the
## wrong register for this.
const COIN_PITCH_START := 0.80
const COIN_PITCH_END := 1.22
## Loudness climbs with the pitch. Pitch alone reads as "going up"; pitch *and*
## level together read as building towards something, which is what a tally
## counting out the monarch's gold should feel like.
const COIN_DB_START := -7.0
const COIN_DB_END := 0.0
## Only a little per-coin jitter, or it smears the climb it is sitting on.
const COIN_PITCH_JITTER := 1.05
const COIN_VOL_JITTER := 2.0
## Clinks ring out over each other rather than each one cutting the last -- a coin
## lands every ~0.44s but the clips are longer than that.
const COIN_POLYPHONY := 5

var _paying := false
var _target: Node3D = null
var _payer: Node3D = null
## Positional, and moved to whatever is being bought -- the clink comes from the
## tally over the thing, not from inside the player's head.
var _clink: AudioStreamPlayer3D = null

func _ready() -> void:
	var pool := AudioStreamRandomizer.new()
	for i in range(COIN_CLIPS.size()):
		pool.add_stream(i, COIN_CLIPS[i])
	pool.random_pitch = COIN_PITCH_JITTER
	pool.random_volume_offset_db = COIN_VOL_JITTER
	pool.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	_clink = AudioStreamPlayer3D.new()
	_clink.stream = pool
	_clink.bus = &"SFX"
	_clink.unit_size = 4.0
	_clink.max_distance = 24.0
	_clink.max_polyphony = COIN_POLYPHONY
	add_child(_clink)

func can_afford(cost: int) -> bool:
	var gm = _gm()
	return gm != null and gm.coins >= cost

## True while a tally is up. The monarch reads this to stay locked on target.
func is_paying() -> bool:
	return _paying

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
		_fill_pip(pips[paid], paid, cost)
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
		var p: Node3D = pips[i]
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
			var p := MarkFx.model(COIN_MODEL, PIP_SCALE)
			MarkFx.tint(p, PIP_UNPAID)
			get_tree().current_scene.add_child(p)
			p.global_position = base + Vector3(start_x + c * PIP_SPACING, r * PIP_ROW_SPACING, 0)
			pips.append(p)
	return pips

## `filled` is how many pips were already gold, so the first coin of a purchase
## arrives with filled = 0 and the last with filled = cost - 1.
func _fill_pip(p: Node3D, filled := 0, cost := 1) -> void:
	if not is_instance_valid(p):
		return
	# the coin has just landed in the pip -- clink it from where the tally is,
	# a step higher than the one before so the tally climbs as it fills
	if is_instance_valid(_clink):
		# ease the climb rather than running it linearly -- a straight ramp reads
		# as mechanical, where easing in leaves the excitement to the last few
		# a 1-gold buy has no climb to make, so it takes the middle of the range --
		# marking a tree is the commonest purchase in the game and would grate if
		# it always fired the brightest, loudest note in the ramp
		var t := 0.5 if cost <= 1 else float(filled) / float(cost - 1)
		var e := ease(clampf(t, 0.0, 1.0), 1.6)
		_clink.pitch_scale = lerpf(COIN_PITCH_START, COIN_PITCH_END, e)
		_clink.volume_db = lerpf(COIN_DB_START, COIN_DB_END, e)
		_clink.global_position = p.global_position
		_clink.play()
	MarkFx.untint(p)      # back to gold: this one's been paid
	var t := create_tween()
	t.tween_property(p, "scale", Vector3.ONE * PIP_SCALE * 1.5, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(p, "scale", Vector3.ONE * PIP_SCALE, 0.1)

func _fly_coin(payer: Node3D, anchor: Node3D, tally_y: float) -> bool:
	var coin := MarkFx.model(COIN_MODEL, FLYING_SCALE)
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
