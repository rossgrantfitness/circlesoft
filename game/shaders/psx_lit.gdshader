// Default PSX material: per-vertex (Gouraud) lighting, vertex snapping, affine warp, nearest
// filtering, stepped distance fog. Use for characters, props and room geometry.
shader_type spatial;
render_mode vertex_lighting, diffuse_lambert, specular_disabled, cull_back;

#include "psx_common.gdshaderinc"

// Edge light (the grim look's readability pass): a banded fresnel glow on the silhouette so characters and
// enemies separate from a dark set. rim_strength 0 (the default) switches it off, so rooms and every
// classic material are untouched; LookProfiles.dress_model turns it on for characters from the profile.
uniform vec3 rim_color : source_color = vec3(0.75, 0.88, 0.92);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.0;
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
// 0 = glow all the way around, 1 = only on surfaces that face up (a light from above and behind).
uniform float rim_top_bias : hint_range(0.0, 1.0) = 0.3;
// Steps in the glow (0 = smooth): a few flat bands read as PSX, never a soft halo.
uniform float rim_bands : hint_range(0.0, 8.0, 1.0) = 3.0;

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
	if (rim_strength > 0.0) {
		float edge = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), rim_power);
		edge *= mix(1.0, smoothstep(-0.3, 0.7, normalize(NORMAL).y), rim_top_bias);
		if (rim_bands > 0.5) {
			edge = floor(edge * rim_bands + 0.5) / rim_bands;
		}
		EMISSION += rim_color * edge * rim_strength * (1.0 - fog);
	}
	ROUGHNESS = 1.0;
}
