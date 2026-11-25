// Море: хвилі, мілина бірюзова, глибина синя, піна біля берега, дві рухомі карти нормалей.
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

uniform sampler2D hmap : filter_linear, repeat_disable;
uniform float hsize = 160.0;
uniform float level = 0.0;
uniform vec3 deep : source_color = vec3(0.03, 0.18, 0.36);
uniform vec3 shallow : source_color = vec3(0.12, 0.62, 0.62);
uniform vec3 foam_col : source_color = vec3(0.95, 0.98, 1.0);
uniform sampler2D n1 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D n2 : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;

varying vec3 wpos;

float hgt(vec2 p) { return textureLod(hmap, clamp(p / hsize + 0.5, 0.0, 1.0), 0.0).r; }

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(w.x * 0.13 + TIME * 1.1) * 0.06 + sin(w.z * 0.19 + TIME * 0.8) * 0.05 + sin((w.x + w.z) * 0.37 + TIME * 1.9) * 0.025;
	wpos = w;
}

void fragment() {
	float ground = hgt(wpos.xz);
	float depth = clamp((level - ground) / 2.2, 0.0, 1.0);
	vec3 col = mix(shallow, deep, smoothstep(0.0, 1.0, depth));
	float fn = texture(foam_noise, wpos.xz * 0.18 + vec2(TIME * 0.02, TIME * 0.015)).r;
	float shore = 1.0 - smoothstep(0.0, 0.07, depth);
	float band = 0.5 + 0.5 * sin(TIME * 1.3 - depth * 90.0 + fn * 4.0);
	float edge = smoothstep(0.0, 0.015, depth);
	float foam = smoothstep(0.62, 0.72, shore * (0.45 + 0.55 * band) + (fn - 0.5) * 0.45) * edge;
	foam = max(foam, smoothstep(0.86, 0.97, fn) * 0.3 * (1.0 - depth));
	ALBEDO = mix(col, foam_col, foam);
	ALPHA = clamp(mix(0.18, 0.94, smoothstep(0.0, 0.45, depth)) + foam * 0.8, 0.0, 1.0) * edge;
	ROUGHNESS = mix(0.04, 0.7, foam);
	SPECULAR = 0.7;
	vec3 a = texture(n1, wpos.xz * 0.045 + vec2(TIME * 0.012, TIME * 0.006)).rgb;
	vec3 b = texture(n2, wpos.xz * 0.09 - vec2(TIME * 0.008, -TIME * 0.011)).rgb;
	NORMAL_MAP = normalize(a + b - 1.0) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.5;
}
