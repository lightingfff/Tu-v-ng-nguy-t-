shader_type canvas_item;
render_mode unshaded;

uniform sampler2D material_atlas : filter_linear, repeat_disable;
uniform float pan = 0.0;
uniform float elapsed = 0.0;
uniform float restored = 0.0;
const vec2 PIXEL = 1.0 / vec2(2560.0, 853.0);

float light_pool(vec2 point, vec2 center, vec2 radius) {
	vec2 q = (point - center) / radius;
	return exp(-dot(q, q) * 2.0);
}

float ray(vec2 p, vec2 start, vec2 end, float width) {
	vec2 line = end - start;
	float t = dot(p - start, line) / dot(line, line);
	vec2 v = p - (start + clamp(t, 0.0, 1.0) * line);
	float spread = 0.004 + width * clamp(t, 0.0, 1.0);
	return exp(-dot(v, v) / (spread * spread)) *
		smoothstep(0.05, 0.20, t) * (1.0 - smoothstep(0.44, 1.0, t));
}

void fragment() {
	vec2 uv = UV;
	// Distant peaks follow the camera more slowly. Keep bridge, shrine and foot positions fixed.
	float peaks = smoothstep(0.28, 0.44, uv.x) * (1.0 - smoothstep(0.70, 0.80, uv.x))
		* (1.0 - smoothstep(0.35, 0.49, uv.y));
	uv.x -= pan * peaks * 0.045;
	vec3 material = texture(material_atlas, uv).rgb;
	vec3 base = texture(TEXTURE, uv).rgb;
	float water_mask = material.b;
	float ripple = sin(uv.y * 641.0 + elapsed * 4.0 + uv.x * 29.0)
		+ 0.40 * sin(uv.y * 887.0 - elapsed * 2.94 - uv.x * 54.0);
	vec2 ripple_shift = vec2(ripple * 3.1, sin(uv.x * 139.0 + elapsed * 2.4) * 0.54);
	vec3 lake = texture(TEXTURE, uv + ripple_shift * PIXEL).rgb;
	vec3 color = mix(base, lake, water_mask * 0.88);

	float green = smoothstep(0.025, 0.15, base.g - base.b);
	float red = smoothstep(0.10, 0.30, base.r - base.g);
	float canopy = max(
		light_pool(uv, vec2(0.245, 0.015), vec2(0.20, 0.13)) * green,
		light_pool(uv, vec2(0.969, 0.098), vec2(0.13, 0.21)) * red
	);
	float sway = sin(elapsed * 1.8 + uv.y * 17.0 + uv.x * 25.0)
		+ 0.33 * sin(elapsed * 3.12 - uv.x * 21.0);
	vec3 trees = texture(TEXTURE, uv + vec2(sway * 4.4, sway * 1.36) * PIXEL).rgb;
	color = mix(color, trees, canopy * 0.77);

	// Light falls from the canopy toward the river, with distinct bands through foliage.
	float sun = 0.025 * ray(uv, vec2(0.098, -0.03), vec2(0.427, 0.49), 0.034);
	sun += 0.041 * ray(uv, vec2(0.127, -0.04), vec2(0.382, 0.58), 0.029);
	sun += 0.035 * ray(uv, vec2(0.154, -0.018), vec2(0.465, 0.46), 0.030);
	float amber = light_pool(uv, vec2(0.157, 0.675), vec2(0.17, 0.072)) * 0.038;
	float shimmer = pow(max(0.0, sin(uv.y * 998.0 + elapsed * 4.5 + uv.x * 61.0)), 5.0);
	float reflection = light_pool(uv, vec2(0.531, 0.88), vec2(0.077, 0.21));
	color += vec3(0.98, 0.72, 0.37) * (sun + amber + shimmer * reflection * water_mask * 0.145);
	color += vec3(0.13, 0.37, 0.51) * water_mask * (0.031 + shimmer * 0.031);

	// Local surface gradients preserve the relief of the individual paving stones.
	vec2 relief = (material.rg - vec2(0.5)) * 2.0;
	float leaf_pattern = sin(uv.x * 97.0 + uv.y * 42.0 + sin(elapsed * 0.65))
		+ 0.55 * sin(uv.x * 211.0 - uv.y * 123.0 - elapsed * 0.62);
	float paving = smoothstep(0.68, 0.735, uv.y) * (1.0 - smoothstep(0.75, 0.83, uv.y));
	float cover = max(1.0 - smoothstep(0.03, 0.29, uv.x), smoothstep(0.78, 0.97, uv.x));
	float shade = smoothstep(-0.35, 0.75, leaf_pattern) * paving * cover;
	color *= mix(vec3(1.0), vec3(0.83, 0.88, 0.94), shade);
	float key = dot(relief, vec2(-0.82, -0.57));
	color += vec3(1.0, 0.78, 0.47) * max(key, 0.0) * 0.34 * (1.0 - shade);
	color *= 1.0 + min(key, 0.0) * 0.37;
	float swell = sin(uv.x * 72.0 + uv.y * 364.0 - elapsed * 2.3)
		+ 0.53 * sin(uv.x * 94.0 - uv.y * 218.0 + elapsed * 1.64);
	float glint = pow(clamp(0.68 * swell, 0.0, 1.0), 9.0);
	color += glint * reflection * water_mask * vec3(0.16, 0.115, 0.042);
	float shrine = light_pool(uv, vec2(0.871, 0.449), vec2(0.059, 0.134));
	float pulse = 0.73 + 0.27 * sin(elapsed * 1.78);
	color += shrine * vec3(0.32, 0.21, 0.075) * pulse * restored;
	float edge = smoothstep(0.59, 0.96, abs(uv.y - 0.46) * 2.0);
	COLOR = vec4(color * (1.0 - edge * 0.075), 1.0);
}
