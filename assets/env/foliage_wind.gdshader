shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(0.85, 1.0, 0.8, 1.0);
uniform float wind_strength = 0.18;
uniform float wind_speed = 1.6;
uniform float alpha_scissor = 0.35;

void vertex() {
	// Sway more toward tip (local Y).
	float tip = max(VERTEX.y, 0.0);
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float phase = wp.x * 0.35 + wp.z * 0.28;
	float gust = sin(TIME * wind_speed + phase) * 0.65 + sin(TIME * wind_speed * 1.7 + phase * 1.3) * 0.35;
	VERTEX.x += gust * wind_strength * tip;
	VERTEX.z += cos(TIME * wind_speed * 0.9 + phase) * wind_strength * 0.55 * tip;
}

void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	float a = tex.a;
	if (a < alpha_scissor) {
		discard;
	}
	ALBEDO = tex.rgb * albedo_tint.rgb;
	ALPHA = a;
	ROUGHNESS = 0.78;
	SPECULAR = 0.2;
}
