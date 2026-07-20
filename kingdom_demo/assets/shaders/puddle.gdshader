shader_type spatial;
// A field of rain pools lying on the grass.
//
// The Compatibility renderer has no decals, so a puddle is a plain flat quad
// laid just above the ground. That only works because the world is one flat
// slab (see CLAUDE.md) -- there is no terrain for a quad to clip through.
//
// The whole field is **one MultiMesh**, so however many pools there are it
// stays a single draw call. Everything that varies per pool is packed into
// INSTANCE_CUSTOM and written *once* at spawn:
//
//     x = threshold   the wetness this pool waits for before it starts filling
//     y = seed        its own outline and ripple rhythm
//
// Filling is then derived in the shader from the global `wetness`, so a storm
// costs three uniform writes a frame rather than one buffer write per pool.
// Small hollows fill first and dry last, purely from their threshold.
//
// `unshaded` on purpose. A lit surface would need the whole light() path
// re-implemented for one flat plane, and it would still not know about the
// storm. Instead `weather.gd` feeds the two colours in already tinted for the
// time of day and the overcast, so the pools go grey under cloud and near-black
// at night without this shader knowing what either of those things are.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded;

// 0 = bone dry, 1 = saturated ground. Drives every pool through its threshold.
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
// 0 = still water, 1 = actively being rained into. Drives the impact rings.
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform vec4 water_color : source_color = vec4(0.10, 0.13, 0.12, 0.80);
uniform vec4 sheen_color : source_color = vec4(0.55, 0.62, 0.70, 1.0);

varying float v_fill;
varying float v_seed;

float hash(float n) {
	return fract(sin(n) * 43758.5453123);
}

void vertex() {
	float threshold = INSTANCE_CUSTOM.x;
	v_seed = INSTANCE_CUSTOM.y;
	// Eased rather than linear so a pool arrives and leaves gently. The 0.35
	// band is what staggers the field: at any given wetness some pools are
	// full, some are half in, and the driest haven't started.
	v_fill = smoothstep(threshold, threshold + 0.35, wetness);
}

void fragment() {
	vec2 p = UV - vec2(0.5);
	float ang = atan(p.y, p.x);
	// Shrink toward the centre as it dries. Guarded so fill = 0 can't divide by
	// zero and blow the pool up to cover the quad.
	float r = length(p) * 2.0 / max(v_fill, 0.001);

	// Two shallow harmonics, keyed off the seed so no two pools share an
	// outline. Kept small deliberately: at higher amplitudes the lobes turn
	// into a cloverleaf and the pool reads as a blob of shadow, not water.
	float wob = 0.055 * sin(ang * 3.0 + v_seed * 6.2831)
	          + 0.030 * sin(ang * 5.0 - v_seed * 11.0);
	float edge = 0.86 + wob;

	// A crisp waterline. The wide soft falloff this used to have was most of
	// what made the pools look like scorch marks.
	float body = smoothstep(edge, edge - 0.09, r);

	// Raindrop impact rings. Four generators, each re-seeding to a new spot
	// every time its cycle wraps, so rings keep landing somewhere new for as
	// long as it rains. `1.0 - f` fades each ring as it spreads.
	float ripple = 0.0;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float t = TIME * 0.95 + fi * 0.37 + v_seed * 5.0;
		float k = floor(t);
		float f = fract(t);
		vec2 c = vec2(hash(k + fi * 13.0 + v_seed), hash(k + fi * 29.0 + v_seed * 7.0)) - 0.5;
		float d = length(p - c * 0.62);
		ripple += smoothstep(0.032, 0.0, abs(d - f * 0.5)) * (1.0 - f);
	}
	ripple *= rain;

	// Surface chop. Deliberately **not** a function of `r` -- a radial wave is
	// a bullseye of concentric rings, which is exactly what this looked like
	// before. Crossing two axis waves gives an irregular shimmer instead.
	float chop = sin(p.x * 21.0 + TIME * 1.3) * sin(p.y * 17.0 - TIME * 1.1);

	// Grazing angles catch more sky. Subtle here by design -- the camera is
	// high and steep, so most of the pool is seen close to face-on.
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);

	// Bright meniscus right at the waterline; reads as surface tension.
	float rim = smoothstep(edge - 0.09, edge - 0.02, r) * smoothstep(edge, edge - 0.01, r);

	// Sky-dominant on purpose. Looking down at standing water from height, what
	// you actually see is the sky in it -- a puddle reads *lighter* than the
	// grass around it, not darker. That base term is what turned these from
	// dark stains into water; much above 0.4 and they go milky and start
	// reading as ice instead.
	float sheen = clamp(0.38 + fres * 0.30 + ripple * 0.30 + rim * 0.35 + chop * 0.05, 0.0, 1.0);

	ALBEDO = mix(water_color.rgb, sheen_color.rgb, sheen);
	ALPHA = body * water_color.a * clamp(v_fill * 1.4, 0.0, 1.0);
}
