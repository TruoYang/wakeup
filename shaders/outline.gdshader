shader_type spatial;
// Viền sáng quanh món đồ đang được trỏ vào: phồng khối ra một chút, chỉ vẽ mặt sau.
render_mode unshaded, cull_front, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.82, 0.3, 1.0);
uniform float width = 0.012;

void vertex() {
	VERTEX += sign(VERTEX) * width;
}

void fragment() {
	ALBEDO = color.rgb * (0.85 + 0.15 * sin(TIME * 6.0));
}
