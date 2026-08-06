class_name MapCatalog
## The built maps, and which one the next run uses.
##
## Four takes on **map 1** -- the same teaching job (one village, one wall you can
## afford, one fight) solved with different terrain ideas, so they can be played
## against each other rather than argued about. `ROADMAP.md` R4 keeps map 1 short
## and single-front; all of them honour that, because only one camp raids.
##
## The first three are the 2026-07 land prototypes and are held to be **temporary**
## -- Andrei removes them once he is happy with the island, and not before. The
## fourth, `flat_island`, is `ISLAND_PROMPTS.md`'s map and the one being built out.
##
## **Every map carries two camps that are nowhere near each other.** One raids: it
## sends the night waves and stokes its fire at dusk, and it is the front the wall
## is for. The other stands dormant with its garrison -- no waves, no flare, but it
## still has to be ridden out to and burned, because `game_manager.report_camp_burned`
## only clears the map when the `bandit_camp` group is empty. So the objective is
## always "burn both", while the *defensive* problem stays single-front.
##
## Scale note: these are ~110-120 m across against the old prototype's 52 m. See
## the header of [MapDef] for why.

## The id used when nothing has been chosen -- the canon shape from `GAME_DESIGN` §9.
const DEFAULT_ID := "mountain_u"

static var _maps: Array[MapDef] = []
static var _selected := ""

# ---------------------------------------------------------------- access

static func all() -> Array[MapDef]:
	if _maps.is_empty():
		_maps = [_mountain_u(), _deep_wood(), _twin_passes(), _flat_island()]
	return _maps

static func by_id(id: String) -> MapDef:
	for m in all():
		if m.id == id:
			return m
	return all()[0]

## The map the current run is played on.
##
## The choice is held in a static here *and* mirrored into `Settings` so it both
## survives the scene change into the game and is remembered next launch. The
## static is read first because autoloads are not resolvable by name inside a
## `--script` SceneTree (a documented trap in `CLAUDE.md`), and verify scripts have
## to be able to pick a map without `Settings` existing at all.
static func current() -> MapDef:
	if _selected == "":
		_selected = _from_settings()
	return by_id(_selected)

static func select(id: String) -> void:
	_selected = id
	var s := _settings()
	if s and "selected_map" in s:
		s.selected_map = id
		if s.has_method("save_settings"):
			s.save_settings()

static func selected_id() -> String:
	return current().id

static func _from_settings() -> String:
	var s := _settings()
	if s and "selected_map" in s and String(s.selected_map) != "":
		return String(s.selected_map)
	return DEFAULT_ID

## Reaches the autoload without assuming it is in scope -- see [method current].
static func _settings() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("/root/Settings")
	return null

# ---------------------------------------------------------------- map 1a

## **The Mountain U** -- the canon shape (§9), finally at full size.
##
## Three bearings sealed by rock, one 16 m corridor north, and the single WallSide
## across it. What the scale buys that the prototype could not: the corridor is a
## 26 m *journey* rather than a doorstep, and it opens into a broad northern basin
## holding both camps 50 m apart, so riding out to burn one is a real expedition
## with a return trip to plan against nightfall.
static func _mountain_u() -> MapDef:
	var m := MapDef.new()
	m.id = "mountain_u"
	m.title = "The Mountain U"
	m.blurb = "Rock on three sides, one corridor north. The clearest shape in the game: " \
		+ "one door, one wall, one fight — and a long ride to the camps beyond."
	m.extent = 58.0
	m.play_min = Vector3(-42.0, -2.0, -58.0)
	m.play_max = Vector3(42.0, 6.0, 42.0)
	m.village = Vector3.ZERO
	m.gates = [
		# the U itself -- south bottom, two long arms
		{c = Vector3(0, 3, 52), s = Vector3(124, 8, 24), kind = MapDef.ROCK},
		{c = Vector3(52, 3, -8), s = Vector3(24, 8, 140), kind = MapDef.ROCK},
		{c = Vector3(-52, 3, -8), s = Vector3(24, 8, 140), kind = MapDef.ROCK},
		# the far wall behind the basin, so the map closes at the top too
		{c = Vector3(0, 3, -68), s = Vector3(124, 8, 24), kind = MapDef.ROCK},
		# the shoulders that pinch the corridor down to 16 m
		{c = Vector3(24, 3, -27), s = Vector3(32, 8, 26), kind = MapDef.ROCK},
		{c = Vector3(-24, 3, -27), s = Vector3(32, 8, 26), kind = MapDef.ROCK},
	]
	# inside the pinch (which starts at z -14), not south of it -- a wall set where
	# the map is still 80 m wide plugs nothing and raiders simply walk round its ends
	m.walls = [{pos = Vector3(0, 0, -16), yaw = 0.0}]
	m.camps = [
		{pos = Vector3(-25, 0, -48), raiding = true},
		{pos = Vector3(25, 0, -48), raiding = false},
	]
	m.muster = Vector3(2.5, 0, -20)
	m.spawn_lane = {from = Vector3(0, 0, -20), to = Vector3(0, 0, -36), half_width = 5.5}
	m.home = AABB(Vector3(-40, -2, -13), Vector3(80, 8, 53))
	# timber runs from the village clearing right out into the basin, so depletion
	# marches the loggers up the corridor toward the camps (§9)
	m.forest = {inner = 12.0, outer = 48.0, spacing = 3.7, cap = 110, bushes = 10}
	m.understory = {spacing = 2.1, cap = 340}
	m.keep_clear = [AABB(Vector3(-10, -2, -42), Vector3(20, 8, 30))]
	return m

# ---------------------------------------------------------------- map 1b

## **The Deep Wood** -- the forest is the terrain gate, and some of it is cuttable.
##
## A small clearing walled by dense woodland with one game trail north. The two
## camps sit in pockets outside the wood, and the corners of that outer ring are
## sealed, so a camp is reachable only through the wood in front of it: the north
## camp through the trail, the west camp only by **felling the plug of harvestable
## trees in the west lane**. Cutting a road opens it for real -- `tree_resource.gd`
## drops each trunk's collider and re-bakes, so the navmesh follows the axe.
##
## ⚠️ The lane you cut is a hole you cannot wall. Raiders path to the hall through
## whatever is open, so carving west before you can hold it is a genuine risk --
## that is the concept's whole edge, and it is deliberate rather than unbalanced.
static func _deep_wood() -> MapDef:
	var m := MapDef.new()
	m.id = "deep_wood"
	m.title = "The Deep Wood"
	m.blurb = "A clearing hemmed in by forest, with one trail out. The second camp is " \
		+ "reachable only by felling a road to it — and the road you cut stays open."
	m.extent = 60.0
	m.play_min = Vector3(-46.0, -2.0, -46.0)
	m.play_max = Vector3(46.0, 6.0, 46.0)
	m.village = Vector3.ZERO
	m.gates = [
		# the wood around the clearing. The collider is only 8 m thick; the trees
		# dressing it spill much wider, so it reads as deep forest without charging
		# the navmesh (or the carve) for depth nobody walks through.
		{c = Vector3(0, 3, 21), s = Vector3(88, 8, 8), kind = MapDef.WOOD},
		{c = Vector3(21, 3, 0), s = Vector3(8, 8, 88), kind = MapDef.WOOD},
		# west side, split to leave the carve lane at z 0
		{c = Vector3(-21, 3, -23.5), s = Vector3(8, 8, 41), kind = MapDef.WOOD},
		{c = Vector3(-21, 3, 23.5), s = Vector3(8, 8, 41), kind = MapDef.WOOD},
		# north side, split to leave the trail at x 0
		{c = Vector3(-25, 3, -21), s = Vector3(38, 8, 8), kind = MapDef.WOOD},
		{c = Vector3(25, 3, -21), s = Vector3(38, 8, 8), kind = MapDef.WOOD},
		# the map edge
		{c = Vector3(0, 3, 54), s = Vector3(140, 8, 20), kind = MapDef.ROCK},
		{c = Vector3(54, 3, 0), s = Vector3(20, 8, 140), kind = MapDef.ROCK},
		{c = Vector3(-54, 3, 0), s = Vector3(20, 8, 140), kind = MapDef.ROCK},
		{c = Vector3(0, 3, -54), s = Vector3(140, 8, 20), kind = MapDef.ROCK},
		# corner spurs joining wood to edge. Without these the outer ring is one
		# continuous loop and you could stroll round to the west camp through the
		# north trail, which would make the carve lane pointless.
		{c = Vector3(-34.5, 3, -34.5), s = Vector3(26, 8, 26), kind = MapDef.WOOD},
		{c = Vector3(34.5, 3, -34.5), s = Vector3(26, 8, 26), kind = MapDef.WOOD},
		{c = Vector3(-34.5, 3, 34.5), s = Vector3(26, 8, 26), kind = MapDef.WOOD},
		{c = Vector3(34.5, 3, 34.5), s = Vector3(26, 8, 26), kind = MapDef.WOOD},
	]
	# in the trail itself (z -25..-17), so the wall's ends bury into the wood
	m.walls = [{pos = Vector3(0, 0, -19), yaw = 0.0}]
	# yaw 90 deg: the plug's rows run along +x, i.e. straight through the west wood
	m.lanes = [{pos = Vector3(-21, 0, 0), yaw = PI * 0.5, width = 6.0, depth = 8.0}]
	# 36 m out, not 31: the play camera sees ~28 m of ground past the monarch, and at
	# 31 m the north camp was visible from the village clearing itself
	m.camps = [
		{pos = Vector3(0, 0, -36), raiding = true},
		{pos = Vector3(-36, 0, 0), raiding = false},
	]
	m.muster = Vector3(2.5, 0, -22)
	m.spawn_lane = {from = Vector3(0, 0, -21), to = Vector3(0, 0, -24), half_width = 4.0}
	m.home = AABB(Vector3(-17, -2, -17), Vector3(34, 8, 34))
	# a tight clearing, so the standing timber is modest -- the lane plug is the
	# other half of this map's stock, and cutting it is both road and income
	m.forest = {inner = 10.0, outer = 16.5, spacing = 3.4, cap = 34, bushes = 8}
	m.understory = {spacing = 2.0, cap = 130}
	m.keep_clear = [AABB(Vector3(-7, -2, -26), Vector3(14, 8, 12))]
	return m

# ---------------------------------------------------------------- map 1c

## **The Twin Passes** -- one village, two doors, and only one of them hot.
##
## A rock massif splits the north approach into two 16 m passes, each with its own
## WallSide and its own camp beyond it. Because exactly one camp raids, the player
## has two walls to buy and a real question about which to buy first -- and the
## answer is readable, because **only the raiding camp stokes its fire at dusk**.
## The dormant pass is the safe road to ride out by; the other is the front.
static func _twin_passes() -> MapDef:
	var m := MapDef.new()
	m.id = "twin_passes"
	m.title = "The Twin Passes"
	m.blurb = "A rock spine splits the north into two passes, each with its own gate " \
		+ "and its own camp. Only one camp raids — read the dusk fires to learn which."
	m.extent = 60.0
	m.play_min = Vector3(-42.0, -2.0, -60.0)
	m.play_max = Vector3(42.0, 6.0, 42.0)
	m.village = Vector3.ZERO
	m.gates = [
		{c = Vector3(0, 3, 52), s = Vector3(124, 8, 24), kind = MapDef.ROCK},
		{c = Vector3(52, 3, -10), s = Vector3(24, 8, 148), kind = MapDef.ROCK},
		{c = Vector3(-52, 3, -10), s = Vector3(24, 8, 148), kind = MapDef.ROCK},
		{c = Vector3(0, 3, -70), s = Vector3(124, 8, 24), kind = MapDef.ROCK},
		# the spine between the passes, and the outer shoulder of each
		{c = Vector3(0, 3, -30), s = Vector3(24, 8, 28), kind = MapDef.ROCK},
		{c = Vector3(34, 3, -30), s = Vector3(12, 8, 28), kind = MapDef.ROCK},
		{c = Vector3(-34, 3, -30), s = Vector3(12, 8, 28), kind = MapDef.ROCK},
	]
	# inside each pass (which starts at z -16), so both flanks bury into rock:
	# the spine on the inboard side, the outer shoulder on the other
	m.walls = [
		{pos = Vector3(20, 0, -18), yaw = 0.0},    # north-east pass
		{pos = Vector3(-20, 0, -18), yaw = 0.0},   # north-west pass
	]
	m.camps = [
		{pos = Vector3(26, 0, -52), raiding = true},
		{pos = Vector3(-26, 0, -52), raiding = false},
	]
	# between the two gates, so a war party can be raised for either pass
	m.muster = Vector3(0, 0, -12)
	# wanderers walk in down the quiet pass, so recruitment and raids never share a
	# road (the lean in GAME_DESIGN §12.21)
	m.spawn_lane = {from = Vector3(-20, 0, -20), to = Vector3(-20, 0, -38), half_width = 5.0}
	m.home = AABB(Vector3(-40, -2, -15), Vector3(80, 8, 55))
	m.forest = {inner = 12.0, outer = 38.0, spacing = 3.7, cap = 100, bushes = 10}
	m.understory = {spacing = 2.1, cap = 320}
	m.keep_clear = [
		AABB(Vector3(10, -2, -46), Vector3(20, 8, 32)),
		AABB(Vector3(-30, -2, -46), Vector3(20, 8, 32)),
	]
	return m

# ---------------------------------------------------------------- map 4

## **Prototype 1 -- Flat Terrain**: a round island in open water (`ISLAND_PROMPTS.md`).
##
## The first map with **no sealed bearing at all**. The other three teach by taking
## directions away -- rock here, wood there, one corridor to hold. This one takes
## nothing away: the sea rings it, so every bearing is a bearing, and the answer is
## a wall on all four sides rather than a gate to stand in.
##
## Three things are new in the data and nowhere else:
##
## * a [member MapDef.shore] instead of `gates`, which [method MapDef.is_blocked]
##   answers off directly -- so the coast is a first-class edge and every existing
##   caller became sea-aware without an edit;
## * `half = 16.0` on each wall, four of them at radius 16, enclosing a 32x32
##   village square rather than plugging a 16 m doorway;
## * camps on the **north-south** axis with the wanderers walking in off the **east**
##   beach, so recruitment and the front never share a road (the §12.21 lean).
##
## Sizes here are placeholder and meant to be corrected by playing, like the flat-5
## hall costs -- the shore's `base` and `wobble` especially.
static func _flat_island() -> MapDef:
	var m := MapDef.new()
	m.id = "flat_island"
	m.title = "Prototype 1 — Flat Terrain"
	m.blurb = "A round island in open water. No pass to hold and no rock to hide behind — " \
		+ "the sea is the only wall the map gives you, and it faces every direction at once."
	m.extent = 108.0
	# base 88 +/- 15, which is the coast running 76-94 m. Three passes to get here,
	# all from playing it:
	#
	# * +/-5 read as **machined**. A wobble has to be a real fraction of the radius
	#   before it stops looking like a circle someone roughened, and most of the
	#   work is the k=1 term (see `MapDef.SHORE_WAVES`) pushing the whole island
	#   off-centre rather than any amount of high harmonic.
	# * base 56 put the camps 38 m out and read as **far too close** -- the land
	#   maps sit theirs 48-55 m out.
	# * base 70 was still short, so everything went up a further 25%.
	#
	# ⚠️ **This is near the ceiling.** The coast reaches 94 m and the ground slab is
	# 240 m across (±120), so there is about 25 m of headroom left. Growing past that
	# means growing the slab in `kingdom_demo.tscn` again, and it is shared by every
	# map. The bake cost of the area is real (~11 ms per 1 000 m2, measured) and is
	# why `nav_world.gd` bakes off-thread -- see its header.
	m.shore = {base = 88.0, wobble = 15.0, beach = 7.0}
	# the map the fog was designed for -- see `MapDef.fog` for why the land
	# prototypes stay unshrouded
	m.fog = true
	# walled on all four sides, so the raid bearing is a real question every night
	m.max_fronts = 2
	# The island's bounding box and **not a metre more**: measured, the coast runs
	# 76-94 m, so 96 covers every walkable square and nothing else. Baking is O(area)
	# and a round map is the worst case for a box filter -- the corners of this box
	# are already 22% pure sea nobody can stand on, and a circle cannot be trimmed
	# any further. Don't set this from `extent`: that has to clear the coast with
	# room to spare, and every spare metre here is ~11 ms a bake.
	m.play_min = Vector3(-96.0, -2.0, -96.0)
	m.play_max = Vector3(96.0, 6.0, 96.0)
	m.village = Vector3.ZERO
	m.gates = []            # supported, and deliberately empty -- the shore seals
	# Four walls, one per compass bearing, each 32 m end to end with its own gate at
	# the centre. Local +x runs along the wall, so a north/south wall takes yaw 0 and
	# an east/west one a quarter turn. Their ends meet at the four corners.
	m.walls = [
		{pos = Vector3(0, 0, -16), yaw = 0.0, half = 16.0},           # north
		{pos = Vector3(16, 0, 0), yaw = -PI * 0.5, half = 16.0},      # east
		{pos = Vector3(0, 0, 16), yaw = PI, half = 16.0},             # south
		{pos = Vector3(-16, 0, 0), yaw = PI * 0.5, half = 16.0},      # west
	]
	# 60 m out -- a **12 s ride** each way at the monarch's 5 m/s, so burning a camp
	# is an expedition planned against daylight rather than an errand. This is the
	# number the island exists to make room for: at the original base-56 shore it had
	# to sit at 38 and read as far too close, and every growth pass since has gone
	# into buying it back. `camp_clear` is 12 and the coast runs ~78 m on these
	# bearings, so the clearing still lands inside the treeline, not on the sand.
	m.camps = [
		{pos = Vector3(0, 0, -60), raiding = true},
		{pos = Vector3(0, 0, 60), raiding = false},
	]
	# **A camp stands in the wood, not in a field.** 10 rather than the default 12,
	# and the disc pushed 3.5 m toward the village: 6.5 m of clearing behind the tents
	# where the trees close in, 13.5 m in front where the fight happens. That is
	# *less* bald ground than the old concentric 12 (20 m across against 24), and all
	# of what is left is on the side the monarch rides in from.
	m.camp_clear = 10.0
	m.camp_clear_bias = 3.5
	m.muster = Vector3(2.5, 0, -20)
	# An east beach arc -- wanderers come up off the sand, not out of a treeline,
	# and on the one bearing neither camp sits on. **Where they come from at all is
	# GAME_DESIGN §12.24 and deliberately still open**; this is the lane, not the
	# answer, and it is the thing the answer will replace.
	m.spawn_lane = {from = Vector3(86, 0, -8), to = Vector3(86, 0, 8), half_width = 4.0}
	# the whole island: on a 360 degree map there is no "bandits' half" to keep the
	# wildlife out of, so `home` stops being a divider and just means "on land"
	m.home = AABB(Vector3(-98, -2, -98), Vector3(196, 8, 196))
	# inner 26 clears the walled square (its corners reach 22.6 m); the outer edge is
	# trimmed again by the beach setback in `_plantable`, so 78 is a ceiling rather
	# than a line you will ever see. The annulus is roomy enough that the cap is
	# never rejected down to -- measured, count == cap exactly -- so this is a
	# *count*, inside `ROADMAP.md` R7's 40-80 band.
	#
	# **The solid count deliberately did not grow with the island.** R7's 40-80 is
	# the run clock -- how much timber there is before the map is spent -- and that
	# should not get longer just because the map got wider. What carries "it looks
	# like a big forest" is the understory, which is collider-free and therefore
	# free to scale; it went up with the area instead. F4 tunes both for real.
	m.forest = {inner = 26.0, outer = 78.0, spacing = 3.7, cap = 80, bushes = 14}
	# **The look knob** (F4). `spacing` above is a walkability guarantee and stays at
	# 3.7; this one is free to be anything, because filler carries no collider and no
	# script -- which is the entire reason "dense to look at" and "never randomly
	# stuck" can both be true. 560 over a 17 000 m² band was one tree per 30 m², i.e.
	# a park. Tightened and raised to read as woodland.
	m.understory = {spacing = 1.9, cap = 1100}
	# **A pocket, not a paddock.** The glade ceiling was 6 m, i.e. a 12 m opening
	# round a 0.7 m bush -- enough that the berries read as the point of a clearing
	# somebody made, rather than as something growing in the wood. 3 m still holds
	# every trunk off far enough to spot one without walking into it, which is the
	# whole job (F4), and leaves the wood closed over the top of it.
	m.bush_glade = 3.0
	# **No roads, deliberately.** This map used to reserve a 12 m lane out to each
	# camp, and it read exactly as what it was: two bald strips of lawn running
	# through a wood, pointing at the thing you were supposed to find. A camp is meant
	# to be *in* the forest -- you ride through trees and it is suddenly there -- and a
	# corridor of mown grass says the opposite before you have gone ten metres.
	#
	# ⚠️ Nothing needs them, and that is particular to this map. `keep_clear` exists
	# because a stand of trees dropped in a 16 m corridor strands a land map: no
	# wanderer walks in, no raid marches out, nothing in the logs. **The island has no
	# corridors.** Raids land at the coast on a rolled bearing (`front_landing`), not
	# out of a camp; wanderers come up the east beach; and the war party paths through
	# open wood, which `forest.spacing` guarantees is walkable at 3.7 m trunk to
	# trunk. Re-add a lane here only if something starts depending on one.
	m.keep_clear = []
	# Reward sites (F6). **Five finds on five different bearings**, none of them near
	# another. The altar and the hermit used to share one clearing 13 m apart out
	# west, on the theory that two stone-and-hearth things read as a shrine precinct;
	# what it actually did was make the whole west a single destination and the other
	# three quarters chests-only. Riding to one reward and finding a second standing
	# in the same glade is one trip paying twice, which is the opposite of what an
	# ungated reward is for -- the price is supposed to be the daylight.
	#
	# So: altar due west, hermit east-south-east, and the three chests on the
	# remaining quarters. Radii run 58-63 m, varied so the set is not a ring, and
	# every one is well inside the 80-93 m coast on its own bearing. Nothing is
	# gated: on a map you can leave in every direction the price is the ride.
	#
	# ⚠️ `clear` on a chest is **4, not 7**. It is a 1 m box, and 7 m of reserved
	# ground put it at the centre of a 14 m lawn -- which reads as a landmark
	# somebody built rather than as treasure somebody hid. 4 keeps the trunks off it
	# so you can see it from a few paces; the sparkle (`reward_site.gd`) does the
	# rest of the work of being findable, and does it far better than bald grass.
	m.sites = [
		# 8, down from 11. The altar's own footprint is ~5 m across (a 3.9 m stag on a
		# plinth, columns at radius 2.5), so 8 still leaves clear ground all round it
		# and reads as a glade the shrine stands in rather than as a field it sits in
		# the middle of.
		{pos = Vector3(-58, 0, -4), kind = MapDef.ALTAR, clear = 8.0},
		{pos = Vector3(55, 0, 22), kind = MapDef.HERMIT, clear = 9.0},
		# ⚠️ Measured against the **wrecks** as well, which is easy to forget because
		# they are placed by bearing rather than by the coordinate written here. The
		# first pass put a chest 18 m off the south-west hull -- close enough to see
		# both from one spot, which makes the ride out pay twice and the map smaller.
		# Nothing non-wreck is now within 25 m of anything else.
		{pos = Vector3(26, 0, -54), kind = MapDef.CHEST, clear = 4.0},
		{pos = Vector3(30, 0, 50), kind = MapDef.CHEST, clear = 4.0},
		{pos = Vector3(-30, 0, -52), kind = MapDef.CHEST, clear = 4.0},
		# The two wrecks (F7 / §10 exit), on opposite beaches and far apart, so
		# choosing one is choosing which shore your people walk to. `yaw` lies each
		# hull along its own stretch of sand rather than at a random angle.
		{pos = Vector3(66, 0, -34), kind = MapDef.WRECK, clear = 10.0, yaw = -0.5},
		{pos = Vector3(-58, 0, 47), kind = MapDef.WRECK, clear = 10.0, yaw = 2.4},
	]
	return m
