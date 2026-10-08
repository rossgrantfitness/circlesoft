// A camera-facing glow disc or ring for combat FX: hit flashes, the wind-up cue, the Lamp Flare shock ring.
// Additive and unlit; `intensity` above 1 pushes it over the glow threshold so it blooms.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float intensity : hint_range(0.0, 8.0) = 2.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
// 0 = a filled glow, 1 = a thin ring at ring_radius (0..1 of the quad's half size).
uniform float ring : hint_range(0.0, 1.0) = 0.0;
uniform float ring_radius : hint_range(0.05, 1.0) = 0.8;
uniform float ring_width : hint_range(0.01, 0.5) = 0.08;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float disk = clamp(1.0 - d, 0.0, 1.0);
	disk = disk * disk;
	float band = clamp(1.0 - abs(d - ring_radius) / ring_width, 0.0, 1.0);
	band = band * band * (3.0 - 2.0 * band) * step(d, 1.0);
	ALBEDO = tint.rgb * intensity;
	ALPHA = mix(disk, band, ring) * fade * tint.a;
}
