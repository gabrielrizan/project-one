extends MultiMeshInstance3D
## The water pools that form while it rains and dry out after.
##
## The whole field is one MultiMesh -- a hundred-odd pools cost a single draw
## call, which is what makes it affordable to scatter them over the map rather
## than only around the camp. Everything that differs per pool (its size, its
## outline, and the wetness it waits for before it starts filling) is baked into
## the instance buffer once; from then on a storm only writes a few uniforms.
## See `puddle.gdshader` for the split.
##
## **Spots are re-picked at the start of every storm, not once at startup.**
## The village doesn't exist until the campfire is lit, so a spot chosen on the
## first frame could easily be under a hut by the third night. Re-picking while
## the ground is still dry is invisible and keeps pools out of whatever has been
## built since.

## Pools are scattered inside this radius of the origin. Comfortably wider than
## the walls, so riding out to the treeline still finds wet ground, but well
## short of the 100x100 slab's edge -- nobody goes out there.
const FIELD_RADIUS := 42.0
const POOL_COUNT := 110
## Rejected spots are retried rather than dropped, or a crowded village would
## thin the field out everywhere it matters most.
const PLACE_TRIES := 6

const POOL_RADIUS := Vector2(0.45, 1.50)
## Just clear of the grass. Any lower z-fights the ground mesh; any higher and
## the pool visibly floats when the camera swings round to a low angle.
const POOL_Y := 0.012

## Big pools sit in the lowest ground, so they arrive first and linger longest.
## Threshold is drawn from this range and then biased by size, which is what
## makes the field fill in an order that looks like drainage rather than noise.
const THRESHOLD := Vector2(0.05, 0.62)

var _mat: ShaderMaterial = null

func _ready() -> void:
	_mat = material_override as ShaderMaterial
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE          # scaled per instance to the pool's diameter
	multimesh.mesh = plane
	multimesh.instance_count = POOL_COUNT
	multimesh.visible_instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Deferred: the clearance test needs the physics space populated, and during
	# `_ready` on the first frame nothing is registered in it yet.
	call_deferred("form")

## Re-scatter the field. Called by `weather.gd` as a storm gathers, while the
## ground is still dry enough that nothing visibly moves.
func form() -> void:
	var placed := 0
	for i in range(POOL_COUNT):
		var spot := _find_spot()
		if spot == Vector3.INF:
			continue
		var radius := randf_range(POOL_RADIUS.x, POOL_RADIUS.y)
		var basis := Basis().scaled(Vector3(radius * 2.0, 1.0, radius * 2.0))
		multimesh.set_instance_transform(placed, Transform3D(basis, spot))
		# Bias the threshold down for wide pools: the big ones are the dips, and
		# a dip that fills last would read as backwards.
		var size_t := inverse_lerp(POOL_RADIUS.x, POOL_RADIUS.y, radius)
		var threshold := lerpf(THRESHOLD.y, THRESHOLD.x, size_t) * randf_range(0.75, 1.25)
		multimesh.set_instance_custom_data(placed,
			Color(clampf(threshold, 0.0, 0.95), randf(), 0.0, 0.0))
		placed += 1
	multimesh.visible_instance_count = placed

## A clear patch of ground, or `Vector3.INF` if every try landed on something.
## The test sphere is lifted so its underside clears the slab -- the ground is a
## collider too, and a query sitting on it would reject every spot on the map.
func _find_spot() -> Vector3:
	var space := get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	for _try in range(PLACE_TRIES):
		# sqrt keeps the scatter even; without it everything crowds the middle
		var a := randf() * TAU
		var d := sqrt(randf()) * FIELD_RADIUS
		var pos := Vector3(cos(a) * d, POOL_Y, sin(a) * d)
		var radius := POOL_RADIUS.y * 0.6      # generous, so pools don't kiss walls
		shape.radius = radius
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis(), pos + Vector3(0, radius + 0.2, 0))
		q.collide_with_areas = false
		if space.intersect_shape(q, 1).is_empty():
			return pos
	return Vector3.INF

## Driven every frame by `weather.gd`, which owns the colours -- see the shader
## header for why the tinting happens up there and not in here.
func set_state(wetness: float, rain: float, water: Color, sheen: Color) -> void:
	if _mat == null:
		return
	visible = wetness > 0.001
	if not visible:
		return
	_mat.set_shader_parameter("wetness", wetness)
	_mat.set_shader_parameter("rain", rain)
	_mat.set_shader_parameter("water_color", water)
	_mat.set_shader_parameter("sheen_color", sheen)
