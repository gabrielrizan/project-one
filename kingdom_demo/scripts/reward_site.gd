extends StaticBody3D
## A reward the monarch rides out and takes himself (ISLAND_PROMPTS F6): a **chest**,
## the **altar**, or the **hermit**.
##
## Built on the `muster_banner.gd` template rather than any base class -- a
## `StaticBody3D` (the monarch's `InteractArea` listens for *bodies*), in the
## `interactable` group, duck-typed `show_prompt` / `hide_prompt` / `interact`. That
## is the whole interface the game has, and three more things using it is cheaper
## than a hierarchy.
##
## ## Ungated, and that is the design
##
## No portals, no risk tiers, no keys, no gating of any kind. On a map you can leave
## in every direction, **the cost of a reward is the daylight spent riding to it
## instead of building** -- which is a real price, paid in the only currency the
## monarch cannot make more of, and it needs no mechanism to enforce.
##
## ## The chest gives rather than costs, which nothing else here does
##
## Every other interactable in the game is hold-to-pay. The chest is the first that
## hands something over, so two decisions had to be made deliberately:
##
## * **No tally.** `GoldFx.pay` is the grammar of *spending*; running it backwards to
##   receive would say the wrong thing. The chest spills real `coin.tscn` coins for
##   the monarch to ride over and collect -- which already exists, already feels
##   good, and makes taking the reward a small motion rather than a transaction.
## * **The same prompt grammar all the same.** It still reads "E  Open the chest" and
##   still appears the same way at the same distance, because "walk up to a thing and
##   press E" is *the* verb (§1) and the player should not have to learn a second one
##   to find out this one is free.
##
## Every site joins `fog_hideable`, so on the island none of them exist until the
## ground they stand on has been explored. Finding them *is* the reward for scouting.

const COIN_SCENE := preload("res://kingdom_demo/scenes/coin.tscn")
const FT := "res://kingdom_demo/assets/3d/kenney_fantasy-town-kit/Models/GLB format/"
const CK := "res://kingdom_demo/assets/3d/kenney_castle-kit/Models/GLB format/"
const SK := "res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/"
## Quaternius Medieval Village Pack (CC0) -- the only assembled *buildings* in the
## project, and the same "Ultimate"-era flat-shaded style as the nature pack.
const QV := "res://kingdom_demo/assets/3d/quaternius_medieval-village/"
## Quaternius Ultimate Modular Ruins Pack (CC0) -- stone statues, columns, arches and
## a proper treasure chest. Same era and style as the nature pack.
const QR := "res://kingdom_demo/assets/3d/quaternius_modular-ruins/"

## PLACEHOLDER, like every other number in the game.
const CHEST_GOLD := 12        # spilled as loose coins, one at a time
const CHEST_RELICS := 1
const ALTAR_COST := 1         # in relics
const HERMIT_COST := 8        # in gold, through the ordinary tally

const PROMPT_Y := 2.3
const GOLD := Color(1, 0.9, 0.4)
## Lighter than "stone" sounds. A tint is flat-shaded (`MarkFx.tint` drops the
## texture), and a thin vertical post under a noon sun catches almost no direct light
## on its sides -- at 0.52 the standing stones came back near-black.
const STONE := Color(0.70, 0.68, 0.65)
const STONE_PALE := Color(0.82, 0.80, 0.76)
## Matches `HallBuilder.ROOF_TINT`, so the hermit's roof and the halls' agree.
const ROOF_SLATE := Color(0.34, 0.33, 0.35)
## The hermit is one of the game's own villagers, not a bespoke model -- see
## `_build_hut`. Drab undyed wool: he is not yours yet.
const HERMIT_MODEL := preload("res://kingdom_demo/assets/3d/characters/villager.glb")
const HERMIT_ROBE := Color(0.44, 0.38, 0.30)

# --- ambient FX ---
## Hearth smoke from the hermit's chimney. **The same job the bandit camps' column
## does**: it says *somebody lives here* from further away than the hut itself reads,
## so a hermit is a thing you notice on the horizon and ride toward rather than
## something you stumble into. Slow and sparse -- a one-man fire, not a camp.
const SMOKE_EVERY := 1.5
## ⚠️ `Sprite3D.pixel_size` is **metres per texel** and `wood_chip.png` is **8x8**, so
## the sprite is 8x whatever you write here. 0.20 is a 1.6 m sheet -- which is what
## the first two passes drew: a translucent grey tarpaulin lying over the grass, not
## a puff of smoke. Measure the texture, then divide.
const SMOKE_COLOR := Color(0.62, 0.60, 0.57, 0.7)
const SMOKE_RISE := Vector2(2.2, 3.4)
## Motes drifting up off the altar. The shrine has no animation of its own and reads
## as inert stone without them; a slow rise is enough to say the place is awake.
const MOTE_EVERY := 0.9
const MOTE_COLOR := Color(1.0, 0.92, 0.66, 0.85)
## Glints off an unopened chest -- the genre's oldest tell, and there is no reason to
## be clever about it. **Motion is what makes a chest findable, not bald ground**: it
## is the smallest thing on the map (a 1 m box) and the one you ride furthest for, and
## the alternative -- reserving a wide clearing round it -- buys visibility at the cost
## of making it look like a monument rather than something hidden. So `clear` came down
## to 4 m in `map_catalog.gd` and this took over the job.
##
## Faster and much smaller than the altar's motes: a glint is a catch of light, so it
## wants to be brief and to happen often. Slow gold billboards off a chest read as it
## being on fire.
const GLINT_EVERY := 0.26
const GLINT_COLOR := Color(1.0, 0.90, 0.52, 0.95)

## What kind of site this is -- set before `add_child`, like `BanditCamp.raiding`.
var kind := MapDef.CHEST

var _prompt: Label3D = null
var _busy := false
var _taken := false
var _hinge: Node3D = null        # the chest lid's pivot
var _heart: Node3D = null        # the altar's centre stone
var _smoke_from := Vector3.ZERO  # the hermit's chimney mouth
var _figure: Node3D = null       # the hermit standing by his fire
var _fx_t := 0.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("reward_site")

	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.6, 1.4)
	cs.shape = box
	cs.position = Vector3(0, 0.8, 0)
	add_child(cs)

	_build()

	_prompt = Label3D.new()
	_prompt.pixel_size = 0.007
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.modulate = GOLD
	_prompt.outline_modulate = Color(0.1, 0.08, 0.05)
	_prompt.font_size = 46
	_prompt.outline_size = 12
	_prompt.position = Vector3(0, PROMPT_Y, 0)
	_prompt.visible = false
	add_child(_prompt)

	FogOfWar.hide_until_found(self)
	NavWorld.rebake(self)

# ---------------------------------------------------------------- the look

## ⚠️ **Every model here was measured before it was used**, and every scale below is
## chosen against a **1.2 m villager** rather than guessed. The kits are wildly
## inconsistent -- `pillar-stone.glb` is 1.00 m tall, `chest.glb` is 26 cm, and
## `fountain-round-detail.glb` is a 2 m ring -- so a shared "looks about right"
## multiplier produces a shrine of doll's-house furniture. The F5 lanterns cost two
## passes to this exact mistake.
##
## Kit attributions from a brief are not reliable either: `pillar-stone.glb` is in
## the **fantasy town** kit, not the castle kit, and there is no `crate.glb` at all.
## Read the directory, then measure, then build.
func _build() -> void:
	match kind:
		MapDef.ALTAR:
			_build_altar()
		MapDef.HERMIT:
			_build_hut()
		_:
			_build_chest()

## A stone circle on a raised ring: `fountain-round-detail` is a 2 m circular stone
## basin, which at 1.4x makes a 2.8 m plinth, and `pillar-stone` uprights standing on
## its rim make the rest. Composed from kit modules at runtime for the same reason
## `HallBuilder` composes the halls -- there is no "shrine" model in any kit, and
## four pieces arranged deliberately read as built rather than as bought.
func _build_altar() -> void:
	# A **stone stag on a plinth**, ringed by columns and standing on paved squares --
	# Quaternius Ultimate Modular Ruins (CC0). Andrei's brief said "maybe altars are
	# some stone statues", and this is that, from a pack rather than kit-bashed.
	#
	# The stag rather than the fox because it is the animal this island already has:
	# `wildlife.gd` puts stags in the wood, so the shrine is a monument to something
	# the player has actually seen. It is 4.63 m as authored, so 0.85x makes it a
	# ~3.9 m monument against a 1.2 m villager -- big enough to ride toward.
	for i in 4:
		var tile := MarkFx.model(load(QR + "Floor_Squares.fbx"), 1.0)
		add_child(tile)
		tile.position = Vector3(-1.0 + float(i % 2) * 2.0, 0.02, -1.0 + float(i / 2) * 2.0)
	_heart = MarkFx.model(load(QR + "Statue_Stag.fbx"), 0.85)
	add_child(_heart)
	_heart.position = Vector3(0, 0.1, 0)
	# four columns at the corners, so it reads as a built place rather than a statue
	# somebody left in a field
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI * 0.25
		var col := MarkFx.model(load(QR + "Column_Round.fbx"), 0.7)
		add_child(col)
		col.position = Vector3(cos(a) * 2.5, 0.05, sin(a) * 2.5)
	# a low warm glow, so the shrine is findable at night without being a beacon
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.86, 0.60)
	light.light_energy = 1.1
	light.omni_range = 7.0
	light.shadow_enabled = false
	add_child(light)
	light.position = Vector3(0, 2.2, 0)

## The hermit's house, built by [HallBuilder] -- the same composer the village halls
## use, so his hut is recognisably a building of this world rather than a prop. 2x2
## and one storey is the smallest thing it can make: a one-room cabin.
func _build_hut() -> void:
	# **An actual house** (Quaternius Medieval Village, CC0). `House_1` is 3.39 m as
	# authored -- ground floor, upper storey and a pitched tiled roof -- so 1.15x
	# makes a 3.9 m cottage against a 1.2 m villager.
	#
	# ⚠️ **`House_3` and `House_4` are roofless base pieces**, not small houses,
	# despite being in the Buildings folder: 2.09 m and 1.07 m tall, and they render
	# as an open-topped stone box. Measure told me the heights but not what they
	# *were*; only looking at it did.
	#
	# Three earlier attempts composed this from the Kenney kits and all three read as
	# a packing crate, because **neither kit contains a house** -- the fantasy town
	# kit's only assembled buildings are a windmill and two watermills. That was an
	# asset problem the whole time, not a composition one, and no amount of arranging
	# modular wall panels was going to fix it.
	var hut := MarkFx.model(load(QV + "House_1.fbx"), 1.15)
	add_child(hut)
	hut.rotation.y = PI          # front door toward the village side
	# **The one off-palette thing about this pack**: Quaternius roofs it in teal,
	# which from this camera is the swimming-pool read `CLAUDE.md` records against
	# the fantasy town kit. Repainted slate, the same colour `HallBuilder` gives the
	# village halls, so every roof in the game agrees. Not burgundy -- the palette
	# keeps red for the monarch.
	MarkFx.repaint(hut, {"RoofTiles": ROOF_SLATE})
	_smoke_from = Vector3(-0.85, 4.3, 0.65)     # the chimney head
	# a lit fire outside it, and something to sit on: a house nobody uses is a shed
	var fire := MarkFx.model(load(QV + "Bonfire_Lit.fbx"), 2.4)
	add_child(fire)
	fire.position = Vector3(2.2, 0.0, 1.5)
	var bench := MarkFx.model(load(QV + "Bench_1.fbx"), 1.8)
	add_child(bench)
	bench.position = Vector3(3.4, 0.0, 0.4)
	bench.rotation.y = -1.2
	# **The hermit himself**, standing by his fire.
	#
	# He is a `villager.glb` and not some special model, because that is exactly what
	# he is about to become: a citizen. The game's whole cast is this one body with
	# different tools worn over it (`villager.gd::_set_model`), and a hermit who
	# arrived in a bespoke silhouette would read as a quest NPC rather than as one
	# more pair of hands. Tinted a drab hooded brown so he is *a* villager rather
	# than one of yours, and untinted the moment he joins.
	_figure = MarkFx.model(HERMIT_MODEL, 1.0)
	add_child(_figure)
	_figure.position = Vector3(1.4, 0.0, 1.9)
	_figure.rotation.y = -2.3
	MarkFx.tint(_figure, HERMIT_ROBE)

## A real treasure chest (Quaternius Modular Ruins, CC0): `Chest_Gold` is 1.18 m as
## authored -- already the right size, no scaling guesswork -- and carries separate
## `DarkWood` / `Wood` / `Metal` / `Gold` materials, so it reads as banded and
## strapped rather than as a painted box.
##
## The lid is the whole model tipped back about its rear edge: the pack has no open
## variant and no separate lid mesh, and a hinge is only a pivot node.
func _build_chest() -> void:
	_hinge = Node3D.new()
	add_child(_hinge)
	_hinge.position = Vector3(0, 0, -0.42)
	var chest := MarkFx.model(load(QR + "Chest_Gold.fbx"), 0.85)
	_hinge.add_child(chest)
	chest.position = Vector3(0, 0, 0.42)

# ---------------------------------------------------------------- ambient FX

## ⚠️ Puffs are parented to the **scene**, not to this node -- they must not inherit
## its transform -- so `visible = false` under fog cannot reach them. The guard is the
## same one `bandit_camp.gd::_smoke` carries, and for the same reason: without it an
## unexplored hermit smokes out of black ground, which is exactly the tell the fog
## exists to remove.
func _process(delta: float) -> void:
	if not visible:
		return
	_fx_t -= delta
	if _fx_t > 0.0:
		return
	match kind:
		MapDef.HERMIT:
			_fx_t = SMOKE_EVERY * randf_range(0.75, 1.3)
			_puff(_smoke_from, SMOKE_COLOR, randf_range(0.055, 0.075),
				randf_range(SMOKE_RISE.x, SMOKE_RISE.y), 1.4, 3.2)
		MapDef.ALTAR:
			_fx_t = MOTE_EVERY * randf_range(0.7, 1.4)
			var a := randf() * TAU
			var r := randf_range(0.2, 1.3)
			_puff(Vector3(cos(a) * r, 1.0, sin(a) * r), MOTE_COLOR,
				randf_range(0.016, 0.028), randf_range(1.6, 2.6), 0.35, 2.4)
		_:
			# **A chest sparkles until it is opened, and then never again.** The open
			# lid is the landmark afterwards; a spent chest that still twinkles is a
			# reward the player rides back across the map to collect twice.
			if _taken:
				set_process(false)
				return
			_fx_t = GLINT_EVERY * randf_range(0.55, 1.6)
			var a := randf() * TAU
			var r := randf_range(0.15, 0.8)
			# `spread` is tiny, so the wind branch of `_puff` barely moves them -- a
			# glint belongs to the chest, unlike smoke, which belongs to the weather.
			_puff(Vector3(cos(a) * r, randf_range(0.4, 0.95), sin(a) * r), GLINT_COLOR,
				randf_range(0.010, 0.020), randf_range(0.6, 1.1), 0.12, 1.0)

## One rising billboard. Drifts on the wind's bearing like every other column in the
## game, so the shrine and the hearth lean the same way the trees and the rain do.
func _puff(local_at: Vector3, color: Color, px: float, rise: float,
		spread: float, life: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var s := MarkFx.particle(MarkFx.CHIP_TEX, px)
	s.modulate = color
	scene.add_child(s)
	s.global_position = to_global(local_at)
	var drift := Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread, spread))
	var wind := get_tree().get_first_node_in_group("wind")
	if wind and wind.has_method("wind_dir"):
		drift = (wind.wind_dir() as Vector3) * spread * randf_range(0.7, 1.4)
	var top := s.global_position + drift + Vector3(0, rise, 0)
	var t := s.create_tween()
	t.tween_property(s, "global_position", top, life).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(s, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(s, "scale", s.scale * randf_range(1.5, 2.3), life)
	t.tween_callback(s.queue_free)

# ---------------------------------------------------------------- interaction

func show_prompt() -> void:
	if _busy or _taken:
		return
	_prompt.text = _prompt_text()
	_prompt.visible = true

func hide_prompt() -> void:
	if is_instance_valid(_prompt):
		_prompt.visible = false

## Kept terse: a world-space `Label3D` is physically large, and a prompt a few words
## too long lies across half the village (CLAUDE.md).
func _prompt_text() -> String:
	match kind:
		MapDef.ALTAR:
			return "Hold E  Altar (%d %s)" % [ALTAR_COST, GameManager.RELIC_NAME]
		MapDef.HERMIT:
			return "Hold E  Hermit (%d)" % HERMIT_COST
		_:
			return "E  Open"

func interact(who: Node3D) -> void:
	if _busy or _taken:
		return
	match kind:
		MapDef.ALTAR:
			await _take_altar(who)
		MapDef.HERMIT:
			await _take_hermit(who)
		_:
			_open_chest(who)

# ---- chest ----

## Free, and the monarch's alone. Spills loose coins he rides over to pick up --
## `coin.gd::pop` and `collect_to` already do exactly this for a cancelled purchase,
## so the gesture is one the player has already learned.
func _open_chest(who: Node3D) -> void:
	_taken = true
	hide_prompt()
	var scene := get_tree().current_scene
	if scene == null:
		return
	for i in CHEST_GOLD:
		var c := COIN_SCENE.instantiate()
		scene.add_child(c)
		c.global_position = global_position + Vector3(0, 0.8, 0)
		var a := randf() * TAU
		var landing := global_position + Vector3(cos(a), 0, sin(a)) * randf_range(0.9, 2.2)
		landing.y = 0.12
		c.pop(landing)
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("add_relics"):
		gm.add_relics(CHEST_RELICS)
	MarkFx.debris(self, global_position + Vector3(0, 0.6, 0), Vector3.UP, 10,
		Color(0.85, 0.72, 0.38, 0.95), 0.022, 1.0)
	# the lid swings back on its hinge and stays there. **The chest is not removed**:
	# a spent site is a landmark, and a thing that vanishes when you touch it reads
	# as a pickup rather than as a place you found.
	if is_instance_valid(_hinge):
		var t := create_tween()
		t.tween_property(_hinge, "rotation:x", deg_to_rad(-105.0), 0.42) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# a short breath of gold out of the open lid, so the burst has somewhere to
	# come from rather than simply appearing
	for i in 7:
		_puff(Vector3(randf_range(-0.3, 0.3), 0.7, randf_range(-0.3, 0.3)),
			Color(1.0, 0.86, 0.42, 0.9), randf_range(0.018, 0.030),
			randf_range(1.1, 1.9), 0.5, 1.3)

# ---- altar ----

## Costs a relic and grants one permanent kingdom-wide blessing. **One per site, and
## exactly one altar on the map** -- the set stays fixed at two rewards, because this
## is not a tech tree and must not become one (Pillar 4).
func _take_altar(who: Node3D) -> void:
	var gm := get_tree().get_first_node_in_group("game_manager")
	if gm == null or gm.relics < ALTAR_COST:
		return
	_busy = true
	hide_prompt()
	gm.spend_relics(ALTAR_COST)
	_taken = true
	_busy = false
	Blessings.grant(get_tree())
	MarkFx.debris(self, global_position + Vector3(0, 1.8, 0), Vector3.UP, 14,
		Color(0.92, 0.86, 0.62, 0.95), 0.022, 1.4)
	# the centre stone answers: a squash-pulse, which is how a *model* flashes in
	# this game (a 3D mesh has no `modulate` -- CLAUDE.md), plus a column of motes
	if is_instance_valid(_heart):
		MarkFx.hit_flash(self, _heart)
	for i in 14:
		var a := randf() * TAU
		_puff(Vector3(cos(a) * randf_range(0.1, 1.4), 0.6, sin(a) * randf_range(0.1, 1.4)),
			Color(1.0, 0.94, 0.72, 0.95), randf_range(0.018, 0.032),
			randf_range(3.0, 4.6), 0.3, 2.6)

# ---- hermit ----

## Costs gold through the ordinary tally, because hiring is spending and should feel
## like it. He joins as a citizen who **bends exactly one rule** (`GAME_DESIGN.md`
## §9) -- see [Blessings].
func _take_hermit(who: Node3D) -> void:
	if not GoldFx.can_afford(HERMIT_COST):
		return
	_busy = true
	hide_prompt()
	var ok: bool = await GoldFx.pay(who, self, HERMIT_COST, 2.2)
	_busy = false
	if not ok:
		if is_instance_valid(who) and global_position.distance_to(who.global_position) < 3.5:
			show_prompt()
		return
	_taken = true
	# he takes his own colours off and walks in: the tint goes, and he is a villager
	# like any other. Actually *spawning* him into the workforce is future work --
	# the blessing is what he brings, and the model here is him leaving for the fire.
	if is_instance_valid(_figure):
		MarkFx.untint(_figure)
		var walk := create_tween()
		walk.tween_property(_figure, "position",
			_figure.position + Vector3(0, 0, 6.0), 3.2).set_trans(Tween.TRANS_SINE)
		walk.parallel().tween_property(_figure, "scale", Vector3.ZERO, 3.2).set_delay(2.2)
		walk.tween_callback(_figure.queue_free)
	Blessings.grant_hermit(get_tree())
	MarkFx.debris(self, global_position + Vector3(0, 1.2, 0), Vector3.UP, 10,
		Color(0.78, 0.73, 0.62, 0.95), 0.02, 0.9)
