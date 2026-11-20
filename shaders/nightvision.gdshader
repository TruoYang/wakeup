shader_type canvas_item;
// Kính nhìn đêm: khuếch đại sáng, ảnh xanh lục, hạt nhiễu, vạch quét, khung ống kính tròn.
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float t = 0.0;

void fragment() {
	vec3 c = texture(scr, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	l = pow(clamp(l * 1.9, 0.0, 1.0), 0.75);
	float n = fract(sin(dot(floor(SCREEN_UV * vec2(640.0, 360.0)) + floor(t * 30.0) * 7.31, vec2(12.9898, 78.233))) * 43758.5453);
	l = clamp(l + (n - 0.5) * 0.14, 0.0, 1.0);
	float scan = 0.93 + 0.07 * sin(SCREEN_UV.y * 760.0 + t * 8.0);
	vec2 d = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float r = length(d - vec2(clamp(d.x, -0.22, 0.22), 0.0));      // hai ống kính liền nhau
	float vig = smoothstep(0.5, 0.36, r);
	vec3 g = vec3(0.22, 1.0, 0.32) * l * scan;
	COLOR = vec4(g * vig, 1.0);
}
