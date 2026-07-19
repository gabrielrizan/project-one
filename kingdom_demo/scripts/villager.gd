extends CharacterBody3D
## A villager drawn in by a full cauldron. It walks to the cauldron, eats, becomes
## a loyal citizen (blue tint), then walks to the nearest building with an open job
## and takes it -- swapping into a builder or archer outfit.
##
## Once employed they run errands between shifts:
##   workers  -- raise a wall the monarch has paid for, or claim a tree he marked,
##               fell it, haul the gold back and dump it at his feet.
##   archers  -- by daylight, strip a marked berry bush or hunt the rabbits and
##               stags roaming the woods, then kneel and present the take.

enum State {
	SEEK_FOOD, EAT, LOYAL, GO_WORK, WORK,
	GO_CHOP, CHOP, LOOT_WAIT, GATHER, DELIVER,
	GO_HUNT, SHOOT, GO_FORAGE, FORAGE, PRESENT,
	GO_BUILD, BUILD,
}

const SPEED := 3.2
const ACCEL := 40.0
const ARRIVE := 1.8
const WORK_ARRIVE := 0.7
const EAT_TIME := 2.5

const CHOP_REACH := 1.15   # where a worker plants their feet to swing
const SWING_TIME := 0.46
const GATHER_REACH := 0.55
const DELIVER_REACH := 1.7
const ERRAND_SCAN := 1.0   # how often an idle villager looks for something to do
const LOOT_TIMEOUT := 5.0
## Give up on a coin that can't be got at, so a villager is never locked out of
## work by one. Collecting anything resets it, so a good haul is never cut short --
## only a coin nobody can reach runs it down. Abandoned gold is not lost: it keeps
## bobbing where it fell and the monarch snaps it up when he rides past.
const GATHER_TIMEOUT := 6.0
const CARRY_SPACING := 0.30
const CARRY_Y := 1.32

const BOW_RANGE := 4.2     # archers loose from beyond the animals' spook range
const AIM_TIME := 0.55
const FORAGE_REACH := 1.0
const PICK_TIME := 2.6
const PICK_BEAT := 0.55
const PRESENT_REACH := 1.6

const BUILD_REACH := 1.4
const HAMMER_BEAT := 0.42
const SITE_WALK_TIMEOUT := 25.0   # can't reach the line -> free the slot for someone who can

## A wanderer carries no tools; taking a job swaps in the model that does, so the
## job someone holds is readable at a glance from across the camp.
const VILLAGER_MODEL := preload("res://kingdom_demo/assets/3d/characters/villager.glb")
const WORKER_MODEL := preload("res://kingdom_demo/assets/3d/characters/worker.glb")
const ARCHER_MODEL := preload("res://kingdom_demo/assets/3d/characters/archer.glb")
const ARROW_MODEL := preload("res://kingdom_demo/assets/3d/props/arrow_marker.glb")
const COIN_MODEL := preload("res://kingdom_demo/assets/3d/props/coin.glb")
const CARRY_SCALE := 0.75
const COIN_SCENE := preload("res://kingdom_demo/scenes/coin.tscn")

@onready var model_root: Node3D = $Model
@onready var _agent: NavigationAgent3D = $NavAgent

var target := Vector3.ZERO          # cauldron position, set by spawner

var _state: int = State.SEEK_FOOD
var _workplace: Node3D = null
var _eat_t := 0.0
var _recheck_t := 0.0
var _mill := Vector3.ZERO
var _mill_t := 0.0
var _bob := 0.0
var _base_y := 0.0
var _nav: NavMover = null

var _tree: Node3D = null
var _quarry: Node3D = null
var _bush: Node3D = null
var _site: Node3D = null
var _build_spot := Vector3.ZERO
var _hammer_t := 0.0
var _site_t := 0.0
var _chop_spot := Vector3.ZERO
var _wait_spot := Vector3.ZERO
var _model: Node3D = null
var _yaw := 0.0
var _swing_t := 0.0
var _aim_t := 0.0
var _pick_t := 0.0
var _beat_t := 0.0
var _facing := 1.0
var _scan_t := 0.0
var _wait_t := 0.0
var _gather_t := 0.0
var _stuck_t := 0.0
var _detour := Vector3.ZERO
var _detour_t := 0.0
var _loot: Array = []               # coins our kill/tree/bush dropped, not gathered yet
var _purse: Array = []              # carried coin models bobbing over our head

func _ready() -> void:
	add_to_group("villager")
	_base_y = 0.0
	_set_model(VILLAGER_MODEL)
	_mill = target
	_nav = NavMover.new(_agent, self)

func _exit_tree() -> void:
	if _nav:
		_nav.cleanup()

func _physics_process(delta: float) -> void:
	match _state:
		State.SEEK_FOOD:
			_seek(delta, target, ARRIVE)
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
				_seek(delta, wp, WORK_ARRIVE)
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
		State.GO_BUILD:
			_walk_to_site(delta)
		State.BUILD:
			_raise_wall(delta)
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
	# eating is what actually empties the pot -- an emptied cauldron can be
	# refilled, which is how the camp grows past its first few wanderers
	var pot = get_tree().get_first_node_in_group("campfire")
	if pot and pot.has_method("take_serving"):
		pot.take_serving()
	_state = State.LOYAL
	_recheck_t = 0.0

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
	_set_model(ARCHER_MODEL if _workplace.job_type == "archer" else WORKER_MODEL)

func _work_anchor() -> Vector3:
	return _workplace.work_point() if is_instance_valid(_workplace) else global_position

# ---- picking up an errand ----

func _job_is(kind: String) -> bool:
	return is_instance_valid(_workplace) and _workplace.job_type == kind

## An archer standing about with no errand -- available for a bush or a hunt.
func is_free_archer() -> bool:
	return _state == State.WORK and _job_is("archer")

## Asked by a wall marker before it takes the monarch's gold: a wall he pays for
## is raised by hand, so with nobody holding a hammer there is nobody to raise it.
func is_worker() -> bool:
	return _job_is("worker")

func _is_night() -> bool:
	var cycle = get_tree().get_first_node_in_group("day_night_cycle")
	return cycle != null and cycle.is_night()

func _look_for_errand() -> void:
	if _job_is("worker"):
		# a wall the monarch has already paid for is waiting on hands -- that comes
		# before going off into the woods after timber
		if not _claim_build_site():
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
	_seek(delta, _chop_spot, 0.2)
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

## The worker model carries its own axe, so the swing is the whole body rocking
## back and driving forward rather than a separate prop being animated.
func _swing_axe() -> void:
	if not is_instance_valid(_model):
		return
	var t := create_tween()
	# rear back over the shoulder...
	t.tween_property(_model, "rotation:x", deg_to_rad(-15.0), 0.17).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_model, "position:y", _base_y + 0.05, 0.17)
	# ...and drive it into the trunk
	t.tween_property(_model, "rotation:x", deg_to_rad(28.0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_model, "position:y", _base_y - 0.04, 0.07)
	t.tween_callback(_land_blow)
	t.tween_property(_model, "rotation:x", 0.0, 0.16).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_model, "position:y", _base_y, 0.16)

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

# ---- raising walls (workers) ----

## A wall the monarch has paid for stands as a bare line of timber until workers
## walk over and put it up. The nearest free hands go first, up to the site's crew
## limit -- more of them on the line and it goes up faster.
func _claim_build_site() -> bool:
	var best: Node3D = null
	var best_d := INF
	for s in get_tree().get_nodes_in_group("build_site"):
		if not s.has_method("needs_builders") or not s.needs_builders():
			continue
		var d := global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	if best == null or not best.claim_builder(self):
		return false
	_site = best
	_build_spot = best.build_spot(self)
	_site_t = SITE_WALK_TIMEOUT
	_state = State.GO_BUILD
	return true

func _site_open() -> bool:
	return is_instance_valid(_site) and _site.site_active()

func _walk_to_site(delta: float) -> void:
	if not _site_open():
		_leave_site()
		return
	_site_t -= delta
	if _site_t <= 0.0:
		_leave_site()
		return
	_seek(delta, _build_spot, 0.25)
	if global_position.distance_to(_build_spot) < BUILD_REACH:
		_state = State.BUILD
		_hammer_t = 0.2
		_face(_site.face_point(global_position))
		_site.builder_ready(self)

func _raise_wall(delta: float) -> void:
	if not _site_open():
		_leave_site()
		return
	_stand(delta)
	_hammer_t -= delta
	if _hammer_t <= 0.0:
		_hammer_t = HAMMER_BEAT
		_swing_hammer()

## The same rock-back-and-drive as felling, but shorter and quicker: driving
## stakes into the line rather than burying an axe in a trunk.
func _swing_hammer() -> void:
	if not is_instance_valid(_model):
		return
	var t := create_tween()
	t.tween_property(_model, "rotation:x", deg_to_rad(-12.0), 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_model, "position:y", _base_y + 0.04, 0.13)
	t.tween_property(_model, "rotation:x", deg_to_rad(24.0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_model, "position:y", _base_y - 0.03, 0.07)
	t.tween_callback(_land_hammer)
	t.tween_property(_model, "rotation:x", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_model, "position:y", _base_y, 0.14)

func _land_hammer() -> void:
	if not _site_open():
		return
	var at: Vector3 = _site.face_point(global_position)
	at.y = 0.1
	var dir := at - global_position
	dir.y = 0.0
	MarkFx.debris(self, at, dir.normalized(), 2, Color(0.72, 0.62, 0.44, 1.0), 0.012, 0.35)

func _leave_site() -> void:
	if is_instance_valid(_site) and _site.has_method("release_builder"):
		_site.release_builder(self)
	_site = null
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
	_seek(delta, _quarry.global_position, BOW_RANGE * 0.85)

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

	var arrow := MarkFx.model(ARROW_MODEL, 0.7)
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = from
	arrow.look_at(to, Vector3.UP)     # the model points down +X, so aim it along the flight
	arrow.rotate_object_local(Vector3.UP, -PI / 2.0)

	var t := arrow.create_tween()
	t.tween_property(arrow, "global_position", to, 0.22).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(func() -> void:
		arrow.queue_free()
		if is_instance_valid(quarry) and quarry.has_method("take_arrow"):
			quarry.take_arrow(from)
	)

	# loose: the archer rocks back with the release
	if is_instance_valid(_model):
		var r := create_tween()
		r.tween_property(_model, "rotation:x", deg_to_rad(-9.0), 0.07)
		r.tween_property(_model, "rotation:x", 0.0, 0.16)

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
	_seek(delta, p, FORAGE_REACH)
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
		if is_instance_valid(_model):
			var t := create_tween()
			t.tween_property(_model, "position:y", _base_y - 0.09, 0.16).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(_model, "rotation:x", deg_to_rad(22.0), 0.16)
			t.tween_property(_model, "position:y", _base_y, 0.22).set_trans(Tween.TRANS_SINE)
			t.parallel().tween_property(_model, "rotation:x", 0.0, 0.22)
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
	_reset_pose()

## Called by the tree / bush / animal once its coins are on the ground.
func receive_loot(coins: Array) -> void:
	_loot = coins
	if _state == State.LOOT_WAIT:
		_state = State.GATHER
		_gather_t = GATHER_TIMEOUT

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
	# nothing left worth chasing -- either we picked it all up, or the last of it
	# is somewhere we can't get to and we've spent long enough trying
	_gather_t -= delta
	if next == null or _gather_t <= 0.0:
		_done_gathering()
		return
	_seek(delta, next.global_position, 0.15)
	if best < GATHER_REACH:
		_loot.erase(next)
		next.collect_to(self)
		_pocket_coin()
		_gather_t = GATHER_TIMEOUT   # still making progress, so keep going

func _done_gathering() -> void:
	_loot.clear()
	if _purse.is_empty():
		_end_errand()
	else:
		_state = State.PRESENT if _job_is("archer") else State.DELIVER

## Workers just dump the timber gold at the king's feet.
func _deliver(delta: float) -> void:
	var king := get_tree().get_first_node_in_group("monarch")
	if king == null:
		_dump_purse(global_position)
		_end_errand()
		return
	_seek(delta, king.global_position, DELIVER_REACH)
	if global_position.distance_to(king.global_position) < DELIVER_REACH + 0.3:
		_face(king.global_position)
		if is_instance_valid(_model):   # a quick bob of a bow as the purse comes off
			var t := create_tween()
			t.tween_property(_model, "rotation:x", deg_to_rad(20.0), 0.1)
			t.tween_property(_model, "rotation:x", 0.0, 0.16)
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
	_seek(delta, king.global_position, PRESENT_REACH)
	if global_position.distance_to(king.global_position) >= PRESENT_REACH + 0.3:
		return

	_face(king.global_position)
	if is_instance_valid(_model):
		# down on one knee: sink and bow the torso, hold, then rise
		var t := create_tween()
		t.tween_property(_model, "position:y", _base_y - 0.22, 0.16).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(_model, "rotation:x", deg_to_rad(16.0), 0.16)
		t.tween_interval(0.34)
		t.tween_property(_model, "position:y", _base_y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(_model, "rotation:x", 0.0, 0.22)
	for i in range(_purse.size()):
		_offer_coin(_purse[i], king, 0.12 + i * 0.1)
	_purse.clear()
	if king.has_method("receive_tribute"):
		king.receive_tribute()
	_end_errand()

func _offer_coin(coin: Node3D, king: Node3D, delay: float) -> void:
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
	t.parallel().tween_property(coin, "scale", Vector3.ONE * CARRY_SCALE * 1.6, 0.42)
	t.tween_callback(func() -> void:
		if gm:
			gm.add_coins(1)
		coin.queue_free()
	)

func _end_errand() -> void:
	_loot.clear()
	_scan_t = ERRAND_SCAN
	_reset_pose()
	_state = State.WORK if is_instance_valid(_workplace) else State.LOYAL

# ---- carried gold ----

func _pocket_coin() -> void:
	var c := MarkFx.model(COIN_MODEL, CARRY_SCALE)
	add_child(c)
	_purse.append(c)
	_layout_purse()
	c.scale = Vector3.ZERO
	c.create_tween().tween_property(c, "scale", Vector3.ONE * CARRY_SCALE, 0.22) 		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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

# ---- body ----

## Swap which model is worn. Models are authored facing +Z with feet at y=0.
func _set_model(scene: PackedScene) -> void:
	if is_instance_valid(_model):
		_model.queue_free()
	_model = scene.instantiate()
	model_root.add_child(_model)
	_model.position.y = _base_y
	_model.rotation.y = _yaw

## Undo any lean/crouch a work animation left behind.
func _reset_pose() -> void:
	if is_instance_valid(_model):
		_model.position.y = _base_y
		_model.rotation.x = 0.0

func _face(p: Vector3) -> void:
	var to := p - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	_yaw = atan2(to.x, to.z)
	_facing = 1.0 if to.x >= 0.0 else -1.0
	if is_instance_valid(_model):
		_model.rotation.y = _yaw

# ---- movement helpers ----

## Walk toward `goal`, stopping once within `stop` of it. The heading comes from
## the navmesh ([NavMover]), so huts, trees and walls are gone round rather than
## walked into, and crossing the palisade finds the gate on its own -- villagers
## used to be told which gate to aim for by hand.
func _seek(delta: float, goal: Vector3, stop: float) -> void:
	var to := goal - global_position
	to.y = 0.0
	var tv := Vector3.ZERO
	if to.length() > stop:
		var dir := _nav.direction_to(goal, delta)
		# The navmesh has nothing left to offer: either we are standing on the end
		# of the path already, or the goal is somewhere it can't reach -- a coin
		# that rolled under a bush. Bear down on it directly and let _unstick cope,
		# which is what every villager did before there was a navmesh.
		if dir == Vector3.ZERO:
			dir = to.normalized()
		tv = _unstick(delta, dir * SPEED)
	velocity.x = move_toward(velocity.x, tv.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, tv.z, ACCEL * delta)
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length() > 0.3)

## The navmesh steers round everything solid that was standing when it was last
## baked, which leaves two ways to still end up wedged: another villager in the
## doorway, or a goal off the mesh that we are bearing down on directly. If we
## are asking to move and hardly moving, sidestep for a moment and try again.
func _unstick(delta: float, want: Vector3) -> Vector3:
	if _detour_t > 0.0:
		_detour_t -= delta
		return _detour * SPEED
	if Vector2(velocity.x, velocity.z).length() > SPEED * 0.35:
		_stuck_t = 0.0
		return want
	_stuck_t += delta
	if _stuck_t < 0.45:
		return want
	_stuck_t = 0.0
	_detour_t = 0.7
	# strike off to one side, still leaning the way we were going
	var side := Vector3(-want.z, 0.0, want.x).normalized()
	if randf() < 0.5:
		side = -side
	_detour = (side * 1.3 + want.normalized()).normalized()
	return _detour * SPEED

## Hold position -- the working tween owns the body pose while we do.
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
	if not is_instance_valid(_model):
		return
	if moving:
		_bob += delta * 10.0
		_model.position.y = _base_y + abs(sin(_bob)) * 0.06
		# turn to face the way we're walking, easing round rather than snapping
		if Vector2(velocity.x, velocity.z).length() > 0.1:
			_yaw = lerp_angle(_yaw, atan2(velocity.x, velocity.z), 0.2)
			_model.rotation.y = _yaw
			_facing = 1.0 if velocity.x >= 0.0 else -1.0
	else:
		_model.position.y = move_toward(_model.position.y, _base_y, delta * 0.5)
	# carried gold rides along with the bob
	var lift := _model.position.y - _base_y
	for c in _purse:
		if is_instance_valid(c):
			c.position.y = CARRY_Y + lift
