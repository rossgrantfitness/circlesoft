// Final picture: 4x4 ordered dither and 15-bit color (5 bits per channel), like the PSX.
// Put on the TextureRect that shows the low-resolution world. Both effects have a global switch:
//   psx_dither_enabled, psx_color_depth_enabled  (0 or 1)
// Dither only matters while color depth is reduced: it hides the banding that reduction makes.
shader_type canvas_item;

global uniform float psx_dither_enabled;
global uniform float psx_color_depth_enabled;

// Levels per channel after reduction: 32 = 5 bits = PSX 15-bit color.
uniform float color_levels : hint_range(2.0, 256.0, 1.0) = 32.0;
// Dither size in color steps (1 = one full step of spread, as on the PSX).
uniform float dither_amount : hint_range(0.0, 2.0) = 1.0;

// ---- World grade (the "look profile", data/world/look_profiles.json; LookProfiles sets these). ----
// grade_amount 0 = off: the picture goes through untouched, exactly the classic look. The grade runs
// BEFORE the 15-bit reduction, so crushed blacks and extra grain show up as chunky PSX banding.
uniform float grade_amount : hint_range(0.0, 1.0) = 0.0;
// 0..1: how much colour is drained (1 = black and white).
uniform float grade_desat : hint_range(0.0, 1.0) = 0.0;
// 0..1: bright, saturated pixels (lamps, warning stripes, the call's teal) keep this much of their colour.
uniform float grade_accent_keep : hint_range(0.0, 1.0) = 0.0;
// Brightness multiplier after everything else (below 1 = darker).
uniform float grade_gain : hint_range(0.0, 2.0) = 1.0;
// Power curve on the mids (above 1 = darker, heavier mids).
uniform float grade_gamma : hint_range(0.5, 3.0) = 1.0;
// Black point: everything under this goes to pure black (crushed blacks).
uniform float grade_crush : hint_range(0.0, 0.5) = 0.0;
// Split tone: shadows lean toward grade_shadow_tint, highlights toward grade_highlight_tint.
uniform vec3 grade_shadow_tint : source_color = vec3(0.7, 0.9, 0.85);
uniform vec3 grade_highlight_tint : source_color = vec3(1.0, 0.85, 0.65);
uniform float grade_tint_amount : hint_range(0.0, 1.0) = 0.0;
// Film grain: noise added per internal pixel, re-rolled grade_grain_fps times a second.
uniform float grade_grain : hint_range(0.0, 0.5) = 0.0;
uniform float grade_grain_fps : hint_range(1.0, 30.0) = 12.0;
// Darkens the corners (0 = none).
uniform float grade_vignette : hint_range(0.0, 1.5) = 0.0;

float bayer4(vec2 pixel) {
	const float BAYER[16] = float[16](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0);
	ivec2 p = ivec2(mod(floor(pixel), 4.0));
	return (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
}

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

vec3 world_grade(vec3 color, vec2 uv, vec2 internal_pixel) {
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	float hi = max(color.r, max(color.g, color.b));
	float lo = min(color.r, min(color.g, color.b));
	float sat = hi > 0.0001 ? (hi - lo) / hi : 0.0;
	float accent = grade_accent_keep * smoothstep(0.72, 0.96, hi) * smoothstep(0.5, 0.8, sat);
	color = mix(color, vec3(luma), grade_desat * (1.0 - accent));
	float tone_luma = dot(color, vec3(0.299, 0.587, 0.114));
	vec3 tone = mix(grade_shadow_tint, grade_highlight_tint, smoothstep(0.08, 0.7, tone_luma));
	color = mix(color, color * tone * 1.25, grade_tint_amount * (1.0 - accent));
	color = max(color - vec3(grade_crush), vec3(0.0)) / max(1.0 - grade_crush, 0.0001);
	color = pow(color, vec3(grade_gamma)) * grade_gain;
	float edge = length((uv - vec2(0.5)) * vec2(1.0, 0.8)) * 1.4;
	color *= 1.0 - grade_vignette * smoothstep(0.35, 1.0, edge);
	float tick = floor(TIME * grade_grain_fps);
	color += (hash21(floor(internal_pixel) + vec2(tick * 17.0, tick * 5.0)) - 0.5) * grade_grain;
	return clamp(color, 0.0, 1.0);
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec3 color = src.rgb;
	if (grade_amount > 0.001) {
		color = mix(color, world_grade(color, UV, UV / TEXTURE_PIXEL_SIZE), grade_amount);
	}
	if (psx_color_depth_enabled > 0.5) {
		float steps = color_levels - 1.0;
		// The pattern is locked to internal pixels, not screen pixels.
		vec2 internal_pixel = UV / TEXTURE_PIXEL_SIZE;
		float offset = (bayer4(internal_pixel) - 0.5) * dither_amount * step(0.5, psx_dither_enabled);
		color = floor(color * steps + offset + 0.5) / steps;
	}
	COLOR = vec4(clamp(color, 0.0, 1.0), src.a);
}
