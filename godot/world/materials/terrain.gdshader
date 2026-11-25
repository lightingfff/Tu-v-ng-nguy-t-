shader_type spatial;
uniform sampler2D grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone : source_color, filter_linear_mipmap, repeat_enable;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float path_distance(vec2 p, vec2 a, vec2 b) {
	vec2 d = b - a;
	return length(p - a - d * clamp(dot(p - a, d) / dot(d,d), 0.0, 1.0));
}

void fragment() {
	vec2 p = world_pos.xz;
	float patch = sin(p.x * 0.36 + sin(p.y * 0.45) * 1.1) * cos(p.y * 0.31 - p.x * 0.13);
	float edge = 0.27 * sin(p.x * 1.9 + p.y * 1.7) + patch * 0.64;
	float path = min(path_distance(p, vec2(-55, 4), vec2(55, 4)),
		path_distance(p, vec2(-24, 4), vec2(-24, -5)));
	path = min(path, path_distance(p, vec2(-19, 4), vec2(-9, -13)));
	path = min(path, path_distance(p, vec2(16, 4), vec2(21, -16)));
	path = min(path, path_distance(p, vec2(32, 4), vec2(32, -6)));
	path = min(path, path_distance(p, vec2(29, 4), vec2(46, 15)));
	float farm = smoothstep(2.75, 3.45, length((p - vec2(-24, 1)) * vec2(.57, 1.0)));
	float footpath = max(1.0 - smoothstep(1.35, 2.58, path + edge), (1.0 - farm) * .86);
	vec3 meadow = texture(grass, p / 3.1).rgb;
	meadow *= mix(vec3(.70, .84, .82), vec3(1.02, 1.01, .79), .5 + .5 * patch);
	vec3 earth = texture(soil, p / 3.45).rgb * (.91 + .11 * patch);
	float village_stone = 1.0 - smoothstep(5.2, 7.4, abs(p.x + 23.3));
	float shrine_stone = 1.0 - smoothstep(3.8, 6.6, abs(p.x - 34.5));
	float pebbles = max(smoothstep(.10, .74, patch) * .62, max(village_stone, shrine_stone) * .91);
	vec3 road = mix(earth, texture(stone, p / 3.6).rgb, pebbles);
	float damp = 1.0 - smoothstep(6.16, 8.32, abs(p.x) + patch * .4);
	ALBEDO = mix(mix(meadow, road, footpath), texture(stone, p / 3.6).rgb * vec3(.74,.88,.87), damp);
	ROUGHNESS = 0.91;
	SPECULAR = 0.16;
}
