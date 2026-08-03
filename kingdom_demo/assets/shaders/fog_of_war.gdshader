shader_type spatial;
// The black over ground you have not walked.
//
// `gl_compatibility` has no decals and no volumetric fog, so fog of war is a
// **mask plus a flat quad**: `fog_of_war.gd` paints an R8 image on the CPU, one
// soft brush per revealer, and this shader reads it as an alpha over the world.
//
// It can only ever darken the *ground*. A single plane at a 45 degree pitch
// occludes the ground **in front of** it, not the ground under it, so anything
// that stands up -- trees, huts, camps, bodies -- is hidden by its own `visible`
// flag instead (the `fog_hideable` group). That split is not an implementation
// detail, it is the only arrangement that works at this camera.
//
// `unshaded` because fog of war is UI wearing a costume: it must read as exactly
// as black at noon as it does at midnight, and a lit surface would go grey at dusk
// and stop hiding anything.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// R8: 0 = never seen, 255 = revealed. Only ever grows -- see `fog_of_war.gd`.
uniform sampler2D mask : filter_linear, repeat_disable, hint_default_black;
// World-space half-extent the mask covers, centred on the origin.
uniform float half_extent = 108.0;
uniform vec4 fog_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
// How hard the edge of the known world is. The brush already has a falloff baked
// into it; this shapes how much of that falloff you actually see, so the frontier
// can be a soft gradient or a crisp line without repainting anything.
uniform float edge_soft : hint_range(0.01, 1.0) = 0.55;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = v_world.xz / (half_extent * 2.0) + vec2(0.5);
	// Outside the mask is unexplored, not revealed. `hint_default_black` plus
	// repeat_disable would clamp the edge texel outward instead, which smears the
	// last row of whatever you happened to have explored out to the horizon.
	float seen = 0.0;
	if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
		seen = texture(mask, uv).r;
	}
	ALBEDO = fog_color.rgb;
	ALPHA = fog_color.a * (1.0 - smoothstep(0.0, edge_soft, seen));
}
