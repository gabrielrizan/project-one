class_name BanditCamp
extends Node3D
## A bandit camp: the object the raid director sends waves from, and the map
## objective the war party burns down (COMBAT_PROMPTS P3 + P10).
##
## P3 built the camp as loose scenery inside night_raids.gd. P10 makes it "an
## object with a lifecycle, not scenery" -- so the visuals, the ember fire and the
## standing garrison now live here, in the `bandit_camp` group, and the raid
## director reads live camps *from the group*. Burning one removes it from the
## group, so raids from that front simply stop (night_raids.gd::_spawn_one).
##
## The burn is the muster's payoff (P10): once the war party has cleared the camp's
## defenders and an escorted archer is in range, the squad looses a fire-arrow
## volley, a beat passes, the tents catch, and the camp swaps to a charcoal wreck.
## **No loot ever drops** -- the reward is the silence (§5). The director is
## instantiated by night_raids.gd (BanditCamp.new()); the whole thing is procedural,
## like the loose camp it replaces, so there is no scene file to keep in sync.

const SK := "res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/"
const BANDIT_SCENE := preload("res://kingdom_demo/scenes/bandit.tscn")

const EMBER := Color(1.0, 0.55, 0.22)
const EMBER_DIM := 0.9        # a camp always smoulders on the horizon
const EMBER_FLARE := 4.5      # ...and the fire is stoked at dusk when a raid is coming
const EMBER_BURN := 9.0       # the white-hot flare of ignition, before it dies to ash

## The standing garrison (P10): a few bandits idling at the fire by day -- the same
## bodies as the night waves, just home. They fight back only as far as the current
## systems allow: they are live `bandit`s the escorted archers must shoot down
## before the volley can loose (bandits ignore the monarch, §11, and followers carry
## nothing to rob, so a melee against the war party would be new combat P10 doesn't
## ask for -- their resistance *is* being there to be cleared). PLACEHOLDER count.
const GARRISON := 3
const DEFENDER_R := 8.0       # "no live defender near the camp" is measured to here
const VOLLEY_R := 8.0         # an escorted archer this close can loose the fire volley
const VOLLEY_ARROWS := 4      # fire arrows in the payoff volley (one per archer, capped)
const IGNITE_BEAT := 0.6      # the pause between the volley landing and the flames
const CHARCOAL := Color(0.12, 0.11, 0.12)
const FLAME_TIME := 3.0       # how long the fire burns before it's a cold wreck

var _burned := false
var _burning := false
var _ember: OmniLight3D = null
var _ember_want := EMBER_DIM
var _flicker := 0.0
var _tents: Array[Node3D] = []   # the pieces that char and slump when it burns

func _ready() -> void:
	add_to_group("bandit_camp")
	_build()
	# after _ready, so the camp's world position (set by the director) is settled
	# before the garrison spawns around it
	call_deferred("_post_garrison")

func _process(delta: float) -> void:
	_flicker_ember(delta)
	if not _burned and not _burning:
		_try_burn()

# ---------------------------------------------------------------- the camp look

func _build() -> void:
	var tent := _place("tent.glb", Vector3(0, 0, -2.8), 2.0, 0.0)   # behind the fire, mouth to the village
	_place("campfire-pit.glb", Vector3.ZERO, 1.6, 0.0)
	_place("bedroll.glb", Vector3(-2.4, 0, -1.4), 1.6, 0.6)
	_place("bedroll.glb", Vector3(2.3, 0, -1.7), 1.6, -0.5)
	_place("barrel.glb", Vector3(2.0, 0, 0.9), 1.3, 0.0)
	_tents.append(tent)
	_ember = OmniLight3D.new()
	add_child(_ember)
	_ember.position = Vector3(0, 0.8, 0)
	_ember.light_color = EMBER
	_ember.light_energy = EMBER_DIM
	_ember.omni_range = 16.0
	_ember.shadow_enabled = false

func _place(file: String, pos: Vector3, sc: float, yaw: float) -> Node3D:
	var n: Node3D = (load(SK + file) as PackedScene).instantiate()
	add_child(n)
	n.position = pos
	n.scale = Vector3.ONE * sc
	n.rotation.y = yaw
	return n

# ---------------------------------------------------------------- the garrison

func _post_garrison() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for i in range(GARRISON):
		var b := BANDIT_SCENE.instantiate()
		b.garrison = true
		b.home = global_position          # mill here, don't march on the hall
		scene.add_child(b)                 # loose in the world, so it paths the navmesh
		var a := TAU * float(i) / float(GARRISON) + randf() * 0.6
		b.global_position = global_position + Vector3(cos(a), 0, sin(a)) * randf_range(1.6, 2.6)

# ---------------------------------------------------------------- the fire

## The director stokes every live camp at dusk when a raid is coming, and lets it
## fall back to a smoulder at dawn (night_raids.gd::_flare).
func flare(on: bool) -> void:
	if _burned:
		return
	_ember_want = EMBER_FLARE if on else EMBER_DIM

## A little life in the fire, easing toward whatever flare last asked for. Stops for
## good once burned -- the burn tween owns the light from then on.
func _flicker_ember(delta: float) -> void:
	if _burned or not is_instance_valid(_ember):
		return
	_flicker += delta * 9.0
	var jitter := 0.85 + 0.15 * sin(_flicker) * sin(_flicker * 1.73)
	_ember.light_energy = move_toward(_ember.light_energy, _ember_want * jitter, delta * 6.0)

# ---------------------------------------------------------------- the director's reads

## Where this camp trickles a wave in from (night_raids.gd::_spawn_one).
func spawn_point() -> Vector3:
	return global_position + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-2.0, 2.0))

func is_burned() -> bool:
	return _burned

# ---------------------------------------------------------------- the burn (P10)

## The trigger, checked every frame while the camp still stands: no live defender
## left near the fire, and an escorted archer close enough to loose. Both must hold
## before the volley -- clearing the garrison is what earns the burn.
func _try_burn() -> void:
	if _defenders_near():
		return
	var archers := _volley_archers()
	if archers.is_empty():
		return
	_begin_burn(archers)

## Any live bandit (garrison, or a night raider that's wandered back) within reach
## of the fire. A dead bandit has already left the `bandit` group, so membership is
## the liveness test -- the same rule the archers' shot uses.
func _defenders_near() -> bool:
	for b in get_tree().get_nodes_in_group("bandit"):
		if is_instance_valid(b) and b.global_position.distance_to(global_position) <= DEFENDER_R:
			return true
	return false

func _volley_archers() -> Array:
	var out: Array = []
	for v in get_tree().get_nodes_in_group("villager"):
		if v.has_method("is_following") and v.is_following() \
				and v.global_position.distance_to(global_position) <= VOLLEY_R:
			out.append(v)
	return out

## The escort looses its volley of fire arrows at the camp, then a beat later the
## flames catch (_ignite). Guarded by `_burning` so it fires exactly once.
func _begin_burn(archers: Array) -> void:
	_burning = true
	_ember_want = EMBER_DIM               # stop stoking -- it's about to be ash
	var n := 0
	for v in archers:
		if n >= VOLLEY_ARROWS:
			break
		if v.has_method("loose_fire_arrow"):
			v.loose_fire_arrow(_flame_point())
		n += 1
	var t := create_tween()
	t.tween_interval(IGNITE_BEAT)
	t.tween_callback(_ignite)

func _flame_point() -> Vector3:
	return global_position + Vector3(randf_range(-1.5, 1.5), 0.6, randf_range(-1.8, 0.6))

## The flames catch: the camp leaves the `bandit_camp` group (so no more waves come
## from this front), the fire burns and dies, the pieces char, and the run manager
## is told to check whether the map is now clear.
func _ignite() -> void:
	_burned = true
	_burning = false
	remove_from_group("bandit_camp")
	_flames()
	_burn_light()
	_char()
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("report_camp_burned"):
		gm.report_camp_burned()

## A burst of rising, flickering flame motes over the tents. No flame asset exists,
## so fire-hot chip sprites (MarkFx.particle) stand in, staggered across the burn --
## P8's missing-list gains a real camp-burn sound (ask-first audio rule).
func _flames() -> void:
	for i in range(26):
		get_tree().create_timer(randf() * FLAME_TIME * 0.7).timeout.connect(_flame_mote)

func _flame_mote() -> void:
	if not is_inside_tree():
		return
	var s := MarkFx.particle(MarkFx.CHIP_TEX, randf_range(0.03, 0.06))
	var hot := randf()
	s.modulate = Color(1.9, 0.55 + hot * 0.8, 0.12, 1.0)   # ember-red up to yellow-hot
	get_tree().current_scene.add_child(s)
	var base := global_position + Vector3(randf_range(-2.4, 2.4), 0.1, randf_range(-3.4, 1.0))
	s.global_position = base
	var top := base + Vector3(randf_range(-0.3, 0.3), randf_range(1.2, 2.2), randf_range(-0.3, 0.3))
	var t := s.create_tween()
	t.tween_property(s, "global_position", top, randf_range(0.7, 1.2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(s, "modulate:a", 0.0, randf_range(0.7, 1.2))
	t.tween_callback(s.queue_free)

## The ember flares white-hot as the tents catch, then dies away to nothing.
func _burn_light() -> void:
	if not is_instance_valid(_ember):
		return
	var t := _ember.create_tween()
	t.tween_property(_ember, "light_energy", EMBER_BURN, 0.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(_ember, "light_energy", 0.0, FLAME_TIME).set_ease(Tween.EASE_IN)

## The wreck: every piece blackens, and the main tent slumps to one side.
func _char() -> void:
	MarkFx.tint(self, CHARCOAL)
	for tent in _tents:
		if not is_instance_valid(tent):
			continue
		var t := tent.create_tween()
		t.tween_property(tent, "rotation:z", tent.rotation.z + deg_to_rad(18.0), 1.4).set_trans(Tween.TRANS_SINE)
		t.parallel().tween_property(tent, "position:y", tent.position.y - 0.3, 1.4)

## Dev: skip the assault and burn this camp now, to see the fire and the objective
## line without riding the full loop. Clears its garrison first so the wreck reads.
func dev_burn() -> void:
	if _burned or _burning:
		return
	for b in get_tree().get_nodes_in_group("bandit"):
		if is_instance_valid(b) and b.garrison \
				and b.global_position.distance_to(global_position) <= DEFENDER_R:
			b.queue_free()
	_burning = true
	_ember_want = EMBER_DIM
	_ignite()
