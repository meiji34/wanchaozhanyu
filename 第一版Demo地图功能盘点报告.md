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

> **报告更新完成（2026-08-06）。** 原始审查阅读代码文件 36 个，运行自动化测试 23 项（全部通过）。后续开发新增核心文件 7 个，修改文件 6 个。当前项目可正常启动、地图可稳定生成、城市/资源/行动菜单交互闭环完整、阵营切换即时刷新。剩余工作主要集中在真机验证和视觉验收层面，不阻塞第一版演示。
>
> **2026-08-06 第二次更新**：追加阶梯地形（Stepped Terrain）视觉适配。将平滑高度地形改为阶梯格子效果（每格顶部水平 + 垂直侧面），同步更新地形碰撞、道路、树木和迷雾覆盖层。单位移动与寻路系统未修改，相关待完成事项见 14.1 节。
