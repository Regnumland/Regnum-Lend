// Метелики: два крильця махають, колір — з частинки.
shader_type spatial;
render_mode cull_disabled, unshaded;

void vertex() {
	float f = sin(TIME * 18.0 + float(INSTANCE_ID) * 1.7);
	float s = sign(VERTEX.x);
	float a = f * 1.1 * s;
	float x = abs(VERTEX.x);
	VERTEX.x = s * x * cos(a);
	VERTEX.y += x * sin(abs(a));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float wing = 1.0 - smoothstep(0.85, 1.0, length(vec2(abs(p.x) - 0.5, p.y) * vec2(1.6, 1.0)));
	if (wing < 0.5) discard;
	ALBEDO = COLOR.rgb * (0.8 + 0.4 * (1.0 - abs(p.y)));
}
