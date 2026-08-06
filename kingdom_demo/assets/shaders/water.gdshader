shader_type spatial;
// The sea around the island.
//
// Geometrically this is one flat ring lying just *above* the ground slab, not a
// plane below it. The slab is 180 m square and the island is ~112 m across, so
// green would otherwise show past the coast in every direction; the ring starts
// at the shore and runs to the horizon, and the slab under it is simply covered.
// That only works because the world is one flat slab (see CLAUDE.md) -- there is
// no terrain for a flat ring to clip through.
//
// Two rules, both learned the hard way and both written down in CLAUDE.md:
//
//   * From this high, steep camera, standing water reads **lighter** than the
//     ground, because what you are looking at in it is the sky. So the base
//     colour is dominated by `sky_color` -- which `sea.gd` feeds straight from
//     the environment -- and the sea greys under cloud, reddens under a blood
//     moon and goes near-black at night without this shader knowing that any of
//     those things exist.
//   * The chop is built from **two crossed axis waves, never a radial term**.
//     `sin(r * k)` over a round mesh draws a bullseye, which is exactly what the
//     puddles looked like before they were rebuilt this way.
//
// `unshaded`, for the same reason `puddle.gdshader` is: re-implementing the
// light() path for one flat surface buys nothing when the colours are being
// handed in already tinted for the hour and the weather.
render_mode blend_mix, cull_disabled, unshaded, depth_draw_opaque;

// The sky, as `day_night_cycle.gd` has already blended it -- time of day, storm,
// blood moon and lightning are all in it by the time it arrives here.
uniform vec4 sky_color : source_color = vec4(0.53, 0.81, 0.92, 1.0);
// The water's own tint, deep and shallow. Both stay well under the sky term.
uniform vec4 deep_color : source_color = vec4(0.10, 0.28, 0.40, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.32, 0.62, 0.63, 1.0);
uniform vec4 foam_color : source_color = vec4(0.94, 0.97, 0.98, 1.0);
// How much sky the surface carries. The single knob for "is this reading as
// water or as a hole in the map".
uniform float sky_mix : hint_range(0.0, 1.0) = 0.55;

// --- the hand-painted coat ---
//
// A seamless watercolour tile (Voxel Core Lab, CC0 — see the pack's SOURCE.md),
// sampled **twice at different scales, scrolling in different directions**. One
// layer at any scale reads as wallpaper the moment you can see two tiles at once,
// and the sea is 640 m across, so you always can. Two layers at an irrational
// ratio never line up.
//
// It is used for its **variation, not its colour**: each sample is divided by the
// tile's own mean (`tex_mean`, measured once by `sea.gd`), which leaves a field
// hovering around 1.0 that *multiplies* the water tint. So the paper grain and the
// tonal drift come from the painting, while the hue still comes from the sky —
// which is what keeps the sea going grey under cloud, red under a blood moon and
// near-black at night without the texture fighting any of it.
uniform sampler2D water_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tex_mean = vec3(0.35);
uniform float tex_strength : hint_range(0.0, 1.0) = 0.85;
// Metres across for the coarse layer. The fine one is a fixed fraction of it.
uniform float tex_metres = 42.0;
uniform float drift = 1.0;
// Surface chop, and how fast it travels.
uniform float chop : hint_range(0.0, 1.0) = 1.0;
uniform float wave_speed = 1.0;
// 0 = open season, 1 = frozen. Winter pushes the sea **paler and flatter** -- more
// sky, less chop -- rather than darker or grey-blue, which would fight the rule
// the whole shader is built on.
uniform float winter : hint_range(0.0, 1.0) = 0.0;
uniform vec4 winter_color : source_color = vec4(0.80, 0.87, 0.92, 1.0);

varying vec3 v_world;
// 0 right at the sand, 1 out in open water. Written into UV.y by `sea.gd` when it
// builds the ring, so the shallows follow the wobble of the coast exactly.
varying float v_depth;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_depth = UV.y;
}

void fragment() {
	float t = TIME * wave_speed;

	// Four travelling waves on four different bearings, **summed**.
	//
	// Deliberately not a function of radius -- `sin(r * k)` over a ring mesh is a
	// bullseye, which is what the puddles used to be. But the puddles' fix, a
	// *product* of one x wave and one z wave, does not survive being scaled up to
	// an ocean: a product is zero along both axes of every cell, so from height it
	// draws a visible plaid grid across the whole sea. Summing directional waves
	// whose bearings and periods share no common factor gives interference with no
	// cell to notice -- the same trick `wind.gd::gust()` uses in one dimension.
	float a = dot(v_world.xz, vec2(0.93, 0.37));
	float b = dot(v_world.xz, vec2(-0.44, 0.90));
	float c = dot(v_world.xz, vec2(0.66, -0.75));
	float surf = sin(a * 0.29 + t * 0.95) * 0.36
	           + sin(b * 0.41 - t * 0.71) * 0.28
	           + sin(c * 0.83 + t * 1.63) * 0.22
	           + sin(a * 1.77 - t * 2.10) * 0.14;
	surf *= chop * mix(1.0, 0.25, winter);
	// Damped with distance. The sea runs to 320 m, and out past the play camera's
	// reach the waves are smaller than a pixel -- which does not make them
	// invisible, it makes them alias into diagonal moire bands right across the
	// horizon. `VERTEX` is view space in a spatial shader, so its length is the
	// distance to the camera and costs nothing.
	surf *= mix(1.0, 0.18, smoothstep(45.0, 150.0, length(VERTEX)));

	// Swell rolling onto the sand: a travelling band keyed off depth, so the
	// waterline is never a dead ring of colour.
	float swell = sin(v_depth * 34.0 - t * 1.6) * 0.5 + 0.5;
	float shorewash = smoothstep(0.22, 0.0, v_depth) * swell;
	// ...and the constant white line where the water actually meets the beach.
	float edge = smoothstep(0.09, 0.0, v_depth);
	float foam = clamp(max(edge, shorewash * 0.75) * mix(1.0, 0.45, winter), 0.0, 1.0);

	// Grazing angles catch more sky. Subtle by design -- the camera is high and
	// steep, so most of the sea is seen close to face-on.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);

	// The painted coat. Two scales, two drift bearings, normalised to its own mean
	// so what survives is the variation rather than the tile's colour.
	vec2 w = v_world.xz / max(tex_metres, 1.0);
	vec3 t1 = texture(water_tex, w + vec2(t * 0.0075, t * 0.0042) * drift).rgb;
	vec3 t2 = texture(water_tex, w * 0.31 + vec2(-t * 0.0031, t * 0.0058) * drift).rgb;
	vec3 coat = (t1 * 0.55 + t2 * 0.45) / max(tex_mean, vec3(0.02));
	// Flattened toward 1.0 in winter, and always at range -- a tile sampled past
	// ~150 m is under a pixel wide and would alias exactly like the chop does.
	float coat_amt = tex_strength * mix(1.0, 0.45, winter)
	               * mix(1.0, 0.35, smoothstep(60.0, 180.0, length(VERTEX)));
	coat = mix(vec3(1.0), coat, coat_amt);

	vec3 body = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.0, 0.35, v_depth)) * coat;
	// Sky-dominant on purpose: looking down at water from height, what you see in
	// it is the sky. Drop this term and the sea reads as a painted hole.
	float sky_amount = clamp(sky_mix + surf * 0.055 + fres * 0.25, 0.0, 1.0);
	vec3 col = mix(body, sky_color.rgb, sky_amount);
	col = mix(col, winter_color.rgb * max(sky_color.rgb, vec3(0.12)), winter * 0.55);
	col = mix(col, foam_color.rgb * max(sky_color.rgb, vec3(0.35)), foam);

	ALBEDO = col;
	// Opaque out at sea; the last half-metre fades so the waterline is a wet edge
	// on the sand rather than a cut-out.
	ALPHA = mix(0.72, 1.0, smoothstep(0.0, 0.03, v_depth));
}
