class_name MapTerrain
## The one source of truth for map 1's shape (COMBAT_PROMPTS P1).
##
## The village sits in a mountain **U that opens to the north**: three bearings
## (south, east, west) are sealed by invisible box colliders, and a single north
## corridor is the only way in. The world stays one flat slab -- a "mountain" here
## is a rock wall standing on flat ground, not real elevation (GAME_DESIGN §9,
## and the deferral note in COMBAT_PROMPTS P1).
##
## Everything terrain-shaped reads from here so the collider boxes, the wanderer
## walk-in and the wildlife ring can never drift apart: `mountains.gd` stamps a
## collider + a dressing of rocks per [member MOUNTAINS] entry, `campfire.gd`
## walks wanderers in through [method corridor_spawn_point], and `wildlife.gd`
## stocks the forest with [method random_belly_point]. Later tasks put the bandit
## camp at [method corridor_mouth] (P3).

## Matches [constant NavWorld.EXTENT]; the bake volume and the sealed square are
## the same size on purpose, so a box inside here is a box the navmesh sees.
const EXTENT := 26.0

## Each mountain is one axis-aligned box: [code]c[/code] centre, [code]s[/code]
## full size. Their union (within [constant EXTENT]) is the sealed terrain; the
## complement is the open belly plus the north corridor. Boxes overlap at the
## corners so the U has no sliver gaps for a raider to thread. Kept low (6 m) --
## tall enough to block and to sit a rock mass on, no taller.
const MOUNTAINS := [
	{c = Vector3(0, 3, 22), s = Vector3(54, 6, 12)},     # south -- the bottom of the U
	{c = Vector3(22, 3, 1), s = Vector3(12, 6, 56)},     # east arm
	{c = Vector3(-22, 3, 1), s = Vector3(12, 6, 56)},    # west arm
	{c = Vector3(13, 3, -18), s = Vector3(10, 6, 20)},   # north-east, narrows the mouth
	{c = Vector3(-13, 3, -18), s = Vector3(10, 6, 20)},  # north-west, narrows the mouth
]

## Half-width of the corridor in x. The surviving WallSideN spans x -8..+8, so the
## mouth is exactly a wall wide and a bought wall closes it end to end.
const CORRIDOR_HALF_X := 8.0

## The wall line: the corridor is everything north (more negative z) of here.
const WALL_Z := -8.0

## Where the road runs out to -- the bandit camp's anchor and the far end of the
## wanderer walk-in. Comfortably inside [constant EXTENT] so the camp bakes.
const MOUTH_Z := -22.0

## The muster banner (P9): just outside the north gate, beside the opening, in the
## corridor -- the staging point a war party is raised at before riding out.
const MUSTER_AT := Vector3(2.5, 0.0, -10.5)

## Where a war party is raised (P9). Per-map data, like the corridor mouth.
static func muster_point() -> Vector3:
	return MUSTER_AT

## True when p sits inside any mountain box (x/z only -- the world is flat).
static func is_mountain(p: Vector3) -> bool:
	for m in MOUNTAINS:
		var c: Vector3 = m.c
		var h: Vector3 = m.s * 0.5
		if absf(p.x - c.x) <= h.x and absf(p.z - c.z) <= h.z:
			return true
	return false

## Open ground: walkable slab, not rock, inside the baked square.
static func is_open(p: Vector3) -> bool:
	return not is_mountain(p) and absf(p.x) < EXTENT and absf(p.z) < EXTENT

## True in the north corridor (in front of / beyond the wall line).
static func is_corridor(p: Vector3) -> bool:
	return absf(p.x) < CORRIDOR_HALF_X and p.z < WALL_Z

## The camp anchor at the mouth of the corridor (P3 drops the tent here).
static func corridor_mouth() -> Vector3:
	return Vector3(0, 0, MOUTH_Z)

## A spawn point up the north corridor, for wanderers walking in (and, later,
## bandits marching down). Kept off the walls so nobody spawns wedged in rock.
static func corridor_spawn_point() -> Vector3:
	return Vector3(
		randf_range(-CORRIDOR_HALF_X + 1.5, CORRIDOR_HALF_X - 1.5),
		0.0,
		randf_range(WALL_Z - 6.0, MOUTH_Z))

## A point in the forest belly around the village -- open ground on the three
## sealed sides, never in the rock and never up the corridor. Rejection-samples a
## ring so wildlife can't land inside a mountain or out on the road.
static func random_belly_point(inner: float, outer: float) -> Vector3:
	for i in 24:
		var a := randf() * TAU
		var r := randf_range(inner, outer)
		var p := Vector3(cos(a) * r, 0.0, sin(a) * r)
		# keep clear of the corridor mouth as well as the rock
		if is_open(p) and p.z > WALL_Z + 1.0:
			return p
	# fallback: due south, dead centre of the belly
	return Vector3(0.0, 0.0, clampf((inner + outer) * 0.5, 0.0, 14.0))
