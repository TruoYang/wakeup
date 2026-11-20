shader_type spatial;
render_mode cull_disabled, depth_draw_always;
// Mặt hồ: sóng nhỏ, màu theo độ sâu, phản chiếu trời, mờ dần ở mép.

uniform vec3 shallow : source_color = vec3(0.16, 0.36, 0.36);
uniform vec3 deep : source_color = vec3(0.02, 0.09, 0.12);
uniform float clarity = 2.6;         // mét nước nhìn xuyên được
uniform float wave_height = 0.045;
uniform float rain = 0.0;            // 0..1: mưa làm mặt nước xao động
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float waves(vec2 p, float t) {
	float h = sin(p.x * 0.9 + t * 1.1) * 0.35 + sin(p.y * 1.3 - t * 0.9) * 0.3;
	h += vnoise(p * 1.7 + vec2(t * 0.35, -t * 0.25)) * 0.7 + vnoise(p * 4.3 - vec2(t * 0.6, t * 0.4)) * 0.3;
	h += vnoise(p * 14.0 + t * 3.0) * rain * 0.6;
	return h;
}

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += (waves(world_pos.xz, TIME) - 0.8) * wave_height;
}

void fragment() {
	float e = 0.12;
	float h0 = waves(world_pos.xz, TIME);
	float hx = waves(world_pos.xz + vec2(e, 0.0), TIME);
	float hz = waves(world_pos.xz + vec2(0.0, e), TIME);
	vec3 n = normalize(vec3((h0 - hx) * 0.55, 1.0, (h0 - hz) * 0.55));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz) * (FRONT_FACING ? 1.0 : -1.0);

	// độ dày lớp nước phía sau điểm này
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_z = -upos.z / upos.w;
	float thickness = max(scene_z + VERTEX.z, 0.0);
	float fog = 1.0 - exp(-thickness / clarity);

	vec2 refr_uv = SCREEN_UV + n.xz * 0.02 * clamp(thickness, 0.0, 1.0);
	vec3 behind = texture(screen_tex, refr_uv).rgb;
	vec3 water = mix(shallow, deep, clamp(thickness / (clarity * 2.5), 0.0, 1.0));
	ALBEDO = vec3(0.0);
	EMISSION = mix(behind, water, clamp(fog + 0.12, 0.0, 1.0)) * 0.92;
	float fres = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 4.0);
	ROUGHNESS = 0.04 + rain * 0.1;
	METALLIC = 0.0;
	SPECULAR = 0.6 + fres * 0.4;
	// bọt ở mép nước
	float foam = smoothstep(0.35, 0.0, thickness) * (0.4 + 0.6 * vnoise(world_pos.xz * 5.0 + TIME * 0.5));
	EMISSION = mix(EMISSION, vec3(0.75, 0.8, 0.8), foam * 0.35);
}
