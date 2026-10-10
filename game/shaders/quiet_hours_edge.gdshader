// Quiet Hours screen-edge fizz (graybox pass for B10; the Technical Artist owns the final look).
// A full-screen ColorRect in the HUD. Pixels near the four screen edges crackle, more thickly the closer they are
// to the edge, re-rolled in steps (like the panel static and the battle static, never smooth). `level` 0..1 is how
// strong it is; the thickness of the band and the density come from data/ui/slice_ui.json "quiet_fx".
// Palette: the same pale cyan and deep navy as the hack panel's own static, so the screen and the panel read as one thing.
shader_type canvas_item;

uniform float level : hint_range(0.0, 1.0) = 0.0;
uniform float step_index = 0.0;
uniform vec2 cells = vec2(320.0, 180.0);
uniform float band_cells = 14.0;
uniform float density = 0.6;
uniform float alpha = 0.55;
uniform vec4 light : source_color = vec4(0.788, 0.965, 1.0, 1.0);
uniform vec4 dark : source_color = vec4(0.102, 0.125, 0.220, 1.0);

float hash31(vec3 p) {
	p = fract(p * vec3(123.34, 456.21, 789.13));
	p += dot(p, p.yzx + 45.32);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	vec2 cell = floor(UV * cells);
	vec2 to_edge = min(cell, cells - 1.0 - cell);
	float edge = min(to_edge.x, to_edge.y);
	// 0 at the very edge's inner side, 1 at the edge: stepped into bands so it reads as dither, not a gradient.
	float near = clamp(1.0 - edge / max(band_cells, 1.0), 0.0, 1.0);
	near = floor(near * 4.0 + 0.5) / 4.0;
	float roll = hash31(vec3(cell, step_index));
	float chance = near * near * density * level;
	float on = step(roll, chance);
	float pick = hash31(vec3(cell.yx, step_index + 7.0));
	vec3 col = pick > 0.35 ? light.rgb : dark.rgb;
	COLOR = vec4(col, on * alpha);
}
