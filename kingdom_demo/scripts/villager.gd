extends CharacterBody3D
## A villager drawn in by a full cauldron. It walks to the cauldron, eats, becomes
## a loyal citizen (blue tint), then walks to the nearest building with an open job
## and takes it -- swapping into a builder or archer outfit.
##
## Once employed they run errands between shifts:
##   workers  -- claim a tree the monarch marked, fell it, haul the gold back and
##               dump it at his feet.
##   archers  -- by daylight, strip a marked berry bush or hunt the rabbits and
##               stags roaming the woods, then kneel and present the take.

enum State {
	SEEK_FOOD, EAT, LOYAL, GO_WORK, WORK,
	GO_CHOP, CHOP, LOOT_WAIT, GATHER, DELIVER,
	GO_HUNT, SHOOT, GO_FORAGE, FORAGE, PRESENT,
}

const SPEED := 3.2
const ACCEL := 40.0
const ARRIVE := 1.8
const WORK_ARRIVE := 0.7
const EAT_TIME := 2.5
const WALL_HALF := 8.0     # matches the palisade square

const CHOP_REACH := 1.15   # where a worker plants their feet to swing
const SWING_TIME := 0.46
const GATHER_REACH := 0.55
const DELIVER_REACH := 1.7
const ERRAND_SCAN := 1.0   # how often an idle villager looks for something to do
const LOOT_TIMEOUT := 5.0
const CARRY_SPACING := 0.24
const CARRY_Y := 1.32

const BOW_RANGE := 4.2     # archers loose from beyond the animals' spook range
const AIM_TIME := 0.55
const FORAGE_REACH := 1.0
const PICK_TIME := 2.6
const PICK_BEAT := 0.55
const PRESENT_REACH := 1.6

const VILLAGER_TEX := preload("res://kingdom_demo/assets/pixel/villager.png")
const BUILDER_TEX := preload("res://kingdom_demo/assets/pixel/builder.png")
const ARCHER_TEX := preload("res://kingdom_demo/assets/pixel/archer.png")
const AXE_TEX := preload("res://kingdom_demo/assets/pixel/axe.png")
const ARROW_TEX := preload("res://kingdom_demo/assets/pixel/bow.png")   # art is an arrow
const COIN_TEX := preload("res://kingdom_demo/assets/pixel/coin.png")
const COIN_SCENE := preload("res://kingdom_demo/scenes/coin.tscn")
const LOYAL_TINT := Color(0.55, 0.75, 1.0)

@onready var sprite: Sprite3D = $Sprite

var target := Vector3.ZERO          # cauldron position, set by spawner

var _state: int = State.SEEK_FOOD
var _workplace: Node3D = null
var _eat_t := 0.0
var _recheck_t := 0.0
var _mill := Vector3.ZERO
var _mill_t := 0.0
var _bob := 0.0
var _base_y := 0.0
var _route_gate := Vector3.ZERO
var _has_gate := false

var _tree: Node3D = null
var _quarry: Node3D = null
var _bush: Node3D = null
var _chop_spot := Vector3.ZERO
var _wait_spot := Vector3.ZERO
var _axe: Sprite3D = null
var _swing_t := 0.0
var _aim_t := 0.0
var _pick_t := 0.0
var _beat_t := 0.0
var _facing := 1.0
var _scan_t := 0.0
var _wait_t := 0.0
var _loot: Array = []               # coins our kill/tree/bush dropped, not gathered yet
var _purse: Array = []              # coin sprites bobbing over our head

func _ready() -> void:
	add_to_group("villager")
	_base_y = sprite.position.y
	_mill = target

func _physics_process(delta: float) -> void:
	match _state:
		State.SEEK_FOOD:
			var g := _route(target)
			_seek(delta, g, (ARRIVE if g == target else 0.4))
			if global_position.distance_to(target) < ARRIVE:
				_state = State.EAT
				_eat_t = EAT_TIME
		State.EAT:
			_mill_near(delta, target, 1.6)
			_eat_t -= delta
			if _eat_t <= 0.0:
				_become_loyal()
		State.LOYAL:
			_mill_near(delta, target, 2.2)
			_recheck_t -= delta
			if _recheck_t <= 0.0:
				_recheck_t = 1.2
				_try_take_job()
		State.GO_WORK:
			if not is_instance_valid(_workplace):
				_become_loyal()
			else:
				var wp: Vector3 = _workplace.work_point()
				var g := _route(wp)
				_seek(delta, g, (WORK_ARRIVE if g == wp else 0.4))
				if global_position.distance_to(wp) < WORK_ARRIVE:
					_start_working()
		State.WORK:
			_mill_near(delta, _work_anchor(), 1.6)
			_scan_t -= delta
			if _scan_t <= 0.0:
				_scan_t = ERRAND_SCAN
				_look_for_errand()
		State.GO_CHOP:
			_walk_to_tree(delta)
		State.CHOP:
			_chop(delta)
		State.GO_HUNT:
			_stalk(delta)
		State.SHOOT:
			_take_aim(delta)
		State.GO_FORAGE:
			_walk_to_bush(delta)
		State.FORAGE:
			_forage(delta)
		State.LOOT_WAIT:
			_seek(delta, _wait_spot, 0.25)
			_wait_t -= delta
			if _wait_t <= 0.0:
				_end_errand()
		State.GATHER:
			_gather(delta)
		State.DELIVER:
			_deliver(delta)
		State.PRESENT:
			_present(delta)

# ---- transitions ----

func _become_loyal() -> void:
	_state = State.LOYAL
	_recheck_t = 0.0
	sprite.texture = VILLAGER_TEX
	sprite.modulate = LOYAL_TINT

func _try_take_job() -> void:
	var best: Node3D = null
	var best_d := INF
	for b in get_tree().get_nodes_in_group("workplace"):
		if b.has_method("has_open_job") and b.has_open_job():
			var d := global_position.distance_to(b.global_position)
			if d < best_d:
				best_d = d
				best = b
	if best and best.claim_job():
		_workplace = best
		_state = State.GO_WORK

func _start_working() -> void:
	_state = State.WORK
	sprite.modulate = Color(1, 1, 1)
	sprite.texture = ARCHER_TEX if _workplace.job_type == "archer" else BUILDER_TEX

func _work_anchor() -> Vector3:
	return _workplace.work_point() if is_instance_valid(_workplace) else global_position

# ---- picking up an errand ----

func _job_is(kind: String) -> bool:
	return is_instance_valid(_workplace) and _workplace.job_type == kind

## An archer standing about with no errand -- available for a bush or a hunt.
func is_free_archer() -> bool:
	return _state == State.WORK and _job_is("archer")

func _is_night() -> bool:
	var cycle = get_tree().get_first_node_in_group("day_night_cycle")
	return cycle != null and cycle.is_night()

func _look_for_errand() -> void:
	if _job_is("worker"):
		_claim_marked_tree()
	elif _job_is("archer") and not _is_night():
		# the monarch's marked bushes come first, then whatever is grazing
		if not _claim_marked_bush():
			_claim_quarry()

## Whichever free archer stands closest gets the bush, so two never set off for
## the same one.
func _nearest_free_archer_to(node: Node3D) -> Node3D:
	var best: Node3D = null
	var bd := INF
	for v in get_tree().get_nodes_in_group("villager"):
		if not v.is_free_archer():
			continue
		var d: float = v.global_position.distance_to(node.global_position)
		if d < bd:
			bd = d
			best = v
	return best

# ---- timber (workers) ----

func _claim_marked_tree() -> void:
	var best: Node3D = null
	var best_d := INF
	for t in get_tree().get_nodes_in_group("marked_tree"):
		if not t.has_method("is_open_for_cutting") or not t.is_open_for_cutting():
			continue
		var d := global_position.distance_to(t.global_position)
		if d < best_d:
			best_d = d
			best = t
	# claiming is what keeps two workers off the same trunk
	if best == null or not best.claim_cutter(self):
		return
	_tree = best
	_chop_spot = _stand_spot(best, CHOP_REACH)
	_state = State.GO_CHOP
	_show_axe(true)

func _stand_spot(t: Node3D, reach: float) -> Vector3:
	var away := global_position - t.global_position
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3(1, 0, 0)
	return t.global_position + away.normalized() * reach

func _tree_standing() -> bool:
	return is_instance_valid(_tree) and not _tree.felled

func _walk_to_tree(delta: float) -> void:
	if not _tree_standing():
		_abandon_tree()
		return
	var g := _route(_chop_spot)
	_seek(delta, g, (0.2 if g == _chop_spot else 0.4))
	if global_position.distance_to(_tree.global_position) < CHOP_REACH + 0.35:
		_state = State.CHOP
		_swing_t = 0.25
		_face(_tree.global_position)

func _chop(delta: float) -> void:
	if not _tree_standing():
		_abandon_tree()
		return
	_stand(delta)
	_swing_t -= delta
	if _swing_t <= 0.0:
		_swing_t = SWING_TIME
		_swing_axe()

func _swing_axe() -> void:
	if not is_instance_valid(_axe):
		return
	var rest := _axe_rest()
	var t := create_tween()
	# wind up over the shoulder...
	t.tween_property(_axe, "position", rest + Vector3(-0.08 * _facing, 0.30, 0), 0.17).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(sprite, "position:y", _base_y + 0.05, 0.17)
	# ...and drive it into the trunk
	t.tween_property(_axe, "position", rest + Vector3(0.45 * _facing, -0.30, 0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(sprite, "position:y", _base_y - 0.04, 0.07)
	t.tween_callback(_land_blow)
	t.tween_property(_axe, "position", rest, 0.16).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(sprite, "position:y", _base_y, 0.16)

func _land_blow() -> void:
	if not _tree_standing():
		return
	if not _tree.take_chop(global_position):
		return
	# timber -- back off and watch it come down
	var away := global_position - _tree.global_position
	away.y = 0.0
	_wait_spot = global_position + (away.normalized() if away.length() > 0.05 else Vector3.RIGHT) * 0.9
	_tree = null
	_wait_for_loot()

func _abandon_tree() -> void:
	if is_instance_valid(_tree) and _tree.has_method("release_cutter"):
		_tree.release_cutter(self)
	_tree = null
	_end_errand()

# ---- the hunt (archers) ----

func _claim_quarry() -> void:
	var best: Node3D = null
	var best_d := INF
	for a in get_tree().get_nodes_in_group("wild_game"):
		if not a.is_open_for_hunting():
			continue
		var d := global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	if best == null or not best.claim_hunter(self):
		return
	_quarry = best
	_state = State.GO_HUNT

func _quarry_alive() -> bool:
	return is_instance_valid(_quarry) and not _quarry.dead

func _stalk(delta: float) -> void:
	if not _quarry_alive() or _is_night():
		_abandon_hunt()
		return
	var d := global_position.distance_to(_quarry.global_position)
	if d <= BOW_RANGE:
		_state = State.SHOOT
		_aim_t = AIM_TIME
		_face(_quarry.global_position)
		_stand(delta)
		return
	var g := _route(_quarry.global_position)
	_seek(delta, g, (BOW_RANGE * 0.85 if g == _quarry.global_position else 0.4))

func _take_aim(delta: float) -> void:
	if not _quarry_alive():
		_abandon_hunt()
		return
	# it wandered out of range again -- close the gap
	if global_position.distance_to(_quarry.global_position) > BOW_RANGE + 1.2:
		_state = State.GO_HUNT
		return
	_stand(delta)
	_face(_quarry.global_position)
	_aim_t -= delta
	if _aim_t <= 0.0:
		_loose_arrow()

func _loose_arrow() -> void:
	if not _quarry_alive():
		_abandon_hunt()
		return
	var quarry: Node3D = _quarry
	var from := global_position + Vector3(0, 0.7, 0)
	var to: Vector3 = quarry.global_position + Vector3(0, 0.2, 0)

	var arrow := Sprite3D.new()
	arrow.texture = ARROW_TEX
	arrow.pixel_size = 0.01
	arrow.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	arrow.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	arrow.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	arrow.flip_h = _facing < 0.0
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = from

	var t := arrow.create_tween()
	t.tween_property(arrow, "global_position", to, 0.22).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(func() -> void:
		arrow.queue_free()
		if is_instance_valid(quarry) and quarry.has_method("take_arrow"):
			quarry.take_arrow(from)
	)

	# loose: the archer rocks back with the release
	var r := create_tween()
	r.tween_property(sprite, "position:x", sprite.position.x - 0.06 * _facing, 0.07)
	r.tween_property(sprite, "position:x", sprite.position.x, 0.16)

	_wait_spot = global_position
	_quarry = null
	_wait_for_loot()

func _abandon_hunt() -> void:
	if is_instance_valid(_quarry) and _quarry.has_method("release_hunter"):
		_quarry.release_hunter(self)
	_quarry = null
	_end_errand()

# ---- foraging (archers) ----

func _claim_marked_bush() -> bool:
	var best: Node3D = null
	var best_d := INF
	for b in get_tree().get_nodes_in_group("marked_bush"):
		if not b.has_method("is_open_for_picking") or not b.is_open_for_picking():
			continue
		var d := global_position.distance_to(b.global_position)
		if d < best_d:
			best_d = d
			best = b
	if best == null:
		return false
	if _nearest_free_archer_to(best) != self:
		return false
	if not best.claim_picker(self):
		return false
	_bush = best
	_state = State.GO_FORAGE
	return true

func _bush_ripe() -> bool:
	return is_instance_valid(_bush) and not _bush.picked

func _walk_to_bush(delta: float) -> void:
	if not _bush_ripe():
		_abandon_bush()
		return
	var p: Vector3 = _bush.pick_point()
	var g := _route(p)
	_seek(delta, g, (FORAGE_REACH if g == p else 0.4))
	if global_position.distance_to(p) < FORAGE_REACH + 0.3:
		_state = State.FORAGE
		_pick_t = PICK_TIME
		_beat_t = 0.0
		_face(p)

func _forage(delta: float) -> void:
	if not _bush_ripe():
		_abandon_bush()
		return
	_stand(delta)
	_beat_t -= delta
	if _beat_t <= 0.0:
		_beat_t = PICK_BEAT
		_bush.rustle(global_position)
		# stoop into the bush and come back up with a handful
		var t := create_tween()
		t.tween_property(sprite, "position:y", _base_y - 0.09, 0.16).set_trans(Tween.TRANS_SINE)
		t.tween_property(sprite, "position:y", _base_y, 0.22).set_trans(Tween.TRANS_SINE)
	_pick_t -= delta
	if _pick_t <= 0.0:
		var bush: Node3D = _bush
		_bush = null
		_wait_spot = global_position
		_wait_for_loot()
		bush.strip()

func _abandon_bush() -> void:
	if is_instance_valid(_bush) and _bush.has_method("release_picker"):
		_bush.release_picker(self)
	_bush = null
	_end_errand()

# ---- hauling the gold home ----

func _wait_for_loot() -> void:
	_state = State.LOOT_WAIT
	_wait_t = LOOT_TIMEOUT
	sprite.position.y = _base_y

## Called by the tree / bush / animal once its coins are on the ground.
func receive_loot(coins: Array) -> void:
	_loot = coins
	if _state == State.LOOT_WAIT:
		_state = State.GATHER

func _gather(delta: float) -> void:
	var next: Node3D = null
	var best := INF
	for c in _loot:
		if not is_instance_valid(c):
			continue
		var d := global_position.distance_to(c.global_position)
		if d < best:
			best = d
			next = c
	if next == null:
		_loot.clear()
		if _purse.is_empty():
			_end_errand()
		else:
			_state = State.PRESENT if _job_is("archer") else State.DELIVER
		return
	_seek(delta, next.global_position, 0.15)
	if best < GATHER_REACH:
		_loot.erase(next)
		next.collect_to(self)
		_pocket_coin()

## Workers just dump the timber gold at the king's feet.
func _deliver(delta: float) -> void:
	var king := get_tree().get_first_node_in_group("monarch")
	if king == null:
		_dump_purse(global_position)
		_end_errand()
		return
	var g := _route(king.global_position)
	_seek(delta, g, (DELIVER_REACH if g == king.global_position else 0.4))
	if global_position.distance_to(king.global_position) < DELIVER_REACH + 0.3:
		_face(king.global_position)
		var t := create_tween()   # a quick bob of a bow as the purse comes off
		t.tween_property(sprite, "scale", Vector3(1.12, 0.86, 1.0), 0.1)
		t.tween_property(sprite, "scale", Vector3.ONE, 0.16)
		_dump_purse(king.global_position)
		_end_errand()

## Archers make a show of it: down on one knee, and the take is offered up into
## the king's hands rather than dropped in the dirt.
func _present(delta: float) -> void:
	var king := get_tree().get_first_node_in_group("monarch")
	if king == null:
		_dump_purse(global_position)
		_end_errand()
		return
	var g := _route(king.global_position)
	_seek(delta, g, (PRESENT_REACH if g == king.global_position else 0.4))
	if global_position.distance_to(king.global_position) >= PRESENT_REACH + 0.3:
		return

	_face(king.global_position)
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector3(1.18, 0.68, 1.0), 0.16).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.34)
	t.tween_property(sprite, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(_purse.size()):
		_offer_coin(_purse[i], king, 0.12 + i * 0.1)
	_purse.clear()
	if king.has_method("receive_tribute"):
		king.receive_tribute()
	_end_errand()

func _offer_coin(coin: Sprite3D, king: Node3D, delay: float) -> void:
	if not is_instance_valid(coin):
		return
	var world := coin.global_position
	remove_child(coin)
	get_tree().current_scene.add_child(coin)
	coin.global_position = world
	var gm = get_tree().get_first_node_in_group("game_manager")
	var dest: Vector3 = king.global_position + Vector3(0, 1.15, 0)
	var peak := world.lerp(dest, 0.5) + Vector3(0, 0.55, 0)
	var t := coin.create_tween()
	t.tween_interval(delay)
	t.tween_method(
		func(p: float) -> void:
			coin.global_position = world.lerp(peak, p).lerp(peak.lerp(dest, p), p),
		0.0, 1.0, 0.42
	).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(coin, "scale", Vector3(1.6, 1.6, 1.6), 0.42)
	t.tween_callback(func() -> void:
		if gm:
			gm.add_coins(1)
		coin.queue_free()
	)

func _end_errand() -> void:
	_show_axe(false)
	_loot.clear()
	_scan_t = ERRAND_SCAN
	sprite.position.y = _base_y
	_state = State.WORK if is_instance_valid(_workplace) else State.LOYAL

# ---- carried gold ----

func _pocket_coin() -> void:
	var c := Sprite3D.new()
	c.texture = COIN_TEX
	c.pixel_size = 0.009
	c.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	c.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	c.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	c.no_depth_test = true
	add_child(c)
	_purse.append(c)
	_layout_purse()
	c.scale = Vector3.ZERO
	c.create_tween().tween_property(c, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _layout_purse() -> void:
	var n := _purse.size()
	var start_x := -CARRY_SPACING * (n - 1) * 0.5
	for i in range(n):
		_purse[i].position = Vector3(start_x + i * CARRY_SPACING, CARRY_Y, 0)

func _dump_purse(toward: Vector3) -> void:
	for c in _purse:
		if not is_instance_valid(c):
			continue
		var coin := COIN_SCENE.instantiate()
		get_tree().current_scene.add_child(coin)
		coin.global_position = c.global_position
		var a := randf() * TAU
		var landing := toward + Vector3(cos(a), 0, sin(a)) * randf_range(0.3, 0.7)
		landing.y = 0.12
		coin.pop(landing)
		c.queue_free()
	_purse.clear()

# ---- tools ----

func _show_axe(on: bool) -> void:
	if on:
		if is_instance_valid(_axe):
			return
		_axe = Sprite3D.new()
		_axe.texture = AXE_TEX
		_axe.pixel_size = 0.011
		_axe.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		_axe.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_axe.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		_axe.shaded = true
		add_child(_axe)
		_axe.position = _axe_rest()
	elif is_instance_valid(_axe):
		_axe.queue_free()
		_axe = null

func _axe_rest() -> Vector3:
	return Vector3(0.20 * _facing, 0.78, 0)

func _face(p: Vector3) -> void:
	# flip toward the target in *screen* space, so it still reads once the player
	# has spun the camera around
	var to := p - global_position
	to.y = 0.0
	var right := Vector3.RIGHT
	var cam := get_viewport().get_camera_3d()
	if cam:
		right = cam.global_transform.basis.x
	_facing = 1.0 if right.dot(to) >= 0.0 else -1.0
	sprite.flip_h = _facing < 0.0
	if is_instance_valid(_axe):
		_axe.flip_h = _facing < 0.0
		_axe.position = _axe_rest()

# ---- routing (steer through gates instead of into walls) ----

func _route(final: Vector3) -> Vector3:
	# Same side of the palisade (or no walls yet) -> head straight there.
	if not _walls_exist() or _inside(global_position) == _inside(final):
		_has_gate = false
		return final
	# Crossing the wall: commit to one gate (cached so we don't dither at corners)
	# and aim for a point just past it, so we walk THROUGH rather than stop on it.
	if not _has_gate:
		_route_gate = _pick_gate(final)
		_has_gate = true
	var inward := final - _route_gate
	inward.y = 0.0
	if inward.length() < 0.01:
		inward = Vector3(0, 0, 1)
	return _route_gate + inward.normalized() * 2.5

func _inside(p: Vector3) -> bool:
	return absf(p.x) < WALL_HALF and absf(p.z) < WALL_HALF

func _pick_gate(final: Vector3) -> Vector3:
	var gates: Array[Vector3] = [
		Vector3(0, 0, -WALL_HALF), Vector3(0, 0, WALL_HALF),
		Vector3(WALL_HALF, 0, 0), Vector3(-WALL_HALF, 0, 0),
	]
	var best: Vector3 = gates[0]
	var bd := INF
	for gp in gates:
		var d := global_position.distance_to(gp) + gp.distance_to(final)
		if d < bd:
			bd = d
			best = gp
	return best

func _walls_exist() -> bool:
	for w in get_tree().get_nodes_in_group("wall_side"):
		if w.built:
			return true
	return false

# ---- movement helpers ----

func _seek(delta: float, goal: Vector3, stop: float) -> void:
	var to := goal - global_position
	to.y = 0.0
	var tv := Vector3.ZERO
	if to.length() > stop:
		tv = to.normalized() * SPEED
	velocity.x = move_toward(velocity.x, tv.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, tv.z, ACCEL * delta)
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length() > 0.3)

## Hold position -- the working tween owns the sprite bob while we do.
func _stand(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)
	move_and_slide()

func _mill_near(delta: float, center: Vector3, radius: float) -> void:
	_mill_t -= delta
	if _mill_t <= 0.0:
		_mill_t = randf_range(1.0, 2.5)
		var a := randf() * TAU
		_mill = center + Vector3(cos(a), 0, sin(a)) * randf_range(0.6, radius)
	_seek(delta, _mill, 0.25)

func _animate(delta: float, moving: bool) -> void:
	if moving:
		_bob += delta * 10.0
		sprite.position.y = _base_y + abs(sin(_bob)) * 0.06
		if absf(velocity.x) > 0.1:
			sprite.flip_h = velocity.x < 0.0
	else:
		sprite.position.y = move_toward(sprite.position.y, _base_y, delta * 0.5)
	# carried gold rides along with the bob
	var lift := sprite.position.y - _base_y
	for c in _purse:
		if is_instance_valid(c):
			c.position.y = CARRY_Y + lift
