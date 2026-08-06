shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D bridge_texture
	: source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 tint_color : source_color = vec4(0.92, 0.82, 0.68, 1.0);


void fragment() {
	ALBEDO = texture(bridge_texture, UV).rgb * tint_color.rgb;
}
