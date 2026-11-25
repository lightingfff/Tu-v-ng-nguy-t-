shader_type spatial;
render_mode cull_disabled;
varying float blade_height;
void vertex() {
	blade_height = clamp(VERTEX.y, 0.0, 1.0);
	float wave = sin(TIME * 1.85 + MODEL_MATRIX[3].x * .54 + MODEL_MATRIX[3].z * .34);
	VERTEX.x += wave * blade_height * blade_height * .21;
	VERTEX.z += wave * blade_height * .15;
}
void fragment() {
	ALBEDO = mix(COLOR.rgb * .63, COLOR.rgb * vec3(1.72,1.43,.91), blade_height);
	ROUGHNESS = .88;
	SPECULAR = .14;
}
