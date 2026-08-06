shader_type spatial;
// The base ground slab -- lit and shadowed normally (this is NOT unshaded, unlike
// water.gdshader and puddle.gdshader: the sun's contact shadow at the feet is a
// load-bearing depth cue here, see CLAUDE.md's shadow notes, so the built-in
// light() pass has to run).
//
// The hand-painted coat is the exact trick `water.gdshader` uses, for the exact
// same reason: a seamless tile sampled once reads as wallpaper the moment two
// tiles are in frame, and a 240 m slab guarantees that. Sampling it **twice, at
// different scales and offsets, then dividing by the tile's own mean** leaves a
// field hovering round 1.0 that multiplies the flat tint -- so paper grain and
// tonal drift survive, but the tile's own colour never fights the season tint or
// the day/night lighting. See that shader's header for the full reasoning.
render_mode blend_mix, depth_draw_opaque;

// The flat colour this slab would be with no coat at all -- `world_decor.gd`
// writes this every season change (spring/summer/autumn green, winter's lerp
// toward snow), exactly as it used to write `StandardMaterial3D.albedo_color`.
uniform vec4 tint : source_color = vec4(0.44, 0.63, 0.33, 1.0);
uniform sampler2D ground_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tex_mean = vec3(0.35);
uniform float tex_strength : hint_range(0.0, 1.0) = 0.85;
// Metres across for one tile of the coarse layer; the fine layer is a fixed
// fraction of it, same as the water shader.
uniform float tex_metres = 9.0;
// `Grass_01` is a near-flat wash **by design** -- that flatness is exactly what
// keeps it from tiling, same reasoning as `Water_02`'s pick in `sea.gd`. But it
// also means dividing it by its own mean leaves `coat` sitting right at 1.0
// almost everywhere, which reads as no texture at all. This pushes the
// *luminance* of that deviation outward without touching what makes it safe to
// tile -- **luminance, not each channel independently**: boosting R/G/B apart
// amplifies whatever tiny per-channel noise the wash has into full hue shifts
// (tried first -- turned the ground into a garish rainbow patchwork). A single
// scalar keeps every pixel exactly `tint`, just lighter or darker.
uniform float tex_contrast : hint_range(1.0, 8.0) = 4.0;
uniform float roughness_val : hint_range(0.0, 1.0) = 1.0;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 w = v_world.xz / max(tex_metres, 1.0);
	vec3 t1 = texture(ground_tex, w).rgb;
	// A second sample at an unrelated scale and a fixed offset -- no scrolling,
	// the ground doesn't move the way the sea does -- so the two never line up.
	vec3 t2 = texture(ground_tex, w * 0.37 + vec2(11.3, -7.9)).rgb;
	vec3 coat = (t1 * 0.55 + t2 * 0.45) / max(tex_mean, vec3(0.02));
	float luma = dot(coat, vec3(0.299, 0.587, 0.114));
	float grain = 1.0 + (luma - 1.0) * tex_contrast;

	ALBEDO = tint.rgb * mix(1.0, grain, tex_strength);
	ROUGHNESS = roughness_val;
}
