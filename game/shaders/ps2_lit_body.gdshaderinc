// PS2 look, step one (docs/pivot/buildability.md section 8, combat_api.md section 6): the per-pixel lit body shared by
// ps2_lit.gdshader (smooth, mipmapped textures) and ps2_lit_crisp.gdshader (nearest). The wrappers declare the three
// texture samplers (the filter is a compile-time hint, so it can't be one shader), then include this file.
//
// What it does differently from psx_lit:
//   * per-pixel lighting from the scene's lights, receives the key light's real-time shadow,
//   * smooth distance fog in the same grim haze colours (psx_fog_* globals, no bands),
//   * the banded edge light kept (rim_*; LookProfiles.dress_model writes it from the profile),
//   * the glTF metallic-roughness map is read (G rough, B metal); the normal map stays in the file for step two,
//   * bright, saturated texels (neon strips, blade glow) can feed the bloom (emissive_pick),
//   * vertex jitter only when the global psx_jitter_strength is above 0 (the optional "retro wobble"); no affine warp.

global uniform vec2 psx_snap_res;
global uniform float psx_jitter_strength;
global uniform vec4 psx_fog_color;
global uniform float psx_fog_near;
global uniform float psx_fog_far;
global uniform float psx_fog_enabled;

uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;
// 0 = ignore the metallic-roughness map and use roughness_base.
uniform float use_orm : hint_range(0.0, 1.0) = 1.0;
uniform float roughness_base : hint_range(0.0, 1.0) = 0.85;
uniform float roughness_scale : hint_range(0.0, 2.0) = 1.0;
// Compatibility has no reflections to show, so a fully metal surface just goes dark: keep it a little.
uniform float metallic_scale : hint_range(0.0, 1.0) = 0.3;
// Neon pick: texels that are both bright and saturated glow by this much (0 = off). Lights On raises it on Red.
uniform float emissive_pick : hint_range(0.0, 4.0) = 0.0;
uniform float emissive_threshold : hint_range(0.0, 1.0) = 0.62;

// Edge light, same meaning as in psx_lit.
uniform vec3 rim_color : source_color = vec3(0.75, 0.88, 0.92);
uniform float rim_strength : hint_range(0.0, 3.0) = 0.0;
uniform float rim_power : hint_range(0.5, 8.0) = 2.2;
uniform float rim_top_bias : hint_range(0.0, 1.0) = 0.3;
uniform float rim_bands : hint_range(0.0, 8.0, 1.0) = 4.0;

varying float v_fog;

void vertex() {
	UV = UV * uv_scale + uv_offset;
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float span = max(psx_fog_far - psx_fog_near, 0.0001);
	v_fog = clamp((-view.z - psx_fog_near) / span, 0.0, 1.0) * psx_fog_enabled;
	v_fog = v_fog * v_fog * (3.0 - 2.0 * v_fog);
	// POSITION must always be written (a shader that writes it only sometimes leaves it empty the rest of the time).
	vec4 clip = PROJECTION_MATRIX * view;
	if (psx_jitter_strength > 0.0 && clip.w > 0.0) {
		vec2 cells = psx_snap_res * 0.5 / psx_jitter_strength;
		vec2 ndc = clip.xy / clip.w;
		ndc = floor(ndc * cells + 0.5) / cells;
		clip = vec4(ndc * clip.w, clip.z, clip.w);
	}
	POSITION = clip;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV) * albedo_tint;
	if (tex.a < alpha_cutoff) {
		discard;
	}
	float fog = v_fog;
	vec3 base = tex.rgb;
	ALBEDO = base * (1.0 - fog);
	float rough = roughness_base;
	float metal = 0.0;
	if (use_orm > 0.5) {
		vec3 orm = texture(orm_texture, UV).rgb;
		rough = clamp(orm.g * roughness_scale, 0.04, 1.0);
		metal = orm.b * metallic_scale;
	}
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.35;
	vec3 glow = vec3(0.0);
	if (emissive_pick > 0.0) {
		float hi = max(base.r, max(base.g, base.b));
		float lo = min(base.r, min(base.g, base.b));
		float sat = hi > 0.001 ? (hi - lo) / hi : 0.0;
		float pick = smoothstep(emissive_threshold, 0.95, hi) * smoothstep(0.35, 0.7, sat);
		glow = base * pick * emissive_pick;
	}
	if (rim_strength > 0.0) {
		vec3 n = normalize(NORMAL);
		float edge = pow(1.0 - clamp(dot(n, normalize(VIEW)), 0.0, 1.0), rim_power);
		edge *= mix(1.0, smoothstep(-0.3, 0.7, n.y), rim_top_bias);
		if (rim_bands > 0.5) {
			edge = floor(edge * rim_bands + 0.5) / rim_bands;
		}
		glow += rim_color * edge * rim_strength;
	}
	EMISSION = glow * (1.0 - fog) + psx_fog_color.rgb * fog;
}
