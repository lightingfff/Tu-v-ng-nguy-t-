shader_type canvas_item;
render_mode unshaded;

uniform sampler2D painting : source_color, filter_linear, repeat_disable;
uniform sampler2D defocused_painting : source_color, filter_linear, repeat_disable;
uniform sampler2D distance_map : filter_linear, repeat_disable;
uniform sampler2D water_map : filter_linear, repeat_disable;
uniform float elapsed = 0.0;
uniform float focus = 0.43;
uniform vec2 camera_offset = vec2(0.0);
uniform float depth_enabled = 1.0;
uniform float atmosphere_enabled = 1.0;

const vec2 SIZE = vec2(1536.0, 1024.0);

float ellipse(vec2 uv, vec2 center, vec2 radius) {
	vec2 p = (uv - center) / radius;
	return exp(-dot(p, p) * 2.0);
}

float soft_ray(vec2 p, vec2 lamp, vec2 target, float angle) {
	vec2 line = target - lamp;
	float n = clamp(dot(p - lamp, line) / dot(line, line), 0.0, 1.0);
	vec2 axis = lamp + n * line;
	float spread = mix(0.005, angle, n);
	float edge = exp(-pow(length(p - axis) / spread, 2.0) * 2.0);
	return edge * smoothstep(0.0, 0.15, n) * (1.0 - smoothstep(0.33, 1.0, n));
}

float mist_band(vec2 uv, float time, float baseline, float span) {
	float ridge = baseline + sin(uv.x * 11.0 - time * 0.08) * 0.019;
	ridge += sin(uv.x * 27.0 + time * 0.13) * 0.008;
	float band = exp(-pow((uv.y - ridge) / span, 2.0) * 2.0);
	float drift = 0.63 + 0.23 * sin(uv.x * 21.0 + time * 0.17 + uv.y * 11.0);
	return band * drift;
}

void fragment() {
	float relief = texture(distance_map, UV).r;
	vec2 uv = UV + camera_offset * (relief - 0.43) * 0.095;
	float depth = texture(distance_map, uv).r;
	float water = texture(water_map, uv).r;
	vec2 view_uv = uv;
	vec3 original = texture(painting, view_uv).rgb;

	float blossoms = ellipse(uv, vec2(0.081, 0.104), vec2(0.22, 0.26));
	blossoms *= smoothstep(0.02, 0.24, original.r - original.g);
	float grasses = max(
		ellipse(uv, vec2(0.09, 0.939), vec2(0.24, 0.17)),
		ellipse(uv, vec2(0.973, 0.834), vec2(0.14, 0.22))
	);
	grasses *= smoothstep(-0.012, 0.075, original.g - original.r);
	float broadleaf = ellipse(uv, vec2(0.273, 0.39), vec2(0.068, 0.079));
	broadleaf *= smoothstep(0.029, 0.16, original.g - original.r);
	float wind = 0.11 + 0.65 * sin(elapsed * 1.52 - uv.y * 18.0 + uv.x * 9.0);
	wind += 0.24 * sin(elapsed * 2.7 + uv.x * 28.0);
	view_uv += vec2(4.4, 1.5) / SIZE * wind * (blossoms + grasses + broadleaf);

	float water_surface = smoothstep(0.14, 0.86, water);
	float ripples = sin(uv.y * 477.0 - elapsed * 3.85 + uv.x * 19.0);
	ripples += 0.46 * sin(uv.y * 789.0 + elapsed * 2.2 - uv.x * 33.0);
	view_uv += vec2(ripples * (1.0 + (uv.y - 0.29) * 10.0), sin(uv.x * 69.0 + elapsed * 1.7) * 0.43)
		/ SIZE * water_surface;
	float blur = smoothstep(0.105, 0.46, abs(depth - focus));
	float near_lens = 1.0 - smoothstep(0.055, 0.29, depth);
	float defocus = max(blur * 0.78, near_lens * 0.86) * depth_enabled;
	vec3 in_focus = texture(painting, view_uv).rgb;
	vec3 defocused = texture(defocused_painting, view_uv).rgb;
	vec3 color = mix(in_focus, defocused, defocus);

	// Light fragments stretch horizontally where water ripples face either light source.
	float glints = pow(max(0.0, sin(uv.y * 821.0 + elapsed * 3.6 + uv.x * 82.0)), 7.0);
	float shimmer = 0.38 + 0.32 * sin(uv.y * 128.0 + uv.x * 324.0 - elapsed * 2.55);
	float moon_x = 0.874 + ripples * 0.0032;
	float lantern_x = 0.793 + ripples * 0.0043;
	float moon = ellipse(uv, vec2(moon_x, 0.347), vec2(0.027, 0.098));
	float lantern = ellipse(uv, vec2(lantern_x, 0.416), vec2(0.016, 0.148));
	color += vec3(0.45, 0.65, 0.91) * moon * glints * shimmer * water_surface * 0.44;
	color += vec3(1.0, 0.56, 0.19) * lantern * glints * shimmer * water_surface * 0.53;
	color += vec3(0.10, 0.22, 0.24) * glints * water_surface * 0.28
		* (1.0 - smoothstep(0.3, 0.6, color.r));

	float breathe = 0.94 + 0.045 * sin(elapsed * 2.2) + 0.02 * sin(elapsed * 4.9);
	float door = ellipse(uv, vec2(0.500, 0.407), vec2(0.097, 0.085)) * 0.093;
	float steps = ellipse(uv, vec2(0.50, 0.515), vec2(0.175, 0.049)) * 0.075;
	float left_pool = ellipse(uv, vec2(0.190, 0.665), vec2(0.14, 0.058)) * 0.053;
	float right_pool = ellipse(uv, vec2(0.852, 0.713), vec2(0.099, 0.063)) * 0.036;
	float lantern_rays = soft_ray(uv, vec2(0.451, 0.319), vec2(0.411, 0.530), 0.062);
	lantern_rays += soft_ray(uv, vec2(0.551, 0.319), vec2(0.582, 0.540), 0.063);
	lantern_rays += soft_ray(uv, vec2(0.197, 0.447), vec2(0.189, 0.694), 0.072) * 0.58;
	float moon_ray = soft_ray(uv, vec2(0.785, 0.059), vec2(0.520, 0.524), 0.095);
	float haze = mist_band(uv, elapsed, 0.245, 0.054) * smoothstep(0.65, 0.94, depth);
	float blue_hour = smoothstep(0.59, 0.95, depth) * (0.043 + haze * 0.094);
	color = mix(color, vec3(0.27, 0.38, 0.66), blue_hour * atmosphere_enabled);
	float low_haze = mist_band(uv, -elapsed * 0.58, 0.698, 0.053);
	low_haze *= smoothstep(0.12, 0.26, uv.x) * (1.0 - smoothstep(0.70, 0.93, uv.x));
	color += vec3(0.99, 0.63, 0.25) * (door + steps + left_pool + right_pool)
		* breathe * atmosphere_enabled;
	color += vec3(1.0, 0.68, 0.34) * lantern_rays * (0.057 + low_haze * 0.031)
		* breathe * atmosphere_enabled;
	color += vec3(0.40, 0.55, 0.91) * (haze * 0.041 + moon_ray * 0.080 + low_haze * 0.042)
		* atmosphere_enabled;

	float vignette = smoothstep(0.34, 0.77, length((uv - vec2(0.5, 0.51)) * vec2(1.08, 0.78)));
	color *= 1.0 - vignette * 0.17;
	COLOR = vec4(color, 1.0);
}
