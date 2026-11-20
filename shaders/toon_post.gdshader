shader_type spatial;
// Phong cách vẽ tay: gộp màu thành mảng như nét cọ (Kuwahara), viền mực mảnh theo độ sâu và pháp tuyến, màu tươi hơn.
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D nr_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform int radius = 3;
uniform float ink = 0.92;
uniform float saturation = 1.38;
uniform vec3 ink_color : source_color = vec3(0.16, 0.11, 0.13);
uniform vec3 shadow_tint : source_color = vec3(0.30, 0.36, 0.62);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 view_pos(vec2 uv, mat4 ip) {
	float d = texture(depth_tex, uv).r;
	if (d < 0.000001) { return vec3(0.0, 0.0, -5000.0); }
	vec4 v = ip * vec4(uv * 2.0 - 1.0, d, 1.0);
	return v.xyz / v.w;
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float k = max(1.0, VIEWPORT_SIZE.y / 720.0);
	// ---- nét cọ: chọn vùng lân cận đồng màu nhất
	vec3 mean[4]; vec3 sq[4];
	for (int q = 0; q < 4; q++) { mean[q] = vec3(0.0); sq[q] = vec3(0.0); }
	int r = clamp(radius, 1, 4);
	for (int j = -r; j <= r; j++) {
		for (int i = -r; i <= r; i++) {
			vec3 c = texture(screen_tex, SCREEN_UV + vec2(float(i), float(j)) * px * k).rgb;
			vec3 c2 = c * c;
			if (i <= 0 && j <= 0) { mean[0] += c; sq[0] += c2; }
			if (i >= 0 && j <= 0) { mean[1] += c; sq[1] += c2; }
			if (i <= 0 && j >= 0) { mean[2] += c; sq[2] += c2; }
			if (i >= 0 && j >= 0) { mean[3] += c; sq[3] += c2; }
		}
	}
	float n = float((r + 1) * (r + 1));
	vec3 col = vec3(0.0);
	float best = 1e9;
	for (int q = 0; q < 4; q++) {
		vec3 m = mean[q] / n;
		vec3 v = abs(sq[q] / n - m * m);
		float var = v.r + v.g + v.b;
		if (var < best) { best = var; col = m; }
	}
	// ---- viền mực
	// Đo khoảng cách từ các điểm lân cận tới mặt phẳng của điểm đang xét: mặt đường nhìn xiên, vạch sơn mỏng
	// không còn sinh nét giả (nét đứt), chỉ chỗ thật sự có bậc, có mép vật mới ra nét.
	vec2 o = px * k * 1.5;
	vec3 nc = texture(nr_tex, SCREEN_UV).xyz * 2.0 - 1.0;
	vec3 p0 = view_pos(SCREEN_UV, INV_PROJECTION_MATRIX);
	float z = -p0.z;
	float far_any = z;
	float near_any = z;
	float dmax = 0.0;
	float nd = 0.0;
	for (int i = 0; i < 4; i++) {
		vec2 uv = SCREEN_UV + (i == 0 ? vec2(-o.x, 0.0) : (i == 1 ? vec2(o.x, 0.0) : (i == 2 ? vec2(0.0, -o.y) : vec2(0.0, o.y))));
		vec3 pi = view_pos(uv, INV_PROJECTION_MATRIX);
		dmax = max(dmax, abs(dot(nc, pi - p0)));
		far_any = max(far_any, -pi.z);
		near_any = min(near_any, -pi.z);
		nd += 1.0 - dot(nc, texture(nr_tex, uv).xyz * 2.0 - 1.0);
	}
	float thr = 0.05 + near_any * 0.014;
	float e_depth = smoothstep(thr, thr * 2.2, dmax);
	if (z > 4000.0) { e_depth = step(near_any, 4000.0); }          // nền trời: nét ở mép vật che trời
	float e_norm = smoothstep(0.22, 0.65, nd) * step(far_any, 4000.0);
	float edge = max(e_depth, e_norm * 0.85);
	// xa thì nét nhạt dần để phố xa không thành mớ nét đen
	edge *= 1.0 - smoothstep(140.0, 600.0, near_any);
	// ---- màu
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	col = mix(col, col * 0.55 + shadow_tint * l * 1.1, (1.0 - smoothstep(0.0, 0.22, l)) * 0.45);   // bóng ngả xanh tím
	col = mix(col, ink_color * (0.25 + l * 0.9), edge * ink);
	ALBEDO = max(col, vec3(0.0));
}
