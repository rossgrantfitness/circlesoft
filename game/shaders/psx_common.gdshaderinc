// PSX look, shared pieces. Included by psx_lit, psx_unlit and psx_fade.
//
// Every effect has a global switch (set from project.godot, flipped at runtime by PsxLook):
//   psx_jitter_strength   vertex snap size in internal pixels (0 = off, 1 = PSX, 2 = very wobbly)
//   psx_affine_strength   0..1 affine warp, multiplied by each material's affine_amount (0 = off)
//   psx_fog_enabled       0 or 1 (near/far/color are psx_fog_near, psx_fog_far, psx_fog_color)
//   psx_vertex_lighting   1 = per-vertex lights, 0 = flat full-bright texture (compare lighting)
// psx_snap_res is the internal render resolution; PsxScreen keeps it in sync.

global uniform vec2 psx_snap_res;
global uniform float psx_jitter_strength;
global uniform float psx_affine_strength;
global uniform vec4 psx_fog_color;
global uniform float psx_fog_near;
global uniform float psx_fog_far;
global uniform float psx_fog_enabled;
global uniform float psx_vertex_lighting;

// Per-material settings (all sit in the material, none are baked in).
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform vec2 uv_offset = vec2(0.0, 0.0);
// How much of the global affine warp this material takes. Characters and props: about 0.75.
// Floors and walls built from small pieces can stay high; one big floor quad shows it most.
uniform float affine_amount : hint_range(0.0, 1.0) = 0.75;
// Fog steps (style guide: 4 visible bands). 0 = smooth fog.
uniform float fog_bands : hint_range(0.0, 16.0, 1.0) = 4.0;
// 1-bit cut-out: texels with alpha below this are not drawn.
uniform float alpha_cutoff : hint_range(0.0, 1.0) = 0.5;

varying vec2 v_uv;          // normal (perspective-correct) UV
varying vec2 v_uv_w;        // UV * w, for the affine path
varying float v_clip_w;     // w, for the affine path
varying float v_fog;        // 0..1 distance fog, per vertex

// Snaps a clip-space position to the internal pixel grid. Strength is the grid size in pixels.
vec4 psx_snap(vec4 clip) {
	if (psx_jitter_strength <= 0.0 || clip.w <= 0.0) {
		return clip;
	}
	vec2 cells = psx_snap_res * 0.5 / psx_jitter_strength; // NDC runs -1..1, so half the pixels
	vec2 ndc = clip.xy / clip.w;
	ndc = floor(ndc * cells + 0.5) / cells;
	return vec4(ndc * clip.w, clip.z, clip.w);
}

// UV after the material's tiling. Varyings can only be assigned inside vertex(), so each shader
// does: v_uv = psx_tiled_uv(UV); v_uv_w = v_uv * clip.w; v_clip_w = clip.w;
//       v_fog = psx_fog_at(-view.z);
vec2 psx_tiled_uv(vec2 uv) {
	return uv * uv_scale + uv_offset;
}

// Distance fog 0..1 for a point view_depth units in front of the camera (switch: psx_fog_enabled).
float psx_fog_at(float view_depth) {
	float span = max(psx_fog_far - psx_fog_near, 0.0001);
	return clamp((view_depth - psx_fog_near) / span, 0.0, 1.0) * psx_fog_enabled;
}

// Blends between the correct UV and the affine (screen-linear) UV.
vec2 psx_fragment_uv() {
	vec2 affine = v_uv_w / v_clip_w;
	return mix(v_uv, affine, affine_amount * psx_affine_strength);
}

// Quantises fog into steps. bands = 4 gives 0, 1/4, 1/2, 3/4, 1.
float psx_fog_steps(float fog) {
	if (fog_bands < 0.5) {
		return fog;
	}
	return min(floor(fog * (fog_bands + 1.0)) / fog_bands, 1.0);
}

// 4x4 Bayer threshold in (0,1) for a pixel position. Used by the fade shader.
float psx_bayer4(vec2 pixel) {
	const float BAYER[16] = float[16](
		0.0, 8.0, 2.0, 10.0,
		12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0,
		15.0, 7.0, 13.0, 5.0);
	ivec2 p = ivec2(mod(floor(pixel), 4.0));
	return (BAYER[p.y * 4 + p.x] + 0.5) / 16.0;
}
