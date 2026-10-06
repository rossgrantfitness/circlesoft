// Default PSX material: per-vertex (Gouraud) lighting, vertex snapping, affine warp, nearest
// filtering, stepped distance fog. Use for characters, props and room geometry.
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_back;

#include "psx_common.gdshaderinc"

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
	vec3 base = tex.rgb * (1.0 - fog);
	// Lighting on: the texture is lit by the per-vertex lights. Off: shown flat, full-bright.
	ALBEDO = base * psx_vertex_lighting;
	EMISSION = base * (1.0 - psx_vertex_lighting) + psx_fog_color.rgb * fog;
	ROUGHNESS = 1.0;
}
