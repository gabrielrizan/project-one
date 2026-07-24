extends CharacterBody3D
## A bandit that marches on the village (COMBAT_PROMPTS P2).
##
## For now it only walks -- no spawner, no combat, no damage. It paths to the hall
## (falling back to the campfire) and idles on arrival. Built like [villager.gd]
## but a fraction of it: one [NavMover], a [Model] holder facing +Z, and the same
## walk bob.
##
## The pile-up at the gate is free: the navmesh routes the march through the
## gateway, and the shut gate -- which opens only for `monarch` and `villager`
## (see [WallSide]) -- physically stops the body. No targeting code, exactly as
## GAME_DESIGN §9 intends.
##
## Visuals are placeholder-then-pack (§11): `villager.glb` flat-tinted charcoal
## into a featureless dark silhouette, a pickaxe scaled into the hands. The final
## look is a downloaded character pack, chosen later under the ask-first licence
## rule (§12).

const MODEL_SCENE := preload("res://kingdom_demo/assets/3d/characters/villager.glb")
const PICKAXE := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/tool-pickaxe.glb")

## Charcoal, per §9 -- Kingdom's Greed register. Slightly blue-cold so it reads as
## a silhouette rather than mud.
const CHARCOAL := Color(0.15, 0.15, 0.18)

## A deliberate march: slower than a villager's 3.2 so it reads as a threat
## closing in rather than someone running an errand. Placeholder, like every pace.
const SPEED := 2.2
const ACCEL := 26.0
const ARRIVE := 2.6
## Panic pace when the rooster turns them: faster than the march, so the retreat
## reads as a rout rather than a stroll home.
const FLEE_SPEED := 3.6
## The charge once it has a victim -- a touch faster than a fleeing citizen's 3.2,
## so a bandit can run one down rather than watching it escape (COMBAT_PROMPTS P5).
const CHASE_SPEED := 3.8
const ROB_RANGE := 2.0          # tools are torn off within this of a citizen
const VICTIM_RESCAN := 0.5      # how often to look for someone to rob

## The loot shouldered after a theft -- a packed bundle, over the shoulder.
const BUNDLE := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/bedroll-packed.glb")

# --- smashing what blocks the way (COMBAT_PROMPTS P6a) ---
const SMASH_AFTER := 0.5        # wedged this long -> start hammering
const SMASH_BEAT := 0.9         # seconds between blows
const SMASH_REACH := 1.8        # how close to the wall line a blow can land
const BUILD_REACH := 2.6        # how close to a building a blow can land (P6b)
const SMASH_DAMAGE := 7.0       # per blow -- PLACEHOLDER, tuned against wall HP
## The villager axe pool, pitched down for blows on timber (§9). Stone impacts are
## genuinely missing and get sourced in P8; for now every blow uses this.
const AXE_CLIPS := [
	preload("res://kingdom_demo/assets/audio/axe_chop_1.ogg"),
	preload("res://kingdom_demo/assets/audio/axe_chop_2.ogg"),
	preload("res://kingdom_demo/assets/audio/axe_chop_3.ogg"),
	preload("res://kingdom_demo/assets/audio/axe_chop_4.ogg"),
	preload("res://kingdom_demo/assets/audio/axe_chop_5.ogg"),
]
const TIMBER_PITCH := 0.85

enum State { MARCH, IDLE, FLEE }

static var _axe_pool: AudioStreamRandomizer = null

@onready var model_root: Node3D = $Model
@onready var _agent: NavigationAgent3D = $NavAgent

var _state := State.MARCH
var _nav: NavMover = null
var _model: Node3D = null
var _goal := Vector3.ZERO         # the FLEE/rout destination (the camp)
var _hall_goal := Vector3.ZERO    # where to march when there's no one to rob
var _run := SPEED       # current pace; the rout raises it to FLEE_SPEED
var dead := false       # read by the archer's shot; one arrow drops a Thug (P4)
var _victim: Node3D = null        # the citizen being run down
var _victim_t := 0.0
var _robbed_someone := false      # every bandit wants one theft, then leaves (§11)
var _stuck_t := 0.0               # wants to move but isn't -- the wedge signature
var _hit_beat := 0.0
var _bob := 0.0
var _yaw := 0.0
var _mill := Vector3.ZERO
var _mill_t := 0.0

func _ready() -> void:
	add_to_group("bandit")
	_nav = NavMover.new(_agent, self)
	_build_model()
	_hall_goal = _target_point()

func _exit_tree() -> void:
	if _nav:
		_nav.cleanup()

## The hall if it stands, else the campfire, else dead centre -- the same target
## the whole march shares, recomputed once at spawn (the village centre doesn't
## move, and the hall sits where the campfire already is if it isn't up yet).
func _target_point() -> Vector3:
	var fire := get_tree().get_first_node_in_group("campfire")
	if is_instance_valid(fire):
		if fire.has_method("hall"):
			var h: Node3D = fire.hall()
			if is_instance_valid(h):
				return h.global_position
		return fire.global_position
	return Vector3.ZERO   # nothing to march on yet

func _build_model() -> void:
	_model = MODEL_SCENE.instantiate()
	model_root.add_child(_model)
	# tint first: it flattens every mesh under the model to one charcoal, so the
	# pickaxe is added *after* to keep its own wood-and-iron colours.
	MarkFx.tint(_model, CHARCOAL)
	var axe := PICKAXE.instantiate()
	_model.add_child(axe)
	axe.position = Vector3(0.22, 0.62, 0.24)   # roughly shouldered in the hand
	axe.rotation = Vector3(0.2, 0.0, -0.6)
	axe.scale = Vector3.ONE * 1.1
	_model.rotation.y = _yaw

func _physics_process(delta: float) -> void:
	match _state:
		State.MARCH:
			_hunt_or_march(delta)
		State.IDLE:
			# a raider with nothing to rob keeps an eye out for a citizen appearing
			_victim_t -= delta
			if _victim_t <= 0.0:
				_victim_t = VICTIM_RESCAN
				_acquire_victim()
				if is_instance_valid(_victim):
					_state = State.MARCH
			_mill_near(delta, _hall_goal, 1.4)
		State.FLEE:
			_seek(delta, _goal, 1.0)
			# reached the camp (or run off the end of the corridor) -> gone at dawn
			if global_position.distance_to(_goal) < 2.0 \
					or global_position.z <= MapTerrain.MOUTH_Z + 1.5:
				queue_free()

## Rooster's turned the night: run for the camp and despawn on arrival. Called by
## the raid director at first light (COMBAT_PROMPTS P3).
func rout(to: Vector3) -> void:
	if dead:
		return
	_goal = to
	_run = FLEE_SPEED
	_state = State.FLEE

## An arrow found its mark (COMBAT_PROMPTS P4). Mirrors wild_animal.gd -- knockback,
## squash, gone -- but **drops nothing** (§5: night is pure cost). One arrow kills
## a Thug for now. Leaves the `bandit` group at once so archers stop targeting it
## and stand down when the last one falls.
func take_arrow(_from: Vector3) -> void:
	if dead:
		return
	dead = true
	remove_from_group("bandit")
	set_deferred("collision_layer", 0)
	velocity = Vector3.ZERO
	set_physics_process(false)   # the death tween owns the body now
	_die(_from)

func _die(from: Vector3) -> void:
	var knock := global_position - from
	knock.y = 0.0
	if knock.length() < 0.01:
		knock = Vector3(0, 0, 1)
	knock = knock.normalized() * 0.35
	create_tween().tween_property(self, "global_position", global_position + knock, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target: Node3D = _model if is_instance_valid(_model) else self
	var f := create_tween()
	f.tween_interval(0.16)
	f.tween_property(target, "scale", Vector3(1.2, 0.15, 1.2), 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	f.tween_interval(0.45)
	f.tween_property(target, "scale", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	f.tween_callback(queue_free)

# ---- robbery (COMBAT_PROMPTS P5) ----

## Run down a robbable citizen if there's one; otherwise vandalise the nearest
## standing building (§9). Chasing is faster than the march so a fleeing citizen can
## be caught, and either way a wedge against the wall gets hammered en route.
func _hunt_or_march(delta: float) -> void:
	_victim_t -= delta
	if _victim_t <= 0.0:
		_victim_t = VICTIM_RESCAN
		_acquire_victim()
	if _victim_robbable():
		_run = CHASE_SPEED
		_seek(delta, _victim.global_position, ROB_RANGE * 0.9)
		if global_position.distance_to(_victim.global_position) <= ROB_RANGE:
			_rob()
		else:
			_smash_if_wedged(delta)
		return
	# nothing to rob -> break the nearest standing building (P6b)
	_victim = null
	_run = SPEED
	var b := _nearest_building()
	if b == null:
		_seek(delta, _hall_goal, ARRIVE)
		if global_position.distance_to(_hall_goal) < ARRIVE:
			_state = State.IDLE
			_mill = _hall_goal
		return
	_seek(delta, b.global_position, BUILD_REACH)
	if global_position.distance_to(b.global_position) <= BUILD_REACH:
		_attack_on_beat(b, delta)
	else:
		_smash_if_wedged(delta)

# ---- smashing (COMBAT_PROMPTS P6a walls, P6b buildings) ----

## Wants to move but isn't -- wedged against a shut gate or a wall section. After a
## moment, hammer whatever run it's up against. When the breach opens, the navmesh
## re-bakes, the body moves again, and this quietly stops.
func _smash_if_wedged(delta: float) -> void:
	if Vector2(velocity.x, velocity.z).length() > SPEED * 0.35:
		_stuck_t = 0.0
		return
	_stuck_t += delta
	if _stuck_t < SMASH_AFTER:
		return
	var wall := _nearest_wall(SMASH_REACH)
	if wall != null:
		_attack_on_beat(wall, delta)

## One blow on a beat: the mirrored swing, the axe pitched down, and a hit on the
## target -- a wall (P6a) or a building (P6b), both duck-typed through take_hit.
func _attack_on_beat(target: Node3D, delta: float) -> void:
	_hit_beat -= delta
	if _hit_beat <= 0.0:
		_hit_beat = SMASH_BEAT
		_swing()
		if is_instance_valid(target) and target.has_method("take_hit"):
			target.take_hit(SMASH_DAMAGE, global_position)

func _swing() -> void:
	if is_instance_valid(_model):
		var t := create_tween()
		t.tween_property(_model, "rotation:x", deg_to_rad(26.0), 0.12).set_trans(Tween.TRANS_QUAD)
		t.tween_property(_model, "rotation:x", 0.0, 0.16).set_trans(Tween.TRANS_SINE)
	_play_axe(global_position + Vector3(0, 0.6, 0))

func _nearest_building() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for b in get_tree().get_nodes_in_group("building"):
		if not (is_instance_valid(b) and b.has_method("take_hit") \
				and b.has_method("is_attackable") and b.is_attackable()):
			continue
		var d: float = global_position.distance_to(b.global_position)
		if d < bd:
			bd = d
			best = b
	return best

func _nearest_wall(reach: float) -> Node3D:
	var best: Node3D = null
	var bd := reach
	for w in get_tree().get_nodes_in_group("wall_side"):
		if not (is_instance_valid(w) and w.has_method("take_hit") and w.has_method("face_point")):
			continue
		var d: float = global_position.distance_to(w.face_point(global_position))
		if d < bd:
			bd = d
			best = w
	return best

func _play_axe(at: Vector3) -> void:
	if _axe_pool == null:
		_axe_pool = AudioStreamRandomizer.new()
		for i in range(AXE_CLIPS.size()):
			_axe_pool.add_stream(i, AXE_CLIPS[i])
		_axe_pool.random_pitch = 1.06
		_axe_pool.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS
	var p := AudioStreamPlayer3D.new()
	p.stream = _axe_pool
	p.bus = &"SFX"
	p.pitch_scale = TIMBER_PITCH
	p.unit_size = 5.0
	p.max_distance = 32.0
	get_tree().current_scene.add_child(p)
	p.global_position = at
	p.finished.connect(p.queue_free)
	p.play()

func _victim_robbable() -> bool:
	return is_instance_valid(_victim) and _victim.has_method("is_robbable") and _victim.is_robbable()

## The nearest employed citizen worth robbing. Once this bandit has its one theft
## it looks for no one -- it's leaving (§11).
func _acquire_victim() -> void:
	if _robbed_someone:
		_victim = null
		return
	var best: Node3D = null
	var bd := INF
	for v in get_tree().get_nodes_in_group("villager"):
		if not (is_instance_valid(v) and v.has_method("is_robbable") and v.is_robbable()):
			continue
		var d: float = global_position.distance_to(v.global_position)
		if d < bd:
			bd = d
			best = v
	_victim = best

## Tear the tools off the victim, shoulder the loot, and leave for the camp,
## satisfied -- one theft each.
func _rob() -> void:
	if not _victim_robbable():
		_victim = null
		return
	_victim.get_robbed(self)
	_robbed_someone = true
	_shoulder_bundle()
	_victim = null
	_run = FLEE_SPEED
	_goal = MapTerrain.corridor_mouth()
	_state = State.FLEE

func _shoulder_bundle() -> void:
	if not is_instance_valid(_model):
		return
	var bundle := BUNDLE.instantiate()
	_model.add_child(bundle)
	bundle.position = Vector3(-0.18, 0.95, -0.1)   # over the shoulder
	bundle.scale = Vector3.ONE * 1.1

# ---- movement (mirrors villager.gd, without the errand machinery) ----

func _seek(delta: float, goal: Vector3, stop: float) -> void:
	var to := goal - global_position
	to.y = 0.0
	var tv := Vector3.ZERO
	if to.length() > stop:
		var dir := _nav.direction_to(goal, delta)
		# navmesh has nothing left (at the path end, or the goal is off-mesh behind a
		# shut gate): bear straight down on it and let physics do the piling up.
		if dir == Vector3.ZERO:
			dir = to.normalized()
		tv = dir * _run
	velocity.x = move_toward(velocity.x, tv.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, tv.z, ACCEL * delta)
	move_and_slide()
	_animate(delta, Vector2(velocity.x, velocity.z).length() > 0.3)

func _mill_near(delta: float, center: Vector3, radius: float) -> void:
	_mill_t -= delta
	if _mill_t <= 0.0:
		_mill_t = randf_range(1.2, 2.8)
		var a := randf() * TAU
		_mill = center + Vector3(cos(a), 0, sin(a)) * randf_range(0.5, radius)
	_seek(delta, _mill, 0.3)

func _animate(delta: float, moving: bool) -> void:
	if not is_instance_valid(_model):
		return
	if moving:
		_bob += delta * 9.0
		_model.position.y = abs(sin(_bob)) * 0.06
		if Vector2(velocity.x, velocity.z).length() > 0.1:
			_yaw = lerp_angle(_yaw, atan2(velocity.x, velocity.z), 0.2)
			_model.rotation.y = _yaw
	else:
		_model.position.y = move_toward(_model.position.y, 0.0, delta * 0.5)
