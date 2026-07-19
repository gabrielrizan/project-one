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
## (lighting the campfire raises three buildings at once), and the bake itself is
## synchronous -- the map is small and a predictable navmesh is worth more here
## than shaving a frame.
##
## There is no runtime obstacle avoidance: units path around what was standing
## when the mesh was last baked. See `GAME_DESIGN.md` for where this is headed.

const GROUP := "nav_region"
## What the baker sweeps for geometry. Our parent joins it, so everything in the
## scene below us is source geometry -- including things added at runtime.
const SOURCE_GROUP := "nav_source"

## Requests that land within this long of each other are folded into one bake.
const REBAKE_DELAY := 0.15

## Half the square we bake. Comfortably past everything gameplay reaches: the
## palisade at 8, the tree line at 15, the wildlife ring at 17, and the wanderers
## who walk in from 19. The forest beyond that is scenery with no collision, so
## there is nothing out there to bake.
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

func _ready() -> void:
	add_to_group(GROUP)
	get_parent().add_to_group(SOURCE_GROUP)
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
	# the ground slab is 100x100; without this we would bake a third of a million
	# cells of empty grass nobody will ever stand on
	# y range trimmed to what actually stands here (ground at 0, tallest tree ~2.6)
	# because a finer cell height would otherwise pay for empty sky
	m.filter_baking_aabb = AABB(
		Vector3(-EXTENT, -2.0, -EXTENT),
		Vector3(EXTENT * 2.0, 8.0, EXTENT * 2.0))

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

func _bake() -> void:
	var lifted := _lift_gates()
	var t := Time.get_ticks_msec()
	bake_navigation_mesh(false)
	for c in lifted:
		c.disabled = false
	surface_offset = _measure_surface()
	if _ready_frame < 0 and navigation_mesh.get_polygon_count() > 0:
		_ready_frame = Engine.get_physics_frames() + 1
	if debug:
		print("[nav] baked %d polys in %d ms (surface +%.2f)"
			% [navigation_mesh.get_polygon_count(), Time.get_ticks_msec() - t, surface_offset])

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
## gates come down for the bake and go straight back up. They swing open for
## anyone walking up to them anyway, which is exactly what the path assumes.
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
