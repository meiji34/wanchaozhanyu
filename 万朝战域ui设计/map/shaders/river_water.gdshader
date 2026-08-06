shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D water_texture
	: source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float texture_scale : hint_range(0.01, 1.0) = 0.11;
uniform vec2 primary_flow_speed = vec2(0.012, 0.0);
uniform vec2 secondary_flow_speed = vec2(-0.004, 0.007);
uniform float secondary_mix : hint_range(0.0, 0.5) = 0.24;
uniform float shimmer_strength : hint_range(0.0, 0.25) = 0.08;

varying vec2 world_xz;


void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}


void fragment() {
	vec2 base_uv = world_xz * texture_scale;
	vec3 primary_color = texture(
		water_texture,
		base_uv + primary_flow_speed * TIME
	).rgb;
	vec3 secondary_color = texture(
		water_texture,
		base_uv.yx * 1.31 + secondary_flow_speed * TIME + vec2(0.29, 0.53)
	).rgb;
	float shimmer = dot(secondary_color, vec3(0.333333));
	vec3 water_color = mix(primary_color, secondary_color, secondary_mix);
	ALBEDO = water_color * tint_color.rgb * mix(
		1.0 - shimmer_strength,
		1.0 + shimmer_strength,
		shimmer
	);
}
