class_name MapChunk
extends Node3D

const PLAIN_COLOR := Color("6f7750")
const MOUNTAIN_GROUND_COLOR := Color("756044")
const RIVER_COLOR := Color("3f7777")
const ROAD_COLOR := Color("aa8755")
const BRIDGE_COLOR := Color("8b6741")
const MOUNTAIN_COLOR := Color("65523d")
const GRASS_MATERIAL_PATH := "res://map/materials/grass_ground_material.tres"
const RIVER_MATERIAL_PATH := "res://map/materials/river_water_material.tres"
const FEATURE_MODEL_SCENE := preload(
	"res://map/assets/model_scenes/map_feature_model.tscn"
)
const PINE_MODEL_PATH := "res://map/assets/models/rts_ancient_pine_hy3d31.glb"
const FEATURE_FILL_RATIO := 0.9
const TREE_FOOTPRINT_SIZE := Vector2i(3, 3)
# 山体规格同时约束模型尺寸和被替换的占位格，避免正式模型只遮住单个尖锥。
const MOUNTAIN_MODEL_SPECS: Array[Dictionary] = [
	{
		"path": "res://map/assets/models/rts_mountain_sharp_peak_hy3d31.glb",
		"footprint": Vector2i(3, 3),
	},
	{
		"path": "res://map/assets/models/rts_mountain_long_ridge_hy3d31.glb",
		"footprint": Vector2i(5, 3),
	},
	{
		"path": "res://map/assets/models/rts_mountain_rounded_cluster_hy3d31.glb",
		"footprint": Vector2i(5, 5),
	},
]
const MOUNTAIN_FEATURE_CHUNK_MODULO := 1
const TREE_FEATURE_CHUNK_MODULO := 4

static var _grass_material_cache: Material
static var _river_material_cache: Material

var chunk_coordinate := Vector2i.ZERO
var map_data: DemoMapData
var _feature_root: Node3D


func configure(p_map_data: DemoMapData, p_chunk_coordinate: Vector2i) -> void:
	map_data = p_map_data
	chunk_coordinate = p_chunk_coordinate
	name = "Chunk_%d_%d" % [chunk_coordinate.x, chunk_coordinate.y]
	_clear_visuals()
	_build_visuals()


func _clear_visuals() -> void:
	for child in get_children():
		child.free()


func _build_visuals() -> void:
	if map_data == null:
		return
	_feature_root = Node3D.new()
	_feature_root.name = "FeatureModels"
	add_child(_feature_root)
	var plain_transforms: Array[Transform3D] = []
	var mountain_ground_transforms: Array[Transform3D] = []
	var river_transforms: Array[Transform3D] = []
	var road_transforms: Array[Transform3D] = []
	var bridge_transforms: Array[Transform3D] = []
	var mountain_transforms: Array[Transform3D] = []
	var mountain_tiles: Array[MapTileData] = []
	var tree_candidates: Array[MapTileData] = []
	var bounds := map_data.get_chunk_grid_bounds(chunk_coordinate)

	for grid_y in range(bounds.position.y, bounds.end.y):
		for grid_x in range(bounds.position.x, bounds.end.x):
			var tile := map_data.get_tile(Vector2i(grid_x, grid_y))
			if tile == null:
				continue
			var world_position := map_data.grid_to_world(tile.grid_position, tile.height)
			var ground_transform := Transform3D(Basis.IDENTITY, world_position)
			match tile.terrain_type:
				MapTileTypes.Terrain.MOUNTAIN:
					mountain_ground_transforms.append(ground_transform)
					mountain_tiles.append(tile)
				MapTileTypes.Terrain.RIVER:
					river_transforms.append(ground_transform)
				_:
					plain_transforms.append(ground_transform)
					if not tile.has_road and map_data.get_city_at_grid(tile.grid_position) == null:
						tree_candidates.append(tile)
			if tile.has_road:
				var road_position := map_data.grid_to_world(tile.grid_position, tile.height + 0.035)
				if tile.terrain_type == MapTileTypes.Terrain.RIVER:
					bridge_transforms.append(Transform3D(Basis.IDENTITY, road_position))
				else:
					road_transforms.append(Transform3D(Basis.IDENTITY, road_position))

	var mountain_model_occupied: Dictionary = {}
	var mountain_placement := _find_mountain_feature_placement(mountain_tiles)
	var uses_mountain_model := not mountain_placement.is_empty()
	if uses_mountain_model:
		uses_mountain_model = _add_mountain_feature(mountain_placement)
		if uses_mountain_model:
			_mark_footprint_occupied(
				mountain_placement.get("grid_position", Vector2i.ZERO),
				mountain_placement.get("world_footprint", Vector2i.ONE),
				mountain_model_occupied
			)
	for mountain_tile in mountain_tiles:
		if mountain_model_occupied.has(mountain_tile.grid_position):
			continue
		mountain_transforms.append(_create_mountain_placeholder_transform(mountain_tile))
	if not uses_mountain_model:
		var selected_tree := _select_tree_feature_tile(tree_candidates)
		if selected_tree != null:
			_add_tree_feature(selected_tree)

	_add_plane_multimesh("PlainGround", plain_transforms, _get_grass_material(), 1.01)
	_add_plane_multimesh(
		"MountainGround",
		mountain_ground_transforms,
		_create_unshaded_material(MOUNTAIN_GROUND_COLOR),
		1.01
	)
	_add_plane_multimesh("RiverGround", river_transforms, _get_river_material(), 1.02)
	_add_plane_multimesh(
		"Roads",
		road_transforms,
		_create_unshaded_material(ROAD_COLOR),
		0.62
	)
	_add_plane_multimesh(
		"Bridges",
		bridge_transforms,
		_create_unshaded_material(BRIDGE_COLOR),
		0.82
	)
	_add_mountain_multimesh(mountain_transforms)


func _select_tree_feature_tile(candidates: Array[MapTileData]) -> MapTileData:
	if (
		candidates.is_empty()
		or _positive_modulo(_chunk_hash(83), TREE_FEATURE_CHUNK_MODULO) != 0
	):
		return null
	var eligible: Array[MapTileData] = []
	for tile in candidates:
		if not _is_feature_site_valid(
			tile.grid_position,
			TREE_FOOTPRINT_SIZE,
			MapTileTypes.Terrain.PLAIN
		):
			continue
		eligible.append(tile)
	if eligible.is_empty():
		return null
	var selected_index := _positive_modulo(_chunk_hash(102), eligible.size())
	return eligible[selected_index]


func _find_mountain_feature_placement(
	mountain_tiles: Array[MapTileData]
) -> Dictionary:
	if (
		mountain_tiles.is_empty()
		or _positive_modulo(_chunk_hash(37), MOUNTAIN_FEATURE_CHUNK_MODULO) != 0
	):
		return {}
	# 山脉走向与 Chunk 坐标相关，改用不同质数的线性散列，避免整条山脉重复同一模型。
	var start_variant := _positive_modulo(
		chunk_coordinate.x * 17 + chunk_coordinate.y * 31 + map_data.seed,
		MOUNTAIN_MODEL_SPECS.size()
	)
	for variant_offset in range(MOUNTAIN_MODEL_SPECS.size()):
		var variant_index := (start_variant + variant_offset) % MOUNTAIN_MODEL_SPECS.size()
		var spec := MOUNTAIN_MODEL_SPECS[variant_index]
		var preferred_footprint := spec.get("footprint", Vector2i(3, 3)) as Vector2i
		var footprint_options: Array[Vector2i] = [preferred_footprint]
		if preferred_footprint != Vector2i(3, 3):
			# 窄山脊无法容纳优选规格时仍使用同一正式模型，但降级到标准 3×3 模型槽。
			footprint_options.append(Vector2i(3, 3))
		for base_footprint in footprint_options:
			var rotation_options := 2 if base_footprint.x != base_footprint.y else 1
			var start_rotation := _positive_modulo(
				_chunk_hash(149 + variant_index),
				rotation_options
			)
			for rotation_offset in range(rotation_options):
				var rotation_quarters := (start_rotation + rotation_offset) % rotation_options
				var world_footprint := base_footprint
				if rotation_quarters % 2 == 1:
					world_footprint = Vector2i(base_footprint.y, base_footprint.x)
				var eligible: Array[MapTileData] = []
				for tile in mountain_tiles:
					if _is_feature_site_valid(
						tile.grid_position,
						world_footprint,
						MapTileTypes.Terrain.MOUNTAIN
					):
						eligible.append(tile)
				if eligible.is_empty():
					continue
				var selected_index := _positive_modulo(
					_chunk_hash(167 + variant_index * 11 + rotation_quarters),
					eligible.size()
				)
				return {
					"grid_position": eligible[selected_index].grid_position,
					"spec": spec,
					"model_footprint": base_footprint,
					"variant_index": variant_index,
					"rotation_quarters": rotation_quarters,
					"world_footprint": world_footprint,
				}
	return {}


func _add_mountain_feature(placement: Dictionary) -> bool:
	var grid_position := placement.get("grid_position", Vector2i.ZERO) as Vector2i
	var tile := map_data.get_tile(grid_position)
	var spec := placement.get("spec", {}) as Dictionary
	var base_footprint := placement.get("model_footprint", Vector2i(3, 3)) as Vector2i
	var model_path := str(spec.get("path", ""))
	var variant_index := int(placement.get("variant_index", 0))
	var rotation_quarters := int(placement.get("rotation_quarters", 0))
	if tile == null or model_path.is_empty():
		return false
	return _add_feature_model(
		tile,
		model_path,
		Vector2(base_footprint) * map_data.cell_size * FEATURE_FILL_RATIO,
		"HighDetailMountain_%d" % variant_index,
		rotation_quarters,
		placement.get("world_footprint", base_footprint)
	)


func _add_tree_feature(tile: MapTileData) -> bool:
	return _add_feature_model(
		tile,
		PINE_MODEL_PATH,
		Vector2(TREE_FOOTPRINT_SIZE) * map_data.cell_size * FEATURE_FILL_RATIO,
		"HighDetailPine",
		_positive_modulo(_chunk_hash(241), 4),
		TREE_FOOTPRINT_SIZE
	)


func _add_feature_model(
	tile: MapTileData,
	model_path: String,
	target_footprint_world_size: Vector2,
	node_name: String,
	rotation_quarters: int,
	grid_footprint_size: Vector2i
) -> bool:
	var feature := FEATURE_MODEL_SCENE.instantiate() as MapFeatureModel
	if feature == null:
		return false
	if not feature.configure_to_footprint(model_path, target_footprint_world_size):
		feature.free()
		return false
	feature.name = node_name
	feature.position = map_data.grid_to_world(tile.grid_position, tile.height)
	feature.rotation.y = float(rotation_quarters) * PI * 0.5
	feature.set_meta("grid_position", tile.grid_position)
	feature.set_meta("grid_footprint_size", grid_footprint_size)
	feature.set_meta("source_model_path", model_path)
	if _feature_root == null:
		feature.free()
		return false
	_feature_root.add_child(feature)
	return true


func _is_feature_site_valid(
	center: Vector2i,
	footprint_size: Vector2i,
	required_terrain: int
) -> bool:
	var footprint_rect := _get_footprint_rect(center, footprint_size)
	var chunk_bounds := map_data.get_chunk_grid_bounds(chunk_coordinate)
	if (
		footprint_rect.position.x < chunk_bounds.position.x
		or footprint_rect.position.y < chunk_bounds.position.y
		or footprint_rect.end.x > chunk_bounds.end.x
		or footprint_rect.end.y > chunk_bounds.end.y
	):
		return false
	for grid_y in range(footprint_rect.position.y, footprint_rect.end.y):
		for grid_x in range(footprint_rect.position.x, footprint_rect.end.x):
			var tile := map_data.get_tile(Vector2i(grid_x, grid_y))
			if (
				tile == null
				or tile.terrain_type != required_terrain
				or tile.has_road
				or map_data.get_city_at_grid(tile.grid_position) != null
			):
				return false
	return true


func _get_footprint_rect(center: Vector2i, footprint_size: Vector2i) -> Rect2i:
	var half_size := Vector2i(
		floori(float(footprint_size.x) * 0.5),
		floori(float(footprint_size.y) * 0.5)
	)
	return Rect2i(center - half_size, footprint_size)


func _mark_footprint_occupied(
	center: Vector2i,
	footprint_size: Vector2i,
	occupied: Dictionary
) -> void:
	var footprint_rect := _get_footprint_rect(center, footprint_size)
	for grid_y in range(footprint_rect.position.y, footprint_rect.end.y):
		for grid_x in range(footprint_rect.position.x, footprint_rect.end.x):
			occupied[Vector2i(grid_x, grid_y)] = true


func _create_mountain_placeholder_transform(tile: MapTileData) -> Transform3D:
	var horizontal_neighbors := (
		_count_mountain_neighbor(tile.grid_position + Vector2i.LEFT)
		+ _count_mountain_neighbor(tile.grid_position + Vector2i.RIGHT)
	)
	var vertical_neighbors := (
		_count_mountain_neighbor(tile.grid_position + Vector2i.UP)
		+ _count_mountain_neighbor(tile.grid_position + Vector2i.DOWN)
	)
	var width_scale := 0.82 + float(horizontal_neighbors) * 0.12
	var depth_scale := 0.82 + float(vertical_neighbors) * 0.12
	var height_scale := 0.72 + tile.height * 0.4
	return Transform3D(
		Basis.IDENTITY.scaled(Vector3(width_scale, height_scale, depth_scale)),
		map_data.grid_to_world(tile.grid_position, tile.height + 0.56)
	)


func _count_mountain_neighbor(grid_position: Vector2i) -> int:
	var neighbor := map_data.get_tile(grid_position)
	return (
		1
		if neighbor != null and neighbor.terrain_type == MapTileTypes.Terrain.MOUNTAIN
		else 0
	)


func _chunk_hash(salt: int) -> int:
	return (
		chunk_coordinate.x * 73856093
		^ chunk_coordinate.y * 19349663
		^ map_data.seed
		^ salt * 83492791
	)


func _positive_modulo(value: int, divisor: int) -> int:
	return ((value % divisor) + divisor) % divisor


func _add_plane_multimesh(
	node_name: String,
	transforms: Array[Transform3D],
	material: Material,
	scale_ratio: float
) -> void:
	if transforms.is_empty():
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * map_data.cell_size * scale_ratio
	plane.material = material
	_add_multimesh_instance(node_name, plane, transforms)


func _add_mountain_multimesh(transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var mountain_mesh := CylinderMesh.new()
	mountain_mesh.top_radius = map_data.cell_size * 0.42
	mountain_mesh.bottom_radius = map_data.cell_size * 0.62
	mountain_mesh.height = 1.4
	mountain_mesh.radial_segments = 8
	mountain_mesh.rings = 1
	mountain_mesh.material = _create_unshaded_material(MOUNTAIN_COLOR)
	_add_multimesh_instance("MountainPlaceholders", mountain_mesh, transforms)


func _add_multimesh_instance(
	node_name: String,
	mesh: Mesh,
	transforms: Array[Transform3D]
) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = transforms.size()
	multimesh.mesh = mesh
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


func _get_grass_material() -> Material:
	if _grass_material_cache == null:
		_grass_material_cache = _load_optional_material(
			GRASS_MATERIAL_PATH,
			PLAIN_COLOR,
			"草地纹理材质"
		)
	return _grass_material_cache


func _get_river_material() -> Material:
	if _river_material_cache == null:
		_river_material_cache = _load_optional_material(
			RIVER_MATERIAL_PATH,
			RIVER_COLOR,
			"河流水面材质"
		)
	return _river_material_cache


func _load_optional_material(
	resource_path: String,
	fallback_color: Color,
	display_name: String
) -> Material:
	if ResourceLoader.exists(resource_path, "Material"):
		var resource := load(resource_path)
		if resource is Material:
			return resource as Material
	push_warning("%s不可用，回退到纯色占位材质：%s" % [display_name, resource_path])
	return _create_unshaded_material(fallback_color)


func _create_unshaded_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
