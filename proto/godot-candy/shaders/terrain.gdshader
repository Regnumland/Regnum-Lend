// Земля: дві відтінки трави з плямами, пісок біля води, земля на схилах, дрібний рельєф із шуму.
shader_type spatial;

uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_n : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 grass_a : source_color = vec3(0.2, 0.36, 0.08);
uniform vec3 grass_b : source_color = vec3(0.36, 0.52, 0.14);
uniform vec3 sand : source_color = vec3(0.86, 0.78, 0.55);
uniform vec3 wet_sand : source_color = vec3(0.55, 0.48, 0.32);
uniform vec3 dirt : source_color = vec3(0.42, 0.32, 0.2);

varying vec3 wpos;
varying float slope;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	slope = 1.0 - NORMAL.y;
}

void fragment() {
	float n = texture(detail, wpos.xz * 0.035).r;
	float n2 = texture(detail, wpos.xz * 0.27).r;
	vec3 g = mix(grass_a, grass_b, smoothstep(0.3, 0.7, n)) * (0.85 + 0.3 * n2);
	float s = 1.0 - smoothstep(0.45, 0.85, wpos.y + (n2 - 0.5) * 0.25);
	vec3 sd = mix(wet_sand, sand, smoothstep(-0.1, 0.35, wpos.y)) * (0.92 + 0.16 * n2);
	vec3 c = mix(g, sd, s);
	c = mix(c, dirt * (0.8 + 0.4 * n2), smoothstep(0.25, 0.5, slope) * 0.8);
	ALBEDO = c;
	ROUGHNESS = mix(0.95, 0.6, step(wpos.y, 0.05));
	NORMAL_MAP = texture(detail_n, wpos.xz * 0.27).rgb;
	NORMAL_MAP_DEPTH = 0.6;
}
