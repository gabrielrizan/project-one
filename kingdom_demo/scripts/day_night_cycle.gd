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

@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment

var _time := 0.0

func is_night() -> bool:
	return _time >= DAY_DURATION

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

	sun.light_energy = lerpf(DAY_ENERGY, NIGHT_ENERGY, blend)
	sun.light_color = DAY_COLOR.lerp(NIGHT_COLOR, blend).lerp(GOLDEN_COLOR, golden * 0.8)
	if world_env.environment:
		world_env.environment.ambient_light_color = DAY_AMBIENT.lerp(NIGHT_AMBIENT, blend)
		world_env.environment.background_color = DAY_BG.lerp(NIGHT_BG, blend).lerp(GOLDEN_BG, golden * 0.7)
