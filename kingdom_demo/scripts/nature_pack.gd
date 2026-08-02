class_name NaturePack
extends RefCounted
## The one place that knows the imported nature-pack (assets/nature-pack/FBX) and
## how to plant a piece of it at a sane size. Trees, rocks, bushes and ground
## detail all come from here, and every family carries its **seasonal variants**
## (green / autumn / snow) so the world can re-skin itself as the season clock
## turns -- see world_decor.gd and tree_resource.gd.
##
## **Why everything is auto-scaled by its AABB.** The pack is raw FBX and nothing
## here can be trusted to import at a known scale or with its base on the floor --
## so [method spawn] measures the model's real bounding box, scales it uniformly to
## a target height in metres, and drops its base to y = 0. A caller says "I want a
## ~5 m tree here" and gets one, whatever units the FBX happened to use. This is
## the single knob for size: if a family looks wrong, change the target height at
## the call site, never a per-model magic number.
##
## Seasonal indexing is stable: `CommonTree_2`, `CommonTree_Autumn_2` and
## `CommonTree_Snow_2` are the same tree in three coats, so a re-skin keeps
## member index `idx` and only changes the variant -- a given tree stays "that
## birch by the gate" through the year.

const DIR := "res://kingdom_demo/assets/nature-pack/FBX/"

## Variant keys. "" is the base (spring/summer green); the season driver maps a
## season to one of these and falls back to "" for any family that lacks it.
const GREEN := ""
const AUTUMN := "autumn"
const SNOW := "snow"

# --- trees: four families, each with the three seasonal coats, five members each.
#     The member index lines up across coats so a re-skin keeps the tree's shape. ---
const TREE_FAMILIES := ["common", "birch", "pine", "willow"]
const _TREE_PREFIX := {
	"common": "CommonTree", "birch": "BirchTree", "pine": "PineTree", "willow": "Willow",
}
const TREE_MEMBERS := 5

## Path to one tree, by family / variant / 1-based member index.
static func tree(family: String, variant: String, idx: int) -> String:
	var p: String = _TREE_PREFIX[family]
	var suffix := "" if variant == GREEN else "_" + _cap(variant)
	return "%s%s%s_%d.fbx" % [DIR, p, suffix, idx]

# --- rocks / bushes / stumps / logs: green vs snow (moss reads fine in summer). ---
static func _rocks(variant: String) -> PackedStringArray:
	if variant == SNOW:
		return _series("Rock_Snow", 7)
	return _series("Rock", 7) + _series("Rock_Moss", 7)

static func _bushes(variant: String) -> PackedStringArray:
	if variant == SNOW:
		return _series("Bush_Snow", 2)
	return _series("Bush", 2) + _series("BushBerries", 2)

static func _stumps(variant: String) -> PackedStringArray:
	if variant == SNOW:
		return PackedStringArray([DIR + "TreeStump_Snow.fbx"])
	return PackedStringArray([DIR + "TreeStump.fbx", DIR + "TreeStump_Moss.fbx"])

static func _logs(variant: String) -> PackedStringArray:
	if variant == SNOW:
		return PackedStringArray([DIR + "WoodLog_Snow.fbx"])
	return PackedStringArray([DIR + "WoodLog.fbx", DIR + "WoodLog_Moss.fbx"])

## Small ground detail. Hidden by the caller in winter (dead grass reads as bare).
static func _detail() -> PackedStringArray:
	return PackedStringArray([
		DIR + "Grass.fbx", DIR + "Grass_2.fbx", DIR + "Grass_Short.fbx",
		DIR + "Flowers.fbx", DIR + "Plant_1.fbx", DIR + "Plant_2.fbx",
		DIR + "Plant_3.fbx", DIR + "Plant_4.fbx", DIR + "Plant_5.fbx",
	])

# ---- picking a random member (callers pass their own seeded rng) ----

static func random_rock(variant: String, rng: RandomNumberGenerator) -> String:
	return _pick(_rocks(variant), rng)

static func random_bush(variant: String, rng: RandomNumberGenerator) -> String:
	return _pick(_bushes(variant), rng)

static func random_stump(variant: String, rng: RandomNumberGenerator) -> String:
	return _pick(_stumps(variant), rng)

static func random_log(variant: String, rng: RandomNumberGenerator) -> String:
	return _pick(_logs(variant), rng)

static func random_detail(rng: RandomNumberGenerator) -> String:
	return _pick(_detail(), rng)

# ---- the scaler ----

## Instance the model at `path`, scaled uniformly so it stands `target_h` metres
## tall with its base on y = 0. Returns a holder Node3D (the FBX scene lives under
## it, untouched) so the AABB maths never fights the model's own transform. Returns
## null if the resource won't load, so a bad path can't crash the whole scatter.
static func spawn(path: String, target_h: float) -> Node3D:
	var scene := load(path) as PackedScene
	if scene == null:
		push_warning("[nature] could not load " + path)
		return null
	var model := scene.instantiate() as Node3D
	if model == null:
		return null
	var holder := Node3D.new()
	holder.add_child(model)
	var box := _combined_aabb(model)
	var h: float = box.size.y
	if h > 0.001:
		# drop the base to the holder's origin, then scale the holder around it
		model.position.y -= box.position.y
		var s: float = target_h / h
		holder.scale = Vector3(s, s, s)
	return holder

## Union of every VisualInstance3D's AABB under `root`, in `root`'s parent space
## (root's own transform included), so scaling the holder gives the true height.
static func _combined_aabb(root: Node) -> AABB:
	var acc := AABB()
	var started := false
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var node: Node = pair[0]
		var xf: Transform3D = pair[1]
		if node is Node3D:
			xf = xf * (node as Node3D).transform
		if node is VisualInstance3D:
			var a: AABB = xf * (node as VisualInstance3D).get_aabb()
			if started:
				acc = acc.merge(a)
			else:
				acc = a
				started = true
		for c in node.get_children():
			stack.append([c, xf])
	return acc if started else AABB(Vector3.ZERO, Vector3.ONE)

# ---- helpers ----

static func _series(prefix: String, n: int) -> PackedStringArray:
	var out := PackedStringArray()
	for i in range(1, n + 1):
		out.append("%s%s_%d.fbx" % [DIR, prefix, i])
	return out

static func _pick(list: PackedStringArray, rng: RandomNumberGenerator) -> String:
	return list[rng.randi() % list.size()]

static func _cap(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)
