shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Bot3 v5 — de-plastic terrain: height-aware material transitions, macro lush/dry
// variation, per-layer normals + roughness, no saturation boost.

uniform sampler2D grass_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_rough : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform float grass_scale = 0.12;
uniform float dirt_scale = 0.15;
uniform float rock_scale = 0.1;
uniform float normal_strength = 0.9;
uniform vec3 lush_tint : source_color = vec3(0.9, 0.96, 0.86);
uniform vec3 dry_tint : source_color = vec3(1.06, 0.98, 0.8);
uniform float macro_scale = 0.009;
uniform float transition_sharpness = 6.0;

varying vec3 v_world_pos;
varying vec3 v_blend;
varying float v_slope;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_blend = COLOR.rgb;
	v_slope = 1.0 - clamp(NORMAL.y, 0.0, 1.0);
}

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec2 wp = v_world_pos.xz;
	vec3 grass = texture(grass_albedo, wp * grass_scale).rgb;
	grass = mix(grass, texture(grass_albedo, wp * grass_scale * 0.31 + vec2(0.37, 0.11)).rgb, 0.4);
	vec3 dirt = texture(dirt_albedo, wp * dirt_scale).rgb;
	dirt = mix(dirt, texture(dirt_albedo, wp * dirt_scale * 2.8).rgb, 0.3);
	vec3 rock = texture(rock_albedo, wp * rock_scale).rgb;
	// Tame orange roads: pull dirt toward a neutral umber.
	dirt = mix(vec3(luma(dirt)), dirt, 0.68) * vec3(1.0, 0.98, 0.95);

	// Macro variation (very low frequency) — lush vs. sun-dried patches, value breakup.
	float m1 = luma(texture(dirt_albedo, wp * macro_scale).rgb);
	float m2 = luma(texture(rock_albedo, wp * macro_scale * 0.37 + vec2(0.5)).rgb);
	float macro = smoothstep(0.25, 0.75, m1 * 0.6 + m2 * 0.7 - 0.15);
	grass *= mix(lush_tint, dry_tint, macro * 0.8);
	grass *= 0.9 + 0.2 * m2;
	// Dirt in the grass reads as trampled earth, a touch darker/cooler than road dirt.
	dirt *= mix(vec3(0.92, 0.9, 0.86), vec3(1.0), macro);

	// Height-based blend: dirt shows in grass crevices first (avoids smeary vertex lerp).
	vec3 w = max(v_blend, vec3(0.0));
	vec3 hgt = vec3(luma(dirt), 1.0 - luma(grass), luma(rock)) * 0.6;
	vec3 hw = w + hgt * 0.35;
	float mx = max(hw.x, max(hw.y, hw.z));
	vec3 bw = max(hw - (mx - 1.0 / transition_sharpness), vec3(0.0));
	bw /= max(bw.x + bw.y + bw.z, 1e-4);

	vec3 albedo = dirt * bw.x + grass * bw.y + rock * bw.z;
	// Slope cavity darkening for depth (not a global darken).
	albedo *= 1.0 - v_slope * 0.35;

	vec3 ng = texture(grass_normal, wp * grass_scale).rgb;
	vec3 nd = texture(dirt_normal, wp * dirt_scale).rgb;
	vec3 nr = texture(rock_normal, wp * rock_scale).rgb;
	NORMAL_MAP = ng * bw.y + nd * bw.x + nr * bw.z;
	NORMAL_MAP_DEPTH = normal_strength * (0.7 + 0.6 * bw.z);

	float gr = texture(grass_rough, wp * grass_scale).r;
	ALBEDO = clamp(albedo, vec3(0.02), vec3(0.95));
	ROUGHNESS = clamp(gr * 0.25 + 0.75, 0.0, 1.0) * bw.y + 0.94 * bw.x + 0.78 * bw.z;
	METALLIC = 0.0;
	SPECULAR = 0.25 + 0.1 * bw.z;
	AO = 1.0 - v_slope * 0.4;
	AO_LIGHT_AFFECT = 0.25;
}
