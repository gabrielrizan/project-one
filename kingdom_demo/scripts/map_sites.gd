extends Node3D
## Stamps the selected map's reward sites (ISLAND_PROMPTS F6), the same way
## `map_walls.gd` stamps its walls and `night_raids.gd` its camps: the layout is
## data in [MapDef], and this node only builds what the data asks for.
##
## A map with no `sites` builds nothing, which is how the three land prototypes stay
## exactly as they were.

const SITE_SCRIPT := preload("res://kingdom_demo/scripts/reward_site.gd")
## The wreck is its own thing: a `build_site` with a crew, not a hold-to-take reward.
const WRECK_SCRIPT := preload("res://kingdom_demo/scripts/wreck_site.gd")

func _ready() -> void:
	var counts := {}
	for s in MapTerrain.sites():
		var node := StaticBody3D.new()
		var kind := String(s.get("kind", MapDef.CHEST))
		node.set_script(WRECK_SCRIPT if kind == MapDef.WRECK else SITE_SCRIPT)
		# before `add_child`, like `BanditCamp.raiding` and `WallSide.half`: `_ready`
		# builds the model from it
		if kind != MapDef.WRECK:
			node.kind = kind
		add_child(node)
		node.global_position = s.pos
		# **A wreck is always on the sand.** Its map entry gives the bearing; the
		# actual spot is resolved against the live coastline, so retuning the shore
		# never strands a hull inland or floats one out to sea.
		if kind == MapDef.WRECK and MapTerrain.has_shore():
			var p: Vector3 = s.pos
			node.global_position = MapTerrain.beach_point(atan2(p.z, p.x))
		# a wreck lies along the shore rather than at a random angle -- `yaw` from the
		# map data if given, so both beaches read as "she came ashore here"
		# ...and she lies *along* the beach, tangent to the coast, rather than at a
		# random angle or pointing inland
		if kind == MapDef.WRECK and MapTerrain.has_shore():
			var q: Vector3 = node.global_position
			node.rotation.y = -atan2(q.z, q.x) + float(s.get("yaw", 0.0))
		else:
			node.rotation.y = float(s.get("yaw", randf() * TAU))
		counts[kind] = int(counts.get(kind, 0)) + 1
	if not counts.is_empty():
		print("[sites] %s: %s" % [MapTerrain.map().id, str(counts)])
	# reward sites carry colliders, so the mesh has to know about them
	if not MapTerrain.sites().is_empty():
		NavWorld.rebake(self)
