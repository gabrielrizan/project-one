extends Node3D
## The sea around the island: water, beach, and the horizon of distant islands.
##
## Only ever does anything on a map that has a [member MapDef.shore]; on the three
## land maps `_ready` finds no coastline and the node stands idle, which is why it
## can live in the shared scene.
##
## **Everything here is a picture. None of it is solid.** The thing that actually
## stops you leaving the island is the ring of invisible boxes `mountains.gd`
## stamps under [constant MapDef.WATER], and it is generated from the same
## [method MapDef.shore_at] this file draws from -- so the sand, the waterline and
## the wall you bump into cannot drift apart.
##
## ## Why the water sits *above* the ground rather than below it
##
## The obvious build is a plane at y ≈ -0.12 with the island's ground poking
## through it. That does not work here: the ground is one 240 m slab and the island
## is ~180 m across, so green would show past the coast on every bearing. Instead
## the water is a **ring** that starts at the shore and runs out to the horizon,
## lying just above the slab and covering it. Flat-on-flat is safe for exactly the
## reason the puddles are (CLAUDE.md: the world is one flat slab), and it means the
## slab's own edge is under water level and can never come into shot.
##
## ## The season reaches the water
##
## Winter pushes the sea **paler and flatter** -- more sky, less chop -- never
## darker or grey-blue, because that would fight the rule the shader is built on
## (from this camera, standing water reads *lighter* than ground, since what you
## see in it is sky). The beach and the distant islands turn with it: a green
## horizon ringing a white island reads as a bug.

const WATER_SHADER := preload("res://kingdom_demo/assets/shaders/water.gdshader")

## The hand-painted coat the sea wears. One of the Voxel Core Lab watercolour tiles
## (CC0, Jonas Voland -- provenance and the picks in that folder's `SOURCE.md`).
##
## `Water_02` on purpose, and **not `Water_01`**: 01 is the pretty one, a shallow
## lagoon with fish silhouettes painted into it, and at our tile scale a fish is
## about a metre long and repeats identically every 42 m. A near-flat wash is what
## a 640 m sheet actually wants -- paper grain and slow tonal drift, with no
## structure in it to give the tiling away.
const WATER_TEX := preload("res://kingdom_demo/assets/textures/watercolor/Water_02.png")

# Season indices -- mirror weather.gd's Season enum (SPRING/SUMMER/AUTUMN/WINTER).
const SPRING := 0
const SUMMER := 1
const AUTUMN := 2
const WINTER := 3

## Angular resolution of the water and beach rings. The shore's fastest harmonic is
## k = 5, so 128 chords follow it to well under a centimetre.
const SEGMENTS := 128
## How far out the water runs. Far past the 240 m slab on purpose -- this is the
## horizon, and the distant islands sit inside it.
const HORIZON := 420.0
## The shallow band, in metres out from the coast, over which the water goes from
## sand-coloured to open sea. The shader's foam and shorewash live in its first
## sixth.
const SHALLOW := 13.0
## How far the water's inner edge tucks back under the sand, so there is no hairline
## gap at the waterline whatever the chord resolution.
const TUCK := 0.5

## Flat sheets on a flat slab, stacked in a fixed order so no two z-fight. Ground
## patches (`world_decor.gd`) sit at 0.02, roads at 0.09 -- both inland, so they
## never meet these.
## Depth precision, not looks, sets these gaps. The beach at 3 cm over the slab and
## the water at 5 cm over that both z-fought into dashed stripes when the coast was
## seen from any distance; the further a surface sits from the camera the more
## clearance it needs, which is why the distant islands get a full 30 cm.
const BEACH_Y := 0.06
const WATER_Y := 0.10
const ISLAND_Y := 0.30

## Distant islands: how many, and the band of open water they sit in. Inside the
## near stop they would read as land you ought to be able to reach; past the far
## one they are under a pixel tall.
## Sized off the coast, not off a constant: the near stop has to sit outside the
## island's furthest reach (94 m) or an island would appear to be land you ought to
## be able to walk to.
const ISLE_COUNT := 12
const ISLE_NEAR := 122.0
const ISLE_FAR := 245.0

## Kept well under the obvious sand value. At 0.80/0.72/0.54 the beach came back
## from a noon sun as near-white pale yellow -- the same exposure trap the ground's
## green fell into (CLAUDE.md), where the fix is the number going *in*, not the hue.
const SAND := Color(0.66, 0.58, 0.40)
const SAND_WINTER := Color(0.87, 0.89, 0.93)
## The distant islands' land, per season. They are read at 100 m+ as silhouette and
## colour and nothing else, so this is the entire season treatment they need.
const ISLE_LAND := {
	SPRING: Color(0.38, 0.54, 0.30),
	AUTUMN: Color(0.62, 0.44, 0.22),
	WINTER: Color(0.88, 0.91, 0.95),
}
const ISLE_ROCK := Color(0.42, 0.44, 0.47)

## Water tints, dimmed by the hour before they reach the shader. Kept well under the
## sky term either way -- see the shader header.
const DEEP := Color(0.09, 0.26, 0.38)
const SHALLOW_COL := Color(0.30, 0.60, 0.62)

var _mat: ShaderMaterial = null
var _beach_mat: StandardMaterial3D = null
var _isles: Node3D = null
var _cycle: Node = null
var _season := SPRING
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	if not MapTerrain.has_shore():
		set_process(false)
		return
	_rng.seed = 4471
	_build_water()
	_build_beach()
	_isles = Node3D.new()
	add_child(_isles)
	call_deferred("_hook_up")

## Deferred so it does not matter whether Weather and DayNightCycle have joined
## their groups yet -- the same shape `world_decor.gd` uses.
func _hook_up() -> void:
	_cycle = get_tree().get_first_node_in_group("day_night_cycle")
	var w := get_tree().get_first_node_in_group("weather")
	if w and w.has_signal("season_changed"):
		if not w.season_changed.is_connected(_on_season_changed):
			w.season_changed.connect(_on_season_changed)
		_on_season_changed(w.season())
	else:
		_on_season_changed(SPRING)

# ---------------------------------------------------------------- the water

func _build_water() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = WATER_SHADER
	_mat.set_shader_parameter("water_tex", WATER_TEX)
	_mat.set_shader_parameter("tex_mean", _mean_of(WATER_TEX))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var t0 := TAU * float(i) / float(SEGMENTS)
		var t1 := TAU * float(i + 1) / float(SEGMENTS)
		var s0 := MapTerrain.shore_at(t0)
		var s1 := MapTerrain.shore_at(t1)
		# the shallows, whose inner edge follows the wobble of the coast exactly...
		_band(st, t0, t1, s0 - TUCK, s1 - TUCK, 0.0, s0 + SHALLOW, s1 + SHALLOW, 1.0)
		# ...and open water on out to the horizon
		_band(st, t0, t1, s0 + SHALLOW, s1 + SHALLOW, 1.0, HORIZON, HORIZON, 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat
	# A 640 m sheet at a low sun would throw its silhouette clean across the map --
	# the same trap the ground patches and roads are kept out of.
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position.y = WATER_Y

## The tile's average colour, so the shader can divide by it and keep only the
## *variation*. Measured rather than typed in: swap the tile in [constant WATER_TEX]
## and the normalisation follows, instead of the sea quietly changing hue.
##
## `resize(1, 1)` is the whole measurement -- the image resampler averages, so one
## call does what scanning a million pixels would, and it happens once at startup.
func _mean_of(tex: Texture2D) -> Vector3:
	var img := tex.get_image()
	if img == null:
		return Vector3(0.35, 0.35, 0.35)
	img = img.duplicate()
	img.resize(1, 1, Image.INTERPOLATE_LANCZOS)
	var c := img.get_pixel(0, 0)
	return Vector3(maxf(c.r, 0.02), maxf(c.g, 0.02), maxf(c.b, 0.02))

## One quad of the ring, as two triangles. `da`/`db` are the shader's depth factor
## (0 at the sand, 1 in open water), carried in UV.y; normals are written straight
## up rather than generated, so winding never has to be reasoned about.
func _band(st: SurfaceTool, t0: float, t1: float, ra0: float, ra1: float, da: float,
		rb0: float, rb1: float, db: float) -> void:
	var a := Vector3(cos(t0) * ra0, 0.0, sin(t0) * ra0)
	var b := Vector3(cos(t1) * ra1, 0.0, sin(t1) * ra1)
	var c := Vector3(cos(t1) * rb1, 0.0, sin(t1) * rb1)
	var d := Vector3(cos(t0) * rb0, 0.0, sin(t0) * rb0)
	# Wound **counter-clockwise seen from above**, i.e. front-facing upward. It is
	# not optional even with culling off: a double-sided material flips NORMAL on a
	# back face, so a ring wound the other way has its normals pointing at the
	# ground and takes no sun at all -- the sand came out a dark olive-brown at
	# noon, which reads as a badly chosen colour rather than as a lighting bug.
	_vert(st, a, da)
	_vert(st, c, db)
	_vert(st, b, da)
	_vert(st, a, da)
	_vert(st, d, db)
	_vert(st, c, db)

func _vert(st: SurfaceTool, at: Vector3, depth: float) -> void:
	st.set_normal(Vector3.UP)
	st.set_uv(Vector2(0.0, depth))
	st.add_vertex(at)

# ---------------------------------------------------------------- the beach

## A sand annulus between the tree line and the waterline, at the same width
## `MapDef` uses as its planting setback -- so the sand and the edge of the wood
## are the same number and cannot disagree.
##
## Its inner edge is deliberately ragged: a clean circle of sand round a wobbly
## coast reads as a machined border, which is the one thing the shore wobble exists
## to avoid.
func _build_beach() -> void:
	var width := MapTerrain.beach_width()
	if width <= 0.0:
		return
	_beach_mat = StandardMaterial3D.new()
	_beach_mat.albedo_color = SAND
	_beach_mat.roughness = 1.0
	# CULL_DISABLED, like every other surface here -- the shore is seen from a fixed
	# steep camera, so there is nothing to save, and it means the sand cannot vanish
	# outright if the winding is ever touched. (`_band` does wind it correctly; see
	# the note there for why that still matters.)
	_beach_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner: Array[float] = []
	for i in SEGMENTS + 1:
		var t := TAU * float(i % SEGMENTS) / float(SEGMENTS)
		# two more harmonics, on top of the coast's own, so the tree line is not
		# just the waterline offset inward by a constant
		var ragged := width * (0.72 + 0.28 * sin(t * 7.0 + 1.3) * sin(t * 3.0 - 0.6))
		inner.append(MapTerrain.shore_at(t) - ragged)
	for i in SEGMENTS:
		var t0 := TAU * float(i) / float(SEGMENTS)
		var t1 := TAU * float(i + 1) / float(SEGMENTS)
		# out to just past the coast, so the water's tucked-back inner edge always
		# has sand underneath it
		_band(st, t0, t1, inner[i], inner[i + 1], 0.0,
			MapTerrain.shore_at(t0) + 1.0, MapTerrain.shore_at(t1) + 1.0, 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _beach_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position.y = BEACH_Y

# ---------------------------------------------------------------- the horizon

## The ring of distant islands.
##
## This is not decoration for its own sake -- it is the replacement for the
## backdrop `world_decor.gd` loses. That file fills everything past the map edge
## with forest, and on an island "past the map edge" is the entire ocean, so its
## whole backdrop is (correctly) rejected. Without something out there the horizon
## is flat water to the sky on every bearing, which reads as the world running out.
##
## Rebuilt per season rather than tinted in place: it is a couple of dozen meshes,
## and rebuilding means the shapes can vary with the coat if they ever need to.
func _grow_isles() -> void:
	for c in _isles.get_children():
		c.queue_free()
	_rng.seed = 4471
	var land: Color = ISLE_LAND.get(_season, ISLE_LAND[SPRING])
	var sand := SAND_WINTER if _season == WINTER else SAND
	var rock := ISLE_ROCK.lerp(land, 0.35)
	for i in ISLE_COUNT:
		# spread by bearing with jitter, so they ring the island without parading
		var a := TAU * (float(i) + _rng.randf_range(-0.34, 0.34)) / float(ISLE_COUNT)
		var r := lerpf(ISLE_NEAR, ISLE_FAR, sqrt(_rng.randf()))
		var at := Vector3(cos(a) * r, 0.0, sin(a) * r)
		# grown with distance so they hold roughly the same size on screen
		var size := _rng.randf_range(6.0, 14.0) * lerpf(1.0, 1.9, (r - ISLE_NEAR) / (ISLE_FAR - ISLE_NEAR))
		_isle(at, size, land, sand, rock)

func _isle(at: Vector3, size: float, land: Color, sand: Color, rock: Color) -> void:
	var holder := Node3D.new()
	_isles.add_child(holder)
	holder.position = Vector3(at.x, ISLAND_Y, at.z)
	_disc(holder, size, sand, 0.0)
	# 10 cm, not 2: at 100-190 m out even the gap *between* an island's own two
	# discs is enough to z-fight into stripes
	_disc(holder, size * 0.78, land, 0.10)
	for i in _rng.randi_range(2, 4):
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(0.0, size * 0.45)
		var h := size * _rng.randf_range(0.28, 0.62)
		_cone(holder, Vector3(cos(a) * d, 0.0, sin(a) * d), size * _rng.randf_range(0.22, 0.42), h,
			rock if _rng.randf() < 0.45 else land)

func _disc(parent: Node3D, radius: float, color: Color, y: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	var edge: Array[Vector3] = []
	for i in n:
		var a := TAU * float(i) / float(n)
		# a lumpy outline: a perfect circle at this distance reads as a coin lying
		# on the water rather than as land
		var rr := radius * _rng.randf_range(0.78, 1.16)
		edge.append(Vector3(cos(a) * rr, 0.0, sin(a) * rr))
	# counter-clockwise from above, like `_band` -- see the note there. Wound the
	# other way these came out unlit brown lumps instead of sand and grass.
	for i in n:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.UP)
		st.add_vertex(edge[i])
		st.set_normal(Vector3.UP)
		st.add_vertex(edge[(i + 1) % n])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _flat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position.y = y

## A flat-shaded low-poly hill, the same construction `mountains.gd::_peak` uses --
## a jagged 5-7 sided cone with no bottom cap, which nothing at this range can see.
func _cone(parent: Node3D, at: Vector3, base: float, height: float, color: Color) -> void:
	var sides := _rng.randi_range(5, 7)
	var apex := Vector3(_rng.randf_range(-0.6, 0.6), height, _rng.randf_range(-0.6, 0.6))
	var ring: Array[Vector3] = []
	for i in sides:
		var a := TAU * i / sides + _rng.randf_range(-0.2, 0.2)
		ring.append(Vector3(cos(a), 0.0, sin(a)) * base * _rng.randf_range(0.8, 1.18))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)         # -1 => flat per-face normals
	for i in sides:
		st.add_vertex(apex)
		st.add_vertex(ring[(i + 1) % sides])
		st.add_vertex(ring[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _flat(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = at

func _flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

# ---------------------------------------------------------------- season & sky

func _on_season_changed(season: int) -> void:
	_season = season
	var winter := 1.0 if season == WINTER else 0.0
	if _mat:
		_mat.set_shader_parameter("winter", winter)
	if _beach_mat:
		_beach_mat.albedo_color = SAND_WINTER if season == WINTER else SAND
	if _isles:
		_grow_isles()

## The sea takes its colour from the sky, every frame.
##
## `day_night_cycle.gd` has already folded the hour, the overcast, the blood moon
## and any lightning flash into `background_color` by the time it is read here, so
## the water greys under cloud, reddens under a blood moon and goes near-black at
## night without this file knowing that any of those things exist -- exactly how
## `weather.gd` feeds the puddles. One uniform write a frame.
func _process(_delta: float) -> void:
	if _mat == null:
		return
	var sky := Color(0.53, 0.81, 0.92)
	var lit := 1.0
	if _cycle:
		if _cycle.world_env and _cycle.world_env.environment:
			sky = _cycle.world_env.environment.background_color
		lit = lerpf(1.0, 0.18, _cycle.darkness())
	_mat.set_shader_parameter("sky_color", sky)
	_mat.set_shader_parameter("deep_color", Color(DEEP.r * lit, DEEP.g * lit, DEEP.b * lit))
	_mat.set_shader_parameter("shallow_color",
		Color(SHALLOW_COL.r * lit, SHALLOW_COL.g * lit, SHALLOW_COL.b * lit))
