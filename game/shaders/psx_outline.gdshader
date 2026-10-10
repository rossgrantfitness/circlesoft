// PSX ink outline (Red prototype D, "Ink Line"). Put this on the second copy of a mesh (the
// "hull"): the same triangles with smoothed normals, drawn back-faces only, pushed out by a
// fixed number of INTERNAL pixels and filled flat Ink. The hull sits behind the real model, so
// only a thin line around its silhouette shows. Imported materials whose name ends in "_outline"
// get this shader.
//
// Snapping: each hull vertex is first snapped to the internal pixel grid exactly like the model's
// own vertex at the same spot (psx_snap), and only THEN pushed out by width pixels. So the line is
// always exactly width pixels from the model's edge and never swims against it.
shader_type spatial;
render_mode unshaded, cull_front;

#include "psx_common.gdshaderinc"

// The line color. Style guide: Ink, never pure black.
uniform vec4 outline_color : source_color = vec4(0.0784314, 0.0705882, 0.1215686, 1.0);
// Line width in internal pixels (1 = the brief's 1 px line).
uniform float outline_width_px : hint_range(0.0, 4.0) = 1.0;

void vertex() {
	vec4 view = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip = PROJECTION_MATRIX * view;
	v_fog = psx_fog_at(-view.z);
	vec4 snapped = psx_snap(clip);
	// Which way is "out" on screen: the vertex normal, seen through the camera.
	vec3 normal_view = normalize((MODELVIEW_NORMAL_MATRIX * NORMAL));
	vec2 half_res = psx_snap_res * 0.5;
	vec2 out_px = (PROJECTION_MATRIX * vec4(normal_view, 0.0)).xy * half_res;
	float len = length(out_px);
	if (len > 0.0001 && snapped.w > 0.0) {
		snapped.xy += (out_px / len) * outline_width_px / half_res * snapped.w;
	}
	POSITION = snapped;
}

void fragment() {
	float fog = psx_fog_steps(v_fog);
	ALBEDO = mix(outline_color.rgb, psx_fog_color.rgb, fog);
}
