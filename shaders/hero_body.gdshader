shader_type spatial;
// Da người thật (texture gốc) + quần áo nhuộm màu theo từng nhân vật. Vùng áo / quần / giày nằm ở kênh màu đỉnh
// (r = áo, g = quần, b = giày) do hero_humanoid.gd tô sẵn theo vị trí trên cơ thể.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_g, filter_linear_mipmap, repeat_enable;
instance uniform vec4 shirt_color : source_color = vec4(0.9, 0.88, 0.84, 1.0);
instance uniform vec4 pants_color : source_color = vec4(0.22, 0.25, 0.3, 1.0);
instance uniform vec4 shoe_color : source_color = vec4(0.1, 0.09, 0.09, 1.0);
instance uniform vec4 skin_tint : source_color = vec4(1.0, 0.95, 0.9, 1.0);
// da mịn kiểu cách điệu (0 = texture da thật nhiều gân / vân, 1 = da trơn một màu, chỉ giữ chút khối)
instance uniform float smooth_skin = 0.0;
instance uniform float cloth_flat = 0.0;
instance uniform vec4 skin_flat : source_color = vec4(0.86, 0.66, 0.52, 1.0);
// găng tay hở ngón (chỉ tay góc nhìn thứ nhất)
instance uniform float glove_on = 0.0;
instance uniform vec4 glove_color : source_color = vec4(0.13, 0.13, 0.14, 1.0);
instance uniform vec4 glove_panel : source_color = vec4(0.42, 0.36, 0.26, 1.0);

varying vec4 mask;

void vertex() {
	mask = COLOR;
}

void fragment() {
	vec3 tex = texture(albedo_tex, UV).rgb;
	float lum = dot(tex, vec3(0.3, 0.59, 0.11));
	vec3 skin = mix(tex * skin_tint.rgb, skin_flat.rgb * (0.88 + 0.22 * clamp(lum * 2.2, 0.0, 1.0)), smooth_skin);
	// vải: lấy độ sáng tối của da làm nếp gấp, nhạt đi để không lộ cơ bắp quá rõ
	float fold = mix(0.72 + 0.5 * clamp(lum * 1.6, 0.0, 1.0), 1.0, cloth_flat);
	// mép vải sắc (không phai dần), có một dải gấp mép sẫm hơn ngay chỗ tay áo / ống quần kết thúc
	float ms = smoothstep(0.4, 0.5, mask.r);
	float mp = smoothstep(0.4, 0.5, mask.g);
	float mb = smoothstep(0.4, 0.5, mask.b);
	float hem = (smoothstep(0.4, 0.5, mask.r) - smoothstep(0.62, 0.72, mask.r));
	vec3 col = skin;
	col = mix(col, shirt_color.rgb * fold * (1.0 - 0.28 * hem), ms);
	col = mix(col, pants_color.rgb * fold, mp);
	col = mix(col, shoe_color.rgb * (0.8 + 0.3 * lum), mb);
	float gl = smoothstep(0.2, 0.3, mask.a) * glove_on;
	float back = smoothstep(0.7, 0.8, mask.a);
	col = mix(col, mix(glove_color.rgb, glove_panel.rgb, back), gl);
	float cloth = clamp(ms + mp + mb + gl, 0.0, 1.0);
	SPECULAR = mix(0.45, 0.2, cloth);
	ALBEDO = col;
	ROUGHNESS = mix(mix(texture(rough_tex, UV).g, 0.55, smooth_skin), 0.95, cloth);
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = mix(mix(1.0, 0.25, smooth_skin), mix(0.3, 0.0, cloth_flat), cloth);
}
