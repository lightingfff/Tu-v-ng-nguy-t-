shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.56, 0.23, 1.0);
uniform float intensity = 0.29;
uniform float threshold = 0.44;
uniform float falloff = 2.4;
uniform float source_energy = 0.88;

void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	float halo = pow(max(1.0 - radius, 0.0), falloff);
	float key = smoothstep(threshold, threshold + 0.22, source_energy);
	ALBEDO = tint.rgb;
	ALPHA = halo * intensity * key;
}
