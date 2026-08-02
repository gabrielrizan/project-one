class_name MapCatalog
## The built maps, and which one the next run uses.
##
## Three takes on **map 1** -- the same teaching job (one village, one wall you can
## afford, one fight) solved with three different terrain ideas, so they can be
## played against each other rather than argued about. `ROADMAP.md` R4 keeps map 1
## short and single-front; all three honour that, because only one camp raids.
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
		_maps = [_mountain_u(), _deep_wood(), _twin_passes()]
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
