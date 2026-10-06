// PSX material with no lighting: lamp bulbs, glows, signs, anything that should look lit from
// inside. Same snap, warp, filter and fog as psx_lit. Imported materials whose name ends in
// "_unlit" are given this shader.
shader_type spatial;
render_mode unshaded, cull_back;

#include "psx_common.gdshaderinc"

// Multiplies the color: above 1 makes a glow brighter than the texture.
uniform float emission_energy : hint_range(0.0, 8.0) = 1.0;

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
	vec4 tex = texture(albedo_texture, psx_fragment_uv()) * albedo_tint;
	if (tex.a < alpha_cutoff) {
		discard;
	}
	float fog = psx_fog_steps(v_fog);
	ALBEDO = mix(tex.rgb * emission_energy, psx_fog_color.rgb, fog);
}
