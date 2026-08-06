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
	GO_PERCH, MOUNT, PERCH, DISMOUNT,   # archer wall defence (P4)
	ROBBED, SPOOKED,                    # robbery + fear (P5)
	FOLLOW,                             # mustered into the monarch's war party (P9)
}

## States a citizen will bolt out of when a bandit gets close at night (P5). Left
## out on purpose: building (workers on a paid site keep working), the perch states
## (archers stay up), and the wanderer/robbed states (nothing to fear for, or
## already fled).
const SPOOKABLE_STATES := [
	State.WORK, State.LOYAL, State.GO_WORK, State.GO_CHOP, State.CHOP,
	State.GO_HUNT, State.SHOOT, State.GO_FORAGE, State.FORAGE,
	State.LOOT_WAIT, State.GATHER, State.DELIVER, State.PRESENT,
]

const SPEED := 3.2
const ACCEL := 40.0
const ARRIVE := 1.8
const WORK_ARRIVE := 0.7
const EAT_TIME := 2.5

const CHOP_REACH := 1.15   # where a worker plants their feet to swing
## Seconds between blows. The swing animation itself is ~0.4s, so the rest is the
## worker gathering themselves for the next one -- felling should read as heavy
## work, not a woodpecker. Every axe hit is also a sound, so this is what stops
## the chop sample machine-gunning.
const SWING_TIME := 1.1
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
## Degrees of forward lean at full draw, shared by the hunt (`_take_aim`) and the
## wall/escort combat loop (`_engage_bandits`) -- both count `_aim_t` down against
## `AIM_TIME`, so one pose function serves an archer whichever kind of target they
## have. Small: this is meant to read as "pulling", not a lunge.
const DRAW_LEAN := 4.0

# --- wall defence (COMBAT_PROMPTS P4) ---
const DEFEND_RANGE := 7.0       # perched archers reach past the 4.2 m hunt range (§9)
const MOUNT_TIME := 0.7         # the scripted climb up onto / down off a perch
const DISMOUNT_GRACE := 3.0     # no bandits this long -> stand down; bridges staggered spawns
const FIRE_RING := 3.2          # ground-defence ring when a raided side has no wall to man
const FOLLOW_DIST := 2.6        # how close a mustered archer trails the monarch (P9)

# --- robbery (COMBAT_PROMPTS P5) ---
const ROB_DOWN_TIME := 3.0      # how long a robbed citizen lies before fleeing to the fire
const FLEE_RANGE := 4.0         # civilians bolt from a bandit this close, at night (§9)
const FLEE_CHECK := 0.35        # how often a citizen looks around for a bandit to flee
const SPOOK_TIME := 1.4         # how long a spooked citizen runs before resuming
const FORAGE_REACH := 1.0
const PICK_TIME := 2.6
const PICK_BEAT := 0.55
const PRESENT_REACH := 1.6

const BUILD_REACH := 1.4
## Same reasoning as SWING_TIME: every beat is now a sound, and at 0.42s it
## machine-gunned. Still quicker than the axe -- tapping stakes into a line is
## lighter work than burying a blade in a trunk.
const HAMMER_BEAT := 0.72
const SITE_WALK_TIMEOUT := 25.0   # can't reach the line -> free the slot for someone who can

## A wanderer carries no tools; taking a job swaps in the model that does, so the
## job someone holds is readable at a glance from across the camp.
const VILLAGER_MODEL := preload("res://kingdom_demo/assets/3d/characters/villager.glb")
const WORKER_MODEL := preload("res://kingdom_demo/assets/3d/characters/worker.glb")
const ARCHER_MODEL := preload("res://kingdom_demo/assets/3d/characters/kaykit/archer_ranger_rig.tscn")
const ARROW_MODEL := preload("res://kingdom_demo/assets/3d/props/arrow_marker.glb")
const COIN_MODEL := preload("res://kingdom_demo/assets/3d/props/coin.glb")
const CARRY_SCALE := 0.75
const COIN_SCENE := preload("res://kingdom_demo/scenes/coin.tscn")

## Five takes of the same axe, so a worker felling a tree doesn't machine-gun one
## noise six times over. Shared by every villager -- an [AudioStreamRandomizer] is
## a stateless resource, so there is no reason to build one per body.
const AXE_CLIPS := [
	preload("res://kingdom_demo/assets/audio/axe_chop_1.ogg"),
	preload("res://kingdom_demo/assets/audio/axe_chop_2.ogg"),
	preload("res://kingdom_demo/assets/audio/axe_chop_3.ogg"),
	preload("res://kingdom_demo/assets/audio/axe_chop_4.ogg"),
	preload("res://kingdom_demo/assets/audio/axe_chop_5.ogg"),
]
const AXE_PITCH := 1.16
const AXE_VOL_JITTER := 3.0

## Driving stakes into a line, so lighter and quicker than the axe.
const HAMMER_CLIPS := [
	preload("res://kingdom_demo/assets/audio/hammer_1.ogg"),
	preload("res://kingdom_demo/assets/audio/hammer_2.ogg"),
	preload("res://kingdom_demo/assets/audio/hammer_3.ogg"),
	preload("res://kingdom_demo/assets/audio/hammer_4.ogg"),
	preload("res://kingdom_demo/assets/audio/hammer_5.ogg"),
]
const HAMMER_PITCH := 1.14
const HAMMER_VOL_JITTER := 3.0
## Raising a wall is a long job with a beat every 0.72s, so it sits well back --
## it should be the sound of work going on nearby, not the loudest thing in camp.
const HAMMER_DB := -7.0

const BOW_CLIPS := [
	preload("res://kingdom_demo/assets/audio/bow_1.ogg"),
	preload("res://kingdom_demo/assets/audio/bow_2.ogg"),
	preload("res://kingdom_demo/assets/audio/bow_3.ogg"),
]
const BOW_PITCH := 1.1
const BOW_VOL_JITTER := 2.5

## Played where the arrow lands, not where it was loosed -- see [_loose_arrow].
const ARROW_HIT_CLIPS := [
	preload("res://kingdom_demo/assets/audio/arrow_hit_1.ogg"),
	preload("res://kingdom_demo/assets/audio/arrow_hit_2.ogg"),
	preload("res://kingdom_demo/assets/audio/arrow_hit_3.ogg"),
]
const ARROW_HIT_PITCH := 1.12
const ARROW_HIT_VOL_JITTER := 2.5

## The purse coming off and going into the king's hands. This is how income
## actually reaches the player, so it wants to be audible feedback rather than
## scenery -- but it fires every time any worker or archer gets home, so it is
## kept quiet and short. Distinct from the tally's `coin_*` clips on purpose:
## those are single coins counted out, this is a handful changing hands.
const GOLD_HAND_CLIPS := [
	preload("res://kingdom_demo/assets/audio/gold_hand_1.ogg"),
	preload("res://kingdom_demo/assets/audio/gold_hand_2.ogg"),
	preload("res://kingdom_demo/assets/audio/gold_hand_3.ogg"),
]
const GOLD_HAND_PITCH := 1.1
const GOLD_HAND_VOL_JITTER := 2.5
const GOLD_HAND_DB := -10.0

## PARKED. Two problems, and only one of them is the clip. The handover animation
## is a quick torso bow, and a sharp coin sound landing on it reads as the
## villager being *slapped* rather than handing anything over. On top of that the
## clip is a leather purse while what you actually watch is loose coins flying
## across one at a time -- there is no pouch anywhere on screen.
##
## Revisit when the handover has a real animation to sit on; the clips, the pool
## and the wiring all stay. Flip this to hear it again.
const GOLD_HAND_ENABLED := false

## A wanderer taking a post picks up the tools that come with it -- the model swaps
## to one carrying an axe or a bow on the same frame, and this is that moment.
## Workers get it a touch lower than archers, which is the cheapest way to make the
## two jobs sound different without two clip sets; real per-role kit (a bowstring,
## a quiver) would follow the material-tier pattern in `building.gd::RAISE_SFX`.
const JOB_CLIPS := [
	preload("res://kingdom_demo/assets/audio/job_tools_1.ogg"),
	preload("res://kingdom_demo/assets/audio/job_tools_2.ogg"),
]
const JOB_PITCH_JITTER := 1.1
const JOB_DB := -8.0
const JOB_PITCH := {"worker": 0.92, "archer": 1.06}

## PARKED pending a decision on what taking a post should actually sound like.
## Clips, pitching and wiring all stay; flip this back on to hear it again.
const JOB_SOUND_ENABLED := false

static var _axe_pool: AudioStreamRandomizer = null
static var _hammer_pool: AudioStreamRandomizer = null
static var _bow_pool: AudioStreamRandomizer = null
static var _arrow_hit_pool: AudioStreamRandomizer = null
static var _job_pool: AudioStreamRandomizer = null
static var _gold_hand_pool: AudioStreamRandomizer = null

@onready var model_root: Node3D = $Model
@onready var _agent: NavigationAgent3D = $NavAgent
@onready var _sfx: AudioStreamPlayer3D = $Sfx

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

# archer wall defence (P4)
var _perch_wall: Node3D = null      # the wall being manned, or null for a fire-ring post
var _perch_index := -1
var _post_foot := Vector3.ZERO      # ground spot at the wall's inner face
var _post_top := Vector3.ZERO       # the perch itself, up on the wall
var _no_bandit_t := 0.0             # counts up while no bandits remain

# robbery + fear (P5)
var _robbed := false                # once true, tools are gone and a wanderer again
var _down_t := 0.0                  # time left lying knocked down
var _spook_t := 0.0                 # time left in a fear-bolt
var _spook_check_t := 0.0
var _spook_to := Vector3.ZERO       # where the bolt is running to

# muster / war party (P9)
var _leader: Node3D = null          # the monarch, while mustered into the party

func _ready() -> void:
	add_to_group("villager")
	_base_y = 0.0
	_set_model(VILLAGER_MODEL)
	_mill = target
	_nav = NavMover.new(_agent, self)
	if _axe_pool == null:
		_axe_pool = _build_pool(AXE_CLIPS, AXE_PITCH, AXE_VOL_JITTER)
	if _hammer_pool == null:
		_hammer_pool = _build_pool(HAMMER_CLIPS, HAMMER_PITCH, HAMMER_VOL_JITTER)
	if _bow_pool == null:
		_bow_pool = _build_pool(BOW_CLIPS, BOW_PITCH, BOW_VOL_JITTER)
	if _arrow_hit_pool == null:
		_arrow_hit_pool = _build_pool(ARROW_HIT_CLIPS, ARROW_HIT_PITCH, ARROW_HIT_VOL_JITTER)
	if _job_pool == null:
		_job_pool = _build_pool(JOB_CLIPS, JOB_PITCH_JITTER, 2.0)
	if _gold_hand_pool == null:
		_gold_hand_pool = _build_pool(GOLD_HAND_CLIPS, GOLD_HAND_PITCH, GOLD_HAND_VOL_JITTER)

## One randomiser per kind of sound, built once and shared. Picks a clip at random
## and jitters pitch and volume, so repeated blows never land identically.
static func _build_pool(clips: Array, pitch: float, vol_jitter: float) -> AudioStreamRandomizer:
	var pool := AudioStreamRandomizer.new()
	for i in range(clips.size()):
		pool.add_stream(i, clips[i])
	pool.random_pitch = pitch
	pool.random_volume_offset_db = vol_jitter
	pool.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	return pool

## `pitch` is set per call rather than left on the player -- it applies to the
## stream while it is playing, so resetting it afterwards would undo it, and
## leaving it set would colour whatever this villager plays next.
func _play(pool: AudioStreamRandomizer, db := 0.0, pitch := 1.0) -> void:
	if not is_instance_valid(_sfx):
		return
	_sfx.stream = pool
	_sfx.volume_db = db
	_sfx.pitch_scale = pitch
	_sfx.play()

## A one-shot at a point in the world, on its own throwaway emitter. Used where
## the sound does not belong to this body -- an arrow landing on its target.
func _thud_at(at: Vector3) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _arrow_hit_pool
	p.bus = &"SFX"
	p.unit_size = 5.0
	p.max_distance = 32.0
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()

func _exit_tree() -> void:
	if _nav:
		_nav.cleanup()

func _physics_process(delta: float) -> void:
	_check_spook(delta)     # fear can interrupt any errand before the state runs (P5)
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
		State.GO_PERCH:
			_walk_to_post(delta)
		State.MOUNT:
			pass                     # the climb tween owns the body
		State.PERCH:
			_defend(delta)
		State.DISMOUNT:
			pass                     # the climb-down tween owns the body
		State.SPOOKED:
			_bolt(delta)
		State.ROBBED:
			_stand(delta)            # lie still where you were knocked down
			_down_t -= delta
			if _down_t <= 0.0:
				_rise_as_wanderer()
		State.FOLLOW:
			_follow(delta)
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
	var job: String = _workplace.job_type
	_set_model(ARCHER_MODEL if job == "archer" else WORKER_MODEL)
	if JOB_SOUND_ENABLED:
		# on the same frame the model swaps to one carrying tools
		_play(_job_pool, JOB_DB, JOB_PITCH.get(job, 1.0))

func _work_anchor() -> Vector3:
	return _workplace.work_point() if is_instance_valid(_workplace) else global_position

# ---- picking up an errand ----

func _job_is(kind: String) -> bool:
	return job_name() == kind

## This villager's trade, or "" for a wanderer with no hut yet. Public because
## things outside the state machine legitimately need to ask -- `wreck_site.gd`
## refuses a sale when no worker exists to build what was bought.
func job_name() -> String:
	return String(_workplace.job_type) if is_instance_valid(_workplace) else ""

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
	elif _job_is("archer"):
		# defending the walls comes before any errand, and unlike hunting it happens
		# at night -- a raid is the whole reason the archers' hut exists (§9)
		if _should_defend():
			_claim_defense_post()
		elif not _is_night():
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
##
## The two steps up to `_land_blow` keep their **original durations** (0.17 +
## 0.07 = 0.24s to contact) -- that callback is also where the chop sound fires,
## and nothing here should touch when it lands. The added torque (`rotation:y`)
## and impact squash are `.parallel()` calls layered onto those same steps, so
## they cost no extra time; only the follow-through after contact is new.
func _swing_axe() -> void:
	if not is_instance_valid(_model):
		return
	var t := create_tween()
	# rear back over the shoulder, winding up with a little torque...
	t.tween_property(_model, "rotation:x", deg_to_rad(-15.0), 0.17).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_model, "rotation:y", _yaw + deg_to_rad(10.0), 0.17).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_model, "position:y", _base_y + 0.05, 0.17)
	# ...and drive it into the trunk, compressing on contact
	t.tween_property(_model, "rotation:x", deg_to_rad(28.0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_model, "rotation:y", _yaw - deg_to_rad(6.0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_model, "position:y", _base_y - 0.04, 0.07)
	t.parallel().tween_property(_model, "scale", Vector3(1.07, 0.93, 1.07), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_land_blow)
	# follow-through: the blade bites and the body keeps travelling a beat
	# before it settles, rather than snapping straight back to rest
	t.tween_property(_model, "rotation:x", deg_to_rad(-4.0), 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_model, "rotation:y", _yaw, 0.09).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_model, "scale", Vector3.ONE, 0.09)
	t.tween_property(_model, "rotation:x", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_model, "position:y", _base_y, 0.14)

func _land_blow() -> void:
	if not _tree_standing():
		return
	# on every blow, not just the one that brings it down -- this is the frame the
	# swing tween drives the axe into the trunk, so the hit and the sound agree
	_play(_axe_pool)
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
## stakes into the line rather than burying an axe in a trunk. Same rule as
## `_swing_axe`: the two steps up to `_land_hammer` (0.13 + 0.07 = 0.20s) keep
## their original durations, since that callback is also where the hammer
## sound fires -- the torque and squash ride along as `.parallel()` calls.
func _swing_hammer() -> void:
	if not is_instance_valid(_model):
		return
	var t := create_tween()
	t.tween_property(_model, "rotation:x", deg_to_rad(-12.0), 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_model, "rotation:y", _yaw + deg_to_rad(6.0), 0.13).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_model, "position:y", _base_y + 0.04, 0.13)
	t.tween_property(_model, "rotation:x", deg_to_rad(24.0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_model, "rotation:y", _yaw - deg_to_rad(4.0), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_model, "position:y", _base_y - 0.03, 0.07)
	t.parallel().tween_property(_model, "scale", Vector3(1.04, 0.96, 1.04), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_land_hammer)
	t.tween_property(_model, "rotation:x", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_model, "rotation:y", _yaw, 0.1).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_model, "position:y", _base_y, 0.14)
	t.parallel().tween_property(_model, "scale", Vector3.ONE, 0.1)

func _land_hammer() -> void:
	if not _site_open():
		return
	_play(_hammer_pool, HAMMER_DB)
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
	_apply_draw_pose(_aim_t)
	if _aim_t <= 0.0:
		_loose_arrow()

## A subtle lean building through the draw, so an archer reads as pulling a bow
## rather than standing dead still until the arrow appears. Shared by the hunt
## and the wall/escort combat loop -- both count `_aim_t` down against
## `AIM_TIME`, and `_shoot_arrow`'s own release rock-back picks up smoothly from
## wherever this leaves `rotation:x`, so draw and release read as one motion.
func _apply_draw_pose(t_left: float) -> void:
	if not is_instance_valid(_model):
		return
	var drawn := 1.0 - clampf(t_left / AIM_TIME, 0.0, 1.0)
	_model.rotation.x = deg_to_rad(-DRAW_LEAN * drawn)

func _loose_arrow() -> void:
	if not _quarry_alive():
		_abandon_hunt()
		return
	_shoot_arrow(_quarry)
	_wait_spot = global_position
	_quarry = null
	_wait_for_loot()

## The reusable shot: bow, arrow in flight, thud and take_arrow at the target, and
## the archer's rock-back. Both the hunt loop and the wall defence (P4) call it --
## take_arrow is duck-typed, so it kills a stag or a bandit the same way.
func _shoot_arrow(target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var from := global_position + Vector3(0, 0.7, 0)
	var to: Vector3 = target.global_position + Vector3(0, 0.2, 0)

	_play(_bow_pool)
	var arrow := MarkFx.model(ARROW_MODEL, 0.7)
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = from
	arrow.look_at(to, Vector3.UP)     # the model points down +X, so aim it along the flight
	arrow.rotate_object_local(Vector3.UP, -PI / 2.0)

	var t := arrow.create_tween()
	t.tween_property(arrow, "global_position", to, 0.22).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(func() -> void:
		arrow.queue_free()
		# the thud belongs where the arrow lands, which can be metres from the
		# archer -- so it gets its own emitter out at the target
		_thud_at(to)
		if is_instance_valid(target) and target.has_method("take_arrow"):
			target.take_arrow(from)
	)

	# loose: the archer rocks back with the release
	if is_instance_valid(_model):
		var r := create_tween()
		r.tween_property(_model, "rotation:x", deg_to_rad(-9.0), 0.07)
		r.tween_property(_model, "rotation:x", 0.0, 0.16)

## The muster's payoff shot (P10): loose a ceremonial fire-arrow at a camp about to
## burn. No target and no damage -- the BanditCamp drives the burn; this is just the
## archer's visible part of the volley, so "the squad looses" reads on screen.
## Reuses the hunt shot's bow, arrow and rock-back, with an ember trail on the arrow.
func loose_fire_arrow(at: Vector3) -> void:
	if not is_inside_tree():
		return
	_face(at)
	_play(_bow_pool)
	var from := global_position + Vector3(0, 0.7, 0)
	var arrow := MarkFx.model(ARROW_MODEL, 0.7)
	get_tree().current_scene.add_child(arrow)
	arrow.global_position = from
	arrow.look_at(at, Vector3.UP)     # the model points down +X, so aim it along the flight
	arrow.rotate_object_local(Vector3.UP, -PI / 2.0)
	var flight := 0.34
	var t := arrow.create_tween()
	t.tween_property(arrow, "global_position", at, flight).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(arrow.queue_free)
	_fire_trail(from, at, flight)
	if is_instance_valid(_model):
		var r := create_tween()
		r.tween_property(_model, "rotation:x", deg_to_rad(-9.0), 0.07)
		r.tween_property(_model, "rotation:x", 0.0, 0.16)

## Ember motes strung along the arrow's flight, so the fire-arrow reads as one (P10).
## A bounded handful, scheduled at points down the line -- the flight is short and
## near-straight, so this trails the arrow without sampling it every frame.
func _fire_trail(from: Vector3, to: Vector3, dur: float) -> void:
	var motes := 6
	for i in range(motes):
		var f := float(i) / float(motes)
		get_tree().create_timer(dur * f).timeout.connect(_ember_mote.bind(from.lerp(to, f)))

func _ember_mote(at: Vector3) -> void:
	if not is_inside_tree():
		return
	var s := MarkFx.particle(MarkFx.CHIP_TEX, 0.03)
	s.modulate = Color(1.9, 0.6, 0.12, 1.0)   # ember-hot
	get_tree().current_scene.add_child(s)
	s.global_position = at
	var t := s.create_tween()
	t.tween_property(s, "global_position", at + Vector3(0, 0.4, 0), 0.5)
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.5)
	t.tween_callback(s.queue_free)

# ---- wall defence (COMBAT_PROMPTS P4) ----

## A raid is on while any bandit stands on the map. The director spawns the first
## of a wave at the dusk horn, so archers mount as the raid begins and are up on the
## wall while the bandits are still marching the corridor -- itself the sign a raid
## is coming (§9). Keying off bandits (not the night-long raid flag) means they also
## stand down for good at dawn, once the survivors have routed, instead of re-manning
## empty walls.
func _should_defend() -> bool:
	return _raid_pressure()

## True while actual raiders threaten the village -- any bandit that isn't a camp
## garrison (P10). A garrison sits out at its camp permanently, so keying wall
## defence off the whole `bandit` group would man the walls every day and night and
## the archers would never hunt or forage. The escorted war party still targets the
## full group when it rides out on the offensive (_engage_bandits), so it clears the
## garrison; only the village's *defensive* mustering filters it out.
func _raid_pressure() -> bool:
	for b in get_tree().get_nodes_in_group("bandit"):
		if is_instance_valid(b) and not b.garrison:
			return true
	return false

## Claim a perch on one of tonight's **lit** walls, through the same duck-typed
## station flow every errand uses. Failing that -- no lit wall with room, or none
## built on the threatened bearing -- take a post ringing the campfire, which is the
## last line (§9). Never a player order (§1).
##
## ## Lit walls only, and the emptiest one rather than the nearest (F5)
##
## This used to take the *nearest* wall with a free perch, which was right while a
## map had one opening: nearest and only were the same wall. On a map walled all the
## way round it is badly wrong -- every archer in the village would crowd the wall
## they happened to be standing by, and a raid arriving on the far side would meet
## nobody.
##
## So the rule is now: **only a lit wall can be manned, and archers go to whichever
## lit wall has the fewest defenders.** That makes them spread evenly across two
## fronts without anyone issuing an order, and it makes the braziers mean something
## to the kingdom and not just to the player. An unlit wall is never manned, however
## close it is or however grand it is.
##
## The odd archer across two fronts simply lands on whichever wall is behind at the
## moment they ask, so nobody is ever left unassigned.
func _claim_defense_post() -> void:
	var best_wall: Node3D = null
	var fewest := INF
	var best_d := INF
	for w in get_tree().get_nodes_in_group("wall_side"):
		if not (w.has_method("perch_available") and w.perch_available()):
			continue
		if w.has_method("is_lit") and not w.is_lit():
			continue
		var n: float = float(w.defenders()) if w.has_method("defenders") else 0.0
		var d: float = global_position.distance_to(w.global_position)
		# distance only breaks ties between equally-manned walls, so two fronts
		# fill in step and each archer still takes the nearer of the two
		if n < fewest or (n == fewest and d < best_d):
			fewest = n
			best_d = d
			best_wall = w
	if best_wall != null:
		var idx: int = best_wall.claim_perch(self)
		if idx >= 0:
			_perch_wall = best_wall
			_perch_index = idx
			_post_foot = best_wall.foot_point(idx)
			_post_top = best_wall.perch_point(idx)
			_quarry = null
			_state = State.GO_PERCH
			return
	var fire := get_tree().get_first_node_in_group("campfire")
	if fire == null:
		return
	_perch_wall = null
	_perch_index = -1
	_quarry = null
	var a := randf() * TAU
	_post_foot = fire.global_position + Vector3(cos(a), 0, sin(a)) * FIRE_RING
	_post_top = _post_foot
	_state = State.GO_PERCH

func _walk_to_post(delta: float) -> void:
	if not _should_defend():
		_leave_post()
		return
	_seek(delta, _post_foot, 0.4)
	if global_position.distance_to(_post_foot) < 0.7:
		if is_instance_valid(_perch_wall):
			_begin_mount()
		else:
			_state = State.PERCH        # ground post -- no climb

## Scripted climb tween up onto the marker; collision comes off so the capsule
## doesn't shove the wall, and the body is parked (no physics) once up.
func _begin_mount() -> void:
	_state = State.MOUNT
	velocity = Vector3.ZERO
	_set_body_collision(false)
	var t := create_tween()
	t.tween_property(self, "global_position", _post_top, MOUNT_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		if _state == State.MOUNT:
			_reset_pose()
			_state = State.PERCH
	)

func _defend(delta: float) -> void:
	# stand down once the raid's spent: a few seconds of no bandits bridges the gaps
	# between staggered arrivals, then the archer climbs down and drifts home. Keys
	# off raid pressure, not the raw group, so a distant camp garrison doesn't pin
	# the archers on the wall forever (P10).
	if not _raid_pressure():
		_no_bandit_t += delta
		if _no_bandit_t >= DISMOUNT_GRACE:
			_leave_post()
			return
	else:
		_no_bandit_t = 0.0
	_engage_bandits(delta)
	# a ground post holds its spot; a perched archer is parked by the tween and must
	# not run physics, or it would fall off the wall.
	if not is_instance_valid(_perch_wall):
		_stand(delta)

## Keep or pick the nearest bandit in defensive range, aim, and loose. Returns true
## while there's one being engaged, so a caller (perch defence or a follower) knows
## to hold position. Shared by _defend (P4) and the war party's _follow (P9).
func _engage_bandits(delta: float) -> bool:
	if not _bandit_alive(_quarry) \
			or global_position.distance_to(_quarry.global_position) > DEFEND_RANGE + 1.5:
		_quarry = _nearest_bandit(DEFEND_RANGE)
		_aim_t = AIM_TIME
	if not is_instance_valid(_quarry):
		return false
	_face(_quarry.global_position)
	_aim_t -= delta
	_apply_draw_pose(_aim_t)
	if _aim_t <= 0.0:
		_shoot_arrow(_quarry)
		_quarry = null
		_aim_t = AIM_TIME
	return true

func _leave_post() -> void:
	_no_bandit_t = 0.0
	_quarry = null
	if _state == State.PERCH and is_instance_valid(_perch_wall):
		_state = State.DISMOUNT
		var t := create_tween()
		t.tween_property(self, "global_position", _post_foot, MOUNT_TIME) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_callback(_finish_dismount)
	else:
		_finish_dismount()

func _finish_dismount() -> void:
	_set_body_collision(true)
	_release_post()
	_reset_pose()
	_state = State.WORK if is_instance_valid(_workplace) else State.LOYAL

func _release_post() -> void:
	if is_instance_valid(_perch_wall) and _perch_wall.has_method("release_perch"):
		_perch_wall.release_perch(self)
	_perch_wall = null
	_perch_index = -1

func _set_body_collision(on: bool) -> void:
	var cs := get_node_or_null("CollisionShape3D")
	if cs:
		cs.disabled = not on

## A dead bandit leaves the `bandit` group at once (see bandit.take_arrow), so group
## membership is the liveness test -- and it also rejects a stale animal quarry left
## over from a hunt the archer broke off to defend.
func _bandit_alive(b: Node) -> bool:
	return is_instance_valid(b) and b.is_in_group("bandit")

func _nearest_bandit(within: float) -> Node3D:
	var best: Node3D = null
	var bd := within
	for b in get_tree().get_nodes_in_group("bandit"):
		if not is_instance_valid(b):
			continue
		var d: float = global_position.distance_to(b.global_position)
		if d < bd:
			bd = d
			best = b
	return best

# ---- muster / the war party (COMBAT_PROMPTS P9) ----

## Asked by the muster banner: an archer citizen not already out or down can join.
func can_muster() -> bool:
	return _job_is("archer") and not _robbed and _state != State.FOLLOW

func is_following() -> bool:
	return _state == State.FOLLOW

## Fall in behind the monarch: leave whatever post or errand this archer was on and
## trail him, shooting what he walks the party into. Never an order to attack (P9).
func muster(leader: Node3D) -> void:
	if not can_muster():
		return
	_set_body_collision(true)   # in case it was perched -- P4 turns collision off up there
	global_position.y = 0.0     # ...and drop it back to the ground
	_release_claims()
	_reset_pose()
	_leader = leader
	_state = State.FOLLOW

## Home dismisses: back to a post, no order given.
func disband() -> void:
	if _state != State.FOLLOW:
		return
	_leader = null
	_reset_pose()
	_state = State.WORK if is_instance_valid(_workplace) else State.LOYAL

func _follow(delta: float) -> void:
	if not is_instance_valid(_leader):
		disband()
		return
	# the escort *is* the assault: halt to loose on anything in range, else keep up
	if _engage_bandits(delta):
		_stand(delta)
		return
	if global_position.distance_to(_leader.global_position) > FOLLOW_DIST:
		_seek(delta, _leader.global_position, FOLLOW_DIST)
	else:
		_stand(delta)

# ---- robbery + fear (COMBAT_PROMPTS P5) ----

## Asked by a bandit before it charges: only an **employed** citizen is worth robbing.
## A wanderer or a loyal-but-jobless villager carries nothing and is ignored (§9), a
## robbed one has nothing left, and a perched archer is out of reach until a breach.
func is_robbable() -> bool:
	if _robbed or not is_instance_valid(_workplace):
		return false
	match _state:
		State.MOUNT, State.PERCH, State.DISMOUNT, State.FOLLOW:
			return false   # up a wall, or marching in the war party -- out of reach
	return true

## A bandit tore the tools off this citizen (§9): knocked flat, the job vacated so
## its vacancy icon returns, the model back to the bare villager. A few seconds down,
## then up as a hungry wanderer -- the cauldron re-recruits them, which is the soup a
## robbery costs.
func get_robbed(_by: Node) -> void:
	if not is_robbable():
		return
	_robbed = true
	_release_claims()
	if is_instance_valid(_workplace) and _workplace.has_method("vacate_job"):
		_workplace.vacate_job()
	_workplace = null
	_set_model(VILLAGER_MODEL)          # the tools are gone
	velocity = Vector3.ZERO
	if is_instance_valid(_model):
		MarkFx.hit_flash(self, _model)
		create_tween().tween_property(_model, "rotation:x", deg_to_rad(-78.0), 0.18) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_down_t = ROB_DOWN_TIME
	_state = State.ROBBED

func _rise_as_wanderer() -> void:
	_robbed = false
	if is_instance_valid(_model):
		create_tween().tween_property(_model, "rotation:x", 0.0, 0.2)
	var fire := get_tree().get_first_node_in_group("campfire")
	target = fire.global_position if is_instance_valid(fire) else global_position
	_state = State.SEEK_FOOD             # a hungry wanderer again

## Let go of every errand claim -- so a robbed or spooked citizen doesn't leave a
## tree, bush, animal, site or perch reserved to nobody.
func _release_claims() -> void:
	if is_instance_valid(_quarry) and _quarry.has_method("release_hunter"):
		_quarry.release_hunter(self)
	_quarry = null
	if is_instance_valid(_tree) and _tree.has_method("release_cutter"):
		_tree.release_cutter(self)
	_tree = null
	if is_instance_valid(_bush) and _bush.has_method("release_picker"):
		_bush.release_picker(self)
	_bush = null
	if is_instance_valid(_site) and _site.has_method("release_builder"):
		_site.release_builder(self)
	_site = null
	_release_post()

## Fear: at night a bandit within a few metres sends a citizen bolting, the way
## wildlife spooks. Builders on a paid site keep working; perched archers, wanderers
## and the already-robbed are left out. Keeps its job -- it resumes once clear.
func _check_spook(delta: float) -> void:
	# archers are the army -- they mount the walls or ring the fire, they don't flee
	if _robbed or _job_is("archer") or not _spookable():
		return
	_spook_check_t -= delta
	if _spook_check_t > 0.0:
		return
	_spook_check_t = FLEE_CHECK
	if not _is_night():
		return
	var b := _nearest_bandit(FLEE_RANGE)
	if b != null:
		_flee_from(b.global_position)

func _spookable() -> bool:
	return _state in SPOOKABLE_STATES

func _flee_from(threat: Vector3) -> void:
	_release_claims()
	var away := global_position - threat
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3(randf() - 0.5, 0.0, randf() - 0.5)
	_spook_to = global_position + away.normalized() * randf_range(3.0, 5.0)
	_spook_t = SPOOK_TIME
	_state = State.SPOOKED

func _bolt(delta: float) -> void:
	_spook_t -= delta
	_seek(delta, _spook_to, 0.3)
	if _spook_t <= 0.0 or global_position.distance_to(_spook_to) < 0.6:
		_reset_pose()
		_state = State.WORK if is_instance_valid(_workplace) else State.LOYAL

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
		if GOLD_HAND_ENABLED:
			_play(_gold_hand_pool, GOLD_HAND_DB)
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
	if GOLD_HAND_ENABLED:
		_play(_gold_hand_pool, GOLD_HAND_DB)
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
	# a rigged KayKit model (currently just the archer) plays real bone
	# animation instead of the bob, which is baked into its walk/run clips
	var rigged := _model.has_method("play")
	if moving:
		if rigged:
			_model.play("Running_A" if Vector2(velocity.x, velocity.z).length() > SPEED * 0.75 else "Walking_A")
		else:
			_bob += delta * 10.0
			_model.position.y = _base_y + abs(sin(_bob)) * 0.06
		# turn to face the way we're walking, easing round rather than snapping
		if Vector2(velocity.x, velocity.z).length() > 0.1:
			_yaw = lerp_angle(_yaw, atan2(velocity.x, velocity.z), 0.2)
			_model.rotation.y = _yaw
			_facing = 1.0 if velocity.x >= 0.0 else -1.0
	elif rigged:
		_model.play("Idle_A")
	else:
		_model.position.y = move_toward(_model.position.y, _base_y, delta * 0.5)
	# carried gold rides along with the bob
	var lift := _model.position.y - _base_y
	for c in _purse:
		if is_instance_valid(c):
			c.position.y = CARRY_Y + lift
