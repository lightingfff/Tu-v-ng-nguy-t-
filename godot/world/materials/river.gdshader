shader_type spatial;
render_mode cull_disabled;
varying vec2 river_point;

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	river_point = p.xz;
	VERTEX.y += sin(p.z * 1.18 - TIME * 1.63 - p.x * .22) * .035;
}

void fragment() {
	vec2 p = river_point;
	float current = TIME * 1.38;
	float a = sin(p.y * 3.7 + p.x * .75 - current);
	float b = cos(p.x * 2.9 + p.y * 2.2 - current * 1.31);
	float thin = pow(max(0.0, sin(p.y * 14.1 - current * 2.4 + b * 1.15 + p.x * 3.1)), 11.0);
	float shore = smoothstep(4.3, 6.2, abs(p.x) + .14 * sin(p.y * 2.2 - current));
	vec3 shallow = vec3(.16, .44, .32);
	vec3 deep = vec3(.045, .217, .252);
	vec3 refraction = mix(deep, shallow, shore);
	float stripe = exp(-pow(abs(p.x - 1.25 - a * .57) / 2.12, 2.0));
	ALBEDO = refraction + (a + b) * vec3(.014,.023,.021);
	EMISSION = thin * (vec3(.11,.23,.19) * shore + vec3(.54,.25,.069) * stripe * (.56 + .44 * b));
	NORMAL_MAP = vec3(.5 + a * .075, .5 + b * .095, 1.0);
	ROUGHNESS = .22;
	SPECULAR = .82;
}
