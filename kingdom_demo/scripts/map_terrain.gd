class_name MapTerrain
## The static facade every system reads the map's shape through.
##
## This used to *be* map 1 -- a block of consts describing one mountain U. The
## layout now lives in [MapDef] values held by [MapCatalog], and this file is the
## thin layer in front of them, so `mountains.gd`, `campfire.gd`, `wildlife.gd`,
## `night_raids.gd`, `muster_banner.gd` and `bandit.gd` did not each have to learn
## that maps are selectable. They still ask `MapTerrain` where things are; they
## just get an answer that depends on what the player picked in the menu.
##
## Keeping the facade static also keeps the old guarantee: the colliders, the
## wanderer walk-in, the wildlife ring and the camps cannot drift apart, because
## there is still exactly one place that knows the shape.
##
## The world is still one flat slab -- a "mountain" is a rock wall standing on flat
## ground, not elevation.

# ---------------------------------------------------------------- the map

static func map() -> MapDef:
	return MapCatalog.current()

## Half-size of the square the map lives in.
static func extent() -> float:
	return map().extent

## The volume the navmesh bakes. Trimmed to reachable ground -- see [MapDef].
static func bake_aabb() -> AABB:
	var m := map()
	return AABB(m.play_min, m.play_max - m.play_min)

## The sealed bearings, as `{c, s, kind}` boxes. `mountains.gd` dresses these.
static func gates() -> Array[Dictionary]:
	return map().gates

## Where this map offers a `WallSide`, as `{pos, yaw}`.
static func walls() -> Array[Dictionary]:
	return map().walls

## Every camp the map starts with, as `{pos, raiding}`.
static func camps() -> Array[Dictionary]:
	return map().camps

## Carve lanes through a wood gate, as `{pos, yaw, width, depth}`.
static func lanes() -> Array[Dictionary]:
	return map().lanes

static func village() -> Vector3:
	return map().village

## Where a war party is raised.
static func muster_point() -> Vector3:
	return map().muster

# ---------------------------------------------------------------- ground tests

## True when p sits inside any sealed gate box (x/z only -- the world is flat).
static func is_blocked(p: Vector3) -> bool:
	return map().is_blocked(p)

## Open ground: walkable slab, not sealed, inside the map.
static func is_open(p: Vector3) -> bool:
	return map().is_open(p)

## Inside the village's own region, as opposed to out among the camps.
static func is_home(p: Vector3) -> bool:
	return map().is_home(p)

## Which kind of gate covers p, or "" if it is not sealed.
static func gate_kind_at(p: Vector3) -> String:
	return map().gate_kind_at(p)

## A point in the forest belly around the village -- open, home-side ground, never
## in the rock. Rejection-sampled, so wildlife can't land inside a mountain.
static func random_belly_point(inner: float, outer: float) -> Vector3:
	return map().belly_point(inner, outer)

## Where a wanderer walks in from.
static func wanderer_spawn_point() -> Vector3:
	return map().spawn_point()

# ---------------------------------------------------------------- the camps

## The raiding camp's position -- the front the wall is for, and where a dev-spawned
## bandit comes from. Falls back to the first camp if a map has no raider set.
static func raid_origin() -> Vector3:
	var raiders := map().raiding_camps()
	if not raiders.is_empty():
		return raiders[0].pos
	return map().default_camp()

## The camp nearest a point -- where a bandit routs or flees to. Reads the live
## `bandit_camp` group first so a burned camp is never run to; falls back to the
## map definition when every camp is ash (the run is over anyway, and a body still
## needs somewhere to go rather than standing in the village).
static func nearest_camp(from: Vector3, tree: SceneTree) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	if tree:
		for c in tree.get_nodes_in_group("bandit_camp"):
			if not is_instance_valid(c):
				continue
			var d: float = c.global_position.distance_to(from)
			if d < best_d:
				best_d = d
				best = c.global_position
	if best_d < INF:
		return best
	for c in map().camps:
		var d: float = (c.pos as Vector3).distance_to(from)
		if d < best_d:
			best_d = d
			best = c.pos
	return best if best_d < INF else map().village

## Close enough to a camp to count as arrived -- the despawn test for a routed
## bandit. Uses the map's camp list rather than the live group, because a bandit
## fleeing to a camp that burns mid-run still needs to be able to leave the field.
static func at_camp(p: Vector3, radius := 3.0) -> bool:
	for c in map().camps:
		if (c.pos as Vector3).distance_to(p) <= radius:
			return true
	return false
