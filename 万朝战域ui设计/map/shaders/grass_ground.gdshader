shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D ground_texture
	: source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform vec4 tint_color : source_color = vec4(1.0);
uniform float detail_scale : hint_range(0.01, 1.0) = 0.12;
uniform float secondary_scale : hint_range(0.01, 1.0) = 0.073;
uniform float secondary_mix : hint_range(0.0, 0.5) = 0.28;
uniform float macro_scale : hint_range(0.001, 0.1) = 0.018;
uniform float macro_strength : hint_range(0.0, 0.35) = 0.11;
uniform float elevation_min = -2.0;
uniform float elevation_max = 12.0;
uniform float elevation_contrast : hint_range(0.0, 0.5) = 0.22;

// ——— 格子视觉参数 ———
// 格子尺寸，必须与 DemoMapData.cell_size 一致，用于在世界空间对齐格子边界
uniform float cell_size = 2.0;
// 格子线开关，关闭后恢复修改前的平滑地形外观
uniform bool grid_line_enabled = true;
// 格子线颜色，默认低饱和深色，避免棋盘感过强
uniform vec4 grid_line_color : source_color = vec4(0.04, 0.03, 0.02, 0.35);
// 格子线宽度（格子尺寸比例，0=无线，0.45=近半格），0.035 约为总宽 7%
uniform float grid_line_width : hint_range(0.0, 0.45) = 0.035;

varying vec2 world_xz;
varying float world_height;


void vertex() {
	vec3 world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_xz = world_position.xz;
	world_height = world_position.y;
}


void fragment() {
	vec3 primary_color = texture(ground_texture, world_xz * detail_scale).rgb;
	vec2 rotated_world = mat2(
		vec2(0.8, -0.6),
		vec2(0.6, 0.8)
	) * world_xz;
	vec3 secondary_color = texture(
		ground_texture,
		rotated_world * secondary_scale + vec2(0.43, 0.17)
	).rgb;
	vec3 detail_color = mix(primary_color, secondary_color, secondary_mix);
	float macro_value = texture(
		ground_texture,
		rotated_world.yx * macro_scale + vec2(0.37, 0.61)
	).g;
	float macro_factor = mix(
		1.0 - macro_strength,
		1.0 + macro_strength,
		macro_value
	);
	float elevation_range = max(elevation_max - elevation_min, 0.001);
	float elevation_ratio = smoothstep(
		0.0,
		1.0,
		clamp((world_height - elevation_min) / elevation_range, 0.0, 1.0)
	);
	float elevation_factor = mix(
		1.0 - elevation_contrast,
		1.0 + elevation_contrast,
		elevation_ratio
	);
	vec3 base_color = detail_color * tint_color.rgb * macro_factor * elevation_factor;

	// 格子线绘制：fract(world/cell) 在格子中心为 0、格子边界为 0.5，
	// 取 abs(fract - 0.5) 得到到最近边界的距离（0=边界, 0.5=中心）。
	// 格子线与 DemoMapData.world_to_grid() 的 round(world/cell) 完全对齐。
	if (grid_line_enabled && grid_line_width > 0.0) {
		vec2 cell_fract = fract(world_xz / cell_size);
		vec2 edge_dist = abs(cell_fract - 0.5);
		float grid_dist = min(edge_dist.x, edge_dist.y);
		float grid_factor = 1.0 - smoothstep(0.0, grid_line_width, grid_dist);
		base_color = mix(base_color, grid_line_color.rgb, grid_factor * grid_line_color.a);
	}

	ALBEDO = base_color;
}
