// A sword-swing trail ribbon: additive, unlit, fades with age (vertex alpha) and is brighter toward the blade tip.
// `glow` pushes the colour above the glow threshold so the trail blooms in the PS2 look.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform float glow : hint_range(0.0, 6.0) = 1.8;
uniform float tip_bias : hint_range(0.0, 1.0) = 0.7;

void fragment() {
	float along = clamp(UV.x, 0.0, 1.0);          // 0 at the blade's base, 1 at its tip
	float fade = mix(1.0 - tip_bias, 1.0, along);
	ALBEDO = COLOR.rgb * glow;
	ALPHA = COLOR.a * fade;
}
