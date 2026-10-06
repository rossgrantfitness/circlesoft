// psx_lit plus a dithered "screen-door" fade, for props that block the view of Red.
// fade = 1 is solid, 0 is gone. Pixels are removed in a 4x4 Bayer pattern (no sorting bugs,
// no real transparency). The prop fader sets `fade` per prop.
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_back;

#include "psx_common.gdshaderinc"

instance uniform float fade : hint_range(0.0, 1.0) = 1.0;

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
	if (fade < psx_bayer4(FRAGCOORD.xy)) {
		discard;
	}
	vec4 tex = texture(albedo_texture, psx_fragment_uv()) * albedo_tint;
	if (tex.a < alpha_cutoff) {
		discard;
	}
	float fog = psx_fog_steps(v_fog);
	vec3 base = tex.rgb * (1.0 - fog);
	ALBEDO = base * psx_vertex_lighting;
	EMISSION = base * (1.0 - psx_vertex_lighting) + psx_fog_color.rgb * fog;
	ROUGHNESS = 1.0;
}
