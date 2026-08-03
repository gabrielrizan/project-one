class_name NavWorld
extends NavigationRegion3D
## The one navmesh the whole map walks on.
##
## It is baked from the world's *static collision*, so anything solid is
## automatically an obstacle -- trees, bushes, huts, finished walls -- with no
## per-object bookkeeping. Nothing here knows what a tree is.
##
## The map changes as the village grows, so the mesh is re-baked on demand:
## whoever puts a collider up or takes one down calls [method NavWorld.rebake]
## and carries on. Requests inside the same moment are folded into one bake
## (lighting the campfire raises three buildings at once).
##
## ## The bake runs on a **background thread**
##
## It used to be synchronous, which was defensible while a map was 8 400 m2 and a
## bake was ~90 ms. The island is 15 400 m2 and bakes in ~170 ms -- ten frames of
## dead screen, **every time a tree falls**, which is the single most common thing
## a worker does. Measured across all four maps the cost is a flat ~11 ms per
## 1 000 m2 of bake volume, so it is the map's *area* that is expensive and no
## amount of tuning the map's edges was ever going to help.
##
## Threading does not make it cheaper. It makes it not the frame's problem: the
## call returns immediately and Recast finishes on its own thread, then
## `bake_finished` fires and the region swaps the new mesh in. Two things follow
## from that and both are easy to get wrong:
##
## * **The gates stay lifted until `bake_finished`.** They are disabled so a shut
##   gate is not baked as a wall across the only gap in the palisade. Re-enabling
##   them on the next line worked when the next line ran after Recast; with a
##   thread it runs *before* Recast has looked at anything, and the village bakes
##   sealed.
## * **`surface_offset` is measured in the callback**, not after the call, because
##   until the thread finishes the mesh is still the old one.
##
## A rebake requested while one is already running is remembered and run after --
## `bake_navigation_mesh` on a region that is mid-bake is not something to invite.
##
## There is no runtime obstacle avoidance: units path around what was standing
## when the mesh was last baked. See `GAME_DESIGN.md` for where this is headed.

const GROUP := "nav_region"
## What the baker sweeps for geometry. Our parent joins it, so everything in the
## scene below us is source geometry -- including things added at runtime.
const SOURCE_GROUP := "nav_source"

## Requests that land within this long of each other are folded into one bake.
const REBAKE_DELAY := 0.15

## Fallback bake half-extent, used only if no map is resolvable (a bare test
## harness). The real volume comes from the selected map -- see [method _configure].
const EXTENT := 26.0

## The baker rounds the agent radius *up* to whole cells, so the cell size decides
## how tightly the mesh can hug a collider. At the 0.25 default a 0.35 radius
## became 0.5, which walled off a ring around every obstacle that villagers can
## physically stand in -- and berry bushes drop their coins 0.5-0.9m out, i.e.
## straight into it. Archers then circled the bush forever trying to reach gold
## the navmesh said was out of bounds. 0.15 keeps the erosion within a hair of the
## body radius. It costs bake time; see [method _bake].
const CELL_SIZE := 0.15

## Villagers are capsules of radius 0.28; two cells of clearance is the nearest
## the mesh can sit without letting them clip a corner they don't fit through.
## It has to stay under half the gate opening (1.0) or the navmesh would pinch
## the gateway shut and seal the village.
const AGENT_RADIUS := 0.3
const AGENT_HEIGHT := 1.5

## Draws every unit's current path and prints when one can't be found.
## Toggled with F3 in-game; see [NavMover].
static var debug := false

## How far the baked walkable surface floats above the ground the bodies stand on.
##
## Recast lays its polygons on top of the voxel column rather than on the collider
## face, so the mesh comes out a couple of cell heights high. Bodies are at y = 0,
## so without accounting for it a unit never gets close enough to a waypoint to
## count it as reached and stalls on the spot, one step into its path. Every agent
## carries it as `path_height_offset`; see [NavMover]. Measured after each bake
## rather than assumed, so changing the cell height can't quietly break walking.
static var surface_offset := 0.0

## The physics frame from which paths mean anything -- see [method is_ready].
static var _ready_frame := -1

var _dirty := false
var _timer := 0.0
## A bake is on the thread right now. Guards against overlapping bakes and against
## the gates going back up before Recast has read them.
var _baking := false
## Gate colliders held down for the bake in flight -- see the file header.
var _lifted: Array[CollisionShape3D] = []
var _bake_started := 0

func _ready() -> void:
	add_to_group(GROUP)
	get_parent().add_to_group(SOURCE_GROUP)
	bake_finished.connect(_on_bake_finished)
	# The scene carries an empty NavigationMesh purely so the editor doesn't warn
	# that the region has none -- the settings below are the real ones, and they
	# are here rather than in the .tscn so they sit next to the reasoning.
	if navigation_mesh == null:
		navigation_mesh = NavigationMesh.new()
	_configure(navigation_mesh)
	_bake()

## Baked from static collision alone: if a thing is solid, units walk round it,
## and nothing has to register itself as an obstacle. Note this rules out the
## decorative forest and rocks, which carry no collider -- they are scenery you
## walk through today and the navmesh keeps it that way.
func _configure(m: NavigationMesh) -> void:
	m.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	m.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	m.geometry_source_group_name = SOURCE_GROUP
	m.agent_radius = AGENT_RADIUS
	m.agent_height = AGENT_HEIGHT
	# The world is one flat slab, so nothing is meant to be climbed and both of
	# these want to be as small as they go. They are not cosmetic: Recast measures
	# climb in whole cells, and at the old 0.25 cell / 0.5 climb a 0.7m berry bush
	# came out exactly two cells tall -- i.e. a step villagers could walk up. The
	# bush vanished from the mesh, peasants heading for the cauldron were routed
	# straight over it, and then bounced off collision that was still there.
	# A doorstep of climb keeps every short obstacle solid.
	m.cell_height = 0.1
	m.agent_max_climb = 0.2
	# Recast calls any flat top with headroom above it walkable, turning bush and
	# hut roofs into little floating islands. They are disconnected so nobody can
	# path onto one, and every realistic goal is at ground level, but filtering
	# ledges clears most of them for nothing.
	m.filter_ledge_spans = true
	# How far the mesh may cut a corner when it simplifies its outlines. The 3.0
	# default is nearly half a metre of licence, which was enough to erase a berry
	# bush from the mesh entirely -- so villagers heading for the cauldron were
	# routed clean through one, then bounced off its collision and shuffled back
	# and forth against it all day. The navmesh has to agree with what physics
	# blocks; anything solid and small needs this tight to survive baking.
	m.edge_max_error = 1.0
	# The map has to agree with the mesh -- a navmesh whose cell size disagrees
	# with the NavigationServer map it lives on produces paths that skim through
	# corners, and Godot warns about it. Set both from the one constant.
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, CELL_SIZE)
	NavigationServer3D.map_set_cell_height(map, m.cell_height)
	m.cell_size = CELL_SIZE
	# The ground slab is far bigger than any map; without this we would bake a
	# third of a million cells of empty grass nobody will ever stand on. The y
	# range is trimmed to what actually stands here (ground at 0, tallest tree
	# ~6.5 m) because a fine cell height otherwise pays for empty sky.
	#
	# **Taken from the selected map, not from a constant.** Baking is O(area) at a
	# 0.15 m cell -- measured at a flat ~11 ms per 1 000 m2 across every map -- so
	# the volume is trimmed to the ground units can actually reach rather than to a
	# square around the origin. Everything outside it is sealed rock, wood or sea.
	# A round map is the worst case for a box filter: the island's corners are 22%
	# open water nobody can stand on, and there is no way to trim a circle. That is
	# what pushed the bake onto a thread (see the file header) -- a coarser cell is
	# still not the lever, because CELL_SIZE is 0.15 to fix a real bug.
	m.filter_baking_aabb = MapTerrain.bake_aabb()

## F3 turns the path lines and the pathfinding log on and off.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_F3:
		debug = not debug
		print("[nav] debug %s" % ("on" if debug else "off"))

func _process(delta: float) -> void:
	if not _dirty:
		return
	_timer -= delta
	if _timer <= 0.0:
		_dirty = false
		_bake()

# ---- asking for a re-bake ----

## False until the first mesh is baked *and* the server has synced it. Before
## that every query comes back empty and every destination looks unreachable,
## which would bury the real reports under a screenful of startup noise.
static func is_ready() -> bool:
	return _ready_frame >= 0 and Engine.get_physics_frames() > _ready_frame

## Call after putting a collider up or taking one down. Static so callers don't
## have to hold a reference -- the region finds itself through its group, the
## same way everything else in this project wires up.
static func rebake(from: Node) -> void:
	var region := from.get_tree().get_first_node_in_group(GROUP)
	if region:
		region.request_rebake()

func request_rebake() -> void:
	_dirty = true
	_timer = REBAKE_DELAY

# ---- baking ----

## Kick a bake off onto the thread. Returns straight away; the work lands in
## [method _on_bake_finished]. See the file header for why the gates and the
## surface measurement have to wait for it.
func _bake() -> void:
	if _baking:
		# already running -- re-arm so the change that just came in is not lost
		request_rebake()
		return
	_baking = true
	_lifted = _lift_gates()
	_bake_started = Time.get_ticks_msec()
	bake_navigation_mesh(true)

func _on_bake_finished() -> void:
	_baking = false
	for c in _lifted:
		c.disabled = false
	_lifted.clear()
	surface_offset = _measure_surface()
	if _ready_frame < 0 and navigation_mesh.get_polygon_count() > 0:
		_ready_frame = Engine.get_physics_frames() + 1
	if debug:
		print("[nav] baked %d polys in %d ms off-thread (surface +%.2f)"
			% [navigation_mesh.get_polygon_count(),
				Time.get_ticks_msec() - _bake_started, surface_offset])

## The ground is one flat slab and everything walks on it, so the lowest polygon
## in the mesh is that slab -- and how far it sits above y = 0 is the offset every
## agent needs. Recast also leaves little walkable islands on the flat roofs of
## huts and walls; they are unreachable from the ground and cost nothing, but they
## are why this takes the lowest vertex rather than an average.
func _measure_surface() -> float:
	var verts := navigation_mesh.get_vertices()
	if verts.is_empty():
		return 0.0
	var lowest := INF
	for v in verts:
		lowest = minf(lowest, v.y)
	return lowest

## A shut gate is a solid box filling the only gap in its wall. Baked in, it
## would seal the village and no villager would ever find a way out again -- so
## gates come down for the bake and go back up in [method _on_bake_finished],
## **not on the next line**: the bake is threaded, so the next line runs long
## before Recast has read any geometry. They swing open for anyone walking up to
## them anyway, which is exactly what the path assumes.
func _lift_gates() -> Array[CollisionShape3D]:
	var lifted: Array[CollisionShape3D] = []
	for w in get_tree().get_nodes_in_group("wall_side"):
		if not w.has_method("gate_collision"):
			continue
		var c: CollisionShape3D = w.gate_collision()
		if c and not c.disabled:
			c.disabled = true
			lifted.append(c)
	return lifted
