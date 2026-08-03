extends Node3D
## Puts a [WallSide] wherever the selected map offers one.
##
## These used to be hand-placed in `kingdom_demo.tscn` -- a single `WallSideN` at
## z = -8, which is exactly as portable as the prototype map it belonged to. A map
## with two passes needs two walls, and a map whose opening faces west needs one
## turned ninety degrees, so the placement follows the map definition instead.
##
## **A closed bearing carries no wall at all.** That is the §11 rule this preserves:
## every wall the monarch can buy is one that can matter, because the terrain has
## already answered the bearings that can't.
##
## A wall runs its local x from -`half` to +`half` with the gate at its centre, so
## a map's opening is sized to match and the wall is set just *inside* it --
## overlapping the rock or wood a little, since a butted joint with no overlap is
## where a raider threads through.
##
## `half` defaults to `wall_side.gd`'s 8.0 (a 16 m run plugging a doorway) and is
## per-map: the island passes 16.0 so four 32 m walls enclose a village square
## rather than sealing a pass.

const WALL_SCENE := preload("res://kingdom_demo/scenes/wall_side.tscn")

func _ready() -> void:
	var n := 0
	for w in MapTerrain.walls():
		var wall: Node3D = WALL_SCENE.instantiate()
		# **Before `add_child`.** `add_child` runs `_ready`, which lays out the run,
		# the collision boxes and the gate off `half` -- set afterwards it would be
		# a wall that reports one length and is built to another.
		wall.half = float(w.get("half", wall.half))
		add_child(wall)
		wall.global_position = w.pos
		wall.rotation.y = float(w.get("yaw", 0.0))
		# named for the log line and for anything that goes looking in the tree;
		# the group is what the rest of the game actually wires through
		wall.name = "WallSide%d" % (n + 1)
		n += 1
	print("[walls] %s: offered %d wall side(s)" % [MapTerrain.map().id, n])
