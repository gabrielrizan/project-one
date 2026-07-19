class_name NavMover
extends RefCounted
## Turns "I want to get to that point" into "step this way", by asking the
## navmesh instead of pointing the body straight at the goal.
##
## Everything that walks owns one: villagers now, enemies when there are any.
## It hands back a flat unit vector, which is exactly what the old straight-line
## steering produced -- so a caller swaps `(goal - position).normalized()` for
## [method direction_to] and keeps the rest of its movement code.
##
## Paths are only recomputed when the goal actually moves, so an archer stalking
## a bolting stag doesn't ask for a fresh path sixty times a second.

## How far a goal has to drift before it is worth a new path...
const REPATH_MOVE := 0.6
## ...or how long, for a goal that is creeping along under the threshold.
const REPATH_EVERY := 0.5
const SAME_GOAL := 0.05
## A goal further than this from the nearest walkable footing is genuinely out of
## reach, rather than just something you stand next to -- see [method _report].
const UNREACHABLE_BY := 2.0

const DEBUG_COLOR := Color(1.0, 0.85, 0.25, 0.9)
const DEBUG_Y := 0.15   # lift the line clear of the grass

var _agent: NavigationAgent3D
var _body: Node3D
var _goal := Vector3.ZERO
var _has_goal := false
var _repath_t := 0.0
var _line: MeshInstance3D = null

func _init(agent: NavigationAgent3D, body: Node3D) -> void:
	_agent = agent
	_body = body

# ---- steering ----

## Flat unit vector toward the next corner of the path to `goal`, or ZERO when
## the navmesh has nothing further to offer -- either we are at the end of the
## path, or no path could be found. Callers treat ZERO as "steer yourself".
func direction_to(goal: Vector3, delta: float) -> Vector3:
	if not is_instance_valid(_agent):
		return Vector3.ZERO
	# The baked surface floats above the ground the body stands on, and the agent
	# measures "have I reached this waypoint yet" in all three axes -- so it has to
	# be told, or it decides it has never arrived anywhere. See [NavWorld].
	if not is_equal_approx(_agent.path_height_offset, NavWorld.surface_offset):
		_agent.path_height_offset = NavWorld.surface_offset
	var fresh := _retarget(goal, delta)
	# forces the agent to compute the path, so the checks below see this frame's
	var finished := _agent.is_navigation_finished()
	if NavWorld.debug:
		if fresh:
			_report(goal)
		_draw_path()
	elif is_instance_valid(_line):
		_line.visible = false
	if finished:
		return Vector3.ZERO
	var to := _agent.get_next_path_position() - _body.global_position
	to.y = 0.0
	return to.normalized() if to.length() > 0.001 else Vector3.ZERO

## True when this call asked the server for a new path.
func _retarget(goal: Vector3, delta: float) -> bool:
	_repath_t -= delta
	if _has_goal:
		var moved := _goal.distance_to(goal)
		if moved < SAME_GOAL:
			return false                        # standing goal -- the path still holds
		if moved < REPATH_MOVE and _repath_t > 0.0:
			return false                        # drifting goal -- not yet worth redoing
	_has_goal = true
	_goal = goal
	_repath_t = REPATH_EVERY
	_agent.target_position = goal
	return true

## Only ever called when the goal changed, so it can't spam the log frame by frame.
##
## Note that a goal *inside* something solid is the normal case, not a failure:
## the cauldron, a tree and a berry bush are all things you walk up to rather than
## stand on, and the path correctly stops at arm's length. Only complain when the
## nearest footing is further off than any of those reaches.
func _report(goal: Vector3) -> void:
	if not NavWorld.is_ready():
		return                                  # nothing is reachable before the first bake
	var path := _agent.get_current_navigation_path()
	if path.is_empty():
		print("[nav] %s: pathfinding failed for %v" % [_body.name, goal])
		return
	var end := path[path.size() - 1]
	end.y = goal.y
	var short := end.distance_to(goal)
	if short > UNREACHABLE_BY:
		print("[nav] %s: %v is unreachable -- nearest footing is %.1fm short"
			% [_body.name, goal, short])

# ---- debug ----

## The path as it currently stands, drawn as a line over the grass. Rebuilt every
## frame while debug is on -- wasteful, and it only ever runs while debugging.
func _draw_path() -> void:
	var path := _agent.get_current_navigation_path()
	if path.size() < 2:
		if is_instance_valid(_line):
			_line.visible = false
		return
	if not is_instance_valid(_line):
		_line = _make_line()
	_line.visible = true
	var mesh: ImmediateMesh = _line.mesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in path:
		mesh.surface_add_vertex(p + Vector3(0, DEBUG_Y, 0))
	mesh.surface_end()

func _make_line() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = ImmediateMesh.new()
	mi.top_level = true          # path points are already world space
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = DEBUG_COLOR
	mat.no_depth_test = true
	mi.material_override = mat
	_body.add_child(mi)
	return mi

## Called when the body goes away, so a stray debug line doesn't outlive it.
func cleanup() -> void:
	if is_instance_valid(_line):
		_line.queue_free()
	_line = null
