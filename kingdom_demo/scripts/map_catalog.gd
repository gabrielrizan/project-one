class_name MapCatalog
## The built maps, and which one the next run uses.
##
## `flat_island` -- `ISLAND_PROMPTS.md`'s map -- is now the only one. The three
## 2026-07 land prototypes (`mountain_u`, `deep_wood`, `twin_passes`) that used to
## sit alongside it while the island was being proven out are gone; this file's own
## header used to say Andrei removes them once he is happy with the island, and not
## before -- that call has now been made. Their code is not worth keeping around
## for reference: `MapDef` and every reader of it (`map_terrain.gd`, `map_walls.gd`,
## `map_forest.gd`, `night_raids.gd`, ...) are generic over whatever `MapDef`s
## `all()` returns, so bringing one back is pasting the old `_mountain_u()`-shaped
## function back in, not a rewrite.
##
## **Every map carries two camps that are nowhere near each other.** One raids: it
## sends the night waves and stokes its fire at dusk, and it is the front the wall
## is for. The other stands dormant with its garrison -- no waves, no flare, but it
## still has to be ridden out to and burned, because `game_manager.report_camp_burned`
## only clears the map when the `bandit_camp` group is empty. So the objective is
## always "burn both", while the *defensive* problem stays single-front.

## The id used when nothing has been chosen.
const DEFAULT_ID := "flat_island"

static var _maps: Array[MapDef] = []
static var _selected := ""

# ---------------------------------------------------------------- access

static func all() -> Array[MapDef]:
	if _maps.is_empty():
		_maps = [_flat_island()]
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

# ---------------------------------------------------------------- the map

## **Prototype 1 -- Flat Terrain**: a round island in open water (`ISLAND_PROMPTS.md`).
##
## The land prototypes it replaced (Mountain U, Deep Wood, Twin Passes) taught by
## taking directions away -- rock here, wood there, one corridor to hold. This one
## takes nothing away: the sea rings it, so every bearing is a bearing, and the
## answer is a wall on all four sides rather than a gate to stand in.
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
