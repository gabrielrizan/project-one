extends Node3D
## Drives the sun and the sky.
##
## Two things keep sunrise from popping. The sun sweeps a continuous 360 across
## the whole cycle, so its angle never snaps when the clock wraps back to zero;
## and dusk/dawn are eased with a golden hour in the middle rather than a linear
## fade. Dawn is deliberately longer than dusk -- waking up is the nicer moment.

const DAY_DURATION := 120.0
const NIGHT_DURATION := 120.0
const CYCLE_DURATION := DAY_DURATION + NIGHT_DURATION
## Both are absolute seconds, so they do NOT scale when the phases change -- at
## the old 60s/30s cycle these were 15% of the day and 47% of the night, and
## doubling the phases quietly cut them to 7.5% and 12%. Widened to keep the
## transitions readable: dusk long enough to be a warning, dawn longer still,
## because waking up is the nicer moment.
const DUSK := 20.0      # final seconds of the day
const DAWN := 28.0      # final seconds of the night

const DAY_ENERGY := 1.2
const NIGHT_ENERGY := 0.35
const DAY_COLOR := Color(1.0, 0.95, 0.85)
const NIGHT_COLOR := Color(0.55, 0.62, 0.90)
const GOLDEN_COLOR := Color(1.0, 0.64, 0.34)
const DAY_AMBIENT := Color(0.55, 0.60, 0.65)
const NIGHT_AMBIENT := Color(0.22, 0.26, 0.40)
const DAY_BG := Color(0.53, 0.81, 0.92)
const NIGHT_BG := Color(0.10, 0.13, 0.26)
const GOLDEN_BG := Color(0.85, 0.55, 0.34)

## Overcast. Applied *after* the day/night blend rather than replacing it, so a
## storm at noon and a storm at midnight are still recognisably noon and midnight
## -- weather dims and greys the sky, it doesn't overwrite the time of day.
const STORM_BG := Color(0.30, 0.33, 0.36)
const STORM_AMBIENT := Color(0.33, 0.35, 0.39)
const STORM_SUN := Color(0.70, 0.72, 0.76)
## How much of the sun a full storm eats. Cloud cover kills the *direct* light
## hardest; ambient only drifts grey, which is why the two are separate numbers.
const STORM_DIM := 0.55
## Lightning. Big on purpose -- a flash has to punch through an already-dark
## storm sky to register at all, and it is gone in under a fifth of a second.
##
## Kept *cold*, and weighted toward ambient rather than sun energy. Driving it
## mostly through the sun made the flash read as the sun coming out: warm, and
## with the grass snapping back to full saturation, as though the storm had
## briefly stopped. Lightning is a huge diffuse source in the cloud deck, so a
## blue-white ambient lift is both truer and much more readable.
const FLASH_ENERGY := 0.85
## The flash is mostly *this* -- a uniform blue-white lift on everything at once.
## Directional energy is kept low on purpose: a strong sun term lights only the
## faces pointing at it and drives the grass to full saturation, which is what
## made early versions look like the clouds had parted.
const FLASH_AMBIENT_ENERGY := 1.7
const FLASH_BG := Color(0.76, 0.81, 0.97)

@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment

## 0..1 overcast, driven by `weather.gd`. Kept here rather than in the weather
## node because the environment has exactly one owner -- two scripts writing
## `background_color` in the same frame would fight and flicker.
var storm := 0.0
## 0..1 lightning flash, spiked by `weather.gd` and decayed by it too.
var flash := 0.0

var _time := 0.0

func is_night() -> bool:
	return _time >= DAY_DURATION

func time_of_day() -> float:
	return _time

## Dev tooling (`dev_menu.gd`) jumps the clock with this. Wrapped rather than
## clamped so "skip to night" from late night lands on the next night, not on a
## clock that refuses to move.
func set_time_of_day(t: float) -> void:
	_time = fposmod(t, CYCLE_DURATION)

## 0 = full daylight, 1 = full dark, eased through dusk and dawn.
func darkness() -> float:
	if _time < DAY_DURATION:
		var t := (_time - (DAY_DURATION - DUSK)) / DUSK
		return smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))
	var night_t := _time - DAY_DURATION
	var d := (night_t - (NIGHT_DURATION - DAWN)) / DAWN
	return 1.0 - smoothstep(0.0, 1.0, clampf(d, 0.0, 1.0))

func _process(delta: float) -> void:
	_time = fmod(_time + delta, CYCLE_DURATION)

	# Half the turn is spent arcing overhead, half beneath us. Sweeping the full
	# circle is what stops the light jumping when _time wraps.
	var swept: float
	if _time < DAY_DURATION:
		swept = 0.5 * (_time / DAY_DURATION)
	else:
		swept = 0.5 + 0.5 * ((_time - DAY_DURATION) / NIGHT_DURATION)
	sun.rotation_degrees.x = -8.0 - 360.0 * swept

	var blend := darkness()
	# the golden hour peaks halfway through each transition
	var golden := smoothstep(0.0, 1.0, clampf(1.0 - absf(blend - 0.5) * 2.0, 0.0, 1.0))

	var energy := lerpf(DAY_ENERGY, NIGHT_ENERGY, blend)
	var sun_col := DAY_COLOR.lerp(NIGHT_COLOR, blend).lerp(GOLDEN_COLOR, golden * 0.8)
	var ambient := DAY_AMBIENT.lerp(NIGHT_AMBIENT, blend)
	var bg := DAY_BG.lerp(NIGHT_BG, blend).lerp(GOLDEN_BG, golden * 0.7)

	# Overcast. The golden hour is the first thing a storm should take away --
	# cloud cover means no low sun breaking through -- so the storm blend is
	# applied on top of a sky that has already had its golden tint mixed in,
	# washing it back out rather than letting the two fight.
	if storm > 0.0:
		energy *= lerpf(1.0, 1.0 - STORM_DIM, storm)
		sun_col = sun_col.lerp(STORM_SUN, storm)
		ambient = ambient.lerp(STORM_AMBIENT, storm * 0.85)
		bg = bg.lerp(STORM_BG, storm)

	# Lightning has to lift the **ambient** as well as the sun. Sun energy alone
	# only brightens surfaces the sun happens to face, so a flash at night --
	# when the sun is under the map and lighting nothing -- did almost nothing.
	# Ambient is what makes the whole world jump.
	if flash > 0.0:
		energy += FLASH_ENERGY * flash
		bg = bg.lerp(FLASH_BG, flash * 0.65)
		sun_col = sun_col.lerp(FLASH_BG, flash * 0.92)
		ambient = ambient.lerp(FLASH_BG, clampf(flash * 0.9, 0.0, 1.0))

	sun.light_energy = energy
	sun.light_color = sun_col
	if world_env.environment:
		world_env.environment.ambient_light_color = ambient
		world_env.environment.background_color = bg
		world_env.environment.ambient_light_energy = 1.0 + FLASH_AMBIENT_ENERGY * flash
