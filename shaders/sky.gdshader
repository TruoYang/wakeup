shader_type sky;
// Bầu trời có mây trôi. Hệ thống thời tiết sẽ điều khiển các tham số này.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;
uniform vec3 top_color : source_color = vec3(0.16, 0.24, 0.36);
uniform vec3 horizon_color : source_color = vec3(0.80, 0.62, 0.46);
uniform vec3 ground_color : source_color = vec3(0.13, 0.13, 0.14);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.86, 0.72);
uniform vec3 cloud_dark : source_color = vec3(0.22, 0.25, 0.31);
uniform float cover : hint_range(0.0, 1.0) = 0.55;
uniform float softness : hint_range(0.02, 0.6) = 0.26;
uniform float speed = 0.004;
uniform float sun_size = 0.035;
uniform float energy = 1.0;
uniform float moon = 0.0;       // 1 = nguồn sáng trên trời là mặt trăng
uniform float stars = 0.0;
global uniform float toon_style;

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float cloud_density(vec2 uv, float t) {
	float n = texture(noise_tex, uv * 0.05 + vec2(t, t * 0.4)).r * 0.58;
	n += texture(noise_tex, uv * 0.13 + vec2(-t * 1.6, t)).r * 0.30;
	n += texture(noise_tex, uv * 0.37 + vec2(t * 2.3, -t * 1.1)).r * 0.12;
	return n;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = clamp(dir.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(h, 0.5));
	if (dir.y < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-dir.y * 8.0, 0.0, 1.0));
	}
	float sun_amount = 0.0;
	if (LIGHT0_ENABLED) {
		float d = max(dot(dir, LIGHT0_DIRECTION), 0.0);
		sun_amount = d;
		// quầng sáng quanh mặt trời + đĩa mặt trời
		if (moon > 0.5) {
			// mặt trăng: đĩa to, sáng dịu, có quầng và vài vệt tối
			float md = acos(clamp(d, -1.0, 1.0));
			float disc = smoothstep(0.052, 0.046, md);
			vec2 muv = (dir.xz - LIGHT0_DIRECTION.xz) * 26.0;
			float mare = texture(noise_tex, muv * 0.5 + 0.3).r;
			col += vec3(0.62, 0.7, 0.9) * exp(-md * 9.0) * 0.22;
			col = mix(col, vec3(0.93, 0.95, 1.0) * (0.72 + 0.28 * mare), disc);
		} else {
			col += LIGHT0_COLOR * (pow(d, 12.0) * 0.25 + pow(d, 220.0) * 0.6);
			col += LIGHT0_COLOR * LIGHT0_ENERGY * smoothstep(1.0 - sun_size * sun_size, 1.0 - sun_size * sun_size * 0.5, d) * 2.0;
		}
	}
	if (stars > 0.01 && dir.y > 0.02) {
		vec2 sp = dir.xz / (dir.y + 0.35) * 90.0;
		vec2 cell = floor(sp);
		float rnd = hash2(cell);
		vec2 pos = fract(sp) - 0.5 - (vec2(hash2(cell + 3.1), hash2(cell + 7.7)) - 0.5) * 0.7;
		float star = smoothstep(0.09, 0.0, length(pos)) * step(0.86, rnd);
		col += vec3(0.85, 0.9, 1.0) * star * stars * (0.5 + 0.5 * sin(TIME * (1.0 + rnd * 3.0) + rnd * 40.0)) * smoothstep(0.02, 0.2, dir.y);
	}
	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.10);
		float t = TIME * speed;
		float n = cloud_density(uv, t);
		float soft = mix(softness, 0.035, toon_style);
		float cov = min(1.0, cover + 0.13 * toon_style);
		float dens = smoothstep(1.0 - cov, 1.0 - cov + soft, n);
		// phía mây hướng về mặt trời sáng hơn
		vec2 toward = LIGHT0_ENABLED ? LIGHT0_DIRECTION.xz * 0.6 : vec2(0.0);
		float n2 = cloud_density(uv + toward, t);
		float shade = clamp((n2 - n) * 4.0 + 0.45, 0.0, 1.0);
		// vẽ tay: mây chỉ có 3 mảng màu rõ (sáng, vừa, bóng)
		float banded = smoothstep(0.30, 0.34, shade) * 0.5 + smoothstep(0.52, 0.56, shade) * 0.5;
		shade = mix(shade, banded, toon_style);
		vec3 cc = mix(cloud_dark, cloud_light, shade * (0.55 + 0.45 * pow(sun_amount, 3.0)));
		cc = mix(cc, cloud_dark, dens * mix(0.45, 0.0, toon_style));   // lõi mây dày thì tối
		float fade = smoothstep(0.0, 0.16, dir.y);
		col = mix(col, cc, dens * fade);
	}
	COLOR = col * energy;
}
