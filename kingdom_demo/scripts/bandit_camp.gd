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
## The camp is composed from **three kits we already own**, the way `HallBuilder` and
## `reward_site.gd` compose theirs. Nothing was downloaded for it: there is no CC0
## bandit-camp pack in any of the usual sources (Quaternius, Kenney, KayKit all have
## medieval kits and none has an encampment), and between the survival kit's tents and
## these two there is already a camp in the box.
const FT := "res://kingdom_demo/assets/3d/kenney_fantasy-town-kit/Models/GLB format/"
const CK := "res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/"
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
## The bandits' own cloth -- `bandit.gd`'s Thug tint, so the standard over the camp and
## the men under it are the same colour. Deliberately a shade off [constant CHARCOAL]:
## a live camp must not already be wearing the colour a burnt one turns.
const BANDIT_CLOTH := Color(0.15, 0.15, 0.18)
## For the kit props that come painted off-palette -- the cart's wheels are blue.
const WALNUT := Color(0.42, 0.30, 0.20)
const FLAME_TIME := 3.0       # how long the fire burns before it's a cold wreck

## The smoke column (see [method _smoke]). Slow and sparse on purpose: it has to
## read as a landmark from across the map, not as a particle effect up close.
const SMOKE_EVERY := 0.55
const SMOKE_RISE := Vector2(6.5, 9.5)   # clears the ~6.5 m treeline
const SMOKE_COLOR := Color(0.58, 0.56, 0.54, 0.85)   # woodsmoke grey, in palette

## Whether this camp sends the night waves.
##
## A map carries two camps and **only one of them raids** (see [MapCatalog]). The
## other keeps its garrison and has to be ridden out to and burned like any other,
## but it never queues a wave and -- the part the player actually reads -- its fire
## never flares at dusk. So the dusk flare stops being decoration and becomes the
## answer to "which way is tonight coming from", which is exactly the job §9 gives
## a visible camp: a wall is an informed bet, not a blind tax.
##
## Set by the raid director before `add_child`, like [member garrison] on a bandit.
var raiding := true

## How close the monarch must ride before the camp resolves (see [method
## _check_discovery]).
##
## Sized against the camera, not against the map. `battle 45` shows ~28 m of
## ground centred on the monarch, so it reaches ~15 m ahead of him -- discovering
## at 26 m means the camp is *always* already revealed by the time it could enter
## frame. The player never sees anything pop in; they just find that riding out is
## the only way to learn what is out there. Raise this above ~16 m at your peril:
## below that the reveal happens on screen and reads as a bug.
const DISCOVER_R := 26.0

var _burned := false
var _burning := false
var _ember: OmniLight3D = null
var _ember_want := EMBER_DIM
var _flicker := 0.0
var _smoke_t := 0.0
var _tents: Array[Node3D] = []   # the pieces that char and slump when it burns
var _props: Node3D = null        # everything you can see of the camp, minus the fire
var _garrison: Array[Node3D] = []
var _found := false

func _ready() -> void:
	add_to_group("bandit_camp")
	_build()
	# Under fog of war the whole camp -- props, smoke column and ember together --
	# is hidden by the mask, and this file's own distance check stands down. See
	# [method _check_discovery] for why that reverses what used to be written here.
	if FogOfWar.enabled():
		_found = true                  # nothing left for the distance check to do
		# ⚠️ **...which also means nothing is left to un-hide `_props`.** `_build`
		# starts it hidden for the *land* maps, where `_check_discovery` shows it when
		# the monarch rides within `DISCOVER_R`. Standing that check down handed the
		# hiding to the fog mask -- and the mask sets `visible` on **this node**, never
		# on a child, so `_props` stayed false forever and the island's camps were an
		# ember, a smoke column and three bandits standing in an empty clearing.
		#
		# Two layers of hiding is the bug. Under fog the mask is the only one, so the
		# props are simply visible and the camp node is what gets hidden.
		_props.visible = true
		FogOfWar.hide_until_found(self)
	# after _ready, so the camp's world position (set by the director) is settled
	# before the garrison spawns around it
	call_deferred("_post_garrison")

func _process(delta: float) -> void:
	_flicker_ember(delta)
	_smoke(delta)
	if not _found:
		_check_discovery()
	if not _burned and not _burning:
		_try_burn()

# ---------------------------------------------------------------- the camp look

## The tents, bedrolls and barrel hang off `_props` rather than off the camp
## directly, so discovery is one `visible` flag instead of a walk over children --
## and so the ember below stays out of it, which is the whole point (see
## [method _check_discovery]).
func _build() -> void:
	_props = Node3D.new()
	add_child(_props)
	_props.visible = false
	# ⚠️ **`tent.glb` is a bare A-frame with no canvas on it.** The camps were built
	# from it for months: four poles and a ridge beam, which from the play camera is
	# not a tent, it is scaffolding, and at night it is nothing at all. The kit's
	# actual tent is **`tent-canvas.glb`** -- the same frame with a canvas over it --
	# and `tent-canvas-half.glb` is the lean-to. Rendering the three side by side is
	# the only thing that showed it; the names and the bounding boxes are identical
	# to three decimal places, because the canvas hangs *inside* the frame.
	#
	# ⚠️ **And every scale here was roughly half what it should be.** Every model in
	# the survival kit is a ~0.5 m piece, so a plausible-looking 2.0x multiplier is a
	# 0.98 m tent -- shorter than the 1.2 m villager meant to sleep in it -- and a
	# 0.98 m bedroll he would not fit on. Measured, then divided into a target size,
	# exactly as `reward_site.gd` does for the kits it composes from: tent 0.49 m ->
	# 1.57 m at the ridge and 1.79 m across the door, bedroll 0.61 m -> 1.40 m long,
	# barrel 0.34 m -> 0.78 m, fire pit 0.28 m -> 1.06 m across.
	#
	# The camp comes to ~10 m across with the fence, and its deepest piece sits 4.8 m
	# back -- inside the 6.5 m of clearing behind it (`MapDef.camp_clear` and
	# `camp_clear_bias`). Grow it and check that number first.
	var tent := _place("tent-canvas.glb", Vector3(0, 0, -3.0), 3.2, 0.0)
	var lean := _place("tent-canvas-half.glb", Vector3(-3.3, 0, -2.2), 2.8, 0.6)
	_place("campfire-pit.glb", Vector3.ZERO, 3.8, 0.0)
	_place("bedroll.glb", Vector3(-2.6, 0, -1.5), 2.3, 0.6)
	_place("bedroll.glb", Vector3(2.5, 0, -1.8), 2.3, -0.5)
	_place("barrel.glb", Vector3(2.2, 0, 1.0), 2.3, 0.0)
	# Loot, which is the one prop that says *bandits* rather than *campers*: they are
	# carrying off somebody's property and it is stacked by the fire.
	_place("box-large.glb", Vector3(3.1, 0, -2.7), 2.4, 0.4)
	_place("box.glb", Vector3(3.7, 0, -1.9), 2.2, -0.3)
	var cart := _place("cart.glb", Vector3(-3.0, 0, 1.9), 1.4, -0.8, FT)
	MarkFx.tint(cart, WALNUT)      # the kit paints its wheels blue; blue is off-palette
	_tents.append(tent)
	_tents.append(lean)
	_raise_standard()
	_ember = OmniLight3D.new()
	add_child(_ember)
	_ember.position = Vector3(0, 0.8, 0)
	_ember.light_color = EMBER
	_ember.light_energy = EMBER_DIM
	_ember.omni_range = 16.0
	_ember.shadow_enabled = false

func _place(file: String, pos: Vector3, sc: float, yaw: float, kit := SK) -> Node3D:
	var n: Node3D = (load(kit + file) as PackedScene).instantiate()
	_props.add_child(n)
	n.position = pos
	n.scale = Vector3.ONE * sc
	n.rotation.y = yaw
	return n

## The standard: a pennant on a post, out in front where the monarch rides in.
##
## **This is what makes the place a faction's camp rather than somebody's campsite.**
## Tents, a fire and bedrolls say people live here; a banner says *these* people, and
## it is the only piece that reads at the range the camp is usually first seen from.
##
## ⚠️ Tinted, and it has to be. The castle kit paints its pennants **blue**, which is
## nowhere in the palette, and the obvious alternative is worse: `banner-red` is exactly
## the burgundy the palette reserves for the monarch, so a red bandit standard would put
## the player's own colour on the enemy. Dark slate is the bandits' own cloth
## (`bandit.gd`'s Thug tint), a shade off the charcoal a burnt camp goes to.
## At 3.2x it stands **2.8 m** -- taller than the tent's 1.57 m ridge and than anything
## else in the camp, which is the point: it is the piece that has to read from outside
## the clearing, and one sized to match the tents would be lost among them.
func _raise_standard() -> void:
	var flag := _place("flag-pennant.glb", Vector3(2.4, 0, 2.4), 3.2, 0.3, CK)
	MarkFx.tint(flag, BANDIT_CLOTH)
	_tents.append(flag)          # it leans and blackens with everything else

## ⚠️ **A ragged palisade was built here and removed** (2026-08-04). Three
## `fence-broken.glb` segments on an arc across the rear, meant to say *they fortified
## this, badly*. Rendered at the play camera's 45° it says nothing of the kind: a broken
## fence is mostly gaps, so three of them 4.8 m out read as **debris scattered behind the
## tents** and made the camp look untidy rather than defended.
##
## This is `reward_site.gd`'s hermit-hut problem again -- neither kit contains a
## palisade, and no arrangement of a garden fence becomes one. If a camp ever wants a
## boundary it wants a *model*, not a composition. The standard above does the "somebody
## claimed this ground" job on its own and does it from much further off.

# ---------------------------------------------------------------- discovery

## **The camp is a rumour until you ride out to it.** On a map with no fog, the
## structures and the garrison stay hidden until the monarch has been within
## [constant DISCOVER_R], while the smoke column and the ember stay visible from
## anywhere.
##
## ⚠️ **Under fog of war none of that applies, and the reasoning that used to be
## written here is reversed.** `fog_of_war.gd` hides the whole camp -- smoke and
## ember included -- until the ground it stands on has been explored, and this
## method stands down entirely (see [method _ready]).
##
## What was argued here before, and why it no longer holds: the split existed
## because smoke said *something is out there, that way* and the dusk flare said
## *and tonight it is that one*, which was the game's only diegetic answer to
## "which way is the raid coming from" -- so a shroud that swallowed them looked
## like it would leave nothing but a quest marker.
##
## **`ISLAND_PROMPTS.md` F5 takes that job away from the smoke and gives it to the
## walls.** Once the raid bearing is rolled fresh each night across the four walls,
## regardless of where the camps are, a smoke column *cannot* forecast a raid --
## it is no longer connected to one. The lit torches do it instead, from inside
## the village, more precisely, and without the player having had to explore at
## all. So smoke reverts to what it always meant literally: *someone lives out
## there, that way* -- a scouting lead and a standing objective, not a forecast.
## Losing it to fog costs nothing the walls do not now pay back.
##
## [method flare] keeps working and keeps meaning something, but what it means is
## now *this camp is still active*, not *tonight comes from here*.
##
## Discovery is permanent either way -- ride away and the camp stays known. It is
## memory of a place, not line of sight, so there is no re-shrouding and nothing to
## re-discover on the way back with the war party.
func _check_discovery() -> void:
	var king := get_tree().get_first_node_in_group("monarch")
	if king == null:
		return
	if king.global_position.distance_to(global_position) <= DISCOVER_R:
		_reveal()

func _reveal() -> void:
	if _found:
		return
	_found = true
	if is_instance_valid(_props):
		_props.visible = true
	for b in _garrison:
		if is_instance_valid(b):
			b.visible = true

# ---------------------------------------------------------------- the garrison

## Garrison bandits are loose in the scene, not children of the camp, so they have
## to be hidden one by one and tracked to be revealed again. Hiding them is only
## cosmetic -- they keep their colliders and stay in the `bandit` group, so
## [method _defenders_near] still counts them. That costs nothing, because
## [constant DISCOVER_R] is 26 m and every engagement in the game happens inside
## 10: the camp resolves long before anything could shoot at an invisible body.
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
		b.visible = _found
		if FogOfWar.enabled():
			FogOfWar.hide_until_found(b)
		_garrison.append(b)

# ---------------------------------------------------------------- the fire

## The director stokes every live camp at dusk when a raid is coming, and lets it
## fall back to a smoulder at dawn (night_raids.gd::_flare).
##
## **A dormant camp never flares.** It still smoulders, so it is findable and still
## reads as inhabited, but the flare belongs to the camp that is actually coming --
## that is the whole signal, and a second fire answering it would erase it.
func flare(on: bool) -> void:
	if _burned or not raiding:
		return
	_ember_want = EMBER_FLARE if on else EMBER_DIM

## A slow column of smoke over the fire -- the camp's daytime beacon.
##
## The ember glow finds a camp at night; nothing found one by day, and on the real
## maps a camp stands 45-55 m out with a treeline in between, so "ride out and burn
## it" had no landmark to ride *at*. A column that clears the canopy gives the
## objective a visible bearing from anywhere in the village without a marker, a
## minimap or a quest arrow -- the same trick the flare pulls at dusk, and diegetic
## for the same reason: it is a thing in the world, not an overlay on it.
##
## Deliberately not tied to [member raiding]: both camps smoke, because smoke says
## *inhabited*, not *hostile tonight*. Telling the two apart is the flare's job.
func _smoke(delta: float) -> void:
	if _burned or _burning:
		return
	# ⚠️ A hidden camp does not smoke. The puffs are parented to the **scene**, not
	# to this node (see [method _smoke_puff] -- they must not inherit the camp's
	# transform), so `visible = false` on the camp cannot reach them: under fog of
	# war the tents vanished and the column went on rising out of black ground,
	# which is precisely the tell the fog exists to remove. On a map without fog
	# this node is always visible and the guard costs nothing.
	if not visible:
		return
	_smoke_t -= delta
	if _smoke_t > 0.0:
		return
	_smoke_t = SMOKE_EVERY * randf_range(0.8, 1.25)
	_smoke_puff()

func _smoke_puff() -> void:
	if not is_inside_tree():
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	# ⚠️ **`pixel_size` is metres per texel and `wood_chip.png` is 8x8**, so a puff is
	# *eight times* the number written here. This was 0.5-0.85 -- a **4 to 7 metre**
	# sheet, which the tween then grows to as much as 15 m -- so the camp's "column"
	# was a single brown slab the size of the clearing hanging over the tents, and the
	# 8x8 texture was magnified enough to read as blocks. 0.11-0.17 is a 0.9-1.4 m
	# puff, about twice the hermit's one-man chimney (`reward_site.gd`), which is the
	# right relationship. Measure the texture, then divide.
	var s := MarkFx.particle(MarkFx.CHIP_TEX, randf_range(0.11, 0.17))
	s.modulate = SMOKE_COLOR
	scene.add_child(s)
	var base := global_position + Vector3(randf_range(-0.4, 0.4), 1.0, randf_range(-0.4, 0.4))
	s.global_position = base
	# drifts along the wind's bearing as it climbs, so the column leans the same way
	# the trees and the rain do rather than standing in its own private calm
	var drift := Vector3(randf_range(-1.6, 1.6), 0.0, randf_range(-1.6, 1.6))
	var wind := get_tree().get_first_node_in_group("wind")
	if wind and wind.has_method("wind_dir"):
		drift = (wind.wind_dir() as Vector3) * randf_range(1.8, 3.4)
	var top := base + drift + Vector3(0, randf_range(SMOKE_RISE.x, SMOKE_RISE.y), 0)
	var life := randf_range(3.4, 5.0)
	var t := s.create_tween()
	t.tween_property(s, "global_position", top, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(s, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(s, "scale", s.scale * randf_range(1.8, 2.6), life)
	t.tween_callback(s.queue_free)

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
	# A camp can be burned without ever having been ridden up to -- `dev_burn()`
	# does exactly that -- and an undiscovered one would char, slump and flame
	# behind a hidden holder, leaving a fire with no camp under it.
	_reveal()
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
