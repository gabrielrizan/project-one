extends Node3D
## Drives the sun and the sky.
##
## Two things keep sunrise from popping. The sun sweeps a continuous 360 across
## the whole cycle, so its angle never snaps when the clock wraps back to zero;
## and dusk/dawn are eased with a golden hour in the middle rather than a linear
## fade. Dawn is deliberately longer than dusk -- waking up is the nicer moment.

## The whole cycle, and the four instants the sun is pinned to. Proportions are
## lifted from a reference day chart whose cycle was 4 minutes; every segment is
## scaled by 1.5 to give us 6. **The named instants are the source of truth** --
## `DAY_DURATION` and the sun's arc are derived from them, so retiming the day
## means editing these five numbers and nothing else.
##
##     Dawn ---20s--- Sunrise ---70s--- Noon ---75s--- Sunset ---40s--- Midnight ---35s--- Dawn
##      x1.5 ->  30s              105s           112.5s             60s               52.5s
##
## Daytime (Dawn -> Sunset) is 247.5s and night (Sunset -> Dawn) is 112.5s, a
## 2.2 : 1 split. The old cycle was 1 : 1, so **night is now much shorter than
## day** -- worth knowing before combat lands, because the night is the threat
## phase and this shortens it a lot in relative terms.
const CYCLE_DURATION := 360.0
const SUNRISE_AT := 30.0        # sun crosses the horizon going up
const NOON_AT := 135.0          # sun at its peak
const SUNSET_AT := 247.5        # sun crosses back down -- night begins here
const MIDNIGHT_AT := 307.5      # sun at its nadir
## Dawn is t = 0, which is why it has no constant: the clock starts there.
const DAY_DURATION := SUNSET_AT
const NIGHT_DURATION := CYCLE_DURATION - SUNSET_AT

## The light transitions, in absolute seconds, and deliberately **not** derived
## from the instants above -- they are how long the sky takes to change, which is
## a readability decision, not an astronomical one. Dusk begins the moment the sun
## goes down; dawn *finishes* as it comes back up, so it starts before the clock
## wraps. Dawn stays the longer of the two -- waking up is the nicer moment.
const DUSK := 30.0      # from sunset, going dark
const DAWN := 42.0      # up to sunrise, coming light

## **Dropped from 1.2 because the ground was clipping.** Measured, the grass's
## green channel sat pinned at exactly 1.000 across the entire frame at noon --
## a clipped channel carries no shading at all, so midday read as a flat sheet of
## fluorescent green with the lighting information thrown away. At 0.9 the noon
## grass lands around 0.90 instead, which keeps headroom and lets the sun's angle
## show through the whole day. If the world ever needs to be brighter again, take
## it out of the *ambient* term, not this one -- ambient is what flattens.
const DAY_ENERGY := 0.9
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

# ---- shadows ----
#
## Shadows are gated on the sun's **real elevation**, never on the clock -- the
## same rule the watch horn follows, and for the same reason: the phase durations
## are placeholder. Measured, the sun climbs 8 degrees -> 83 at noon -> below the
## horizon for the whole night phase, so elevation is the honest signal.
##
## Two things go wrong without the gate. Under the map the sun is the moon
## stand-in and "shadow" means nothing -- it would cast them *upward*. And just
## above the horizon the streaks run away: a 2 m hut throws 14 m of shadow at
## 8 degrees and 57 m at 2, so the last sliver of the climb has to be faded out
## rather than left to smear the map.
##
## **The fade is what controls shadow length, because nothing else can.** Length
## is set by the sun's arc, and that arc is the whole day/night cycle -- so the
## only honest lever is to make the longest shadows *faint*, letting them read as
## a soft smear instead of a hard bar across the village. Opened up from 2-12
## after play-testing: at 12 the late-afternoon shadows were still at full
## strength while running 8 m long. At 20 the sun is above the threshold for
## about 84 s of the 120 s day, so the raking light survives -- it just stops
## being jet black on the way out.
## Widened again after play-testing. **Shadow length cannot be shortened without
## lying about where the sun is** -- it is set by the arc, and the arc is the day.
## The honest lever is to make the longest ones *faint*, which is also what real
## low-sun light does: the shallower the angle, the more atmosphere it travels
## through and the softer and weaker the shadow gets. So the fade now runs out to
## 28 degrees rather than 20. At 19 degrees -- roughly where a 4.5m tree throws a
## 13m shadow across the whole frame -- strength drops from 0.99 to 0.57, so the
## streak reads as a soft smear rather than a hard black bar.
const SHADOW_FADE_IN := 8.0     # degrees of elevation -- fully off at or below
const SHADOW_FADE_FULL := 28.0  # ...and at full strength from here up

# ---- depth fog ----
#
## Aerial perspective. Everything was equally saturated at every distance, so the
## eye got no depth ordering at all and the world read as one flat layer of
## stickers. `gl_compatibility` has no volumetric fog; plain depth fog is the
## intended substitute (and `weather.gd` was already written expecting it).
##
## **The fog colour is always the sky colour.** One blend drives both, so the
## horizon can never disagree with the haze in front of it -- at noon, at golden
## hour, at midnight, under a storm, and during a lightning flash, where the whole
## distance lights up with the sky exactly as a real cloud deck would. That is
## also why fog lives here and not in `weather.gd`: the environment has exactly
## one owner (see `storm` above), and two writers in a frame fight and flicker.
##
## **Tuned to what the camera can actually see, not to the size of the map.** The
## first pass used an 18-65 m band, which measured correctly and did nothing at
## all on screen: from 8.63 m back at a 40 degree pitch the far edge of the frame
## is only ~32 m out, so two thirds of that band sat behind the horizon. The
## visible range is roughly 3 m to 32 m and the fog has to do its whole job inside
## it. If D5 pulls the camera back, FOG_FAR is the number to move.
##
## Strengthened after play-testing -- at 0.55 over a 9-42 m band a clear day had
## no perceptible fog at all. The reason it reads so much weaker than the storm
## does is **luminance, not density**: fog mixes toward the sky, and at midday a
## light blue sky over bright lime grass is a mix of two similar brightnesses, so
## 40% fog barely shifts the pixel. A grey storm sky over the same grass is a big
## luminance step and shows up instantly. A clear day therefore needs a visibly
## higher number to land the *same* amount of depth.
## **Fog is weather, not atmosphere.** Clear-day fog was tried at four different
## strengths and never earned its place: at a low setting it was invisible, and at
## a high enough setting to read it bleached the treeline pale instead of pushing
## it back. The reason is that depth fog can only tint toward one flat colour, and
## against this palette that reads as *washed out* rather than *far away* -- the
## trees lose contrast without gaining distance. So fog now only exists when it is
## raining, where it is doing an honest job (you genuinely cannot see far through
## rain) and where the grey it mixes toward is the sky it belongs to.
##
## **Re-tuned for the `battle 45` camera.** From 18.38 m up at a 45 degree pitch
## with a 34 degree lens, the visible ground runs from **21 m to 39 m of slant
## distance** -- so the old 8-40 m band would have fogged the grass under the
## monarch's feet. Fog has to start past the near edge and ramp to the far one.
## Any camera change moves these again; the presets on C do not, which is why
## they are for looking rather than for shipping.
const FOG_NEAR := 22.0          # metres before fog starts at all
const FOG_FAR := 55.0           # ...and where it reaches its full amount
const FOG_CURVE := 1.2          # >1 keeps the near ground clean and ramps late
const FOG_STORM := 0.95         # rain closes the world in
const FOG_STORM_NEAR := 14.0    # ...and brings the wall of grey most of the way in

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
##
## Both ends are measured against the horizon crossings rather than against the
## phase boundaries, and both wrap with `fposmod`, so the dawn ramp can straddle
## the end of the cycle without a special case.
func darkness() -> float:
	var to_sunrise := fposmod(SUNRISE_AT - _time, CYCLE_DURATION)
	if to_sunrise < DAWN:
		return smoothstep(0.0, 1.0, to_sunrise / DAWN)
	var since_sunset := fposmod(_time - SUNSET_AT, CYCLE_DURATION)
	if since_sunset < DUSK:
		return smoothstep(0.0, 1.0, since_sunset / DUSK)
	# Either full daylight or the flat middle of the night.
	return 1.0 if is_night() else 0.0

## How far round its circle the sun has travelled since sunrise, in degrees:
## 0 rising, 90 overhead, 180 setting, 270 at its nadir, 360 back at sunrise.
##
## Piecewise through the four instants rather than one linear sweep, because the
## reference day is not symmetric -- sunrise to noon is shorter than noon to
## sunset, and the sun is under the map for less of the cycle than it is over it.
## The rate therefore changes at each instant, which is invisible: the two changes
## in daylight happen at noon and midnight, where elevation is barely moving.
## Still one continuous 360 across the cycle, so nothing snaps when `_time` wraps.
func _sun_angle() -> float:
	var t := _time
	if t < SUNRISE_AT:
		t += CYCLE_DURATION      # the pre-dawn stretch belongs to the previous night
	if t < NOON_AT:
		return remap(t, SUNRISE_AT, NOON_AT, 0.0, 90.0)
	if t < SUNSET_AT:
		return remap(t, NOON_AT, SUNSET_AT, 90.0, 180.0)
	if t < MIDNIGHT_AT:
		return remap(t, SUNSET_AT, MIDNIGHT_AT, 180.0, 270.0)
	return remap(t, MIDNIGHT_AT, SUNRISE_AT + CYCLE_DURATION, 270.0, 360.0)

func _process(delta: float) -> void:
	_time = fmod(_time + delta, CYCLE_DURATION)

	sun.rotation_degrees.x = -_sun_angle()

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
	_update_shadows()
	if world_env.environment:
		var env := world_env.environment
		env.ambient_light_color = ambient
		env.background_color = bg
		env.ambient_light_energy = 1.0 + FLASH_AMBIENT_ENERGY * flash
		# Fog rides the sky it has already been blended into -- storm, golden hour
		# and flash are all in `bg` by now, so none of them need their own fog term.
		# It only sits *paler* than that sky, and only in clear daylight.
		# Switched off outright when it isn't raining rather than left on at zero
		# density: it saves the pass, and it makes "fog is weather" true in the
		# code rather than only in the numbers. Safe to own here -- this is the
		# environment's single writer, which is exactly what `weather.gd` doing
		# the same thing violated.
		env.fog_enabled = storm > 0.002
		if env.fog_enabled:
			env.fog_light_color = bg
			env.fog_density = FOG_STORM * storm
			env.fog_depth_begin = lerpf(FOG_NEAR, FOG_STORM_NEAR, storm)

## Fades the sun's shadows in and out with its height above the horizon. `-basis.z`
## is the direction the light travels, so negating its Y gives the sine of the
## elevation directly.
func _update_shadows() -> void:
	var dir := -sun.global_transform.basis.z
	var elevation := rad_to_deg(asin(clampf(-dir.y, -1.0, 1.0)))
	var t := smoothstep(SHADOW_FADE_IN, SHADOW_FADE_FULL, elevation)
	# Switched off outright at the bottom rather than left on at zero opacity: the
	# gate has to hold even if `shadow_opacity` turns out to be a no-op under
	# gl_compatibility, and it saves the shadow pass for half of every cycle.
	sun.shadow_enabled = t > 0.0
	sun.shadow_opacity = t
