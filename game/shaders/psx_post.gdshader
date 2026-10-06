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

float bayer4(vec2 pixel) {
	const float BAYER[16] = float[16](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0);
	ivec2 p = ivec2(mod(floor(pixel), 4.0));
	return (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec3 color = src.rgb;
	if (psx_color_depth_enabled > 0.5) {
		float steps = color_levels - 1.0;
		// The pattern is locked to internal pixels, not screen pixels.
		vec2 internal_pixel = UV / TEXTURE_PIXEL_SIZE;
		float offset = (bayer4(internal_pixel) - 0.5) * dither_amount * step(0.5, psx_dither_enabled);
		color = floor(color * steps + offset + 0.5) / steps;
	}
	COLOR = vec4(clamp(color, 0.0, 1.0), src.a);
}
