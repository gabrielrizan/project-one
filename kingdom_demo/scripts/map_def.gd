class_name MapDef
extends RefCounted
## The shape of one playable map, as data.
##
## Everything that used to be hard-coded in `map_terrain.gd` for the single
## prototype map lives here instead, so a map is a *value* the game is handed
## rather than a set of constants compiled into the terrain script. [MapCatalog]
## holds the built ones and [MapTerrain] is the static facade the rest of the game
## still reads through -- no caller outside those three files knows maps are
## swappable.
##
## **Scale is real, not prototype.** The old map was a 26 m half-extent square: the
## camp sat 22 m from the fire, which is four seconds' ride, so "march out and burn
## a camp" had no journey in it. These maps run 55-60 m half-extent (~110-120 m
## across), putting a camp ~45-55 m out -- 9-11 s at the monarch's 5 m/s. That is
## far enough that riding to a camp is an expedition you plan around daylight, and
## it is what the 40-80 resource trees of `ROADMAP.md` R7 need room to spread over.
##
## Two conventions worth knowing before editing a layout:
## * A **gate** is one axis-aligned box that seals a bearing, exactly as before --
##   the navmesh bakes from static collision, so one hidden box closes a direction
##   with no per-prop bookkeeping. `kind` only changes what gets *drawn* on it.
## * The world is still **one flat slab**. A "mountain" is a rock wall standing on
##   flat ground; there is no elevation anywhere.

## A gate dressed as rock: a ridge of stone peaks (the original mountain look).
const ROCK := "rock"
## A gate dressed as dense woodland. Same solid box -- the trees standing on it are
## scenery, so a wood is as impassable as a cliff and costs the navmesh no more.
## What makes a wood *different* is that its [member lanes] can be cut through.
const WOOD := "wood"
## Open sea, past the coastline. **Nothing is drawn on it** -- unlike ROCK and WOOD
## this kind dresses nothing, it only seals. `mountains.gd` stamps a ring of
## invisible boxes tangent to the shore under it, because a map with no gates has
## nothing else holding anybody in: `monarch.gd` carries no bounds clamp anywhere,
## so on every existing map the only thing that stops him riding off the 180 m slab
## is a gate collider. The sea has to be as physical as a cliff.
const WATER := "water"

var id := ""
var title := ""
## One line for the menu: what this map's shape asks of the player.
var blurb := ""

## Half-size of the square the map lives in. Bounds checks use it; the navmesh uses
## the tighter [member play_min] / [member play_max] box instead.
var extent := 58.0

## The volume the navmesh actually bakes, in world space. Deliberately *not* a
## square around the origin: baking is O(area) at a 0.15 m cell, and these maps are
## ~5x the old one's area, so the bake is trimmed to the ground units can really
## reach. Everything outside is sealed rock or wood nobody paths through.
var play_min := Vector3(-42.0, -2.0, -60.0)
var play_max := Vector3(42.0, 6.0, 44.0)

## The sealed bearings. Each entry is `{c = centre, s = full size, kind = ROCK/WOOD}`.
## Boxes are meant to **overlap at the corners** so a bearing has no sliver gap for
## a raider to thread -- the same rule the first map's U followed.
var gates: Array[Dictionary] = []

## The coastline, or `{}` for a landlocked map.
##
## `{base, wobble, beach}` -- a base radius about the origin plus a deterministic
## low-frequency wobble in theta, so the island reads as round without reading as
## machined. `beach` is how wide the sand ring is, and doubles as the setback no
## resource may be planted inside (a tree standing in the surf).
##
## **No rng anywhere in it.** The shore is pure geometry of theta, which is the
## only reason the collider ring, the water mesh, the beach and every plantability
## test can each compute it independently and still agree to the millimetre.
##
## The whole coastline design is one line: [method is_blocked] answers true past
## it. `is_open`, `gate_kind_at`, `_plantable`, `_scatter`, `belly_point`,
## `wildlife.gd` and `world_decor.gd` all already ask that predicate, so they
## became sea-aware without an edit between them. There is deliberately **no
## parallel "is this water" concept** for callers to learn.
var shore := {}

## Whether this map is played under fog of war (`fog_of_war.gd`).
##
## **Per map, not global.** The three land prototypes are laid out to be *read* --
## a corridor you can see is a corridor you understand -- and shrouding them would
## be arguing with the thing each was built to demonstrate. The island is the map
## the fog was designed for, where exploring in every direction is the point.
var fog := false

## How many walls a night's raid may come at **at once** (ISLAND_PROMPTS F5).
##
## The three land maps have one hot bearing by construction -- a corridor, a trail,
## a pair of passes with one camp behind each -- so 1 leaves them exactly as they
## were. The island is walled on all four sides and rolls its fronts fresh each
## night, so it takes 2: enough that "which wall?" is a real question, few enough
## that the answer is still an answer (`ROADMAP.md` R4 wants map 1 readable).
var max_fronts := 1

## Reward sites the monarch rides out to (ISLAND_PROMPTS F6): `{pos, kind, clear}`.
##
## `kind` is one of [constant CHEST], [constant ALTAR] or [constant HERMIT]; `clear`
## is how much ground the site keeps free of trees, honoured by [method _plantable]
## exactly the way [member camp_clear] is -- a reward you cannot see from two paces
## away is not a reward, it is a scavenger hunt.
##
## **Ungated on purpose.** No portals, no risk tiers, no keys. On a 360-degree map
## the cost of a reward is simply the daylight spent riding to it instead of
## building, which is a real price and needs no mechanism to enforce.
var sites: Array[Dictionary] = []

const CHEST := "chest"
const ALTAR := "altar"
const HERMIT := "hermit"
## A beached wreck: the §10 map exit (F7). Rebuilt by a crew, then rung.
const WRECK := "wreck"

## Where a raid marching on `wall` comes ashore, in world space.
##
## On a map with a **shore** the raiders come in off the sea on that bearing, which
## needs no camp on that side to justify it and is the whole reason the bearing can
## be rolled at random. On a landlocked map there is no such thing, and the caller
## falls back to marching them out of a camp exactly as before -- so this returns
## the village when asked, and `night_raids.gd` takes the hint.
func front_landing(wall: Dictionary) -> Vector3:
	if not has_shore():
		return village
	var out: Vector3 = (wall.pos as Vector3) - village
	out.y = 0.0
	if out.length() < 0.01:
		out = Vector3(0, 0, -1)
	var theta := atan2(out.z, out.x)
	# a little inside the waterline, so they wade up the sand rather than spawning
	# on the collider ring and shoving against it
	var r := shore_at(theta) - beach_width() * 0.5
	return Vector3(cos(theta) * r, 0.0, sin(theta) * r)

## A point on the sand at bearing `theta`, halfway across the beach.
##
## Used to seat the wrecks (F7): "a wreck lies on the beach" is a rule, so it is
## resolved against [method shore_at] at spawn rather than written into the map as a
## coordinate that would go stale the first time the coast is retuned.
func beach_point(theta: float) -> Vector3:
	var r := shore_at(theta) - beach_width() * 0.45
	return Vector3(cos(theta) * r, 0.0, sin(theta) * r)

## The shore's wobble, as harmonics in theta. Fixed phases, sharing no common
## factor, and amplitudes summing to 1.0 so `shore.wobble` really is the peak
## deviation in metres.
##
## **`k = 1` is the one that stops it reading as a circle**, and it was missing
## from the first pass. Two, three and five lobes are all *symmetric* about the
## origin, so however many you stack the outline stays a rounded polygon with the
## village dead in the middle of it; a single k = 1 term pushes the whole island
## off-centre and turns it into a shape with a long side and a short one. The
## higher harmonics then only have to break up the edge rather than carry it.
##
## Nothing here is high frequency, and it should stay that way: at a 56 m radius,
## k = 7 is a 50 m bay. Scalloping -- an edge that reads as a broken mesh rather
## than as a coast -- does not start until k is in the thirties.
const SHORE_WAVES := [
	{k = 1.0, amp = 0.34, phase = 0.9},
	{k = 2.0, amp = 0.24, phase = 2.1},
	{k = 3.0, amp = 0.18, phase = 4.3},
	{k = 5.0, amp = 0.13, phase = 0.4},
	{k = 7.0, amp = 0.11, phase = 3.1},
]

## Where a `WallSide` is offered, as `{pos, yaw, half}`. A wall runs its local x
## from -`half` to +`half` with the gate at its centre, so an opening wants to be
## `2 * half` across and the wall placed just inside it. `half` defaults to
## `wall_side.gd`'s own 8.0; the island sets 16.0 so four walls enclose a 32x32
## village instead of a doorway. **A closed bearing carries no entry at all** --
## that is the §11 rule that every wall you can buy is one that can matter.
var walls: Array[Dictionary] = []

## Bandit camps, as `{pos, raiding}`. Exactly one is expected to be `raiding`: it is
## the only one that sends night waves and the only one whose fire flares at dusk.
## The other stands with its garrison as a second objective to ride out and burn.
var camps: Array[Dictionary] = []

## Where the muster banner stands -- outside the wall, on the side the war party
## rides out from.
var muster := Vector3.ZERO

## Carve lanes: a gap left in a WOOD gate, plugged with **harvestable** trees.
## Felling them opens the lane, because `tree_resource.gd::_fell()` drops the
## collider and re-bakes the navmesh -- so "cut a road through the forest" is
## already true in the engine and needs no new mechanic.
##
## `{pos, yaw, width, depth}`; trees are packed at [constant PLUG_SPACING].
var lanes: Array[Dictionary] = []

## Where the village stands. Everything economic is placed relative to it.
var village := Vector3.ZERO

## The region the village economy lives in (xz; y ignored) -- wildlife, berry
## bushes and the wanderer walk-in all stay inside it. Keeps a stag from spawning
## out in the bandits' half of the map where nothing could ever reach it.
var home := AABB(Vector3(-40, -2, -14), Vector3(80, 8, 54))

## The **solid, harvestable** trees and the bushes:
## `{inner, outer, spacing, cap, bushes}`.
##
## `spacing` is the minimum distance between two trunks and it is a **walkability
## guarantee, not a style choice**. A trunk's collider is 0.5 m in radius and the
## navmesh erodes by a 0.3 m agent radius either side, so two trunks closer than
## ~1.6 m leave a gap that *looks* walkable and is not -- which is precisely how a
## villager or the monarch ends up wedged against nothing. At the spacing used here
## every gap is over 2 m of genuinely clear ground.
##
## An earlier version placed these in **stands** (clumps with travel between). It
## read as blobs with dead space rather than as woodland, so they are now scattered
## evenly by blue noise -- see [method forest_points].
var forest := {inner = 12.0, outer = 46.0, spacing = 3.7, cap = 105, bushes = 10}

## The **decorative canopy** woven between the harvestable trees:
## `{spacing, cap}`.
##
## This is what makes a wood look like a wood. It can be packed far tighter than the
## solid trees because **it carries no collider at all** (the rule `nav_world.gd`
## already relies on: scenery is walked through and the navmesh keeps it that way),
## so no amount of it can ever trap anybody. Density and passability are therefore
## independent knobs, which is the only reason "dense forest" and "never randomly
## stuck" can both be true.
##
## Set `cap` to 0 for a bare, sparse look -- that is the one dial that switches
## between the two options on the table.
var understory := {spacing = 2.1, cap = 300}

## No tree of either kind stands this close to a camp.
##
## A camp needs room to fight in: the assault is a squad of archers shooting a
## garrison, and trees in among the tents mean blocked shots, bodies pathing round
## trunks and a payoff you cannot see. It doubles as the visual cue that a camp is a
## *place* -- a clearing someone made.
var camp_clear := 12.0

## How far the camp's clearing is pushed **toward the village**, in metres.
##
## A disc centred on the camp gives a camp sitting in the middle of a bald circle,
## which reads as a camp in a field rather than a camp in a wood. Offsetting the
## same disc puts the tents at the *back* of their clearing with the trees closing
## in behind them, and all the open ground on the side the monarch arrives from --
## so the fighting ground is in front of the camp, where the fight happens, and the
## clearing is not one metre bigger for it.
##
## ⚠️ It is a **shift, not an extension**: `camp_clear - camp_clear_bias` is what is
## left behind the tents, so the two have to be read together. Below about 6 the
## trees start growing through the tent, which is `bandit_camp.gd`'s deepest piece
## at ~4 m back from centre.
##
## 0 on the land prototypes, which keeps their layouts exactly as they were.
var camp_clear_bias := 0.0

## Where a camp's clearing is actually centred -- see [member camp_clear_bias].
##
## `night_raids.gd` turns the camp to face the same way, so the tent's mouth and the
## open ground agree. A camp at the village itself (there is none, but the maths has
## to answer) keeps its clearing concentric.
func camp_clearing_centre(camp: Dictionary) -> Vector3:
	var pos: Vector3 = camp.pos
	if camp_clear_bias <= 0.0:
		return pos
	var home := village - pos
	home.y = 0.0
	if home.length() < 0.01:
		return pos
	return pos + home.normalized() * camp_clear_bias

## Where wanderers walk in from: `{from, to, half_width}`, a lane they appear along.
var spawn_lane := {from = Vector3.ZERO, to = Vector3.ZERO, half_width = 5.0}

## Regions no resource tree may be planted in (xz; y ignored).
##
## These are the map's **arteries** -- a corridor, a pass, the trail through a wood.
## They are open ground, so the outward-biased forest would happily drop a stand in
## one, and a stand that happens to seal a 16 m corridor strands the entire map:
## no wanderer walks in, no raid marches down, and nothing in the logs says why.
## Cheaper to reserve the ground than to detect the failure.
var keep_clear: Array[AABB] = []

## Trees this far apart in a lane plug leave no walkable gap. A tree's collider is
## 0.5 m in radius and the navmesh erodes by a 0.3 m agent radius on each side, so
## anything over ~1.6 m centre-to-centre opens a path -- measured off `tree.tscn`
## and `nav_world.gd::AGENT_RADIUS`, not guessed. Rows are staggered on top of this
## so there is no diagonal slip-through either.
const PLUG_SPACING := 1.35

# ---------------------------------------------------------------- queries

## True on a map that has a coastline at all -- see [member shore].
func has_shore() -> bool:
	return not shore.is_empty()

## The coast's distance from the origin at bearing `theta` (radians, `atan2(z, x)`).
## Landlocked maps answer [member extent], so callers need no special case.
func shore_at(theta: float) -> float:
	if shore.is_empty():
		return extent
	var s := 0.0
	for w in SHORE_WAVES:
		s += float(w.amp) * sin(float(w.k) * theta + float(w.phase))
	return float(shore.get("base", extent)) + float(shore.get("wobble", 0.0)) * s

## How wide the sand runs, and how far inland nothing may be planted.
func beach_width() -> float:
	return float(shore.get("beach", 0.0)) if has_shore() else 0.0

## True out past the coastline. Always false on a landlocked map.
##
## Point generation needs this on its own: rejecting by [method is_blocked] would
## also reject the ROCK and WOOD gates, which is exactly where the backdrop
## scenery is *supposed* to stand.
func beyond_shore(p: Vector3) -> bool:
	if shore.is_empty():
		return false
	return Vector2(p.x, p.z).length() >= shore_at(atan2(p.z, p.x))

## True when p sits inside any sealed gate box (x/z only -- the world is flat),
## or out past the shore -- the sea is as solid as a cliff.
func is_blocked(p: Vector3) -> bool:
	if beyond_shore(p):
		return true
	for g in gates:
		var c: Vector3 = g.c
		var h: Vector3 = g.s * 0.5
		if absf(p.x - c.x) <= h.x and absf(p.z - c.z) <= h.z:
			return true
	return false

## Open ground: walkable slab, not sealed, inside the map.
func is_open(p: Vector3) -> bool:
	return not is_blocked(p) and absf(p.x) < extent and absf(p.z) < extent

## Which kind of gate covers p ([constant ROCK] / [constant WOOD] /
## [constant WATER]), or "" if the point is not sealed at all. Lets the decor tell
## rock from wood, so scenery trees are never planted up the face of a mountain --
## or, now, floating out at sea.
func gate_kind_at(p: Vector3) -> String:
	if beyond_shore(p):
		return WATER
	for g in gates:
		var c: Vector3 = g.c
		var h: Vector3 = g.s * 0.5
		if absf(p.x - c.x) <= h.x and absf(p.z - c.z) <= h.z:
			return String(g.get("kind", ROCK))
	return ""

## True inside the village's own region -- used to keep wildlife and wanderers on
## the home side rather than out among the camps.
func is_home(p: Vector3) -> bool:
	return p.x >= home.position.x and p.x <= home.position.x + home.size.x \
		and p.z >= home.position.z and p.z <= home.position.z + home.size.z

## A point in the forest belly around the village: open, home-side ground.
## Rejection-samples a ring, and falls back to the village itself rather than
## returning something inside a mountain.
func belly_point(inner: float, outer: float) -> Vector3:
	for i in 32:
		var a := randf() * TAU
		var r := randf_range(inner, outer)
		var p := village + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if is_open(p) and is_home(p):
			return p
	return village + Vector3(0, 0, inner)

## Where a wanderer appears, somewhere along the walk-in lane.
func spawn_point() -> Vector3:
	var from: Vector3 = spawn_lane.from
	var to: Vector3 = spawn_lane.to
	var hw: float = spawn_lane.half_width
	var along := from.lerp(to, randf())
	var dir := (to - from)
	dir.y = 0.0
	# offset across the lane, not along it, so nobody lands inside its edge wall
	var side := Vector3(-dir.z, 0.0, dir.x).normalized() if dir.length() > 0.01 else Vector3.RIGHT
	return along + side * randf_range(-hw, hw)

## The camps that actually raid. Read live from the definition; whether a camp is
## still standing is the `bandit_camp` group's business, not this file's.
func raiding_camps() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c in camps:
		if c.get("raiding", false):
			out.append(c)
	return out

## The far end of the map from the village -- where a routed bandit runs to when it
## has no camp of its own to head for.
func default_camp() -> Vector3:
	if camps.is_empty():
		return village
	return camps[0].pos

# ---------------------------------------------------------------- forest layout

## The **most** clear ground a berry bush may claim around itself.
##
## **"You can spot a bush without hunting for it" is one of the two things this
## map's wood is for** (ISLAND_PROMPTS F4), and it is not something density tuning
## can deliver -- a bush under a closed canopy is a bush you find by walking into
## it, at any density. So bushes are scattered **first** and registered in the
## shared grid demanding far more room than their own size, which makes every
## other tree, solid and filler alike, keep back. Each bush ends up in a small
## glade of its own, which reads as a clearing someone forages in.
##
## ⚠️ A **ceiling, not a value** -- the real one is scaled to the wood it is being
## cut out of by [method _bush_rules]. Taken literally on a small map it is
## catastrophic: six 6 m glades come to 680 m² of clearing, and `deep_wood`'s entire
## forest ring is 540, so the bushes ate the wood and the map went from 30 trees to
## 9. Anything that reserves ground has to be a fraction of the ground available.
var bush_glade := 6.0

## The most of the forest band that all the glades together may reserve.
const GLADE_SHARE := 0.25

## What a solid trunk asks of *other* populations, as against `forest.spacing`,
## which is what it asks of its own kind.
##
## The two are different numbers on purpose. Trunk-to-trunk spacing is a
## **walkability guarantee** and has to stay wide; what filler needs is only to not
## grow out of a markable tree, and holding it a full trunk-spacing away would bore
## a bald ring round every tree the player can actually sell.
var solid_demand := 2.4

## Plan all three tree populations in one pass, against one shared exclusion grid.
##
## **The order is the design.** Bushes claim their glades first, then the solid
## harvestable trees fill the wood around them, then the filler packs into whatever
## is left. Run the other way round -- which is how this used to work, as three
## independent calls -- and the wood simply closes over the berries.
##
## Returns `{bushes, solid, filler}`.
func forest_plan(rng: RandomNumberGenerator) -> Dictionary:
	# One cell for the whole grid, sized to the largest clearance in play.
	#
	# ⚠️ This was a real bug, not a tidy-up. `_scatter` used to derive the cell from
	# its own gap, so the solid pass keyed the grid at 3.7 m and the filler pass read
	# the same dictionary at 2.1 -- different keys for the same ground, so the filler
	# **never saw a single solid tree** and the "no sprite growing out of a markable
	# trunk" guarantee documented here was not happening at all. Nothing can share a
	# spatial hash unless it agrees on the bucket size.
	var rules := _bush_rules()
	var cell := maxf(float(rules.glade),
		maxf(float(forest.spacing), float(understory.spacing))) + 0.1
	var grid := {}
	var bushes := _bush_scatter(rng, grid, cell, rules)
	var solid := _scatter(rng, grid, cell, forest.inner, forest.outer,
		float(forest.spacing), solid_demand, int(forest.cap), 2.0)
	var filler := _scatter(rng, grid, cell, maxf(6.0, forest.inner - 6.0),
		float(forest.outer) + 4.0, float(understory.spacing),
		float(understory.spacing), int(understory.cap), 1.0)
	return {bushes = bushes, solid = solid, filler = filler}

## Dart-throwing scatter with a shared exclusion grid.
##
## Every point carries **two** clearances: `gap`, which it wants from its own kind,
## and `demand`, which it asks of everyone who comes later. A candidate must satisfy
## its own gap *and* the demand of every neighbour it finds, so one grid handles
## three populations with different rules and none of them has to know about the
## others. The neighbour test stays O(1) rather than O(points).
func _scatter(rng: RandomNumberGenerator, grid: Dictionary, cell: float,
		inner: float, outer: float, gap: float, demand: float, cap: int,
		pad: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	if cap <= 0:
		return pts
	for attempt in cap * 40:
		if pts.size() >= cap:
			break
		var a := rng.randf() * TAU
		var r := lerpf(inner, outer, sqrt(rng.randf()))
		var p := village + Vector3(cos(a) * r, 0.0, sin(a) * r)
		if not is_open(p) or not _plantable(p, pad):
			continue
		if not _grid_clear(grid, cell, p, gap):
			continue
		_grid_add(grid, cell, p, demand)
		pts.append(p)
	return pts

func _cell_of(p: Vector3, cell: float) -> Vector2i:
	return Vector2i(int(floor(p.x / cell)), int(floor(p.z / cell)))

## True when p is far enough from everything already placed nearby. Checks the 3x3
## block of cells around p, which covers every point that could possibly be within
## the largest clearance in play -- **provided `cell` is at least that clearance**,
## which is why [method forest_plan] derives one cell for every population rather
## than letting each pass pick its own.
func _grid_clear(grid: Dictionary, cell: float, p: Vector3, gap: float) -> bool:
	var c := _cell_of(p, cell)
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			var key := Vector2i(c.x + dx, c.y + dz)
			if not grid.has(key):
				continue
			for e in grid[key]:
				if p.distance_to(e.p) < maxf(gap, float(e.gap)):
					return false
	return true

func _grid_add(grid: Dictionary, cell: float, p: Vector3, gap: float) -> void:
	var key := _cell_of(p, cell)
	if not grid.has(key):
		grid[key] = []
	grid[key].append({p = p, gap = gap})

## Berry bushes, in closer than the timber -- archers forage by daylight and should
## not have to cross the map to do it.
##
## Runs **first** of the three populations and registers each bush in the shared
## grid demanding a glade of clearance, which is what puts every one of them in an
## opening. Retries hard rather than skipping: there are only a dozen or so, and
## coming out three short is visible where a missing filler tree is not.
func _bush_scatter(rng: RandomNumberGenerator, grid: Dictionary, cell: float,
		rules: Dictionary) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for i in int(forest.bushes):
		for tries in 80:
			var a := rng.randf() * TAU
			var r := rng.randf_range(float(rules.band_in), float(rules.band_out))
			var p := village + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if is_open(p) and is_home(p) and _plantable(p, 3.0) \
					and _spaced(pts, p, float(rules.sep)):
				_grid_add(grid, cell, p, float(rules.glade))
				pts.append(p)
				break
	return pts

## Where bushes go and how much room they take, **scaled to the wood they are being
## cut out of** rather than fixed.
##
## Two numbers, both derived from the forest band's area against the bush count:
##
## * `sep`, how far apart bushes stand. On a big map they should be spread, so
##   foraging takes an archer somewhere; on a small one they have to pack or they
##   will not fit at all.
## * `glade`, capped at [member bush_glade] and at a fraction of `sep` -- glades that
##   overlap are not glades, and glades that add up to more than the forest are how
##   `deep_wood` lost two thirds of its trees.
##
## The band runs across most of the forest, not just its inner lip: the old fixed
## 9-34 m ring put every bush on the island in one tight annulus round the walls.
func _bush_rules() -> Dictionary:
	var inner := float(forest.inner)
	var outer := float(forest.outer)
	var n := maxf(1.0, float(forest.bushes))
	var area := PI * maxf(1.0, outer * outer - inner * inner)
	# the spacing at which `n` bushes would just fill the band, taken down by half
	# so they are spread without being a lattice.
	#
	# ⚠️ The **ceiling is what makes them look scattered**, and 12 was too high. It
	# only ever bound on the island, whose band is big enough that the formula asks
	# for 19 -- and a minimum separation that large against 14 bushes is no longer a
	# minimum, it is a lattice: every bush as far from its neighbours as it can get,
	# which is the one arrangement random placement never produces. At 8 the odd pair
	# falls near each other and the rest do not, which is what random looks like.
	var sep := clampf(sqrt(area / n) * 0.55, 3.6, 8.0)
	# ...and cap the glades at a quarter of the wood between them. `sep` alone was
	# not enough of a brake: `deep_wood` still lost a third of its trees, because
	# eight 3.6 m glades reserve 325 m² of a 540 m² ring. Solving `n·pi·r² <=
	# GLADE_SHARE·area` is the only form of this that cannot eat a small map, and on
	# a big one it is slack enough that `bush_glade` is what actually binds.
	var by_share := sqrt(GLADE_SHARE * area / (n * PI))
	return {
		band_in = maxf(6.0, inner - 4.0),
		band_out = maxf(inner + 2.0, outer * 0.85),
		sep = sep,
		glade = minf(bush_glade, minf(sep * 0.8, by_share)),
	}

## The trees that plug one carve lane, in a staggered grid across it.
func lane_plug_points(lane: Dictionary) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	var pos: Vector3 = lane.pos
	var yaw: float = lane.yaw
	var w: float = lane.width
	var d: float = lane.depth
	var across := Vector3(cos(yaw), 0.0, -sin(yaw))
	var along := Vector3(sin(yaw), 0.0, cos(yaw))
	var cols := maxi(2, int(round(w / PLUG_SPACING)))
	var rows := maxi(2, int(round(d / PLUG_SPACING)))
	for r in rows:
		# stagger every other row by half a spacing so there is no straight
		# diagonal gap between trunks for the navmesh to squeeze a path through
		var off := 0.5 * PLUG_SPACING if r % 2 == 1 else 0.0
		for c in cols:
			var u := (float(c) - float(cols - 1) * 0.5) * PLUG_SPACING + off
			var v := (float(r) - float(rows - 1) * 0.5) * PLUG_SPACING
			if absf(u) > w * 0.5 + 0.1:
				continue
			pts.append(pos + across * u + along * v)
	return pts

# ---------------------------------------------------------------- helpers

## Somewhere a resource may stand: clear of the wall lines and their gateways (so a
## bought wall never lands on a tree, and a felled tree never leaves a hole in the
## palisade), clear of the muster banner, out of the village itself, and out of the
## map's arteries.
func _plantable(p: Vector3, pad: float) -> bool:
	for w in walls:
		var wp: Vector3 = w.pos
		# the gateway itself, which wants room for traffic either side of it...
		if p.distance_to(wp) < 10.0 + pad:
			return false
		# ...and a corridor along the whole run. A disc around the centre was enough
		# while every wall was 16 m end to end; at `half` 16 it leaves the outer
		# two thirds of the line unprotected, and a tree felled out of the middle of
		# a palisade is a hole you cannot wall.
		if _dist_to_wall(w, p) < 5.0 + pad:
			return false
	if p.distance_to(muster) < 4.0 + pad:
		return false
	for box in keep_clear:
		if p.x >= box.position.x and p.x <= box.position.x + box.size.x \
				and p.z >= box.position.z and p.z <= box.position.z + box.size.z:
			return false
	# room to fight in around a camp, and it is room **on the village side** -- see
	# [member camp_clear_bias]
	for c in camps:
		if p.distance_to(camp_clearing_centre(c)) < camp_clear:
			return false
	# ...and room to *see* around a reward site -- see [member sites]
	for s in sites:
		if p.distance_to(s.pos) < float(s.get("clear", 8.0)):
			return false
	# nothing grows in the sand. The setback is the beach's own width, so the ring
	# of sand and the tree line can never disagree about where the wood stops.
	if has_shore():
		var edge := shore_at(atan2(p.z, p.x)) - beach_width() - pad
		if Vector2(p.x, p.z).length() > edge:
			return false
	return p.distance_to(village) > 8.0 + pad

## How far p lies from a wall's *run*, not from its centre. The run is the segment
## `pos ± half` along the wall's local x, which `yaw` turns into world space.
func _dist_to_wall(w: Dictionary, p: Vector3) -> float:
	var pos: Vector3 = w.pos
	var yaw := float(w.get("yaw", 0.0))
	var half := float(w.get("half", 8.0))
	# rotation about +Y sends local +X to (cos yaw, 0, -sin yaw)
	var along := Vector3(cos(yaw), 0.0, -sin(yaw))
	var d := clampf((p - pos).dot(along), -half, half)
	return p.distance_to(pos + along * d)

func _spaced(pts: Array[Vector3], p: Vector3, gap: float) -> bool:
	for q in pts:
		if q.distance_to(p) < gap:
			return false
	return true
