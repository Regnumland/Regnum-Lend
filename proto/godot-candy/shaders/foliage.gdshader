// Крони дерев: колір за кольором вершин (світло зверху, тінь знизу), вітер, світло крізь листя.
shader_type spatial;
render_mode cull_back;

uniform vec3 dark : source_color = vec3(0.07, 0.2, 0.06);
uniform vec3 light : source_color = vec3(0.42, 0.62, 0.16);
uniform vec3 warm : source_color = vec3(0.65, 0.68, 0.2);

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 o = MODEL_MATRIX[3].xyz;
	float k = clamp(VERTEX.y * 0.25, 0.0, 1.0);
	VERTEX.x += sin(TIME * 1.3 + o.x * 0.3 + w.y * 0.6) * 0.08 * k;
	VERTEX.z += cos(TIME * 1.1 + o.z * 0.3 + w.x * 0.5) * 0.06 * k;
}

void fragment() {
	vec3 c = mix(dark, light, COLOR.r);
	c = mix(c, warm, COLOR.g * 0.5);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	BACKLIGHT = vec3(0.3, 0.4, 0.1);
	AO = mix(0.4, 1.0, COLOR.r);
}
