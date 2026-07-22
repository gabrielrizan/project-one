extends Node3D
## Rain, storms, and the season clock that decides when either is allowed.
##
## One node drives the lot, the same way `wind.gd` sweeps every tree: three
## particle layers, the pool field, the overcast sky and the lightning all hang
## off a single intensity value.
##
## **Why it looks the way it does.** The project renders with `gl_compatibility`
## (`project.godot`), which has no volumetric fog, no decals and no screen-space
## reflections. That rules out the usual photoreal storm kit, so the haze is
## faked with depth fog plus a slow mist layer, the pools are flat quads on the
## slab, and the lightning is a light spike rather than a light shaft. For a
## flat-shaded low-poly game that is the *better* register anyway -- it is
## art-directable, and it keeps the browser-export door open. Do not "upgrade"
## this to volumetrics without re-tuning `day_night_cycle.gd` wholesale.
##
## **The two clocks are separate on purpose.** Intensity is what you can see and
## hear right now; wetness is how saturated the ground is, and it lags a long
## way behind -- pools keep filling after a shower peaks and are still there
## well after the last drop. Tying the pools straight to intensity made rain
## look like a light switch.

signal lightning(delay: float, loudness: float)

enum Season { SPRING, SUMMER, AUTUMN, WINTER }
enum State { CLEAR, GATHERING, RAINING, CLEARING }

## Seasons are a data-level concept for now: they gate weather and nothing else.
## Snow and per-season colour shifts are planned but deliberately not built --
## see `GAME_DESIGN.md`. **Winter has no rain and no snow yet**, so it currently
## reads as a dry spell; that is the placeholder, not the design.
##
## `chance` is rolled each time a clear spell runs out. `strength` is the range a
## storm's peak intensity is drawn from. `thunder` is the odds that a storm is a
## thunderstorm at all -- summer gets the big ones, autumn is steady and grey.
const SEASONS := {
	Season.SPRING: {
		"name": "Spring", "chance": 0.65, "strength": Vector2(0.30, 0.72), "thunder": 0.25,
	},
	Season.SUMMER: {
		"name": "Summer", "chance": 0.40, "strength": Vector2(0.55, 1.00), "thunder": 0.70,
	},
	Season.AUTUMN: {
		"name": "Autumn", "chance": 0.80, "strength": Vector2(0.35, 0.85), "thunder": 0.15,
	},
	Season.WINTER: {
		"name": "Winter", "chance": 0.00, "strength": Vector2(0.0, 0.0), "thunder": 0.0,
	},
}

## A season lasts this many full day/night cycles. At the current 240s cycle
## that is 12 minutes a season -- long enough that a season feels like a stretch
## of play, short enough that a test session sees more than one.
const CYCLES_PER_SEASON := 3

const CLEAR_GAP := Vector2(70.0, 200.0)     # dry spell before the next roll
const RAIN_LENGTH := Vector2(55.0, 150.0)
const GATHER_TIME := Vector2(8.0, 18.0)     # sky darkens before the first drop
const CLEAR_TIME := Vector2(10.0, 22.0)

## Intensity eases toward its target at this rate, so no transition ever snaps.
const RAMP := 0.14

## **Rain breathes while it falls.** Without this a storm ramps to its peak and
## then holds dead flat until its timer runs out, so every storm has the same
## shape and only its height and length differ -- which is exactly what makes
## weather feel canned.
##
## Two sine rates that don't divide into each other, the same trick `wind.gd`
## uses for gusts: the sum never repeats on any period short enough for the ear
## or eye to catch. `SWELL` is how far it wanders either side of the peak, as a
## *fraction* of that peak, so a drizzle wavers gently and a downpour surges
## hard -- one rule covering both, rather than a flat number that would swamp
## light rain and be invisible in heavy.
## The peak stays the storm's ceiling -- swelling only ever pulls *down* from it,
## between here and full. A storm is never allowed to breathe its way to nothing,
## or it reads as having stopped and then restarted rather than eased off.
const SWELL := 0.35
const SWELL_RATE_A := 0.055
const SWELL_RATE_B := 0.021
## Wetness rises to meet the rain but dries far slower -- pools outlive the
## shower that made them, which is most of what sells the aftermath.
const WET_RISE := 0.055
const WET_DRY := 0.012

# ---- the look ----

## Emission box, centred on the camera and dropped from above it. Wide enough to
## cover the view at any spin angle, because the camera turns with Z / X.
const RAIN_BOX := Vector3(17.0, 0.5, 17.0)
const RAIN_TOP := 13.0
const RAIN_MAX := 2600           # `amount_ratio` scales this down; never restarts
const RAIN_SPEED := Vector2(15.0, 21.0)
const SPLASH_MAX := 700
const MIST_MAX := 90

## Overcast never reaches 1.0 from rain alone -- a downpour is dark, but pinning
## the sky to full storm made midday unreadable.
const STORM_CEIL := 0.88
## **Cloud cover is not proportional to rainfall.** Drizzle falls out of a sky
## that is already fully overcast; what separates it from a downpour is how much
## water comes down, not how much cloud is up there. Driving overcast linearly off
## intensity got that wrong at the bottom of the range: light rain (0.35) dimmed
## the sun by only 16%, so it read as bright midday sun with a few pale streaks
## drawn over it, and the streaks were invisible against lit grass.
##
## An exponent below 1 lifts the low end hard and leaves the top almost untouched:
## 0.35 -> 0.56 and 0.7 -> 0.82, while 1.0 stays exactly 1.0, so a downpour looks
## exactly as it did. A *floor* would have been the other way to say this, but it
## pops -- intensity ramps up from 0 through the gathering phase, so a floor makes
## the sky lurch the instant rain starts. This stays continuous through zero.
const OVERCAST_CURVE := 0.55

## The *wet ground* under the water, not the water itself -- the shader mixes
## this heavily toward the sky colour, because standing water seen from height
## reads lighter than the grass around it. Kept fairly sheer: at high alpha the
## pools stop looking like water lying on grass and start looking like holes
## cut in it. Tinted by the sky each frame so they grey out under cloud and go
## near-black at night.
const WATER_BASE := Color(0.24, 0.30, 0.28, 0.46)

## Lightning is scheduled against the *storm*, not the clock: no strikes until
## the rain has some weight behind it.
const STRIKE_MIN_INTENSITY := 0.45
## Divided by 1.5 from the original 9-34s, which is a 50% lift in strikes (and
## therefore in thunder, since every flash gets one). Scaling the gap rather
## than loosening `STRIKE_MIN_INTENSITY` or the seasons' thunder odds keeps
## *which* storms are thundery exactly as it was -- only their rate changes.
const STRIKE_GAP := Vector2(6.0, 22.5)
## Distant, so the flash arrives well before the sound. Seconds of delay, which
## also sets how muffled the thunder is when `ambience.gd` plays it.
const THUNDER_DELAY := Vector2(2.5, 9.0)
const FLASH_DECAY := 7.0

const PUDDLE_SHADER := preload("res://kingdom_demo/assets/shaders/puddle.gdshader")
const PUDDLES_SCRIPT := preload("res://kingdom_demo/scripts/puddles.gd")

var _puddles: Node = null

## Typed `int` rather than `Season` throughout: the enum is here to name the
## values, but GDScript is fussy about assigning back out of `Season.values()`.
var _season: int = Season.SPRING
var _cycles := 0
var _last_time := 0.0

var _state: State = State.CLEAR
var _timer := 0.0
var _target := 0.0
var _peak := 0.0
var _thundery := false

var _t := 0.0
var _intensity := 0.0
var _wetness := 0.0
var _flash := 0.0
var _pulses: Array = []          # pending [delay, strength] flashes
var _strike_t := 0.0

var _rain: GPUParticles3D = null
var _splash: GPUParticles3D = null
var _mist: GPUParticles3D = null
var _rig: Node3D = null
var _cycle: Node = null

func _ready() -> void:
	add_to_group("weather")
	_season = randi() % Season.size()
	_timer = randf_range(CLEAR_GAP.x, CLEAR_GAP.y)
	_strike_t = randf_range(STRIKE_GAP.x, STRIKE_GAP.y)
	_puddles = _make_puddles()
	_rain = _make_rain()
	_splash = _make_splash()
	_mist = _make_mist()
	call_deferred("_find_refs")

func _find_refs() -> void:
	_rig = get_tree().get_first_node_in_group("camera_rig")
	_cycle = get_tree().get_first_node_in_group("day_night_cycle")
	if _cycle:
		_last_time = _cycle.time_of_day()

# ---------------------------------------------------------------- public

func is_raining() -> bool:
	return _intensity > 0.02

## 0..1, what is falling right now.
func intensity() -> float:
	return _intensity

## 0..1, how saturated the ground is. Lags well behind `intensity()`.
func wetness() -> float:
	return _wetness

func season() -> int:
	return _season

func season_name() -> String:
	return SEASONS[_season]["name"]

func state_name() -> String:
	return ["clear", "gathering", "raining", "clearing"][_state]

func rains_this_season() -> bool:
	return SEASONS[_season]["chance"] > 0.0

# ---------------------------------------------------------------- dev hooks

## Start a storm now. `snap` lands it instantly rather than letting the sky
## gather -- which is the point of a dev key, but it does skip the nicest part.
func force_rain(strength: float, snap: bool = true, thundery: bool = true) -> void:
	_peak = clampf(strength, 0.0, 1.0)
	_target = _peak
	_thundery = thundery
	_state = State.RAINING
	_timer = randf_range(RAIN_LENGTH.x, RAIN_LENGTH.y)
	if snap:
		_intensity = _peak
	_puddles.form()

func stop_rain(snap: bool = true) -> void:
	_target = 0.0
	_state = State.CLEAR
	_timer = randf_range(CLEAR_GAP.x, CLEAR_GAP.y)
	if snap:
		_intensity = 0.0

## Dry the ground out too. Separate from `stop_rain` because watching the pools
## dry off naturally is usually what you want to see.
func dry_out() -> void:
	_wetness = 0.0

func set_season(s: int) -> void:
	_season = s
	_cycles = 0

func next_season() -> void:
	set_season((_season + 1) % Season.size())

## One strike, right now, wherever the weather is up to.
func strike_lightning() -> void:
	_pulses.append([0.0, 1.0])
	# A real strike flickers rather than flashing once.
	if randf() < 0.55:
		_pulses.append([randf_range(0.07, 0.16), randf_range(0.35, 0.7)])
	var delay := randf_range(THUNDER_DELAY.x, THUNDER_DELAY.y)
	# Farther away means later and quieter -- one number drives both, so the
	# delay you see is always consistent with the boom you hear.
	var far := inverse_lerp(THUNDER_DELAY.x, THUNDER_DELAY.y, delay)
	lightning.emit(delay, lerpf(1.0, 0.35, far))

# ---------------------------------------------------------------- tick

func _process(delta: float) -> void:
	_t += delta
	_advance_seasons()
	_advance_state(delta)
	# Only a storm that is actually falling breathes. Gathering and clearing set
	# `_target` themselves and must be left to run to their ends.
	if _state == State.RAINING:
		_target = _peak * _swell()
	_intensity = move_toward(_intensity, _target, RAMP * delta)
	_advance_wetness(delta)
	_advance_lightning(delta)
	_drive_look(delta)

## Seasons advance off the day/night clock rather than a timer of their own, so
## "three cycles" stays true however the cycle length is retuned. A wrap is
## detected by the clock running backwards; a dev time-jump can therefore cost
## or gift a cycle, which is a fair trade for not duplicating the clock.
func _advance_seasons() -> void:
	if _cycle == null:
		return
	var t: float = _cycle.time_of_day()
	if t < _last_time:
		_cycles += 1
		if _cycles >= CYCLES_PER_SEASON:
			_cycles = 0
			next_season()
	_last_time = t

func _advance_state(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	match _state:
		State.CLEAR:
			# The season decides whether anything happens at all. A failed roll
			# just buys another dry spell, so winter simply never starts one.
			if randf() < float(SEASONS[_season]["chance"]):
				var band: Vector2 = SEASONS[_season]["strength"]
				_peak = randf_range(band.x, band.y)
				_thundery = randf() < float(SEASONS[_season]["thunder"])
				_target = _peak
				_state = State.GATHERING
				_timer = randf_range(GATHER_TIME.x, GATHER_TIME.y)
				_puddles.form()
			else:
				_timer = randf_range(CLEAR_GAP.x, CLEAR_GAP.y)
		State.GATHERING:
			_state = State.RAINING
			_timer = randf_range(RAIN_LENGTH.x, RAIN_LENGTH.y)
		State.RAINING:
			_target = 0.0
			_state = State.CLEARING
			_timer = randf_range(CLEAR_TIME.x, CLEAR_TIME.y)
		State.CLEARING:
			_state = State.CLEAR
			_timer = randf_range(CLEAR_GAP.x, CLEAR_GAP.y)

## How much of its peak the storm is giving right now, 1-SWELL .. 1. Two slow
## waves whose rates don't divide into each other, so the sum has no period
## short enough to notice -- lifted straight from `wind.gd::gust()`, which
## solves the same "make it wander convincingly" problem for the trees.
func _swell() -> float:
	var w := (sin(_t * TAU * SWELL_RATE_A) + sin(_t * TAU * SWELL_RATE_B)) * 0.5
	return 1.0 - SWELL * 0.5 * (1.0 - w)

func _advance_wetness(delta: float) -> void:
	if _intensity > 0.02:
		# Heavier rain saturates faster, but never past what is falling -- a
		# drizzle should leave shallow pools however long it goes on for.
		_wetness = move_toward(_wetness, _intensity, WET_RISE * (0.5 + _intensity) * delta)
	else:
		_wetness = move_toward(_wetness, 0.0, WET_DRY * delta)

func _advance_lightning(delta: float) -> void:
	_flash = maxf(0.0, _flash - FLASH_DECAY * delta)
	for i in range(_pulses.size() - 1, -1, -1):
		_pulses[i][0] -= delta
		if _pulses[i][0] <= 0.0:
			_flash = maxf(_flash, float(_pulses[i][1]))
			_pulses.remove_at(i)

	if not _thundery or _intensity < STRIKE_MIN_INTENSITY:
		return
	_strike_t -= delta
	if _strike_t <= 0.0:
		_strike_t = randf_range(STRIKE_GAP.x, STRIKE_GAP.y)
		strike_lightning()

# ---------------------------------------------------------------- the look

func _drive_look(_delta: float) -> void:
	var env: Environment = null
	if _cycle:
		_cycle.storm = clampf(pow(_intensity, OVERCAST_CURVE) * STORM_CEIL, 0.0, 1.0)
		_cycle.flash = _flash
		if _cycle.world_env:
			env = _cycle.world_env.environment

	# Depth fog used to be written from right here, rain-only: `fog_enabled` was
	# tied to `_intensity > 0.02`, so the moment it stopped raining fog was turned
	# **off entirely**. That silently defeated the clear-day aerial perspective in
	# `day_night_cycle.gd` -- density and colour were being written every frame
	# onto a disabled fog, so no value of either could ever show on screen and only
	# a storm ever looked hazy. Fog now belongs to the cycle along with the rest of
	# the environment (see `CLAUDE.md`), and it still thickens with rain, because
	# `storm` is set a few lines above and the cycle reads it. Nothing was lost.

	_follow_camera()

	var lit := 1.0
	if _cycle:
		lit = lerpf(1.0, 0.22, _cycle.darkness())
	var sky: Color = env.background_color if env else Color(0.5, 0.6, 0.7)
	var water := Color(WATER_BASE.r * lit, WATER_BASE.g * lit, WATER_BASE.b * lit, WATER_BASE.a)
	# Pools mirror whatever the sky is doing, so they grey out under cloud and
	# pick the sunset up at dusk without any special-casing here.
	var sheen := sky.lerp(Color(0.85, 0.90, 0.95), 0.25) * lit
	sheen.a = 1.0
	_puddles.set_state(_wetness, _intensity, water, sheen)

	if _rain:
		_rain.emitting = _intensity > 0.02
		_rain.amount_ratio = clampf(_intensity, 0.0, 1.0)
		_tilt_rain()
	if _splash:
		_splash.emitting = _intensity > 0.05
		_splash.amount_ratio = clampf(_intensity, 0.0, 1.0)
	if _mist:
		_mist.emitting = _intensity > 0.15
		_mist.amount_ratio = clampf(_intensity, 0.0, 1.0)

## The rain box rides the camera rig, not the monarch -- the rig is already the
## smoothed follow position, so the rain doesn't judder when the king changes
## direction. Height is fixed; only the ground plane is tracked.
func _follow_camera() -> void:
	if _rig == null:
		return
	var p: Vector3 = _rig.global_position
	if _rain:
		_rain.global_position = Vector3(p.x, RAIN_TOP, p.z)
	if _splash:
		_splash.global_position = Vector3(p.x, 0.03, p.z)
	if _mist:
		_mist.global_position = Vector3(p.x, 1.1, p.z)

## Rain leans along the same bearing the trees are leaning and the leaves are
## travelling. Reusing `wind.gd`'s bearing rather than picking one is the whole
## point -- a storm blowing across the wind would read as two weathers at once.
func _tilt_rain() -> void:
	if _rain == null:
		return
	var wind := get_tree().get_first_node_in_group("wind")
	var mat := _rain.process_material as ParticleProcessMaterial
	if wind == null or mat == null:
		return
	var dir: Vector3 = wind.wind_dir()
	var push: float = wind.gust() * lerpf(1.5, 6.5, _intensity)
	mat.gravity = Vector3(dir.x * push, -22.0, dir.z * push)

# ---------------------------------------------------------------- particles

## The pool field. Built here rather than in the scene so the shader and its
## material are wired in one place -- see `puddles.gd` for how the field itself
## is laid out.
func _make_puddles() -> Node:
	var field := MultiMeshInstance3D.new()
	var mat := ShaderMaterial.new()
	mat.shader = PUDDLE_SHADER
	field.material_override = mat
	field.set_script(PUDDLES_SCRIPT)
	add_child(field)
	return field

## Built in code rather than sat in the scene, the same way `menu.gd` builds its
## layout -- there is no hand-authored `.tscn` to drift out of sync with these
## numbers, and every value that matters is visible in one place.
func _make_rain() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = RAIN_MAX
	p.lifetime = 1.2
	p.preprocess = 1.2          # so switching rain on doesn't start with empty sky
	p.explosiveness = 0.0
	p.randomness = 0.35
	p.visibility_aabb = AABB(Vector3(-24, -RAIN_TOP - 2.0, -24), Vector3(48, RAIN_TOP + 6.0, 48))
	p.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = RAIN_BOX
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 0.0
	mat.initial_velocity_min = RAIN_SPEED.x
	mat.initial_velocity_max = RAIN_SPEED.y
	mat.gravity = Vector3(0, -22.0, 0)
	mat.scale_min = 0.75
	mat.scale_max = 1.5
	p.process_material = mat

	# A long thin quad billboarded around Y: it stays upright in the world and
	# only spins to face the camera, which is exactly how a falling streak
	# should behave when the player swings the view with Z / X.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.022, 0.62)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	look.billboard_keep_scale = true
	look.albedo_color = Color(0.74, 0.82, 0.90, 0.5)
	look.disable_receive_shadows = true
	quad.material = look
	p.draw_pass_1 = quad

	_add_layer(p)
	return p

## The impacts. Short, tiny and very numerous -- individually invisible, but
## they are what stops the ground looking like rain is falling *past* it rather
## than onto it.
func _make_splash() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = SPLASH_MAX
	p.lifetime = 0.32
	p.randomness = 0.6
	p.visibility_aabb = AABB(Vector3(-24, -1, -24), Vector3(48, 4, 48))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(RAIN_BOX.x, 0.02, RAIN_BOX.z)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 32.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.4
	mat.gravity = Vector3(0, -7.0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.1
	p.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.028, 0.028)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	look.billboard_keep_scale = true
	look.albedo_texture = _soft_dot()
	look.albedo_color = Color(0.82, 0.88, 0.93, 0.55)
	look.disable_receive_shadows = true
	quad.material = look
	p.draw_pass_1 = quad

	_add_layer(p)
	return p

## The haze. Big, slow, nearly invisible quads drifting at head height -- this is
## the stand-in for the volumetric fog Compatibility doesn't have, and it does
## the half of the job depth fog can't: giving the air some visible movement.
func _make_mist() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = MIST_MAX
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.randomness = 0.8
	p.visibility_aabb = AABB(Vector3(-26, -3, -26), Vector3(52, 10, 52))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(18.0, 1.6, 18.0)
	mat.direction = Vector3(1, 0, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 0.5
	mat.initial_velocity_max = 1.6
	mat.gravity = Vector3.ZERO
	mat.scale_min = 3.5
	mat.scale_max = 8.0
	p.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	look.billboard_keep_scale = true
	look.albedo_texture = _soft_dot()
	look.albedo_color = Color(0.70, 0.74, 0.78, 0.10)
	look.disable_receive_shadows = true
	quad.material = look
	p.draw_pass_1 = quad

	_add_layer(p)
	return p

## A soft round dot, generated rather than downloaded -- `GradientTexture2D` can
## fill radially, so this costs no asset and no licence.
##
## It exists because a quad with flat alpha shows its own square edges the
## moment two of them overlap, and the mist layer is nothing *but* overlapping
## quads: at 90 of them the haze came out as a grid of visible rectangles. A
## radial alpha falloff is what makes them read as one continuous fog instead.
func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t

## Every layer is repositioned by hand each frame, so interpolation is turned
## off for it -- the project runs with `physics_interpolation` on globally
## (`project.godot`), and an interpolated emitter lags the camera it is supposed
## to be centred on.
##
## **Nothing weather draws ever casts a shadow.** Now that the sun does
## (`day_night_cycle.gd`), the default would have every raindrop, splash and mist
## quad rendered into the shadow map -- thousands of them, for a stipple of dark
## specks over the whole village that reads as dirt, not rain. Gated here rather
## than on each emitter so any layer added later inherits it.
func _add_layer(p: GPUParticles3D) -> void:
	p.emitting = false
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(p)
