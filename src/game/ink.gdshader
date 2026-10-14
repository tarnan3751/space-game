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
// building's bottom edge does not dip into the ground. Instances only ever turn about Y and
// scale uniformly, so the ground's height in model space is -origin.y / scale.

uniform float ink_px = 2.2;
uniform vec4 ink_color : source_color = vec4(0.106, 0.102, 0.18, 1.0);

void vertex() {
	float width = ink_px * 2.0 / (720.0 * abs(PROJECTION_MATRIX[1][1]));
	float scale = MODEL_MATRIX[1][1];
	vec3 pushed = VERTEX + normalize(NORMAL) * width / scale;
	pushed.y = max(pushed.y, min(VERTEX.y, -MODEL_MATRIX[3][1] / scale));
	VERTEX = pushed;
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
