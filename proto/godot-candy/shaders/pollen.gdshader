// Пилок у повітрі: м'які світні цятки, завжди обличчям до камери.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	ALBEDO = vec3(1.0, 0.95, 0.7);
	ALPHA = (1.0 - smoothstep(0.0, 1.0, d)) * 0.55 * COLOR.a;
}
