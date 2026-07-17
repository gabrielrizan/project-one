extends Node3D

const DAY_DURATION := 60.0
const NIGHT_DURATION := 30.0
const CYCLE_DURATION := DAY_DURATION + NIGHT_DURATION
const TRANSITION := 6.0

const DAY_ENERGY := 1.2
const NIGHT_ENERGY := 0.5
const DAY_COLOR := Color(1.0, 0.95, 0.85)
const NIGHT_COLOR := Color(0.6, 0.66, 0.9)
const DAY_AMBIENT := Color(0.55, 0.6, 0.65)
const NIGHT_AMBIENT := Color(0.26, 0.3, 0.44)
const DAY_BG := Color(0.53, 0.81, 0.92)
const NIGHT_BG := Color(0.16, 0.2, 0.36)

@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment

var _time := 0.0

func is_night() -> bool:
	return _time >= DAY_DURATION

func _process(delta: float) -> void:
	_time = fmod(_time + delta, CYCLE_DURATION)
	sun.rotation_degrees.x = -180.0 * (_time / CYCLE_DURATION) - 10.0

	var blend := 0.0
	if _time < DAY_DURATION:
		blend = clamp((_time - (DAY_DURATION - TRANSITION)) / TRANSITION, 0.0, 1.0)
	else:
		var night_t := _time - DAY_DURATION
		blend = 1.0 - clamp((night_t - (NIGHT_DURATION - TRANSITION)) / TRANSITION, 0.0, 1.0)

	sun.light_energy = lerp(DAY_ENERGY, NIGHT_ENERGY, blend)
	sun.light_color = DAY_COLOR.lerp(NIGHT_COLOR, blend)
	if world_env.environment:
		world_env.environment.ambient_light_color = DAY_AMBIENT.lerp(NIGHT_AMBIENT, blend)
		world_env.environment.background_color = DAY_BG.lerp(NIGHT_BG, blend)
