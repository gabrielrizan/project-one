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
## Both populations are drawn from [NaturePack] and **both turn with the season** --
## see [method _grow_filler] for why the filler being the one that did not was the
## most visible thing on the map.
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

# Season indices -- mirror weather.gd's Season enum (SPRING/SUMMER/AUTUMN/WINTER).
const AUTUMN := 2
const WINTER := 3

## Filler heights. Kept **below** `tree_resource.gd`'s 4.0-5.2 m on purpose: the
## markable trees should stay the biggest thing in the wood, because that
## silhouette is what the player learns to look for.
const FILLER_H := Vector2(2.6, 4.2)

## Fixed so a map's layout is stable between runs -- the same reason
## `world_decor.gd` seeds its scatter. Change it to reroll every map at once.
@export var forest_seed := 4211

var _filler_points: Array[Vector3] = []
var _filler_holder: Node3D = null
var _variant := "___"

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed
	var m := MapTerrain.map()

	# One pass, three populations, one exclusion grid -- **bushes first**, so each
	# one keeps its glade and the wood cannot close over the berries. See
	# [method MapDef.forest_plan]; the order is the whole of that design.
	var plan: Dictionary = m.forest_plan(rng)

	var bushes := 0
	for p in plan.bushes:
		var b: Node3D = BUSH_SCENE.instantiate()
		add_child(b)
		b.global_position = Vector3(p.x, 0.0, p.z)
		b.rotation.y = rng.randf() * TAU
		FogOfWar.hide_until_found(b)
		bushes += 1

	var trees := 0
	for p in plan.solid:
		_tree(p, rng)
		trees += 1

	# The filler's *positions* are drawn once; only its models are re-made when the
	# season turns, so the wood keeps its exact shape all year and only its coat
	# changes -- the same guarantee `world_decor.gd` gets by re-seeding its rng.
	_filler_points = plan.filler
	_filler_holder = Node3D.new()
	add_child(_filler_holder)
	var filler := _filler_points.size()
	call_deferred("_hook_weather")

	# The lane plugs come after the stands so they are never displaced by one, and
	# they ignore the spacing rules entirely: a plug has to be *tight* to seal.
	var plugged := 0
	for lane in m.lanes:
		for p in m.lane_plug_points(lane):
			_tree(p, rng)
			plugged += 1

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
	# hidden until the ground under it has been walked, on a map with fog. Cosmetic
	# only -- the trunk keeps its collider and stays in `tree`, so it still blocks
	# and still bakes into the navmesh while unseen.
	FogOfWar.hide_until_found(t)

# ---------------------------------------------------------------- the understory

## Follow the season clock. Deferred so it does not matter whether Weather has
## joined its group yet; the first grow happens here off the current season.
func _hook_weather() -> void:
	var w := get_tree().get_first_node_in_group("weather")
	if w and w.has_signal("season_changed"):
		if not w.season_changed.is_connected(_on_season_changed):
			w.season_changed.connect(_on_season_changed)
		_on_season_changed(w.season())
	else:
		_on_season_changed(0)

func _on_season_changed(season: int) -> void:
	var variant := _variant_for(season)
	# spring and summer are the same coat, so an ordinary tick costs nothing
	if variant != _variant:
		_variant = variant
		_grow_filler()

func _variant_for(season: int) -> String:
	if season == AUTUMN:
		return NaturePack.AUTUMN
	if season == WINTER:
		return NaturePack.SNOW
	return NaturePack.GREEN

## Rebuild the understory in the current season's coat.
##
## **This is the population that sets how dense the wood looks**, so it is also the
## one that shows most when it disagrees with everything around it. It used to load
## Kenney GLBs tinted through a colour ramp and never changed with the season -- so
## in autumn and winter it stood summer-green (and, worse, part of it stood *baked
## orange* year-round, because the survival kit's colormap paints those crowns and
## no tint can pull them back) among nature-pack trees that had all turned. Three
## tree populations, one coat between them.
##
## Layout is untouched by a re-skin: the points were drawn once at `_ready` and the
## rng is re-seeded here, so every tree keeps its place, its family and its member
## index -- the same tree in a different coat, exactly like `tree_resource.gd`.
## Filler carries no script and no collider, so none of this can reach the navmesh.
func _grow_filler() -> void:
	var old := _filler_holder
	_filler_holder = Node3D.new()
	add_child(_filler_holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = forest_seed + 1
	for p in _filler_points:
		_filler(p, rng)
	if is_instance_valid(old):
		old.queue_free()

## One filler tree: canopy, no script, no collider, cannot be marked and cannot
## block. Same models as the markable trees, at a smaller target height -- there is
## no visual tell between the two populations by design, and there does not need to
## be, because `world_decor.gd`'s rule 1 keeps every *reachable* tree harvestable.
func _filler(p: Vector3, rng: RandomNumberGenerator) -> void:
	var fam: String = NaturePack.TREE_FAMILIES[rng.randi() % NaturePack.TREE_FAMILIES.size()]
	var idx := rng.randi_range(1, NaturePack.TREE_MEMBERS)
	var t := NaturePack.spawn(NaturePack.tree(fam, _variant, idx),
		rng.randf_range(FILLER_H.x, FILLER_H.y))
	if t == null:
		return
	_filler_holder.add_child(t)
	t.position = Vector3(p.x, 0.0, p.z)
	t.rotation.y = rng.randf() * TAU
	# no script, so `wind.gd` has to rock it from the outside
	t.add_to_group("wind_sway")
	FogOfWar.hide_until_found(t)
