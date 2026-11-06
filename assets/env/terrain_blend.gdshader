shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float grass_scale = 0.1;
uniform float dirt_scale = 0.13;
uniform float rock_scale = 0.08;
uniform float detail_mix = 0.85;

varying vec3 v_world_pos;
varying vec3 v_world_normal;
varying vec3 v_blend;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_blend = COLOR.rgb;
}

vec3 sample_xz(sampler2D tex, vec3 wp, float sc) {
	return texture(tex, wp.xz * sc).rgb;
}

void fragment() {
	vec3 w = max(v_blend, vec3(0.001));
	w = pow(w, vec3(1.25));
	w /= (w.x + w.y + w.z);

	vec3 grass = sample_xz(grass_albedo, v_world_pos, grass_scale);
	vec3 dirt = sample_xz(dirt_albedo, v_world_pos, dirt_scale);
	vec3 rock = sample_xz(rock_albedo, v_world_pos, rock_scale);
	// Second octave for micro-breakup
	grass = mix(grass, sample_xz(grass_albedo, v_world_pos, grass_scale * 3.5), 0.35);
	dirt = mix(dirt, sample_xz(dirt_albedo, v_world_pos, dirt_scale * 2.8), 0.3);

	vec3 albedo = dirt * w.x + grass * w.y + rock * w.z;
	// Slight saturation boost on grass-dominant pixels
	float gdom = w.y;
	vec3 gray = vec3(dot(albedo, vec3(0.299, 0.587, 0.114)));
	albedo = mix(albedo, mix(gray, albedo, 1.25), gdom * 0.45);
	albedo = mix(vec3(0.2, 0.35, 0.15), albedo, detail_mix);

	vec3 ntex = texture(grass_normal, v_world_pos.xz * grass_scale).rgb;
	NORMAL_MAP = ntex;
	NORMAL_MAP_DEPTH = 0.55 * w.y + 0.35;

	ALBEDO = clamp(albedo, vec3(0.02), vec3(1.0));
	ROUGHNESS = mix(0.9, 0.72, w.z);
	METALLIC = 0.0;
	SPECULAR = 0.3;
}
