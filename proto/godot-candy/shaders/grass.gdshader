// Трава навколо героя: одна сітка травинок «перекочується» за героєм (позиції загортаються в квадрат gsize),
// висота береться з карти висот, вітер — пориви з шуму, герой приминає траву.
shader_type spatial;
render_mode cull_disabled, world_vertex_coords;

uniform sampler2D hmap : filter_linear, repeat_disable;
uniform float hsize = 160.0;
uniform vec3 center = vec3(0.0);
uniform vec3 hero = vec3(0.0);
uniform float gsize = 36.0;
uniform sampler2D wind_noise : filter_linear, repeat_enable;
uniform vec3 base_col : source_color = vec3(0.10, 0.25, 0.05);
uniform vec3 tip_col : source_color = vec3(0.55, 0.75, 0.22);
uniform vec3 dry_col : source_color = vec3(0.78, 0.74, 0.36);

varying float v_t;
varying vec3 v_col;

float hgt(vec2 p) { return textureLod(hmap, p / hsize + 0.5, 0.0).r; }
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 wp = o.xz + gsize * round((center.xz - o.xz) / gsize);
	float y = hgt(wp);
	float r = length(wp - center.xz);
	float fade = 1.0 - smoothstep(gsize * 0.36, gsize * 0.5, r);
	float land = smoothstep(0.45, 0.75, y);
	vec3 local = (VERTEX - o) * fade * land;
	float t = UV.y;
	vec2 wuv = wp * 0.025 + vec2(TIME * 0.045, TIME * 0.02);
	float gust = textureLod(wind_noise, wuv, 0.0).r;
	vec2 bend = vec2(0.55, 0.25) * (gust * 1.5 - 0.25) + vec2(sin(TIME * 2.1 + wp.x * 0.8), cos(TIME * 1.7 + wp.y * 0.7)) * 0.08;
	vec2 dh = wp - hero.xz;
	float dl = length(dh);
	bend += dh / max(dl, 0.001) * smoothstep(1.3, 0.15, dl) * 1.3;
	float hb = max(local.y, 0.0);
	local.xz += bend * t * t * hb;
	local.y -= length(bend) * t * t * hb * 0.3;
	VERTEX = vec3(wp.x, y - 0.02, wp.y) + local;
	float hv = hash(floor(wp * 0.35));
	v_t = t;
	v_col = mix(base_col, tip_col, t) * (0.85 + 0.3 * hash(wp));
	v_col = mix(v_col, dry_col * mix(0.7, 1.05, t), smoothstep(0.6, 1.0, hv) * 0.55 * t);
	NORMAL = normalize(vec3(bend.x * 0.25, 1.0, bend.y * 0.25));
}

void fragment() {
	ALBEDO = v_col;
	ROUGHNESS = 0.8;
	SPECULAR = 0.3;
	BACKLIGHT = vec3(0.35, 0.45, 0.12) * v_t;
	AO = mix(0.3, 1.0, v_t);
	AO_LIGHT_AFFECT = 0.5;
}
