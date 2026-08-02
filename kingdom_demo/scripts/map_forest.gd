extends Node3D
## Plants the map's **harvestable** resources: timber stands, berry bushes, and the
## tree plugs that block a wood gate's carve lanes.
##
## The prototype had 19 trees and 8 bushes hand-placed in `kingdom_demo.tscn`, which
## is fine for one map and impossible for three. Placement now comes from the map
## definition ([method MapDef.forest_points]), seeded, so a map is the same place
## every time you play it but each map is its own place.
##
## ## Two populations in the same wood, and why that is the only way this works
##
## **Solid trees** (`tree.tscn`) carry a script and a 0.5 m collider. They are the
## markable ones, they block, and the navmesh bakes them. **Filler trees** carry
## neither -- they are the same models with no script and no collider, walked
## through exactly the way `world_decor.gd`'s scenery always has been
## (`nav_world.gd` states the rule outright).
##
## That split is what lets a wood be dense *and* safe to walk:
##
## * Filler sets how dense the canopy **looks**, and can be packed arbitrarily
##   tight, because nothing collider-free can ever wedge anybody.
## * Solid trees set how much the wood **blocks**, and are held apart by
##   `MapDef.forest.spacing` so every gap between two trunks is over 2 m of really
##   clear ground -- never the ~1 m gap that looks passable and isn't.
##
## Density and passability are therefore independent, which is the whole trick. Turn
## `MapDef.understory.cap` to 0 for the sparse look; raise it for a thicker wood.
## Neither touches how the map plays.
##
## ## Even, not clumped
##
## An earlier pass placed the solid trees in **stands** -- clumps with open travel
## between them -- on the theory that a stand is a thing you ride to and work
## through. On the ground it read as blobs of trees separated by suspiciously empty
## lawn, so placement is blue noise now: even coverage, minimum spacing, no lattice.
## See [method MapDef.forest_points].
##
## ## Clear ground around the camps
##
## Nothing is planted within `MapDef.camp_clear` of a bandit camp. The assault is a
## squad of archers shooting a garrison, and trunks among the tents mean blocked
## shots and a payoff you cannot see -- so a camp sits in a clearing, which also
## reads as somebody having made the place.

const TREE_SCENE := preload("res://kingdom_demo/scenes/tree.tscn")
const BUSH_SCENE := preload("res://kingdom_demo/scenes/berry_bush.tscn")

const SK := "res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/"
const COLORMAP := preload("res://kingdom_demo/assets/3d/kenney_survival-kit/Models/GLB format/Textures/colormap.png")

## Greens the filler is tinted through. Deliberately a **narrow, slightly cooler and
## darker range than the markable trees wear**, so the wood has variation without the
## filler ever competing to look like the thing you can sell.
const FILLER_TINTS := [
	Color(0.74, 0.88, 0.64), Color(0.64, 0.80, 0.56),
	Color(0.82, 0.92, 0.70), Color(0.58, 0.74, 0.50),
]

## Fixed so a map's layout is stable between runs -- the same reason
## `world_decor.gd` seeds its scatter. Change it to reroll every map at once.
@export var forest_seed := 4211

var _filler_scenes: Array = []
var _filler_mats: Array[StandardMaterial3D] = []

func _load_filler() -> void:
	if not _filler_scenes.is_empty():
		return
	# Weighted toward pine by repeating it. An even four-way split came out roughly
	# half autumn, and because the colormap bakes those crowns orange the tint cannot
	# pull them back to green -- a wood that was half ember read as autumn everywhere
	# and fought the palette's greens for the frame.
	var pine: PackedScene = load(SK + "tree.glb")
	var pine_tall: PackedScene = load(SK + "tree-tall.glb")
	_filler_scenes = [
		pine, pine_tall, pine, pine_tall, pine, pine_tall,
		load(SK + "tree-autumn.glb"), load(SK + "tree-autumn-tall.glb"),
	]
	for c in FILLER_TINTS:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = COLORMAP
		mat.albedo_color = c
		mat.roughness = 1.0
		# mipmaps + linear so the tiny colour atlas doesn't bleed between swatches
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_filler_mats.append(mat)

func _ready() -> void:
	_load_filler()
	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed
	var m := MapTerrain.map()

	# one pass, two populations: the solid trees fill an exclusion grid, and the
	# filler pass reuses it so no sprite grows out of a markable trunk
	var seeded: Array = m.forest_grid(rng)
	var solid: Array = seeded[0]
	var grid: Dictionary = seeded[1]

	var trees := 0
	for p in solid:
		_tree(p, rng)
		trees += 1

	var filler := 0
	for p in m.understory_points(rng, grid):
		_filler(p, rng)
		filler += 1

	# The lane plugs come after the stands so they are never displaced by one, and
	# they ignore the spacing rules entirely: a plug has to be *tight* to seal.
	var plugged := 0
	for lane in m.lanes:
		for p in m.lane_plug_points(lane):
			_tree(p, rng)
			plugged += 1

	var bushes := 0
	for p in m.bush_points(rng):
		var b: Node3D = BUSH_SCENE.instantiate()
		add_child(b)
		b.global_position = Vector3(p.x, 0.0, p.z)
		b.rotation.y = rng.randf() * TAU
		bushes += 1

	print("[forest] %s: %d timber trees (+%d in lane plugs), %d filler, %d bushes"
		% [m.id, trees, plugged, filler, bushes])
	# every trunk is a collider, so the mesh has to account for them before anyone
	# walks; one coalesced bake covers the lot
	NavWorld.rebake(self)

## One harvestable tree. Rotation only -- **never scaled**, because `tree_resource.gd`
## measures its chop height, blaze and topple hinge in metres against a 1.2 m
## villager (`TRUNK_Y`, `TRUNK_BASE_Y`, `BANNER_Y`). Scaling the body would put the
## axe bite and the paint daub somewhere a person cannot reach.
func _tree(p: Vector3, rng: RandomNumberGenerator) -> void:
	var t: Node3D = TREE_SCENE.instantiate()
	add_child(t)
	t.global_position = Vector3(p.x, 0.0, p.z)
	t.rotation.y = rng.randf() * TAU

## One filler tree: canopy, no script, no collider, cannot be marked and cannot
## block. Scaled and tinted across a range so the wood is not one tree repeated, and
## kept a little **smaller on average than a solid trunk** -- the markable trees
## should stay the biggest thing in the wood, since that is the silhouette the
## player learns to look for.
func _filler(p: Vector3, rng: RandomNumberGenerator) -> void:
	var scene: PackedScene = _filler_scenes[rng.randi() % _filler_scenes.size()]
	var t: Node3D = scene.instantiate()
	add_child(t)
	t.position = Vector3(p.x, 0.0, p.z)
	var s := rng.randf_range(1.9, 3.0)
	t.scale = Vector3(s, s * rng.randf_range(0.9, 1.25), s)
	t.rotation.y = rng.randf() * TAU
	_tint(t, _filler_mats[rng.randi() % _filler_mats.size()])
	# no script, so `wind.gd` has to rock it from the outside
	t.add_to_group("wind_sway")

func _tint(n: Node, mat: StandardMaterial3D) -> void:
	if n is MeshInstance3D:
		n.material_override = mat
	for c in n.get_children():
		_tint(c, mat)
