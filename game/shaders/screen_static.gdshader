// Radio-static battle transition (canvas_item). Put it on a full-screen ColorRect inside the 3D world's
// viewport (so the noise is as chunky as the internal 384x216 pixels) and drive `progress` from code:
//   progress 0 = clear picture, 1 = fully covered by static.
// The picture is lost in blocks (a dither-like dissolve) while horizontal bands tear sideways, a thin bright
// roll bar crawls down, and the noise itself is a hash that jumps at `frame_hz` (stepped, like old TVs).
// `boss` (0..1) adds the longer, nastier version: bigger tears and a flicker that inverts the noise.
// All colors come from the palette (Ink, Slate, Chalk, a cold Signals-blue wash), set from
// data/battle_stage/stage.json by battle_static.gd.
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float boss : hint_range(0.0, 1.0) = 0.0;
uniform float time_s = 0.0;
uniform float frame_hz = 24.0;
uniform vec2 pixel_grid = vec2(384.0, 216.0);
uniform vec2 block_px = vec2(3.0, 2.0);
uniform float band_rows = 6.0;
uniform vec4 dark : source_color = vec4(0.078, 0.071, 0.122, 1.0);
uniform vec4 mid : source_color = vec4(0.357, 0.396, 0.451, 1.0);
uniform vec4 light : source_color = vec4(0.929, 0.918, 0.847, 1.0);
uniform vec4 tint : source_color = vec4(0.435, 0.545, 0.659, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.18;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 px = floor(UV * pixel_grid);
	float frame = floor(time_s * frame_hz);

	// Horizontal tear: each band of rows slides sideways by a random amount that grows with coverage.
	float band = floor(px.y / max(band_rows, 1.0));
	float tear = (hash21(vec2(band, frame)) - 0.5) * (14.0 + 40.0 * boss) * smoothstep(0.05, 0.7, progress);
	vec2 spx = vec2(px.x + floor(tear), px.y);

	// Which blocks have gone to static already: a fixed random threshold per block, so the dissolve is stable.
	vec2 block = floor(spx / max(block_px, vec2(1.0)));
	float threshold = hash21(block + vec2(17.0, 91.0));
	float edge = progress * 1.12 - 0.06;
	bool covered = threshold < edge;

	// The noise: 4 grey levels from the palette, new every frame.
	float n = hash21(spx + vec2(frame * 13.0, frame * 7.0));
	float flicker = boss > 0.0 ? step(0.5, hash21(vec2(frame, 3.0))) * boss * step(0.35, progress) * step(progress, 0.9) : 0.0;
	if (flicker > 0.5) {
		n = 1.0 - n;
	}
	vec3 col = dark.rgb;
	if (n > 0.86) {
		col = light.rgb;
	} else if (n > 0.55) {
		col = mid.rgb;
	} else if (n > 0.3) {
		col = mix(dark.rgb, mid.rgb, 0.45);
	}
	col = mix(col, tint.rgb * (0.4 + 0.6 * n), tint_amount);

	// Scanlines: every other row a touch darker.
	if (mod(px.y, 2.0) > 0.5) {
		col *= 0.82;
	}

	// A bright roll bar crawling down the picture while the static is partly there.
	float roll = fract(time_s * 0.9);
	float bar = smoothstep(0.035, 0.0, abs(UV.y - roll)) * smoothstep(0.0, 0.2, progress) * (1.0 - smoothstep(0.85, 1.0, progress));
	col = mix(col, light.rgb, bar * 0.55);

	COLOR = vec4(col, covered ? 1.0 : 0.0);
}
