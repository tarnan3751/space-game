shader_type spatial;
render_mode cull_front, unshaded;

// The ink outline (MaterialKit.ink and ink_selected): an inverted hull. The outline mesh holds
// the body's triangles with position-averaged normals (LowPolyMesh.to_outline_mesh); this
// pushes each vertex out along its normal and draws only the back faces, in ink_color.
//
// The line is ink_px pixels wide at a 720 px viewport height and scales with the viewport
// height. The camera is orthographic, so that is a fixed share of its vertical extent:
// 2 / |PROJECTION_MATRIX[1][1]| world units span the viewport (abs, because the Compatibility
// renderer flips the projection's Y when it draws into a render target).
//
// The push never takes a vertex below the ground (world y = 0) unless it already was, so a
// building's bottom edge does not dip into the ground. Instances scale uniformly, and only
// moving parts turn about any axis but Y, high enough above the ground that the clamp does not
// reach them, so the ground's height in model space is -origin.y / scale.
//
// The outline carries its parts' flags (UV2.y) and phases (COLOR.a), and moves each vertex as
// the body's shader does (effects.gdshaderinc: BOB and JITTER) before the push, so an outline
// never comes off a bobbing or jittering part. Parts that flicker are never outlined.

#include "res://src/game/effects.gdshaderinc"

uniform float ink_px = 2.2;
uniform vec4 ink_color : source_color = vec4(0.106, 0.102, 0.18, 1.0);

void vertex() {
	float width = ink_px * 2.0 / (720.0 * abs(PROJECTION_MATRIX[1][1]));
	float scale = length(MODEL_MATRIX[0].xyz);
	vec3 moved = effect_vertex(VERTEX, surf_flags(UV2), surf_phase(COLOR), MODEL_MATRIX);
	vec3 pushed = moved + normalize(NORMAL) * width / scale;
	pushed.y = max(pushed.y, min(moved.y, -MODEL_MATRIX[3][1] / scale));
	VERTEX = pushed;
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
