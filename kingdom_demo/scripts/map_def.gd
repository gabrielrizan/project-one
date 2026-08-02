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

## Where a `WallSide` is offered, as `{pos, yaw}`. A wall runs its local x from
## -8 to +8 (`wall_side.gd::HALF`) with the gate at its centre, so an opening wants
## to be ~16 m across and the wall placed just inside it. **A closed bearing carries
## no entry at all** -- that is the §11 rule that every wall you can buy is one that
## can matter.
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

## True when p sits inside any sealed gate box (x/z only -- the world is flat).
func is_blocked(p: Vector3) -> bool:
	for g in gates:
		var c: Vector3 = g.c
		var h: Vector3 = g.s * 0.5
		if absf(p.x - c.x) <= h.x and absf(p.z - c.z) <= h.z:
			return true
	return false

## Open ground: walkable slab, not sealed, inside the map.
func is_open(p: Vector3) -> bool:
	return not is_blocked(p) and absf(p.x) < extent and absf(p.z) < extent

## Which kind of gate covers p ([constant ROCK] / [constant WOOD]), or "" if the
## point is not sealed at all. Lets the decor tell rock from wood, so scenery trees
## are never planted up the face of a mountain.
func gate_kind_at(p: Vector3) -> String:
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

## The solid, harvestable trees, scattered evenly across the band.
##
## **Blue noise, not clumps and not a grid.** Dart-throwing with a minimum-distance
## rule gives the one distribution that reads as natural: no two trunks closer than
## `forest.spacing`, but no lattice regularity either. Stands were tried first and
## looked like blobs of trees separated by suspiciously empty lawn.
##
## Radius is drawn with `sqrt(u)`, which is uniform *by area* -- sampling the radius
## linearly would crowd the middle of the band and thin the outside, which is a
## subtle version of the same unevenness.
##
## Deterministic for a given seed, so a map is the same place every time you play it.
func forest_points(rng: RandomNumberGenerator) -> Array[Vector3]:
	return forest_grid(rng)[0]

## The decorative canopy, woven in among the solid trees.
##
## Takes the grid the harvestable pass filled, so filler keeps a respectful distance
## from a trunk (no sprite growing out of a markable tree) while packing tightly
## against its own kind. Collider-free, so density here is free of consequence.
func understory_points(rng: RandomNumberGenerator, grid: Dictionary) -> Array[Vector3]:
	return _scatter(rng, grid, maxf(6.0, forest.inner - 6.0), float(forest.outer) + 4.0,
		float(understory.spacing), int(understory.cap), 1.0)

## Dart-throwing scatter with a shared exclusion grid.
##
## `grid` maps a coarse cell to the points in it, each carrying the clearance it
## demands of everyone else; a candidate must satisfy **both** its own gap and the
## gap of every neighbour it finds. One grid therefore handles two populations with
## different spacing rules without either needing to know about the other, and the
## neighbour test stays O(1) instead of O(points).
func _scatter(rng: RandomNumberGenerator, grid: Dictionary, inner: float, outer: float,
		gap: float, cap: int, pad: float) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	if cap <= 0:
		return pts
	var cell := maxf(gap, 2.0)
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
		_grid_add(grid, cell, p, gap)
		pts.append(p)
	return pts

func _cell_of(p: Vector3, cell: float) -> Vector2i:
	return Vector2i(int(floor(p.x / cell)), int(floor(p.z / cell)))

## True when p is far enough from everything already placed nearby. Checks the 3x3
## block of cells around p, which covers every point that could possibly be within
## the largest clearance in play.
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

## The grid the harvestable pass built, so the understory pass can respect it.
func forest_grid(rng: RandomNumberGenerator) -> Array:
	var grid := {}
	var pts := _scatter(rng, grid, forest.inner, forest.outer,
		float(forest.spacing), int(forest.cap), 2.0)
	return [pts, grid]

## Berry bushes, in closer than the timber -- archers forage by daylight and should
## not have to cross the map to do it.
func bush_points(rng: RandomNumberGenerator) -> Array[Vector3]:
	var pts: Array[Vector3] = []
	for i in int(forest.bushes):
		for tries in 40:
			var a := rng.randf() * TAU
			var r := rng.randf_range(9.0, maxf(11.0, forest.inner + 8.0))
			var p := village + Vector3(cos(a) * r, 0.0, sin(a) * r)
			if is_open(p) and is_home(p) and _plantable(p, 3.0) and _spaced(pts, p, 4.0):
				pts.append(p)
				break
	return pts

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
		if p.distance_to(wp) < 10.0 + pad:
			return false
	if p.distance_to(muster) < 4.0 + pad:
		return false
	for box in keep_clear:
		if p.x >= box.position.x and p.x <= box.position.x + box.size.x \
				and p.z >= box.position.z and p.z <= box.position.z + box.size.z:
			return false
	# room to fight in around a camp -- see [member camp_clear]
	for c in camps:
		if p.distance_to(c.pos) < camp_clear:
			return false
	return p.distance_to(village) > 8.0 + pad

func _spaced(pts: Array[Vector3], p: Vector3, gap: float) -> bool:
	for q in pts:
		if q.distance_to(p) < gap:
			return false
	return true
