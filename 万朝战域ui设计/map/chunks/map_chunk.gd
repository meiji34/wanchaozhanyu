class_name MapChunk
extends Node3D

enum LODLevel {
	LOD0 = 0,  ## 完整：地形 + 碰撞 + 森林 + 水体 + 道路 + 迷雾
	LOD1 = 1,  ## 精简：地形 + 水体 + 道路（无碰撞/无森林）
	LOD2 = 2,  ## 远景代理：仅地形轮廓面片 + 迷雾
}

const PLAIN_COLOR := Color("6f7750")
const MOUNTAIN_GROUND_COLOR := Color("756044")
const RIVER_COLOR := Color("3f7777")
const ROAD_COLOR := Color("aa8755")
const NORMAL_ROAD_COLOR := Color("92764f")
const RING_ROAD_COLOR := Color("b18b4c")
const HIDDEN_PATH_COLOR := Color("6d6047")
const BRIDGE_COLOR := Color("8b6741")
const FORD_COLOR := Color("aa996f")
const FOG_UNKNOWN_COLOR := Color(0.02, 0.02, 0.02, 0.88)
## EXPLORED 和 VISIBLE 均完全透明，不再需要区分常量；仅保留 FOG_VISIBLE_COLOR 用于 _sample_fog_color 默认返回值
const FOG_VISIBLE_COLOR := Color(0.0, 0.0, 0.0, 0.0)
const FOG_HEIGHT_OFFSET := 0.12

const MATERIAL_CONFIGS := {
	&"grass": {
		"path": "res://map/materials/grass_ground_material.tres",
		"fallback": PLAIN_COLOR,
		"name": "草地纹理材质",
	},
	&"river": {
		"path": "res://map/materials/river_water_material.tres",
		"fallback": RIVER_COLOR,
		"name": "河流水面材质",
	},
	&"forest": {
		"path": "res://map/materials/forest_ground_material.tres",
		"fallback": Color("3f6042"),
		"name": "森林区纹理材质",
	},
	&"mountain": {
		"path": "res://map/materials/mountain_ground_material.tres",
		"fallback": MOUNTAIN_GROUND_COLOR,
		"name": "山地区纹理材质",
	},
	&"wetland": {
		"path": "res://map/materials/wetland_ground_material.tres",
		"fallback": Color("557562"),
		"name": "湿地区纹理材质",
	},
	&"central": {
		"path": "res://map/materials/central_ground_material.tres",
		"fallback": Color("877650"),
		"name": "中央区纹理材质",
	},
	&"road": {"fallback": ROAD_COLOR},
	&"normal_road": {"fallback": NORMAL_ROAD_COLOR},
	&"ring_road": {"fallback": RING_ROAD_COLOR},
	&"hidden_path": {"fallback": HIDDEN_PATH_COLOR},
	&"bridge": {
		"path": "res://map/materials/bridge_deck_material.tres",
		"fallback": BRIDGE_COLOR,
		"name": "临时桥梁桥面贴图材质",
	},
	&"ford": {"fallback": FORD_COLOR},
}

static var _material_cache: Dictionary = {}

## 格子视觉线开关（默认开启）。切换后立即更新所有已缓存地面材质，无需重建 Chunk。
static var grid_visual_enabled: bool = true


## 切换格子视觉线显示。遍历所有已缓存地面 ShaderMaterial，设置 grid_line_enabled 参数。
## 对未加载的 Chunk，下次加载时自动从该静态变量读取当前状态。
static func set_grid_visual_enabled(enabled: bool) -> void:
	grid_visual_enabled = enabled
	for material_key in _material_cache:
		var material := _material_cache[material_key] as Material
		if material is ShaderMaterial:
			(material as ShaderMaterial).set_shader_parameter(
				&"grid_line_enabled", enabled
			)

enum ChunkRuntimeState {
	UNLOADED = 0,   ## 未加载
	PRELOADED = 1,  ## 后台就绪，不显示、不碰撞、不接收输入
	ACTIVATING = 2, ## 主线程正在创建渲染对象，尚未显示
	ACTIVE = 3,     ## 活动状态，显示 + 碰撞 + 交互
	FAILED = 4,     ## 构建失败
}

var chunk_coordinate := Vector2i.ZERO
var map_data: DemoMapData
var lod_level: int = LODLevel.LOD0
var runtime_state: int = int(ChunkRuntimeState.UNLOADED)


## 当前阵营覆盖层使用的阵营 ID（由 MapController 设置）
var fog_faction_id: int = DemoPlayerContext.FactionId.FOREST


func configure(
	p_map_data: DemoMapData,
	p_chunk_coordinate: Vector2i,
	p_lod_level: int = int(LODLevel.LOD0)
) -> void:
	map_data = p_map_data
	chunk_coordinate = p_chunk_coordinate
	lod_level = p_lod_level
	name = "Chunk_%d_%d" % [chunk_coordinate.x, chunk_coordinate.y]
	var bounds := map_data.get_chunk_grid_bounds(chunk_coordinate)
	position = map_data.vertex_grid_to_world(bounds.position)
	_clear_visuals()
	runtime_state = int(ChunkRuntimeState.ACTIVATING)
	match lod_level:
		LODLevel.LOD0:
			_build_visuals()  # 完整：地形+碰撞+森林+水体+道路+迷雾
		LODLevel.LOD1:
			_build_visuals()  # 精简：地形+水体+道路（无碰撞/无森林，由 _build_visuals 内部控制）
		LODLevel.LOD2:
			_build_lod2_proxy(bounds)  # 远景代理面片
	# 构建完成后统一标记为 ACTIVE 或 PRELOADED
	if lod_level <= LODLevel.LOD1:
		runtime_state = int(ChunkRuntimeState.ACTIVE)
		visible = true
		process_mode = Node.PROCESS_MODE_INHERIT
	else:
		runtime_state = int(ChunkRuntimeState.PRELOADED)
		visible = false
		process_mode = Node.PROCESS_MODE_DISABLED


## 将预加载 Chunk 升级为活动状态（显示 + 启用流程）
func activate() -> void:
	if runtime_state == ChunkRuntimeState.ACTIVE:
		return
	runtime_state = int(ChunkRuntimeState.ACTIVE)
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	# 确保迷雾覆盖层反映当前探索状态
	rebuild_fog()


## 将活动 Chunk 降级为预加载状态（隐藏，保留数据和网格）
func deactivate() -> void:
	if runtime_state != ChunkRuntimeState.ACTIVE:
		return
	runtime_state = int(ChunkRuntimeState.PRELOADED)
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED


func _clear_visuals() -> void:
	for child in get_children():
		child.free()


func _build_visuals() -> void:
	if map_data == null:
		return
	var bounds := map_data.get_chunk_grid_bounds(chunk_coordinate)
	var ground_mesh := TerrainMeshBuilder.build_ground_mesh(map_data, bounds)
	for surface_index in range(ground_mesh.get_surface_count()):
		var surface_key := int(ground_mesh.surface_get_name(surface_index))
		ground_mesh.surface_set_material(surface_index, _get_surface_material(surface_key))
	_add_mesh_instance("Terrain", ground_mesh)

	if lod_level <= LODLevel.LOD1:
		var water_mesh := TerrainMeshBuilder.build_water_mesh(map_data, bounds)
		if water_mesh.get_surface_count() > 0:
			water_mesh.surface_set_material(0, _get_cached_material(&"river"))
			_add_mesh_instance("RiverWater", water_mesh)

		_build_road_layer(bounds, MapTileTypes.RoadType.MAIN, "MainRoads", &"road")
		_build_road_layer(bounds, MapTileTypes.RoadType.NORMAL, "NormalRoads", &"normal_road")
		_build_road_layer(bounds, MapTileTypes.RoadType.RING, "RingRoads", &"ring_road")
		_build_road_layer(bounds, MapTileTypes.RoadType.HIDDEN, "HiddenPaths", &"hidden_path")

		var bridge_mesh := TerrainMeshBuilder.build_road_mesh(
			map_data,
			bounds,
			true,
			MapTileTypes.RoadType.NONE,
			"bridge"
		)
		if bridge_mesh.get_surface_count() > 0:
			bridge_mesh.surface_set_material(0, _get_cached_material(&"bridge"))
			_add_mesh_instance("BridgeDeckPlaceholders", bridge_mesh)

		var ford_mesh := TerrainMeshBuilder.build_road_mesh(
			map_data,
			bounds,
			true,
			MapTileTypes.RoadType.NONE,
			"ford"
		)
		if ford_mesh.get_surface_count() > 0:
			ford_mesh.surface_set_material(0, _get_cached_material(&"ford"))
			_add_mesh_instance("Fords", ford_mesh)

	if lod_level == LODLevel.LOD0:
		_build_collision(bounds)
		_build_forest(bounds)

	_build_fog_overlay(bounds)


func _build_road_layer(
	bounds: Rect2i,
	road_type: int,
	node_name: String,
	material_key: StringName
) -> void:
	var road_mesh := TerrainMeshBuilder.build_road_mesh(map_data, bounds, false, road_type)
	if road_mesh.get_surface_count() == 0:
		return
	road_mesh.surface_set_material(0, _get_cached_material(material_key))
	_add_mesh_instance(node_name, road_mesh)


func _add_mesh_instance(node_name: String, mesh: ArrayMesh) -> void:
	if mesh.get_surface_count() == 0:
		return
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _build_collision(bounds: Rect2i) -> void:
	var faces := TerrainMeshBuilder.build_collision_faces(map_data, bounds)
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "TerrainCollisionShape"
	collision_shape.shape = shape
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	body.add_child(collision_shape)
	add_child(body)


func _build_forest(bounds: Rect2i) -> void:
	var multimesh := TerrainMeshBuilder.build_tree_multimesh(map_data, bounds)
	if multimesh == null:
		return
	var trees := MultiMeshInstance3D.new()
	trees.name = "ForestTrees"
	trees.multimesh = multimesh
	trees.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trees)


func _get_surface_material(surface_key: int) -> Material:
	match surface_key:
		TerrainMeshBuilder.SURFACE_FOREST:
			return _get_cached_material(&"forest")
		TerrainMeshBuilder.SURFACE_MOUNTAIN:
			return _get_cached_material(&"mountain")
		TerrainMeshBuilder.SURFACE_WETLAND:
			return _get_cached_material(&"wetland")
		TerrainMeshBuilder.SURFACE_CENTRAL:
			return _get_cached_material(&"central")
		_:
			return _get_cached_material(&"grass")


func _get_cached_material(material_key: StringName) -> Material:
	if _material_cache.has(material_key):
		return _material_cache[material_key] as Material
	var material_config: Dictionary = MATERIAL_CONFIGS.get(material_key, {})
	var fallback_color: Color = material_config.get("fallback", PLAIN_COLOR)
	var resource_path := str(material_config.get("path", ""))
	var material := (
		_load_optional_material(
			resource_path,
			fallback_color,
			str(material_config.get("name", material_key))
		)
		if not resource_path.is_empty()
		else _create_unshaded_material(fallback_color)
	)
	_material_cache[material_key] = material
	return material


func _load_optional_material(
	resource_path: String,
	fallback_color: Color,
	display_name: String
) -> Material:
	if ResourceLoader.exists(resource_path, "Material"):
		var resource := load(resource_path)
		if resource is Material:
			var material := resource as Material
			# 加载后同步当前格子视觉开关状态，确保未加载 Chunk 也遵守设置
			if material is ShaderMaterial:
				(material as ShaderMaterial).set_shader_parameter(
					&"grid_line_enabled", grid_visual_enabled
				)
			return material
	push_warning("%s不可用，回退到纯色占位材质：%s" % [display_name, resource_path])
	return _create_unshaded_material(fallback_color)


func _create_unshaded_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


## ——— 迷雾覆盖层 ———

func _build_fog_overlay(bounds: Rect2i) -> void:
	if map_data == null or map_data.fog_data == null:
		return
	var fog := map_data.fog_data
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var has_any_fog := false
	var cs := map_data.cell_size

	# 阶梯迷雾：每格顶部 + 侧面，雾色由格子自身状态决定
	for local_y in range(bounds.size.y):
		for local_x in range(bounds.size.x):
			var grid_position := bounds.position + Vector2i(local_x, local_y)
			if not map_data.is_valid_grid(grid_position):
				continue
			var surface_height := map_data.get_surface_height_at_grid(grid_position)
			var fog_color := _get_cell_fog_color(fog, grid_position)
			if fog_color.a > 0.01:
				has_any_fog = true

			# 顶部四边形
			var base := vertices.size()
			for corner in TerrainMeshBuilder.QUAD_CORNERS:
				vertices.append(Vector3(
					(float(local_x) + float(corner.x)) * cs,
					surface_height + FOG_HEIGHT_OFFSET,
					(float(local_y) + float(corner.y)) * cs
				))
				colors.append(fog_color)
				normals.append(Vector3.UP)
			indices.append_array(PackedInt32Array([
				base, base + 1, base + 2,
				base + 2, base + 1, base + 3,
			]))

			# 侧面（仅当当前格子高于邻居时生成，使用当前格子雾色）
			for dir_info in TerrainMeshBuilder.SIDE_DIRECTIONS:
				var neighbor_grid: Vector2i = grid_position + dir_info.offset
				if not map_data.is_valid_grid(neighbor_grid):
					continue
				var neighbor_height := map_data.get_surface_height_at_grid(neighbor_grid)
				if surface_height <= neighbor_height:
					continue
				var ca: Vector2i = dir_info.corner_a
				var cb: Vector2i = dir_info.corner_b
				var side_base := vertices.size()
				vertices.append(Vector3(
					(float(local_x) + float(ca.x)) * cs,
					surface_height + FOG_HEIGHT_OFFSET,
					(float(local_y) + float(ca.y)) * cs))
				vertices.append(Vector3(
					(float(local_x) + float(cb.x)) * cs,
					surface_height + FOG_HEIGHT_OFFSET,
					(float(local_y) + float(cb.y)) * cs))
				vertices.append(Vector3(
					(float(local_x) + float(ca.x)) * cs,
					neighbor_height + FOG_HEIGHT_OFFSET,
					(float(local_y) + float(ca.y)) * cs))
				vertices.append(Vector3(
					(float(local_x) + float(cb.x)) * cs,
					neighbor_height + FOG_HEIGHT_OFFSET,
					(float(local_y) + float(cb.y)) * cs))
				var normal: Vector3 = dir_info.normal
				for _i in range(4):
					colors.append(fog_color)
					normals.append(normal)
				indices.append_array(PackedInt32Array([
					side_base, side_base + 1, side_base + 2,
					side_base + 2, side_base + 1, side_base + 3,
				]))

	if not has_any_fog:
		return
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.no_depth_test = true
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "FogOverlay"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# 迷雾覆盖层不参与射线拾取，防止阻挡地图点击
	instance.set_meta(&"fog_overlay", true)
	add_child(instance)


func rebuild_fog() -> void:
	## 在迷雾状态更新后重建本 Chunk 的迷雾覆盖层
	var fog_node := get_node_or_null("FogOverlay")
	if fog_node != null:
		fog_node.free()
	# 清理遗留的旧阵营覆盖层节点（已移除该功能，但可能存在旧实例）
	var legacy_faction_node := get_node_or_null("FactionOverlay")
	if legacy_faction_node != null:
		legacy_faction_node.free()
	if map_data != null:
		var bounds := map_data.get_chunk_grid_bounds(chunk_coordinate)
		_build_fog_overlay(bounds)


func _get_cell_fog_color(fog: FogData, grid_position: Vector2i) -> Color:
	## 阶梯迷雾：直接返回格子自身的迷雾状态颜色
	if fog.is_unknown(grid_position, fog_faction_id):
		return FOG_UNKNOWN_COLOR
	return FOG_VISIBLE_COLOR


## ——— LOD2 远景代理 ———

func _build_lod2_proxy(bounds: Rect2i) -> void:
	## LOD2：简单彩色面片代理，无碰撞/无森林/无道路
	if map_data == null:
		return
	var cell_w := float(bounds.size.x) * map_data.cell_size
	var cell_h := float(bounds.size.y) * map_data.cell_size
	# 使用 Chunk 中心平均阶梯高度
	var sum_height := 0.0
	var count := 0
	for local_y in range(bounds.size.y):
		for local_x in range(bounds.size.x):
			sum_height += map_data.get_surface_height_at_grid(bounds.position + Vector2i(local_x, local_y))
			count += 1
	var avg_height := sum_height / float(count) if count > 0 else 0.0

	var vertices := PackedVector3Array([
		Vector3(0.0, avg_height, 0.0),
		Vector3(cell_w, avg_height, 0.0),
		Vector3(0.0, avg_height, cell_h),
		Vector3(cell_w, avg_height, cell_h),
	])
	var normals := PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP, Vector3.UP])
	# 颜色基于区域类型取平均色调
	var dominant_zone := MapTileTypes.Zone.NEUTRAL
	for local_y in range(bounds.size.y):
		for local_x in range(bounds.size.x):
			var zone_type := map_data.get_zone_type_at(bounds.position + Vector2i(local_x, local_y))
			if zone_type != MapTileTypes.Zone.NEUTRAL:
				dominant_zone = zone_type
				break
	var base_color := PLAIN_COLOR
	match dominant_zone:
		MapTileTypes.Zone.FOREST:
			base_color = Color("3f6042")
		MapTileTypes.Zone.MOUNTAIN:
			base_color = MOUNTAIN_GROUND_COLOR
		MapTileTypes.Zone.WETLAND:
			base_color = Color("557562")
		MapTileTypes.Zone.CENTRAL:
			base_color = Color("877650")
	var colors := PackedColorArray([base_color, base_color, base_color, base_color])
	var indices := PackedInt32Array([0, 2, 1, 1, 2, 3])
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	var instance := MeshInstance3D.new()
	instance.name = "LOD2Proxy"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	# LOD2 也有迷雾叠加
	_build_fog_overlay(bounds)
