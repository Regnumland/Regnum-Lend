// Небо: градієнт, сонце з ореолом, нерухомі пухнасті хмари з шуму.
shader_type sky;

uniform vec3 top : source_color = vec3(0.20, 0.45, 0.85);
uniform vec3 horizon : source_color = vec3(0.70, 0.83, 0.95);
uniform vec3 ground : source_color = vec3(0.30, 0.40, 0.48);
uniform sampler2D clouds : filter_linear_mipmap, repeat_enable;

void sky() {
	vec3 d = EYEDIR;
	float t = clamp(d.y, 0.0, 1.0);
	vec3 c = mix(horizon, top, pow(t, 0.5));
	if (d.y < 0.0) c = mix(horizon, ground, clamp(-d.y * 4.0, 0.0, 1.0));
	float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
	c += LIGHT0_COLOR * (pow(sd, 1500.0) * 30.0 + pow(sd, 60.0) * 0.35 + pow(sd, 6.0) * 0.12);
	if (d.y > 0.01) {
		vec2 uv = d.xz / (d.y + 0.12) * 0.25;
		float n = texture(clouds, uv).r * 0.65 + texture(clouds, uv * 2.7 + 0.37).r * 0.35;
		float cl = smoothstep(0.48, 0.72, n) * smoothstep(0.01, 0.2, d.y);
		vec3 cc = mix(vec3(0.72, 0.78, 0.86), vec3(1.0, 0.99, 0.97), smoothstep(0.5, 0.85, n));
		cc += LIGHT0_COLOR * pow(sd, 5.0) * 0.35;
		c = mix(c, cc, cl * 0.92);
	}
	COLOR = c;
}
