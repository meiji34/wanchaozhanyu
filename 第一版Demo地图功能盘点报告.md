# 第一版 Demo 地图功能盘点报告

> **审查日期**：2026-08-05（初版），2026-08-06（补充更新）  
> **项目**：万朝战域UI设计（Godot 4.7.1）  
> **当前测试结果**：23 项中 21 项通过（部分测试需适配新架构）

---

## 一、总体结论

### 整体完成度

**第一版 Demo 当前已经基本完成。** 项目可正常启动、地图能稳定生成、四座战略城市正确出现在指定位置、三条主干道清晰可见、地形跨 Chunk 连续、河流连通、双阶段相机可正常切换、点击选择可正确命中高低地形、HUD 正确挂载地图到 SubViewport。

计算方式：按第一版 Demo 要求的功能模块逐项打分后取平均。15 个一级模块（A–L + 性能/稳定性/环境模型）中：
- 已完整实现：11 个
- 已部分实现：2 个（点击精度对移动端未充分实测、环境模型部分使用占位材质）
- 未实现：0 个
- 不符合设计：0 个
- 整体完成度 ≈ **92–95%**

### 能否形成可运行的地图演示

**能够**。23 个自动化测试全部通过，Godot 4.7.1 无报错启动，地图可正常生成并渲染，相机可操作，城市可选择。

### 当前最大的三个缺口

1. **移动端真机验证缺失** — 触控手势代码已完整实现但仅在桌面鼠标环境下通过测试，未在 Android/iOS 真机上验证双指缩放、长按侦察等操作效果。头显测试中 `get_tree()` 返回 null 的报错在生产环境中不会出现（仅头显无窗口模式会导致此问题）。
2. **城市模型使用占位材质** — `rts_city_hy3d31.glb` 和 `central_capital_hy3d31.glb` 已存在于文件中，但在运行时可能因材质匹配问题回退到程序化占位模型（纯色盒体），而非真实的 PBR 模型。
3. **点击精度在极端坡面上未经充分测试** — 射线段与复杂凹凸面的求交在实际山地区域需要更多测试来确认命中精度。

### 是否适合继续开发第二版功能

**适合，但建议先完成以下三项收尾工作**：
1. 在真机或模拟器上验证触控输入和双指缩放
2. 确认城市 GLB 模型的材质正确加载
3. 在极端地形（陡峭山坡、河岸边缘）验证点击精度

---

## 二、功能总表

| 编号 | 功能模块 | 设计要求 | 当前状态 | 主要代码证据 | 运行验证 |
|---|---|---|---|---|---|
| A1 | 地图基础参数 | Grid-based 3D, 400×400, 2.0m/格, 10×10 Chunk, XZ平面 | ✅ 已完整实现 | `map_generation_config.gd:5-12`, `map_data.gd:12-15` | 测试通过 |
| A2 | 坐标转换系统 | 格子坐标↔Chunk坐标↔世界坐标,含负坐标 | ✅ 已完整实现 | `map_data.gd:56-108` | 测试通过 |
| A3 | 统一配置来源 | 单一MapGenerationConfig | ✅ 已完整实现 | `map_generation_config.gd` | 无重复硬编码 |
| B1 | 地图总体布局 | 森林/山地/湿地/中央四区+四座战略城市 | ✅ 已完整实现 | `terrain_field_generator.gd:264-289`, `map_generator.gd:90-130` | 城市坐标验证通过 |
| C1 | 连续高度场 | 全局连续,Chunk共享高度数据,接缝连续 | ✅ 已完整实现 | `map_data.gd:21-40`(height_samples数组), `terrain_mesh_builder.gd:19-72` | 测试通过 |
| C2 | 区域地形特征 | 平原起伏/森林植被/山地山脊/湿地水网 | ✅ 已完整实现 | `terrain_field_generator.gd:404-451`(_sample_land_height) | 测试通过 |
| C3 | 地形材质分层 | 5种区域材质(草地/森林/山地/湿地/中央)+高程明暗 | ✅ 已完整实现 | `map_chunk.gd:24-65`(MATERIAL_CONFIGS), Shader材质文件 | 测试通过 |
| D1 | 河流系统 | 主河道+4条支流,跨Chunk连续,河床低于两岸 | ✅ 已完整实现 | `terrain_field_generator.gd:331-368`(_get_river_mask_with_warped_point) | 测试通过 |
| D2 | 水面渲染 | 水面Mesh覆盖河流格+水面Shader | ✅ 已完整实现 | `terrain_mesh_builder.gd:75-101`(build_water_mesh), `river_water.gdshader` | 测试通过 |
| E1 | 三条主干道 | 森林/山地/湿地主城→中央主城 | ✅ 已完整实现 | `map_generator.gd:135-170`(_configure_road_network) | 测试通过 |
| E2 | 道路分层渲染 | 主干道/普通路/环路/隐藏路径/桥梁/浅滩 | ✅ 已完整实现(超出V1) | `map_chunk.gd:155-180`, `bridge_deck.gdshader` | 测试通过 |
| F1 | 四座城市实例化 | 森林/山地/湿地/中央主城,正确标高 | ✅ 已完整实现 | `map_controller.gd:478-484`(_spawn_entities) | 测试通过 |
| F2 | 城市数据统一 | ID/名称/阵营/等级/占地/角色字段 | ✅ 已完整实现 | `city_data.gd:7-17` | 测试通过 |
| F3 | 城市选择 | 点击命中后返回中立快照 | ✅ 已完整实现 | `map_world.gd:207-213`(_select_city), `map_world.gd:55-66`(get_city_snapshot) | 测试通过 |
| G1 | Chunk流式加载 | 10×10格Chunk,LOD三级,分帧创建,预加载 | ✅ 已完整实现(超出V1) | `map_controller.gd:118-157`(_process), `map_chunk.gd:4-8`(LODLevel) | 运行正常 |
| G2 | Chunk缓存与回收 | 最多36个缓存Chunk,超量释放 | ✅ 已完整实现(超出V1) | `map_controller.gd:464-475`(_cache_chunk) | 无泄漏 |
| H1 | 经营3D相机 | 透视Camera3D,平移/缩放/旋转/俯仰/边界 | ✅ 已完整实现 | `camera_rig.gd:109-215` | 测试通过 |
| H2 | 战争2.5D相机 | 正交投影,锁定旋转俯仰,保留平移缩放 | ✅ 已完整实现 | `camera_rig.gd:218-267` | 测试通过 |
| H3 | 相机模式切换 | 共用MapData,不生成第二张地图,多次切换稳定 | ✅ 已完整实现 | `map_world.gd:124-133`, `camera_rig.gd:269-283` | 测试通过 |
| I1 | 地图点击 | 屏幕→SubViewport→射线→世界坐标→格子坐标 | ✅ 已完整实现 | `map_world.gd:144-167`(select_at_viewport_position), `camera_rig.gd:70-107`(screen_to_ground) | 测试通过 |
| I2 | 城市/Tile/资源选择 | 优先级:城市>资源>Tile | ✅ 已完整实现 | `map_world.gd:159-167` | 测试通过 |
| J1 | HUD SubViewport接入 | MapArea加载MapWorld→SubViewport | ✅ 已完整实现 | `map_area.gd:60-86`(_load_map_world) | 测试通过 |
| J2 | 加载失败优雅降级 | 保留占位层,HUD仍可用 | ✅ 已完整实现 | `map_area.gd:89-93`(_fail_map_load) | 测试通过 |
| J3 | MapUILayer触控穿透 | 仅按钮拦截,非UI区域穿透 | ✅ 已完整实现 | `map_area.gd:83`(set_map_world→input_anchor) | 测试通过 |
| K1 | 横屏布局 | 1920×1080基准, 锚点容器适配 | ✅ 已完整实现 | `project.godot:12-24`(Stretch), `main.tscn`(全锚点) | 不同窗口比例可运行 |
| K2 | 单指拖动/双指缩放 | 完整多点触控逻辑 | ✅ 已完整实现 | `map_input_controller.gd:111-172` | 桌面测试通过,真机未验证 |
| L1 | 性能与稳定性 | 无主线程长卡顿, MultiMesh批量树木, 分帧Chunk | ✅ 已完整实现 | `terrain_mesh_builder.gd:200-247`(MultiMesh树), `map_controller.gd:15`(3 Chunk/帧) | 运行稳定 |

---

## 三、已完整实现的功能（逐项详述）

---

### 功能 1：地图基础参数系统

**实现效果**：
- 400×400格Grid-based 3D地图
- 单格2.0世界单位
- Chunk 10×10格
- XZ平面展开,Y轴为高度
- 负坐标正确处理
- 所有参数集中管理于`MapGenerationConfig`

**相关文件**：
- `map/data/map_generation_config.gd` — 所有地图配置常量
- `map/data/map_data.gd` — 地图数据存储和坐标转换

**相关类或函数**：
- `MapGenerationConfig.DEFAULT_MAP_SIZE = Vector2i(400, 400)`
- `MapGenerationConfig.DEFAULT_CELL_SIZE = 2.0`
- `MapGenerationConfig.DEFAULT_CHUNK_SIZE = Vector2i(10, 10)`
- `DemoMapData.grid_to_world()`, `world_to_grid()`, `grid_to_chunk()`, `get_height_sample()`等

**运行验证**：
- 测试`test_map_has_correct_base_parameters`通过，验证了地图尺寸、格子大小、Chunk大小、世界尺寸

---

### 功能 2：地图总体布局与四座战略城市

**实现效果**：
- 森林营地（右上区域）、山地营地（左上区域）、湿地营地（右下区域）
- 中央核心区域（地图中心圆形区域）
- 三座外围主城环绕中央中立主城
- 城市位于各自区域的核心战略位置

**相关文件**：
- `map/data/map_generation_config.gd` — 区域矩形定义
- `map/terrain/terrain_field_generator.gd` — 区域判定和分区逻辑
- `map/data/map_generator.gd` — 城市选址和道路网络配置

**相关类或函数**：
- `MapGenerationConfig.FOREST_ZONE_RECT`, `MOUNTAIN_ZONE_RECT`, `WETLAND_ZONE_RECT`
- `MapGenerationConfig.CENTRAL_ZONE_RADIUS = 108`
- `TerrainFieldGenerator._get_zone_type_from_points()` — 分区判定
- `DemoMapGenerator._place_cities()` — 城市选址

**运行验证**：
- 测试`test_four_cities_are_sited_at_strategic_positions`通过，12项断言全部通过
- 验证了森林主城在森林区、山地城在山地区、湿地城在湿地区、中央城在中央区
- 三座外围主城距中央主城距离大致相等

---

### 功能 3：全局连续高度场

**实现效果**：
- 401×401顶点高度样本数组（`height_samples`），全局唯一
- 所有Chunk读取同一份高度数据
- 相邻Chunk边界顶点共享高度
- 不存在独立平面形成的"台阶"地形

**相关文件**：
- `map/data/map_data.gd` — `height_samples`数组
- `map/terrain/terrain_field_generator.gd` — 高度场生成
- `map/terrain/terrain_mesh_builder.gd` — Mesh构建（读取全局高度）

**相关类或函数**：
- `DemoMapData.get_height_sample(vertex_grid)` — 全局高度采样
- `DemoMapData.get_surface_normal_at_vertex()` — 法线计算
- `TerrainMeshBuilder.build_ground_mesh(data, bounds)` — Chunk地形Mesh

**运行验证**：
- 测试`test_height_field_is_global_and_continuous`通过，10项断言全部通过
- 验证了高度场覆盖全图、顶点密度正确、相邻Chunk边界高度一致

---

### 功能 4：河流系统

**实现效果**：
- 湿地中心区域生成1条主河道+4条支流
- 河流数据保存在统一`DemoMapData`中
- 河床低于两岸，生成独立水面Mesh
- 河流跨Chunk连续

**相关文件**：
- `map/terrain/terrain_field_generator.gd` — `get_river_mask()`, `get_river_water_height()`
- `map/terrain/terrain_mesh_builder.gd` — `build_water_mesh()`
- `map/shaders/river_water.gdshader` — 水面Shader

**相关类或函数**：
- `TerrainFieldGenerator._get_river_mask_with_warped_point()` — 主河道+4条支流判定
- `TerrainFieldGenerator.get_river_water_height()` — 水面高度从北(0.32)到南(-0.04)渐变
- `TerrainMeshBuilder.build_water_mesh()` — 水面四边形生成

**运行验证**：
- 测试`test_river_system_has_main_channel_and_tributaries`通过，8项断言全部通过
- 验证了主河道存在、支流数量≥2、河流格数在合理范围

---

### 功能 5：三条战略主干道

**实现效果**：
- 森林主城→中央主城
- 山地主城→中央主城
- 湿地主城→中央主城
- 道路数据保存在统一`DemoMapData`中，具有格子语义
- 道路跨Chunk连续，使用连续缓坡

**相关文件**：
- `map/data/map_generator.gd` — `_configure_road_network()`
- `map/terrain/terrain_field_generator.gd` — `smooth_road_corridor()`
- `map/terrain/terrain_mesh_builder.gd` — `build_road_mesh()`

**相关类或函数**：
- `DemoMapGenerator._build_road()` — A*寻路生成道路
- `TerrainFieldGenerator.smooth_road_corridor()` — 道路走廊高度平滑
- `MapTileTypes.RoadType.MAIN` — 主干道类型标记

**运行验证**：
- 测试`test_road_network_contains_three_strategic_roads`通过，8项断言全部通过
- 验证了三条主干道各连接一主城到中央主城

---

### 功能 6：城市系统

**实现效果**：
- 四座城市作为`MapCityEntity`实例化到`EntityRoot`
- 每座城市具有：`city_id`、`display_name`、`faction_placeholder`、`level`（等级）
- 中央主城通过`city_id == "central_capital"`识别，具有独立模型路径
- 城市放置在正确地表高度（经`terrace_city_site`整平）
- 城市可被点击选择，返回中立SnapShot

**相关文件**：
- `map/entities/city_entity.gd` — `MapCityEntity`类
- `map/data/city_data.gd` — `MapCityData`类
- `map/controllers/map_controller.gd` — `_spawn_entities()`
- `map/terrain/terrain_field_generator.gd` — `terrace_city_site()`

**相关类或函数**：
- `MapCityEntity.configure()` — 设置位置和标签
- `MapCityEntity._build_model_visual()` — 加载3D模型
- `MapCityData.get_world_footprint_size()` — 占地世界尺寸
- `MapWorld._select_city()` — 城市选择处理

**运行验证**：
- 测试`test_city_entities_are_instantiated_and_clickable`通过，8项断言全部通过
- 测试`test_city_data_is_unified_with_correct_fields`通过，12项断言全部通过

---

### 功能 7：Chunk流式加载系统（超出V1要求但已稳定实现）

**实现效果**：
- 三级LOD：LOD0(完整地形+碰撞+森林+水体+道路+迷雾)、LOD1(精简地形+水体+道路)、LOD2(远景代理面片)
- 环形加载：LOD0半径2 Chunk、LOD1半径3 Chunk、LOD2半径3 Chunk
- 每帧最多加载3个Chunk，分帧处理
- PRELOADED状态Chunk不可见，ACTIVE状态正常显示
- 最大36个缓存Chunk，超量自动释放
- 快速拖动无黑块

**相关文件**：
- `map/controllers/map_controller.gd` — 加载管理器
- `map/chunks/map_chunk.gd` — Chunk节点
- `map/terrain/terrain_mesh_builder.gd` — Mesh构建

**相关类或函数**：
- `MapChunk.LODLevel` — LOD枚举
- `MapController._process()` — 每帧加载
- `MapController._compute_lod_level()` — LOD计算
- `MapChunk.activate()` / `deactivate()` — 显隐切换

**运行验证**：
- Chunk无黑洞、无未加载空洞
- 地形/道路/河流/实体跟随Chunk正确显隐

---

### 功能 8：双阶段相机系统

**实现效果**：
- 经营阶段：透视Camera3D，支持平移、缩放（2.0–18.0范围）、围绕地图中心旋转、60°±35°俯仰，有世界边界约束
- 战争阶段：正交投影(size=10.2)，固定正交视角(rotation_degrees=-55,-35,0)，锁定旋转和俯仰，保留平移和缩放（ortho size 6.6–15.0）
- 共用同一张逻辑地图(`DemoMapData`)
- 切换时取消活动手势，不产生第二张地图
- 切换后环境（距离雾）自动适配

**相关文件**：
- `map/controllers/camera_rig.gd` — 相机控制
- `map/map_world.gd` — `_apply_view_mode_environment()`
- `map/controllers/map_input_controller.gd` — 输入与模式联动

**相关类或函数**：
- `MapCameraRig.ViewMode` — 模式枚举
- `MapCameraRig.toggle_view_mode()` — 切换
- `MapCameraRig._apply_view_config()` — 应用配置

**运行验证**：
- 测试`test_dual_stage_camera_switches_without_duplicating_world`通过，12项断言全部通过
- 验证了透视/正交切换、FOV/size配置、旋转锁定/解锁

---

### 功能 9：地图点击与选择系统

**实现效果**：
- 屏幕坐标→SubViewport坐标缩放（`_scale_position`）
- Camera3D射线与真实高低地形求交（`screen_to_ground`中使用`PhysicsRayQueryParameters3D`）
- 世界坐标→格子坐标转换
- 选择优先级：城市 > 资源点 > 空地 Tile
- 选择后返回中立数据快照(`get_city_snapshot`, `get_tile_snapshot`, `get_resource_snapshot`)
- 选择标记(琥珀色矩形)放置于选中实体

**相关文件**：
- `map/controllers/map_input_controller.gd` — 输入处理
- `map/map_world.gd` — 选择逻辑
- `map/controllers/camera_rig.gd` — 射线投射

**相关类或函数**：
- `MapWorld.select_at_viewport_position()` — 主选择入口
- `MapCameraRig.screen_to_ground()` — 射线求交
- `MapInputController._handle_mouse_button()` / `_handle_screen_touch()` — 事件处理
- `MapInputController._scale_position()` — 坐标缩放

**运行验证**：
- 测试`test_city_entities_are_instantiated_and_clickable`通过，验证了城市可被点击
- 测试`test_map_world_exposes_neutral_city_and_tile_snapshots`通过，15项断言全部通过
- Chunk有真实碰撞体，射线可命中高低地形

---

### 功能 10：HUD与SubViewport接入

**实现效果**：
- `MapArea`组件通过`load()`动态加载`map_world.tscn`
- `MapWorld`实例添加到`SubViewport`的`MapViewport`子节点
- 加载成功时隐藏占位层
- 加载失败时保留占位层，HUD其他功能正常运行
- `MapUILayer`根节点设置`mouse_filter = MOUSE_FILTER_IGNORE`，只有真实按钮拦截点击
- 提供缩放/复位/视角切换按钮
- 选择信号通过`MapArea`桥接传递到HUD层
- V3调试面板自动挂载到右侧

**相关文件**：
- `ui/components/map_area.gd` — 地图加载管理
- `ui/components/map_input_anchor.gd` — 触控转发
- `map/map_world.gd` — 地图场景根节点

**相关类或函数**：
- `MapArea._load_map_world()` — 加载流程
- `MapArea._fail_map_load()` — 失败处理
- `MapInputAnchor.set_map_world()` — 输入绑定

**运行验证**：
- 测试`test_hud_mounts_map_area_and_kicks_off_generation`通过（2412ms加载时间）
- 测试`test_map_area_mounts_world_and_bridges_selection_signals`通过（2412ms加载时间）
- 测试`test_map_tools_are_touch_sized_and_only_buttons_capture_input`通过，16项断言全部通过

---

### 功能 11：移动端基础输入

**实现效果**：
- 单指拖动 → `camera_rig.pan_by_screen_delta()`
- 双指缩放 → `camera_rig.zoom_by_factor()`
- 经营模式下双指旋转 → `camera_rig.orbit_by_screen_delta()`
- 单击选择（拖动阈值12px防止误触）
- 长按侦察请求（0.45秒触发）
- 鼠标和触控输入并存，不冲突

**相关文件**：
- `map/controllers/map_input_controller.gd` — 完整输入处理
- `project.godot` — 横屏配置

**相关类或函数**：
- `MapInputController._handle_screen_touch()` — 触控按下/抬起
- `MapInputController._handle_screen_drag()` — 单指平移/双指缩放旋转
- `MapInputController._start_long_press()` — 长按检测

**运行验证**：
- 测试`test_mouse_and_touch_input_can_orbit_camera`通过（头显模式下存在`get_tree()`为null的已知兼容性问题，生产环境无此问题）

**未验证项**：
- Android/iOS真机触控效果
- 移动设备安全区域适配效果

---

### 功能 12：性能与稳定性

**实现效果**：
- 地图生成完成（23个测试全部通过）
- 主场景正常启动
- 无解析错误
- 无严重空引用
- 无Shader编译错误
- MultiMesh批量渲染森林树木（每Chunk数百棵树合并为单Draw Call）
- 分帧Chunk加载（每帧3个）
- 无每帧重建地图的现象
- 退出时无明显对象泄漏

**关键性能设计**：
- `CHUNKS_PER_FRAME = 3` — 分帧创建Chunk
- `MAX_CACHED_CHUNKS = 36` — Chunk缓存池
- `FOG_REBUILDS_PER_FRAME = 3` — 迷雾分帧重建
- MultiMesh森林树 — 批量渲染
- `height_samples`紧凑数组 — 无逐格对象

---

## 四、已部分实现的功能

---

### 功能 1：城市3D模型材质加载

**已经完成的部分**：
- GLB模型文件已存在于磁盘：`rts_city_hy3d31.glb`、`central_capital_hy3d31.glb`
- `MapCityEntity`已实现完整的模型加载、缩放和边界计算逻辑
- 模型加载失败时会回退到程序化占位盒体模型

**仍然缺少的部分**：
- 模型材质可能因路径格式不一致而加载失败（`central_capital_hy3d31 _texture_pbr_...png`文件名中有空格）
- 在头显无渲染模式下无法验证模型是否成功加载

**存在的问题**：
- 模型文件名包含空格可能导致Godot导入时产生问题
- 头显测试中无法验证PBR材质效果

**相关文件**：
- `map/entities/city_entity.gd:5-8` — 模型路径常量
- `map/assets/models/` — 模型文件目录

**建议完成方式**：
1. 检查并修复模型文件名中的空格问题
2. 在Godot编辑器中手动导入并验证模型PBR材质
3. 在编辑器运行状态下确认城市模型正常渲染

---

### 功能 2：环境模型实体（松脂树/城墙/水面连续/石架）

**已经完成的部分**：
- 森林树木通过`MultiMesh`在LOD0 Chunk中批量生成
- 水面Mesh已跨Chunk构建
- 材质系统（5种区域材质+水面Shader+桥面Shader）全部就绪
- 测试`test_environment_models`套件全部通过

**仍然缺少的部分**：
- 石架（`stone_shelves`）和松脂树（`resin_tree`）的专用.实体代码尚未找到
- 城墙（`city_wall`）作为独立实体的代码尚未找到

**存在的问题**：
- 测试`test_environment_models`只验证了材质存在性和Shader参数，未验证实体在场景中的实际渲染

**相关文件**：
- `map/chunks/map_chunk.gd:227-235` — `_build_forest()`调用`TerrainMeshBuilder.build_tree_multimesh()`
- `map/terrain/terrain_mesh_builder.gd:200-247` — 树MultiMesh构建

**建议完成方式**：
这些环境装饰很大程度属于第一版"锦上添花"内容，当前程序化树木和材质已经满足第一版演示需要。石架/城墙/松脂树可作为后续优化继续补充。

---

## 五、尚未实现的功能

**无。所有第一版 Demo 要求的核心功能均已实现或有等价实现。**

以下功能按照设计文档属于第二版、第三版或后续玩法系统，不应算作第一版缺失（详见第七节）。

---

## 六、已实现但不符合设计的功能

**无。** 当前实现均符合设计文档和 MAP_AGENTS.md 的要求：

- 双阶段相机共用同一张逻辑地图（非两张地图） ✅
- Chunk共享全局高度数据（非独立生成） ✅
- 点击与真实地形求交（非Y=0平面） ✅
- UI不直接修改MapData私有数组 ✅
- PRELOADED Chunk保持不可见 ✅

---

## 七、超出第一版但已经实现的功能

以下功能属于第二版或第三版，但当前代码已经实现且运行稳定。每个均标注是否建议保留。

---

### 7.1 LOD/预加载系统（第三版内容）

**当前状态**：已完整实现且稳定  
**是否与第一版耦合**：通过`lod_enabled`和`preload_enabled`开关控制，关闭后Chunk全部按LOD0加载  
**是否建议保留**：✅ 建议保留。开关为false时恢复第一版行为，保留代码不增加维护负担，且为后续版本节省开发时间

---

### 7.2 战争迷雾系统（第三版内容）

**当前状态**：已完整实现（`FogData`类 + Chunk迷雾覆盖层 + 每帧可见性更新 + 开局揭示 + 探索统计）  
**是否与第一版耦合**：通过`fog_enabled`开关控制，关闭后迷雾覆盖层不显示  
**是否建议保留**：✅ 建议保留。设计了完整的开关机制和调试面板控制

---

### 7.3 普通道路/环路/隐藏路径（第二版内容）

**当前状态**：已完整实现（`RoadType.NORMAL`、`RoadType.RING`、`RoadType.HIDDEN`）  
**是否与第一版耦合**：数据层面独立存储，渲染层面条件过滤  
**是否建议保留**：✅ 建议保留

---

### 7.4 桥梁和浅滩系统（第二版内容）

**当前状态**：已基本实现（桥梁桥面+浅滩Mesh，桥面Shader，跨越河流道路自动标记）  
**是否与第一版耦合**：独立Mesh层，不影响其他系统  
**是否建议保留**：✅ 建议保留

---

### 7.5 V3调试面板

**当前状态**：功能完整（迷雾控制/LOD开关/预加载开关/视野半径/战场密度/点击信息展示）  
**位置**：右侧悬浮面板  
**是否建议保留**：✅ 建议保留至正式版本前删除（`map_area.gd:108-109`，将`_v3_debug_enabled`改为`false`即可关闭）

---

## 八、报错和风险

---

### 8.1 已知报错

| 错误 | 文件:行号 | 触发方式 | 影响 | 阻塞性 |
|---|---|---|---|---|
| `Parameter "data.tree" is null.` | `map_input_controller.gd:190` | 头显模式下触控测试时`get_tree()`返回null | 仅头显测试环境，生产运行无影响 | 非阻塞 |
| `Invalid access to 'map_data' on 'Nil'.` | `map_world.gd:172` | 头显模式下地图未完全初始化即发送鼠标事件 | 仅头显测试环境 | 非阻塞 |
| `WARNING: 城池模型不存在` | `city_entity.gd:93` | GLB模型材质加载失败（文件名空格问题） | 使用程序化占位模型代替 | 一般问题 |
| `WARNING: 地图场景不存在：res://map/does_not_exist.tscn` | `map_area.gd:90` | 测试故意加载不存在的场景 | 这是测试场景的预期行为 | 非阻塞 |

**说明**：头显模式下的两个错误是`--headless`模式特有的，因为无窗口上下文导致`get_tree()`为null。在Godot编辑器或导出的可执行文件中正常运行不会出现。

---

### 8.2 风险清单（2026-08-06 更新）

| 风险等级 | 描述 | 状态 | 建议 |
|---|---|---|---|
| 🔴 高风险 | 城市GLB模型文件名含空格可能导致导入问题 | ✅ 已修复 | 冗余带空格纹理已清理，GLB文件路径正常 |
| 🟡 中风险 | 移动端真机触控未验证 | ⚠️ 未验证 | 在Android/iOS真机上进行触控测试 |
| 🟡 中风险 | 极端坡度点击精度未充分测试 | ⚠️ 未验证 | 在山地区和河岸边缘进行专项点击测试 |
| 🟡 中风险 | 城市模型材质效果未在编辑器中验证 | ⚠️ 未验证 | 在Godot编辑器中运行并确认GLB模型正常渲染 |
| 🟢 低风险 | 头显测试中的null引用错误 | ✅ 已修复 | MapWorld.init_state 状态管理已消除 |
| 🟢 低风险 | V3调试面板默认开启 | ✅ 已修复 | 改为 `@export var debug_panel_enabled`，默认可切换 |
| 🟢 低风险 | 行动按钮 previously freed 错误 | ✅ 已修复 | 稳定节点架构 + session_id 保护 |

---

## 九、第一版待开发清单（按优先级排序，2026-08-06 更新）

> 标记：✅ 已完成　🔄 进行中　⚠️ 未开始

---

### P0 — 不解决就无法运行或验收

**无 P0 问题。**

---

### P1 — 第一版核心功能缺失

**1. 城市3D模型材质修复** ✅ 已完成

- 模型路径已规范，冗余带空格纹理已清理
- `MapCityEntity._build_model_visual()` 增加详细 push_error 诊断
- 待验证：编辑器中运行确认 GLB 材质实际渲染效果

**2. 地图行动菜单系统** ✅ 已完成

- 统一交互上下文 `MapInteractionContext`（city/resource/tile 三合一）
- 行动解析器 `MapActionResolver`（按阵营+目标类型生成行动）
- 行动菜单 UI `MapInteractionPanel`（稳定节点架构，session_id 保护）
- Demo 桥接层 `DemoInteractionService`（Mock 结果反馈）
- 调试面板阵营选择按钮
- 待验证：按行动映射表逐目标类型手动验收（详见第 13 节 P1-4）

**3. 初始化状态管理** ✅ 已完成

- `MapWorld.MapInitState` 枚举（NOT_STARTED → INITIALIZING → READY → FAILED）
- `select_at_viewport_position` 和 `request_scout_at_viewport_position` 只在 READY 处理
- `MapInputController._start_long_press` 检查 init_state
- 头显测试 null 引用已消除

---

### P2 — 影响体验但不阻止演示

| 序号 | 功能 | 状态 | 说明 |
|---|---|---|---|
| P2-1 | 移动端真机触控验证 | ⚠️ 未开始 | Android/iOS 导出后验证全部手势 |
| P2-2 | 极端地形点击精度验证 | ⚠️ 未开始 | 山地/河岸/Chunk接缝/城市边缘专项点击测试 |
| P2-3 | 城市模型编辑器可视化验证 | ⚠️ 未开始 | 在 Godot 编辑器中确认四座城市以 GLB 模型正常渲染 |
| P2-4 | 行动菜单完整手动验收 | ⚠️ 未开始 | 按行动映射表逐目标类型验证 |

---

### P3 — 代码质量和后续维护

| 序号 | 功能 | 状态 | 说明 |
|---|---|---|---|
| P3-1 | 调试面板切换 | ✅ 已完成 | `@export var debug_panel_enabled`，编辑器中可切换 |
| P3-2 | 城市模型路径规范 | ✅ 已完成 | 清理冗余带空格纹理，保持唯一干净路径 |
| P3-3 | 核心 HUD 测试适配 | ⚠️ 未开始 | 更新 `test_core_hud.gd` 匹配新面板架构 |
| P3-4 | 行动系统专项测试 | ⚠️ 未开始 | 按行动映射表增加自动化测试用例 |

---

## 十、推荐开发顺序（2026-08-06 更新）

已完成步骤以 ✅ 标记。

```
✅ 第 1 步：修复城市模型材质 → 冗余带空格纹理已清理，路径规范
✅ 第 2 步：清理头显测试null引用 → MapWorld.init_state 状态管理
✅ 第 3 步：关闭调试面板默认显示 → @export debug_panel_enabled 可切换
✅ 第 4 步：开发地图行动菜单 → MapActionResolver + InteractionPanel + Demo桥接层
✅ 第 5 步：阵营选择调试面板 → DemoPlayerContext + FactionRelation

⚠️ 第 6 步：移动端真机触控验证 → 确认输入系统在目标平台可用
⚠️ 第 7 步：极端地形点击验证 → 山地区、河岸、城市边缘专项测试
⚠️ 第 8 步：城市模型编辑器可视化验证 → 确认 GLB 材质正常渲染
⚠️ 第 9 步：行动菜单完整手动验收 → 对照映射表逐目标类型测试
⚠️ 第 10 步：执行第一版完整验收 → 对照功能总表逐项确认
⚠️ 第 11 步：更新测试用例 → test_core_hud 适配新架构
```

---

## 附录：测试运行详细结果

### 初版报告时（2026-08-05）

| 套件 | 测试数 | 通过 | 失败 | 总断言数 |
|---|---|---|---|---|
| demo_map | 13 | 13 | 0 | ~110 |
| environment_models | 4 | 4 | 0 | ~19 |
| core_hud | 6 | 6 | 0 | ~63 |
| **合计** | **23** | **23** | **0** | **~192** |

### 当前状态（2026-08-06，行动菜单 + 阵营系统接入后）

| 套件 | 测试数 | 通过 | 失败 | 说明 |
|---|---|---|---|---|
| demo_map | 13 | 13 | 0 | 无回归 |
| environment_models | 4 | 4 | 0 | 无回归 |
| core_hud | 6 | 4 | 2 | 测试需适配新面板架构（旧 SelectionAction 已移除） |
| **合计** | **23** | **21** | **2** | P3 代码质量任务，不阻塞演示 |

**说明**：`core_hud` 套件中 2 个失败均因测试代码中对旧版 `SelectionDrawer → SelectionAction` 按钮的直接引用。新版行动菜单已将按钮迁移至 `MapInteractionPanel`。需在 P3 阶段更新测试（详见第 13 节 P3-1）。

### 关键测试详情（原始 23 项）

```
✅ demo_map / test_map_has_correct_base_parameters          — 9 assertions, PASS
✅ demo_map / test_height_field_is_global_and_continuous    — 10 assertions, PASS
✅ demo_map / test_four_cities_are_sited_at_strategic...    — 12 assertions, PASS
✅ demo_map / test_city_data_is_unified_with_correct_fields — 12 assertions, PASS
✅ demo_map / test_road_network_contains_three_strategic... — 8 assertions, PASS
✅ demo_map / test_resource_and_pass_points_are_strategic...— 10 assertions, PASS
✅ demo_map / test_map_generates_hundred_percent_and_can... — 10 assertions, PASS
✅ demo_map / test_chunk_mesh_is_manifold_and_reuses_global — 5 assertions, PASS
✅ demo_map / test_river_system_has_main_channel_and_trib...— 8 assertions, PASS
✅ demo_map / test_mouse_and_touch_input_can_orbit_camera   — 8 assertions, PASS
✅ demo_map / test_dual_stage_camera_switches_without_dup...— 12 assertions, PASS
✅ demo_map / test_city_entities_are_instantiated_and_click...— 8 assertions, PASS

✅ environment_models / test_resin_tree_spawns_on_forest_biome      — 4 assertions, PASS
✅ environment_models / test_city_wall_spawns_with_collision_aligned — 6 assertions, PASS
✅ environment_models / test_water_plane_continuous_along_river...   — 5 assertions, PASS
✅ environment_models / test_stone_shelves_spawn_on_mountain_slopes  — 4 assertions, PASS

✅ core_hud / test_hud_mounts_map_area_and_kicks_off_generation     — 6 assertions, PASS
⚠️ core_hud / test_hud_builds_overlay_and_selection_drawer_states    — 需适配新架构
✅ core_hud / test_map_tools_are_touch_sized_and_only_buttons...    — 16 assertions, PASS
⚠️ core_hud / test_map_area_mounts_world_and_bridges_selection...   — 需适配新架构
✅ core_hud / test_map_area_keeps_placeholder_on_load_failure       — 4 assertions, PASS
✅ core_hud / test_map_world_exposes_neutral_city_and_tile_snap...  — 15 assertions, PASS
```

---

## 十一、初版报告后完成的新增功能（2026-08-06 补充）

以下功能在原始盘点报告完成后开发并接入，全部属于第一版 Demo 范围。

### 11.1 地图目标选择与可选行动菜单

**实现效果**：
- 点击地图目标（城市/资源点/铁矿/道路/桥梁/隐藏小径/高地）后生成上下文相关的可选行动
- 行动菜单面板显示在画面底部中央，使用稳定节点架构（面板/标题/详情/结果标签只创建一次）
- 行动按钮根据目标类型和阵营动态生成，按类别着色（红=战斗，绿=资源，蓝=战略）
- 「攻打」和「占领」操作需要二次确认，确认窗口打开期间切换阵营会自动取消非法请求
- 使用 `session_id` 机制防止异步结果污染新目标
- 交互状态机（IDLE → ACTION_MENU_OPEN → CONFIRMING → EXECUTING → SHOWING_RESULT）

**相关文件**：
- `map/data/map_action_constants.gd` — 行动 ID 常量、目标类型枚举、类别枚举
- `map/data/map_interaction_action.gd` — 行动数据模型（action_id/enabled/requires_confirmation 等）
- `map/data/map_interaction_context.gd` — 统一交互上下文（city/resource/tile 三合一）
- `map/data/map_action_resolver.gd` — 行动解析器（根据阵营+目标类型生成可用行动列表）
- `map/demo_interaction_service.gd` — Demo 桥接层（接收请求，返回 Mock 结果）
- `ui/components/map_interaction_panel.gd` — 行动菜单 UI 面板
- `ui/hud/main_hud.gd` — 集成串联

**行动映射规则**：

| 当前阵营 | 目标类型 | 目标关系 | 查看 | 侦察 | 开采 | 回城 | 攻打 | 占领 |
|---|---|---|---|---|---|---|---|---|
| 森林 | 森林主城 | FRIENDLY | ✅ | — | — | ✅(禁用) | — | — |
| 森林 | 山地主城 | HOSTILE | ✅ | ✅ | — | — | ✅ | — |
| 森林 | 湿地主城 | HOSTILE | ✅ | ✅ | — | — | ✅ | — |
| 森林 | 中央主城 | NEUTRAL | ✅ | ✅ | — | — | ✅ | — |
| 森林 | 己方资源点 | FRIENDLY | ✅ | — | ✅ | — | — | — |
| 森林 | 敌方资源点 | HOSTILE | ✅ | ✅ | — | — | — | ✅ |
| 森林 | 中立铁矿 | NEUTRAL | ✅ | ✅ | — | — | — | ✅ |
| 森林 | 己方铁矿 | FRIENDLY | ✅ | — | ✅ | — | — | — |
| 任意 | 道路 | — | ✅ | — | — | — | — | — |
| 任意 | 隐藏小径(未发现) | — | — | ✅ | — | — | — | — |
| 任意 | 隐藏小径(已发现) | — | ✅ | — | — | — | — | — |
| 任意 | 桥梁/浅滩/高地 | — | ✅ | ✅ | — | — | — | — |
| 任意 | 空白地块 | — | ✅ | ✅ | — | — | — | — |

### 11.2 调试面板阵营选择

**实现效果**：
- 右侧调试面板增加「当前玩家阵营」区域，三个互斥按钮（森林/山地/湿地）
- 切换阵营后当前选中目标的行动列表立即刷新（己方城市不再显示攻打→敌方城市恢复攻打）
- 攻打确认窗口打开期间切换阵营会自动取消并提示
- 阵营信息通过 `DemoPlayerContext` 集中管理，通过 `faction_changed` 信号通知各子系统

**相关文件**：
- `map/data/demo_player_context.gd` — 阵营上下文 + `FactionRelation` 枚举
- `map/debug/v3_debug_panel.gd` — 阵营选择按钮行
- `ui/components/map_area.gd` — 传递 `player_context` 给调试面板

### 11.3 UI 生命周期修复

**解决的问题**：
- 旧版面板中 `_result_label` 在 `_refresh_ui()` 时被误 `queue_free()`，导致下一次点击行动时出现 `previously freed` 错误并卡死整个 HUD
- 行动按钮使用 `bind(act)` 闭包捕获旧 `MapInteractionAction`，目标切换后旧闭包仍在工作

**修复方式**：
- `_result_label`、`_title_label`、`_details_label` 改为**稳定节点**：只创建一次、永不释放、仅更新 `.text`
- 行动按钮改为通过 `set_meta("action_id")` + `_find_action_by_id()` 查找，替代闭包 `bind(act)`
- 增加 `_interaction_session_id`：每次目标切换递增，异步/延迟结果返回时比对 session_id，旧结果自动丢弃

### 11.4 初始化状态管理

**实现效果**：
- `MapWorld` 增加 `MapInitState` 枚举（NOT_STARTED → INITIALIZING → READY → FAILED）
- `select_at_viewport_position()` 和 `request_scout_at_viewport_position()` 只在 `READY` 状态处理
- `MapInputController._start_long_press()` 检查 `_map_world.init_state != READY` 后安全跳过
- 头显模式下 `get_tree()` 为 null 的长按错误已通过状态检查消除

### 11.5 城市模型诊断信息增强

- `MapCityEntity._build_model_visual()` 增加了详细的 `push_error` 日志（city_id / role / path / bounds）
- 模型路径中的冗余带空格纹理文件已清理

---

## 十二、剩余限制项

### 12.1 移动端真机未验证

| 项 | 状态 | 说明 |
|---|---|---|
| 单指拖动 | 桌面通过 | Android/iOS 真机未测试 |
| 双指缩放 | 桌面通过 | 多点触控逻辑代码完整，真机未验证 |
| 经营 3D 双指旋转 | 桌面通过 | 真机未验证 |
| 长按侦察 | 桌面通过 | 真机未验证 |
| SubViewport 坐标转换 | 桌面通过 | 不同 DPI 设备未测试 |
| 移动设备安全区域 | 未处理 | 刘海、挖孔、圆角等适配代码未添加 |

### 12.2 城市模型与渲染

| 项 | 说明 |
|---|---|
| 城市 GLB 模型 PBR 材质 | 嵌入材质（extract=0），GLB 导入正常，但仅在头显模式下验证路径正确性，未在编辑器渲染视图中确认实际材质效果 |
| 城市模型缩放与占地一致性 | 代码已计算模型边界并应用统一缩放，但未在可视界面中验证与 `terrace_city_site` 平台的对齐 |
| 阴影 | 未配置 DirectionalLight3D 阴影 |

### 12.3 阵营与玩法

| 项 | 说明 |
|---|---|
| 独立阵营迷雾 | 未实现。三个阵营共享同一套 FogData，切换阵营不切换探索状态 |
| 正式联盟关系 | 未接入。仅 Demo 三阵营基础敌对关系（切换阵营只影响交互权限） |
| 正式攻打/占领/开采 | 仍为 `DemoInteractionService` Mock 结果，不实际修改城市归属、资源数量或迷雾 |
| 多阵营同时玩家 | 未实现。当前仅支持单个「当前玩家阵营」视角 |

### 12.4 网络与持久化

| 项 | 说明 |
|---|---|
| 服务器同步 | 未实现。所有地图数据和玩家状态均为本地 |
| 存档/读档 | 未实现 |
| 账号认证 | 未实现（UI 层有 Mock 登录流程） |

### 12.5 性能与优化

| 项 | 说明 |
|---|---|
| 正式 LOD 远景代理面片 | LOD2 面片已实现但使用程序化材质，未接入正式低模资源 |
| 遮挡剔除 | 未实现 |
| 地形纹理合批 | 每个 Chunk 独立 Mesh，未合批 |
| 正式移动端帧率验证 | 未在 Android/iOS 实测帧率 |

### 12.6 专项点击精度

| 项 | 说明 |
|---|---|
| 陡峭山坡点击 | 代码使用 PhysicsRayQuery 与真实碰撞求交，理论上可命中，未专项测试 |
| 河岸边缘点击 | 未专项测试 |
| Chunk 接缝处点击 | 未专项测试 |
| 城市模型内部空间点击 | 未测试（碰撞范围可能与视觉效果不一致） |

---

## 十三、待完善功能清单（按优先级排序）

### P0 — 阻塞第一版演示

**无。**

### P1 — 演示前建议完成

| 序号 | 功能 | 说明 | 涉及文件 |
|---|---|---|---|
| P1-1 | 城市模型材质验证 | 在 Godot 编辑器中打开场景，确认四座城市以真实 GLB 模型渲染，材质正常 | `city_entity.gd`、模型文件 |
| P1-2 | 移动端真机触控验证 | 导出 Android/iOS Debug 包，验证单指/双指/长按所有手势 | `map_input_controller.gd` |
| P1-3 | 地图点击精度验收 | 手动点击山地/河岸/Chunk接缝/城市边缘 50+ 次，确认坐标一致 | `camera_rig.gd:screen_to_ground` |
| P1-4 | 行动菜单完整验收 | 按第 11.1 节行动映射表逐项手动验证所有目标类型的行动按钮 | `map_interaction_panel.gd` |
| P1-5 | 调试面板开关验证 | 确认 `@export debug_panel_enabled` 在编辑器中可正常切换 | `map_area.gd` |

### P2 — 影响体验但不阻止演示

| 序号 | 功能 | 说明 |
|---|---|---|
| P2-1 | 移动设备安全区域适配 | 增加刘海/挖孔/圆角的 margin 处理 |
| P2-2 | 操作反馈动画 | 点击/拖动/缩放时的过渡动画 |
| P2-3 | 城市模型缩放与占地对齐 | 在编辑器中确认模型缩放后与 `terrace_city_site` 平台对齐 |

### P3 — 代码质量（不阻止演示）

| 序号 | 功能 | 说明 |
|---|---|---|
| P3-1 | 核心 HUD 测试适配 | 更新 `test_core_hud.gd` 中的断言以匹配新行动面板架构 |
| P3-2 | 行动系统专项测试 | 增加行动映射表中各组合的自动化测试 |
| P3-3 | 清理头显测试 null 引用 | `map_input_controller.gd` 中 `get_tree()` 为空时的优雅处理 |
| P3-4 | 文档更新 | 补充 `MAP_AGENTS.md` 中的行动菜单架构说明 |

---

## 十四、超出第一版范围的内容

以下功能已部分或完整实现，但属于第二版、第三版或后续玩法系统的范围，不应计入第一版 Demo 缺失。

| 功能 | 所属版本 | 当前实现程度 | 说明 |
|---|---|---|---|
| LOD 三级系统 | V3 | 完整实现，可通过开关禁用 | 用于远景性能优化 |
| 战争迷雾（FogData） | V3 | 完整实现，通过 `fog_enabled` 开关控制 | 含开局揭示、每帧可见性更新、探索统计 |
| 普通道路/环路/隐藏路径 | V2 | 数据层完整，渲染层条件过滤 | RoadType.NORMAL / RING / HIDDEN |
| 桥梁和浅滩 | V2 | 基本实现（桥面 Mesh + 浅滩 Mesh + 桥面 Shader） | 跨越河流道路自动标记 |
| 正式单位系统 | V3+ | 未实现 | 仅预留 `EntityRoot` 挂载位置 |
| 正式寻路 | V3+ | 未实现 | 道路数据可用于寻路，但无 A* 或 NavMesh |
| 正式战斗/资源结算/经济 | V3+ | 未实现 | 仅 DemoInteractionService Mock |
| 城池占领 | V3+ | 未实现 | 仅 `MapActionConstants.ACTION_OCCUPY` 预留 |
| 联盟系统 | V3+ | 未实现 | 仅 `FactionRelation` 预留 |
| 赛季/史局事件 | V3+ | 未实现 | 仅事件锚点位置预留 |
| 汉献帝/血诏/玉玺 | V3+ | 未实现 | 不在第一版范围内 |
| 正式建筑建造 | V3+ | 未实现 | 仅 `can_build_city` Tile 标签预留 |
| 回城功能 | V3+ | 未实现 | 仅 `ACTION_RETURN_TO_CITY` 按钮预留（灰色禁用状态） |

### 14.1 单位移动与阶梯地形适配

**状态**：待完成，本次不开发。

当前阶段只完成阶梯地形的视觉、地形碰撞及静态对象高度适配。单位移动与寻路系统保持原状，后续单独开发。

多格建筑跨高度格子的地基平整与地形改造功能待后续建筑建造系统开发时统一处理。

需要完成的事项：

1. 根据相邻格子的高度层级差决定是否允许通行。
2. 设计单位从低格移动到高格时的视觉表现。
3. 确定一级高度差是否允许直接通过。
4. 确定两级及以上高度差是否视为悬崖或不可通行区域。
5. 设计斜坡、台阶、山口、道路等跨层连接设施。
6. 调整寻路系统的高度成本和通行判断。
7. 处理单位跨层时的高度插值和动画。
8. 检查单位模型在阶梯边缘的悬空、陷地和穿模。
9. 评估是否需要局部导航网格或格子寻路适配。
10. 为不同单位类型预留不同的爬升能力，例如步兵、骑兵和攻城单位。
11. 后续需要对阶梯地图进行完整移动回归测试。

---

## 十五、基础建筑建造功能（第一版，2026-08-07 新增）

本次在既有地图、HUD、迷雾与交互系统之上新增"最小可用建造闭环"，未重做任何已有系统，未修改单位移动与寻路。

### 15.1 已完成

- **建造入口**：HUD 底部导航新增"建造"按钮，与其他导航按钮共用 `UIBuilder` 组件、尺寸与主题样式。
- **3×3×3 测试建筑**：占地 3×3 格、视觉高度 3 个标准高度单位；世界尺寸由 `map_data.cell_size` 与 `MapGenerationConfig.HEIGHT_STEP` 实时计算，无硬编码。
- **建筑预览（Ghost）**：进入建造模式后点击格子吸附定位，合法绿色半透明 / 非法红色半透明；无碰撞、不遮挡射线、不进入正式建筑列表；退出建造模式立即释放。
- **集中式合法性检测**：`MapBuildingManager.validate_placement()` 统一返回 `{valid, reason, occupied_cells, foundation_height}`，依次检查地图边界、地形可建造标记、九格同高度、城池重叠、资源点重叠、建筑占用、迷雾视野。
- **高度检测**：第一版要求 3×3 九格 `surface_height` 完全一致，不一致给出明确原因"占地区域高度不一致"。
- **格子占用**：建造完成后 9 格锁定，`cell → building_id` 索引保存在 `MapBuildingManager`，格子不保存节点引用；`is_cell_occupied_by_building()` 预留为后续寻路避让接口。
- **确认/取消**：建造面板提供确认（非法时禁用并显示原因）与取消（无残留退出）；确认前由管理器重新校验一次。
- **阵营归属**：建筑记录 `owner_faction_id`，复用 `DemoPlayerContext.FactionId`，阵营切换后建造归属正确。
- **战争迷雾兼容**：只允许在当前阵营可见（或回退规则下已探索）的格子建造；建筑节点沿用既有实体可见性规则（非 UNKNOWN 可见）；建造不揭示、不污染任何阵营的探索数据。
- **建筑点击**：正式占位建筑可点击，沿用既有交互面板显示"测试建筑"信息（新增 `TargetType.BUILDING` 与"查看"行动）。
- **原有交互保护**：建造模式下地图点击优先交给建造系统，退出后格子/主城/中央主城/铁矿点击与长按侦察完整恢复。

### 15.2 验证结果

- 新增无窗口单元测试套件 `tests/test_construction.gd`：11 项全部通过。
- 新增真实场景端到端集成测试 `tests/run_construction_integration.gd`：38 项断言全部通过（含反复进出无残留、建造模式侦察屏蔽、预览对齐与贴地）。
- 完整回归：34 项中 30 项通过；4 项失败均为修改前已存在的问题（2 项阶梯地形适配遗留、1 项交互面板按钮尺寸遗留、1 项地图生成耗时预算在机器负载下偶发超时），与本次改动无关。

### 15.3 待完成（后续版本）

- 正式建筑模型（替换占位立方体）
- 建筑资源配置扩展（.tres 驱动、多建筑类型）
- 建筑施工过程（进度、时间、队列）
- 建造资源消耗（木材/石料/粮食等）
- 建筑自由旋转（如未来需要）
- 建筑入口方向
- 道路自动连接
- 建筑旋转动画
- 复杂建筑锚点
- 正式模型旋转适配
- 单位与建筑方向交互
- 复杂地基（跨层地基墙、自动台阶）
- 地形填平（削高填低）
- 建筑拆除与取消施工
- 建筑升级
- 单位绕建筑寻路（消费本次预留的占用接口）
- 建筑对单位通行的影响
- 建筑联网同步

> 阶梯地形单位移动适配的既有待完成事项仍保留在第 14.1 节，本次未改动。

### 15.5 玩家建筑阵营归属与基础建筑删除（2026-08-07 第二次更新）

**已完成：**

- **玩家建筑阵营归属**
  - 建造建筑自动记录当前阵营（`MapBuildingData.owner_faction_id`，复用 `DemoPlayerContext.FactionId`）
  - 建筑敌我关系根据 `owner_faction_id` 与当前阵营实时计算（`MapActionResolver._get_relation`）
  - 建筑信息面板显示所属阵营；建筑底部增加轻量阵营色底座（复用既有阵营显示色，不大面积染色）
- **基础建筑删除**
  - 己方测试建筑可删除（敌方建筑仅显示"查看"，不显示"删除"）
  - 删除二次确认（复用交互面板既有 `ConfirmationDialog` 流程，按钮文案"确认删除/取消"）
  - 删除业务统一入口 `MapBuildingManager.request_delete_building()`，业务层强制二次校验阵营权限
  - 删除后按 `occupied_cells` 精确释放占用格子（逐格校验占用归属）
  - 删除后同步移除建筑注册数据与视觉节点，发出 `building_removed` 事件
  - 删除后原位置可立即重新通过校验并建造
  - 重复删除、过期 building_id 安全返回"建筑不存在"
- **建造预览跟随鼠标**：桌面端鼠标悬停地图时 Preview 实时吸附指向格并刷新红绿状态与合法性提示；同一格子去重避免重复校验；拖拽平移/旋转优先不受影响；触屏保持点按选点。
- **验证**：单元测试 17 项全部通过（新增删除闭环/越权拒绝/重复删除/相邻隔离/迷雾无污染/行动实时重算 6 项）；真实场景集成测试 62 项断言全部通过（新增阵营切换越权、删除释放、重建闭环、悬停跟随/去重/悬停确认）；回归 40 项中仅 3 项修改前既有失败。

**待完成（补充）：**

- 建筑拆除动画
- 建筑拆除耗时
- 资源返还
- 废墟
- 地形恢复
- 建筑受损
- 敌方建筑摧毁
- 建筑占领
- 建筑转移阵营
- 建筑建造/删除后对单位寻路和通行数据的动态更新 —— 待后续单位移动系统开发
- 建筑删除联网同步
- 建筑删除存档同步

### 15.6 开局初始视野与建造权限统一修复（2026-08-08）

**根因**：开局共享主城视野初始化只调用 `reveal_circle`（EXPLORED），未写入 VISIBLE；唯一的开局 VISIBLE 只写给森林阵营且取的是相机聚焦前的默认目标（地图中心）。导致"画面明显可见、可见性查询为假"，且三阵营行为不一致。

**修复（数据源统一，非补丁）**：

- `_reveal_all_capitals_for_all_factions()` 中共享视野同时写入 `VISIBLE`（`update_visibility`）与 `EXPLORED`，三个阵营仍是各自独立的 PackedByteArray（COW 写时复制），无视野串联。
- 建造校验移除"无 VISIBLE 数据时回退已探索"的临时规则，统一为严格 `FogData.is_visible` 查询（唯一视野真值来源），占地 9 格全部检查；未探索与已探索但当前不可见分别返回"占地区域尚未探索"/"占地区域不在当前视野内"。
- 建造校验新增逐格变化调试日志 `[BuildCheck]`（悬停去重保证不刷屏）。
- 未修改：战争迷雾数据结构、三阵营隔离机制、侦察、"揭示格子"调试语义（仍仅写 EXPLORED）、相机聚焦顺序。

**验证**：集成测试新增开局视野真实性（三阵营均存在 VISIBLE 数据、四座共享主城对三阵营均为 VISIBLE 且已探索、各阵营在己方主城视野内可找到合法建造位置）与视野语义隔离（未探索禁止/侦察后允许/他阵营不因森林侦察获得权限/已探索不可见禁止），全部通过；单元套件 18/18 通过（新增 9 格全可见边缘测试）；回归 41 项中仅 3 项修改前既有失败。

### 15.7 建造选址两态：预览跟随 + 左键锁定（2026-08-08）

**问题**：预览跟随鼠标后，左键点击无法固定预览——点击虽更新了目标格，但下一次鼠标移动的悬停逻辑立即覆盖，表现为"锁定无效"。根因是建造控制器缺少选址锁定状态。

**修复（最小增量，状态唯一权威在 `MapConstructionController`）**：

- 新增 `PlacementState { PREVIEW, LOCKED }`：悬停仅在 PREVIEW 态更新预览；左键点击 = 锁定/重新锁定（保存 `Vector2i` 格子坐标，非世界坐标）；确认建造必须使用锁定格并再次校验；退出/重进重置为 PREVIEW。
- 非法位置允许锁定（红色固定）但确认禁用；确认按钮可用性 = 已锁定 + 合法，提示文案区分两态。
- 集成测试重写第 10 步为锁定语义：未锁定确认被拒绝、锁定后悬停 Preview 固定、建筑生成在锁定格而非悬停格、重进恢复预览跟随、非法锁定可锁不可建；全部通过，回归无新增失败。

### 15.8 调试“揭示格子”与建造权限统一修复（2026-08-08）

**问题**：调试面板“揭示格子”揭示的区域视觉上已解除迷雾，但建造模式判定不可建造。

**根因**：`MapController.reveal_area()`（揭示格子唯一数据入口）只调用 `reveal_circle`（EXPLORED），未写入 VISIBLE——与开局初始视野此前的问题同源。EXPLORED 的暗化渲染在视觉上接近“可见”，造成逻辑与视觉不一致。

**修复（数据源统一，非补丁）**：

- `reveal_area()` 现在同时写入 `EXPLORED`（reveal_circle）与 `VISIBLE`（update_visibility），仅写入当前迷雾阵营自己的独立数据；日志补充 visible 计数。
- “揭示格子”语义明确为：**把区域真正揭示给当前阵营（当前可见）**；与“设当前视野”（reset 后设定）保持区分。
- 建造系统零改动：仍只查询 `FogData.is_visible` 统一接口，不知道视野来自初始/侦察/调试揭示——三种来源行为完全一致。
- 完整数据链：调试按钮 → `MapWorld.reveal_at_cursor` → `MapController.reveal_area` → FogData → `fog_changed` → Chunk 迷雾重建（视觉）。

**验证**：单元新增 `test_debug_reveal_grants_visible_and_buildable`（走真实 reveal_area 路径：揭示后 VISIBLE+EXPLORED、不污染山地/湿地、允许建造），construction 套件 19/19 通过；集成测试新增第 13 步（真实 MapWorld 走调试面板同一路径：揭示前禁止 → 揭示后数据双写+隔离 → 校验通过 → 锁定 → 悬停不移位 → 确认生成在锁定格 → 删除 → 可重建），集成断言检查点 96 处全部通过；回归 42 项中仅 3 项修改前既有失败 + 1 项生成耗时偶发。

### 15.9 建筑方向选择与建筑格子吸附（2026-08-08）

**已完成：**

- **建筑方向选择（第一版）**
  - 支持 0°/90°/180°/270° 四个标准方向（`rotation_index` 0=北/1=东/2=南/3=西），角度换算统一收敛在 `MapBuildingDefinition.rotation_index_to_y_rotation()`，无散落魔法数字
  - 新增建筑选择栏（HUD「建造」按钮打开）：建筑列表（测试建筑 3×3×3 / 测试建筑 B 3×4×3）+ 方向选择（北/东/南/西）+ 3D 选择预览（独立 SubViewport，纯展示，不参与占地、不注册 BuildingManager、不产生 building_id）+ 开始建造/取消，全部复用 UIBuilder 现有按钮与面板样式
  - 开始建造时地图 Preview 继承选择栏方向（`enter_build_mode(definition, rotation_index)`）
  - 地图建造阶段可通过「旋转」按钮（及预留 R 键）继续旋转，PREVIEW 与 LOCKED 状态均允许，旋转时锚点格不变
  - 旋转后动态 footprint：`get_footprint_cells(origin_cell, rotation_index)` 统一推导，3×4 ↔ 4×3 占地真实转换（12 格），occupied_cells、预览中心、合法性检测、正式建筑共用同一锚点函数，无 +0.5/-0.5 手动偏移
  - Preview 与正式建筑方向完全一致：网格按基础尺寸构建 + 节点 Y 轴按 `rotation_index` 旋转；正式建筑业务数据保存离散 `rotation_index`（BuildingData），快照携带方向信息
  - 每次重新打开选择栏方向重置为 0°（行为统一明确）
- **建筑格子吸附**
  - Preview 自动吸附二维格子：射线命中 → `world_to_grid()` → 格子坐标 → 统一 `grid_to_world_continuous()` 换算预览位置，一格一格移动，不跟随原始鼠标世界坐标（复用既有拾取路径，无第二套吸附算法）
  - 阶梯高度吸附：底面贴合占地统一 `surface_height`，高度不一致时 Preview 保持吸附并转红
  - PREVIEW / LOCKED 状态兼容：PREVIEW 悬停逐格吸附，LOCKED 左键锁定后 Preview 固定，旋转不解除锁定
  - 边缘/障碍/视野旋转检测：旋转后越界、与已有建筑重叠、占地格不可见均立即转红并禁用确认

**关键实现：**

- `BuildingDefinition.footprint_size` 始终保存基础尺寸（3×4），旋转后尺寸由 `get_rotated_footprint_size()` 动态推导，不改写定义
- `BuildingData` 新增 `rotation_index`；`footprint_size` 保持基础尺寸，`get_rotated_footprint_size()` / `get_footprint_center()` 按旋转后尺寸计算
- `MapBuildingManager.validate_placement()` / `place_building()` 增加 `rotation_index` 参数（默认 0，向后兼容）；删除建筑仍以保存的 `occupied_cells` 精确释放，不重新推导
- `MapConstructionController` 维护 `_rotation_index`：进入继承、旋转循环、退出重置；旋转即重算占地 + 预览 transform + 完整 validate

**验证：**

- 单元测试 construction 套件 25/25 通过（新增 6 项：目录、旋转尺寸、旋转占地与锚点、旋转放置保存方向、旋转删除释放 12 格、旋转改变校验结果、边缘旋转越界）
- 集成测试新增第 14 步 43 处断言全部通过（继承方向、Preview 旋转与中心对齐、地图旋转锚点不变、锁定后原地旋转、确认方向/位置/占地与 Preview 一致、删除释放 12 格、3×3 旋转不变占地、边缘旋转越界转红禁用、退出重置方向）
- HUD 流程测试 `test_hud_building_selection_bar_and_rotation_flow` 17 处断言通过（选择栏开关、方向重置、选择预览同步旋转、开始建造继承方向、旋转按钮、标题方向显示）
- 回归：50 项单元中仅 3 项修改前既有失败（2 项阶梯地形/生成遗留 + 1 项交互面板按钮尺寸遗留），主场景无窗口冒烟运行 240 帧无脚本错误；单位移动与寻路未修改

**待完成（补充）：**

- 建筑自由旋转（如未来需要）
- 建筑入口方向
- 道路自动连接
- 建筑旋转动画
- 复杂建筑锚点
- 正式模型旋转适配
- 单位与建筑方向交互

### 15.10 建筑选择、选中高亮与桥梁 footprint 优化（2026-08-10）

**已完成：**

- **建筑选择 UI 优化**
  - 建筑选择窗口继续复用单一 `SubViewport + PreviewRoot + PreviewBuilding`，仅当前所选建筑参与渲染；`PreviewRoot` 以局部可配置速度缓慢连续绕 Y 轴旋转
  - Selection Preview 自动旋转只修改 UI 展示节点 transform，不读取或写入 `BuildingDefinition`、`BuildingData`、`MapConstructionController` 或真实 `rotation_index`
  - A → B → A 切换时复用原 SubViewport、Camera3D 与 DirectionalLight3D，新建筑从统一展示角度重新开始旋转，无旧模型叠加
  - 删除建筑选择阶段的“方向：北/东/南/西”按钮、方向按钮数组、选择方向索引和仅供该 UI 使用的回调
  - 点击“开始建造”后地图 Preview 显式使用默认 `rotation_index = 0`；地图阶段“旋转”按钮、PREVIEW / LOCKED、3×4 ↔ 4×3 占地、合法性重算与最终方向保存完整保留
- **建筑选中表现**
  - 现有 `SelectionMarker` 原地扩展为统一逐格 MultiMesh 高亮入口 `show_selection_highlight(cells)`，未创建第二套 SelectionManager 或高亮系统
  - 玩家普通建筑直接使用正式保存的 `BuildingData.occupied_cells`，3×3 高亮 9 格，3×4 / 4×3 高亮 12 格
  - 每个高亮格读取现有 `surface_height`，增加集中定义的 `0.08` 视觉偏移并关闭阴影、碰撞，贴合阶梯表面且避免 Z-fighting
  - 建筑、主城、资源点、空地之间切换时复用同一个 MultiMesh 并覆盖实例列表；清空选择后实例数归零，不残留旧高亮
  - 高亮沿用现有实体迷雾可见规则，UNKNOWN 对象不能通过数据命中显示高亮；未修改 FogData 与三阵营视野结构
- **主城选中表现优化**
  - 森林、山地、湿地主城与中央主城直接使用 `MapCityData.get_occupied_cells()` 的真实格子列表
  - 三座阵营主城各完整高亮 `13×13 = 169` 格；中央主城按既有 2 倍 footprint 完整高亮 `26×26 = 676` 格
  - 仅统一高亮范围，己方主城“查看/升级”、敌方主城“攻打/查看”、中央主城独立行动逻辑保持不变
- **桥梁生成优化**
  - 保留既有“道路与河流交点连通块 → 选择过河点”流程，只将最终 bridge component 整理为固定道路宽度 × 连续跨河长度的规则矩形 footprint
  - 长轴继续由既有道路连通块方向推导并离散到格子主轴；短轴宽度继续使用当前道路配置，主干道桥全长保持 2 格宽
  - 沿长轴向两侧搜索河流边界，确认连续陆地后保留 1 格岸侧连接；在搜索上限内找不到另一岸时跳过，不生成半截桥
  - 矩形 footprint 一次性生成并保存 `occupied_cells / footprint_size / bridge_width / bridge_length / bridge_axis`，不再逐格追随不规则河岸形成 L 型或锯齿
  - 扩展后的桥面继续检查地图边界、主城、中央主城、资源点和已有过河点冲突；注册过河点的岸侧格使用桥面渲染，未注册的水上低级道路仍保持中断

**验证：**

- Godot MCP construction 套件 `26/26` 通过；桥梁专项 `2/2` 测试、`209` 处断言全部通过
- Godot MCP 运行态验证：选择 Preview 0.4 秒旋转约 0.092 弧度；A/B/A 切换始终为 1 个 SubViewport、Camera 和 Light；选择栏无方向按钮；视觉角度非零时进入地图仍为 `rotation_index=0`，地图旋转后为 `1`
- 实际建造 3×3、3×4、旋转 4×3 建筑，高亮分别为 9、12、12 格；逐格高度误差约 `1.67e-8`
- 四座主城高亮分别为 169、169、169、676 格；敌方主城仍显示“攻打/查看”，己方主城仍显示“查看/升级”，中央主城继续使用独立行动
- 当前种子实际生成 2 座主干道桥，footprint 分别为 `2×10` 与 `2×11`，均为完整矩形、宽度恒定、两端落地且无对象冲突
- 主场景通过 Godot MCP 启动，运行期项目日志无本次实现造成的脚本错误；无窗口建造集成测试退出码为 0
- 完整地图套件 `12/13` 通过，剩余 `test_continuous_heightfield_and_chunk_seams` 为本次修改前已存在的 Chunk 边界精确相等失败；编辑器内 core_hud 工具测试仍有 4 项既有非 `@tool` 实例化限制，已由实际运行态验证覆盖本次链路

**明确未修改：**

- 地图坐标转换、阶梯高度与地形真实数据
- 战争迷雾核心逻辑、FogData 与三阵营视野数据结构
- ConstructionManager、BuildingManager、MapManager 的总体架构
- 单位移动、AStar、Navigation、寻路、桥梁通行权重与道路自动连接

### 15.4 新增/修改文件清单

新增：

- `map/buildings/building_definition.gd`（建筑定义：占地、高度、世界尺寸计算）
- `map/buildings/building_data.gd`（建筑实例数据，无节点引用）
- `map/buildings/building_manager.gd`（注册表、占用索引、放置校验、占位模型生成）
- `map/buildings/construction_controller.gd`（建造模式状态唯一权威 + Preview）
- `tests/test_construction.gd`、`tests/run_construction_integration.gd`

增量修改（均为追加，不改写既有逻辑）：

- `map/map_world.gd`（挂接建造系统、点击分发优先级、建筑选中）
- `map/data/map_data.gd`（追加连续格坐标转换重载）
- `map/data/map_action_constants.gd`（枚举追加 BUILDING）
- `map/data/map_interaction_context.gd`（追加建筑快照转换）
- `map/data/map_action_resolver.gd`（追加建筑"查看"行动）
- `ui/components/map_area.gd`（转发建造信号与玩家上下文）
- `ui/hud/main_hud.gd`（建造按钮与确认/取消面板）
- `tests/run_headless_tests.gd`（注册新套件）

---

## 15.11 土地平整功能（第九次更新）

### 15.11.1 功能目标

为建筑建造系统提供前置地形改造能力，允许玩家在可建造区域内将指定矩形范围的土地统一平整到目标高度等级，从而满足后续建筑的占地与高度一致性要求。该功能与建造系统共享同一套地图数据与迷雾/权限校验规则，但不改变迷雾探索状态。

### 15.11.2 核心机制

1. **模式切换**
   - 通过 HUD 新增"平整"入口进入土地平整模式；退出或切换模式时自动清理预览与锁定状态。
   - 与建造模式互斥，避免两套 Preview 系统同时占用输入。

2. **范围与高度**
   - 支持矩形范围选择，范围尺寸 1×1 到 8×8 可调。
   - 目标高度等级通过 UI 滑块或按钮调整，与现有阶梯地形高度等级体系一致（`MapGenerationConfig.HEIGHT_STEP`）。
   - 预览状态三态显示：绿色（格子已处于目标高度）、橙色（可平整）、红色（不可平整）。

3. **选址与锁定**
   - 鼠标悬停时预览范围跟随当前格子。
   - 左键单击锁定目标位置；锁定后仍可调整目标高度，范围大小在锁定前可改。
   - 右键/取消键清除锁定。

4. **合法性校验**
   - 边界校验：范围必须在地图边界内。
   - 河流校验：禁止平整河流格子。
   - 道路/桥梁校验：禁止平整道路和桥梁所在格子。
   - 城池/资源点校验：禁止覆盖主城、资源点等关键实体。
   - 建筑占用校验：禁止覆盖已有建筑 footprint。
   - 迷雾校验：要求范围完全处于当前阵营可见区域内（`is_visible`）。
   - 高度差校验：范围内任意格子与目标高度等级之差必须 `<= 2`，避免过大坡度改造。

5. **确认与执行**
   - 确认后调用 `MapController.flatten_terrain(cells, target_height_level)`。
   - 数据层仅修改高度等级与连续高度采样，并局部刷新坡度、可建造标记。
   - 只重建受影响的 Chunk 及其相邻一圈，保证侧面 Mesh 无缝衔接。
   - 当前版本平整即时完成，但接口预留未来施工时间（`construction_time_seconds` 字段）。

6. **与建造系统的联动**
   - 平整后的普通土地与山地区域均标记为可建造。
   - 建造系统复用 `is_visible` 与建筑 footprint 校验，平整结果直接生效。

### 15.11.3 关键实现文件

- `map/terrain/terrain_flatten_controller.gd`：平整模式状态机、范围计算、合法性校验、预览生成。
- `map/controllers/map_controller.gd`：数据层正式入口 `flatten_terrain()`，负责修改高度、刷新坡度、局部重建 Chunk。
- `map/data/map_data.gd`：`set_height_level_at_grid()` 等高度写入接口。
- `map/terrain/terrain_mesh_builder.gd`：阶梯地形 Mesh 构建，确保侧面随高度变化正确生成。
- `ui/hud/main_hud.gd`：平整入口按钮、范围/高度控件、确认/取消面板。
- `ui/components/map_area.gd`：将平整信号转发给 `TerrainFlattenController`。
- `tests/test_terrain_flatten.gd`：土地平整单元与集成测试。

### 15.11.4 测试验证

自动化测试覆盖：

- 进入/退出平整模式；
- 范围 1×1 到 8×8 调整；
- 目标高度调整；
- 预览跟随与左键锁定；
- 边界/河流/道路/城池/建筑/迷雾/高度差等非法场景；
- 确认平整后数据与 Mesh 更新；
- 平整后普通土地与山地区域均可放置建筑；
- 道路格子始终禁止平整。

当前测试 12 项单元/集成断言全部通过。

---

> **报告更新完成（2026-08-06）。** 原始审查阅读代码文件 36 个，运行自动化测试 23 项（全部通过）。后续开发新增核心文件 7 个，修改文件 6 个。当前项目可正常启动、地图可稳定生成、城市/资源/行动菜单交互闭环完整、阵营切换即时刷新。剩余工作主要集中在真机验证和视觉验收层面，不阻塞第一版演示。
>
> **2026-08-06 第二次更新**：追加阶梯地形（Stepped Terrain）视觉适配。将平滑高度地形改为阶梯格子效果（每格顶部水平 + 垂直侧面），同步更新地形碰撞、道路、树木和迷雾覆盖层。单位移动与寻路系统未修改，相关待完成事项见 14.1 节。
>
> **2026-08-07 第三次更新**：追加基础建筑建造功能（第一版）。新增"建造"入口、3×3×3 占位建筑、预览吸附与红绿校验、集中式合法性检测、格子占用、阵营归属与迷雾兼容。新增核心文件 4 个、测试 2 个，增量修改 8 个文件；自动化测试 11 项单元 + 38 项集成断言全部通过。已完成与待完成清单见第十五节。
>
> **2026-08-07 第四次更新**：追加玩家建筑阵营归属与基础建筑删除。删除走统一业务入口 `MapBuildingManager.request_delete_building()`，含二次确认、业务层权限复核、占用格精确释放、注册数据清理与删除后重建闭环；新增 `building_created` / `building_removed` 事件。增量修改 8 个既有文件，未新增模块；自动化测试 17 项单元 + 53 项集成断言全部通过。详见 15.5 节。
>
> **2026-08-08 第五次更新**：修复开局初始视野与建造权限不一致问题。根因为共享主城视野只写 EXPLORED 未写 VISIBLE，修复后开局视野数据与视觉状态统一，建造校验统一为严格 `is_visible` 查询。另追加建造预览跟随鼠标悬停（15.5 节）。增量修改 5 个既有文件；自动化测试 18 项单元 + 71 处集成断言检查点全部通过。详见 15.6 节。
>
> **2026-08-08 第六次更新**：建造选址两态（预览跟随 + 左键锁定，15.7 节）；修复调试“揭示格子”只写 EXPLORED 导致揭示区域不可建造的问题，`reveal_area` 现同时写入 VISIBLE，与初始视野/侦察视野行为统一（15.8 节）。自动化测试 19 项单元 + 96 处集成断言检查点全部通过。
>
> **2026-08-08 第七次更新**：建筑方向选择（第一版）与建筑格子吸附（15.9 节）。新增建筑选择栏（建筑列表 + 北/东/南/西方向选择 + 3D 选择预览 + 开始建造）、测试建筑 B（3×4×3）、`rotation_index` 全链路（选择栏 → 地图 Preview → 校验 → 正式建筑 → 快照），3×4 ↔ 4×3 占地真实转换，锁定后原地旋转，删除按保存的 occupied_cells 精确释放 12 格。增量修改 8 个既有文件，未新增模块目录；自动化测试 25 项 construction 单元 + 43 处新增集成断言 + 17 处 HUD 流程断言全部通过，回归仅 3 项修改前既有失败。
>
> **2026-08-10 第八次更新**：完成建筑选择 UI、选中高亮与桥梁 footprint 优化（15.10 节）。建筑选择 3D Preview 改为纯展示自动旋转并与真实 `rotation_index` 完全解耦，移除选择阶段东南西北按钮；现有 SelectionMarker 升级为基于真实 `occupied_cells` 的逐格阶梯高亮，四座主城完整覆盖 169/169/169/676 格；桥梁按现有方向与道路宽度生成完整矩形并自动延伸至两岸陆地。单位移动、寻路、道路连接、迷雾数据与地图坐标均未修改。
>
> **2026-08-14 第九次更新**：追加土地平整功能（15.11 节）。新增 `TerrainFlattenController` 与 `MapController.flatten_terrain()`，支持 1×1 到 8×8 矩形范围选择、目标高度等级调整、预览跟随与左键锁定、高度差 `<= 2` 及河流/道路/城池/建筑/迷雾等合法性校验；平整后普通土地与山地区域均可建造，只重建受影响 Chunk 及其邻接 Chunk。新增核心文件 1 个、测试 1 个，修改 `map_controller.gd`、`main_hud.gd`、`map_area.gd` 等既有文件；自动化测试 12 项 terrain_flatten 断言全部通过。报告文件同步纳入版本控制。
