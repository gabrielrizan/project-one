shader_type spatial;
// The fog over ground you have not walked.
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
// `unshaded` because fog of war is UI wearing a costume: it must read as dark at
// noon as it does at midnight, and a lit surface would go grey at dusk and stop
// hiding anything.
//
// **The mist is alive.** A drifting fbm noise wafts the frontier so the edge of
// the known world breathes and rolls like low cloud, rather than sitting as a hard
// stamped line -- "wind through the fog". Crucially the noise only bites in the
// **transition band**: deep unexplored ground stays fully opaque (it must still
// hide what it hides), and fully-explored ground stays fully clear (it must not
// flicker back). Only the frontier moves.
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

// R8: 0 = never seen, 255 = revealed. Only ever grows -- see `fog_of_war.gd`.
uniform sampler2D mask : filter_linear, repeat_disable, hint_default_black;
// World-space half-extent the mask covers, centred on the origin.
uniform float half_extent = 108.0;
// Near-black, faintly cool -- reads as black but gives the rolling edge a mist feel.
uniform vec4 fog_color : source_color = vec4(0.02, 0.03, 0.05, 1.0);
// How much of the brush's baked falloff shows as a gradient. Higher = softer, wider
// frontier; lower = crisper line. The brush already has the falloff; this shapes it.
uniform float edge_soft : hint_range(0.05, 1.0) = 0.70;

// --- the drift ---
// Metres across for one octave of the mist. Bigger = broader, slower-reading rolls.
uniform float mist_metres = 22.0;
// How far (in mask units, 0..1) the noise is allowed to push the frontier in and
// out. This is the visible "waft" -- the edge rolls back and forth by this much.
uniform float edge_wobble : hint_range(0.0, 0.5) = 0.16;
// Drift bearing and speed of the mist, in metres/second.
uniform vec2 mist_drift = vec2(0.6, 0.35);

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// --- value noise + fbm, world-space so the drift is consistent at any zoom ---
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * vnoise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
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

	// Drifting mist, sampled in world metres so it doesn't swim when the camera
	// zooms or pans. Two layers on unrelated drifts so it never reads as a loop.
	vec2 w = v_world.xz / max(mist_metres, 1.0);
	float n = fbm(w + mist_drift * TIME / max(mist_metres, 1.0));
	n = mix(n, fbm(w * 1.9 - mist_drift.yx * TIME * 0.7 / max(mist_metres, 1.0)), 0.5);

	// The waft only acts on the frontier: `band` is ~1 where `seen` sits inside the
	// soft edge and 0 both deep in the fog and well into explored ground, so neither
	// the opaque core nor the cleared interior is ever touched.
	float band = 1.0 - abs(seen - edge_soft * 0.5) / max(edge_soft * 0.5, 0.001);
	band = clamp(band, 0.0, 1.0);
	float wobble = (n - 0.5) * 2.0 * edge_wobble * band;

	float reveal = smoothstep(0.0, edge_soft, seen + wobble);
	ALBEDO = fog_color.rgb;
	ALPHA = fog_color.a * (1.0 - reveal);
}
