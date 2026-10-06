// PSX cel shader (Red prototype D, "Ink Line"). Same vertex snap, affine warp, nearest filtering and
// stepped fog as psx_lit, but lighting is cut into exactly TWO flat bands: lit and shade.
//
// The texture is a swatch strip split in half. The LEFT half holds the lit colors, the RIGHT half
// holds each color's darker sibling at the same spot (offset shade_uv_offset, default half the
// width to the right). So the artist paints one palette and its shade side by side; the shader
// only picks which one to show. Imported materials whose name ends in "_cel" get this shader.
//
// How the bands are decided: for every light, dot(normal, light direction) * attenuation is
// compared with band_threshold. At or above it the pixel is "lit" (adds the lit color tinted by
// the light), below it the pixel stays in shade. A 4x4 Bayer dither (internal pixels) wobbles the
// threshold a little so the band edge is a dithered step, not a smooth gradient. There is no
// specular, no ramp and no per-pixel normal detail. (The cut itself is evaluated per pixel because
// that is the only place Godot lets a shader choose between two colors per light.)
shader_type spatial;
render_mode cull_back;

#include "psx_common.gdshaderinc"

// Where the shade sibling of each swatch lives, relative to the lit color (UV units).
uniform vec2 shade_uv_offset = vec2(0.5, 0.0);
// dot(normal, light) * attenuation at or above this is the lit band.
uniform float band_threshold : hint_range(-1.0, 1.0) = 0.25;
// Size of the dithered wobble on the band edge, in light units (0 = hard edge).
uniform float band_dither : hint_range(0.0, 0.5) = 0.12;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip = PROJECTION_MATRIX * view;
	v_uv = psx_tiled_uv(UV);
	v_uv_w = v_uv * clip.w;
	v_clip_w = clip.w;
	v_fog = psx_fog_at(-view.z);
	POSITION = psx_snap(clip);
}

void fragment() {
	vec2 uv = psx_fragment_uv();
	vec4 lit_tex = texture(albedo_texture, uv) * albedo_tint;
	if (lit_tex.a < alpha_cutoff) {
		discard;
	}
	vec3 shade = texture(albedo_texture, uv + shade_uv_offset).rgb * albedo_tint.rgb;
	float fog = psx_fog_steps(v_fog);
	// Shade band is the base color. Lighting (below) adds the lit band on top.
	// Lighting off (compare view): show the lit color flat and full-bright.
	vec3 base = mix(lit_tex.rgb, shade, step(0.5, psx_vertex_lighting));
	ALBEDO = vec3(0.0);
	EMISSION = mix(base, psx_fog_color.rgb, fog);
	ROUGHNESS = 1.0;
}

void light() {
	vec2 uv = psx_fragment_uv();
	vec3 lit_color = texture(albedo_texture, uv).rgb * albedo_tint.rgb;
	vec3 shade_color = texture(albedo_texture, uv + shade_uv_offset).rgb * albedo_tint.rgb;
	float edge = (psx_bayer4(FRAGCOORD.xy) - 0.5) * band_dither;
	float amount = dot(NORMAL, LIGHT) * ATTENUATION + edge;
	float band = step(band_threshold, amount);
	// LIGHT_COLOR carries the light's energy times PI.
	vec3 tint = clamp(LIGHT_COLOR / PI, 0.0, 1.0);
	float not_fogged = 1.0 - psx_fog_steps(v_fog);
	// Lighting switched off (compare view): fragment() already shows the lit color, add nothing.
	SPECULAR_LIGHT += (lit_color - shade_color) * tint * band * not_fogged * step(0.5, psx_vertex_lighting);
}
