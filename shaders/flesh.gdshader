shader_type spatial;
// Da thịt quái vật: sần sùi, u bướu, gân máu, chỗ ướt bóng nhờn, phập phồng như đang thở.

uniform vec3 base_color : source_color = vec3(0.10, 0.11, 0.12);
uniform vec3 mottle_color : source_color = vec3(0.22, 0.16, 0.14);
uniform vec3 vein_color : source_color = vec3(0.45, 0.06, 0.04);
uniform float bump = 1.0;
uniform float wetness = 0.6;
uniform float vein_amount = 0.5;
uniform float glow = 0.0;
uniform float scale = 1.0;
uniform float pulse = 0.02;
uniform float hurt = 0.0;
global uniform float toon_style;

float hash3(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float noise3(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { return noise3(p) * 0.5 + noise3(p * 2.03) * 0.28 + noise3(p * 4.1) * 0.15 + noise3(p * 8.3) * 0.07; }
// đường gân: các rãnh mảnh ngoằn ngoèo
float ridges(vec3 p) { float n = abs(noise3(p) * 2.0 - 1.0); float m = abs(noise3(p * 2.1 + 7.0) * 2.0 - 1.0); return 1.0 - smoothstep(0.0, 0.09, min(n, m + 0.04)); }
float height(vec3 p) {
	// chỉ có gợn lớn, mềm: khối đồ sộ, trơn
	return noise3(p * 1.3) * 0.6 + noise3(p * 2.9) * 0.3;
}

varying vec3 op;
void vertex() {
	op = VERTEX * scale;
	float breathe = sin(TIME * 1.6 + op.y * 0.7) * pulse;
	VERTEX += NORMAL * breathe;
}

void fragment() {
	float h = height(op);
	float e = 0.12;
	vec3 grad = vec3(height(op + vec3(e, 0, 0)) - h, height(op + vec3(0, e, 0)) - h, height(op + vec3(0, 0, e)) - h) / e;
	vec3 n_obj = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 n_new = normalize(n_obj - (grad - dot(grad, n_obj) * n_obj) * 0.22 * bump * (1.0 - toon_style));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_new, 0.0)).xyz);

	float m = noise3(op * 0.7 + 3.0) * 0.65 + noise3(op * 1.9 + 9.0) * 0.35;
	float v = ridges(op * 1.4) * vein_amount;
	vec3 col = mix(base_color, mottle_color, smoothstep(0.35, 0.7, m));
	col *= 0.72 + 0.45 * smoothstep(0.2, 0.9, h);                // khe rãnh tối hơn
	col = mix(col, vein_color, v * mix(0.8, 0.0, toon_style));
	col = mix(col, mix(base_color, mottle_color, 0.35), toon_style * 0.75);       // vẽ tay: mảng màu phẳng, trơn
	col = mix(col, vec3(0.8, 0.1, 0.05), hurt * 0.6);
	ALBEDO = col;
	float wet = smoothstep(0.35, 0.8, noise3(op * 0.9 + 11.0)) * wetness;
	ROUGHNESS = mix(mix(0.82, 0.12, wet), 1.0, toon_style);
	SPECULAR = mix(0.5 + wet * 0.4, 0.05, toon_style);
	float rim = pow(1.0 - clamp(dot(normalize(VIEW), NORMAL), 0.0, 1.0), 3.0);
	EMISSION = vein_color * (v * 0.25 * (0.6 + 0.4 * sin(TIME * 2.4 + op.y)) + glow * (0.3 + v)) + mottle_color * rim * mix(0.12, 0.5, toon_style);
}
