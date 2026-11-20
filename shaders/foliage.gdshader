shader_type spatial;
// Tán cây: mặt gồ ghề, lá nhiều sắc độ, đung đưa theo gió.
uniform vec3 leaf_a : source_color = vec3(0.10, 0.26, 0.08);
uniform vec3 leaf_b : source_color = vec3(0.26, 0.42, 0.14);
uniform float wind = 0.35;
global uniform float toon_style;

float hash3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float noise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float bump = noise3(wp * 1.3) * 0.7 + noise3(wp * 3.1) * 0.3;
	VERTEX += NORMAL * (bump - 0.4) * 0.9;
	float sway = sin(TIME * 1.3 + wp.x * 0.4 + wp.z * 0.3) * wind * 0.12;
	VERTEX.x += sway * (VERTEX.y + 1.5) * 0.3;
}
void fragment() {
	float n = noise3(wp * 2.4) * 0.6 + noise3(wp * 9.0) * 0.4;
	float nt = smoothstep(0.47, 0.53, noise3(wp * 0.9) * 0.6 + noise3(wp * 2.1) * 0.4);
	ALBEDO = mix(mix(leaf_a, leaf_b, n), mix(leaf_a * 1.25, leaf_b * 1.35, nt), toon_style);
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.15, 0.25, 0.05);
	NORMAL_MAP_DEPTH = 1.0 - toon_style;
	NORMAL_MAP = vec3(0.5 + (noise3(wp * 7.0) - 0.5) * 0.6, 0.5 + (noise3(wp * 7.0 + 31.0) - 0.5) * 0.6, 1.0);
}
