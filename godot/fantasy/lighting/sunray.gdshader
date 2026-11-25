shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.83, 0.61, 1.0);
uniform float intensity = 0.11;
uniform float falloff = 1.65;
uniform float drift_speed = 0.19;

float dust(vec2 local, float seed) {
	vec2 cell = floor(local);
	vec2 center = vec2(fract(sin(dot(cell, vec2(71.9, 41.7)) + seed) * 4732.183),
		fract(sin(dot(cell, vec2(43.2, 18.1)) + seed) * 9271.34));
	return 1.0 - smoothstep(0.019, 0.057, length(fract(local) - center));
}

void fragment() {
	float down = UV.y;
	float drift = TIME * drift_speed;
	float spread = mix(0.24, 0.48, down);
	float hinge = sin(down * 1.8 + drift) * 0.042 * down;
	float edge = 1.0 - smoothstep(spread * 0.46, spread, abs(UV.x - 0.5 + hinge));
	float fade = smoothstep(0.0, 0.08, down) * pow(max(1.0 - down, 0.0), falloff);
	float strands = 0.80 + sin(UV.x * 34.0 + drift * 0.6) * 0.16;
	float motes = dust(UV * vec2(6.0, 17.0) + vec2(drift * 1.8, -drift * 1.1), 2.0);
	ALBEDO = tint.rgb;
	ALPHA = edge * fade * intensity * (strands + 0.72 * motes);
}
