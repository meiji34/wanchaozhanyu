class_name V3DebugPanel
extends CanvasLayer

## 第三版调试控制面板 — 右侧响应式布局
## 后期删除：从 map_area.gd 移除 _spawn_debug_panel() 调用并删除本文件。

const PANEL_WIDTH_RATIO := 0.26
const PANEL_MIN_WIDTH := 380.0
const PANEL_MAX_WIDTH := 560.0
const SAFE_MARGIN_V := 20.0
const SAFE_MARGIN_R := 12.0

var _map_world: MapWorld
var _controller: MapController
var _player_context: DemoPlayerContext = null
var _collapsed := false

# 根容器
var _debug_root: Control
var _collapsed_button: Button
var _right_margin: MarginContainer
var _panel: PanelContainer
var _tab_container: TabContainer
var _map_vbox: VBoxContainer
var _building_vbox: VBoxContainer

# 状态标签（始终显示）
var _camera_mode_label: Label
var _hit_grid_label: Label
var _hit_fog_label: Label
var _resolution_label: Label
var _stats_label: Label

# 地图调试控件
var _fog_toggle: Button
var _grid_visual_toggle: Button
var _initial_radius_slider: HSlider
var _initial_radius_label: Label
var _vision_radius_slider: HSlider
var _vision_radius_label: Label
var _reveal_cursor_radius_slider: HSlider
var _reveal_cursor_radius_label: Label

# 建筑调试控件
var _city_select_label: Label
var _city_footprint_label: Label
var _city_model_size_label: Label
var _city_platform_height_label: Label

var _stats_counter := 0
var _last_viewport_size := Vector2.ZERO

# 阵营选择
var _faction_label: Label
var _faction_buttons: Array[Button] = []


func configure(map_world: MapWorld, controller: MapController, player_context: DemoPlayerContext = null) -> void:
	_map_world = map_world
	_controller = controller
	_player_context = player_context
	_refresh_all()
	if _player_context != null:
		_player_context.faction_changed.connect(_on_faction_changed)
		_player_context.faction_id_changed.connect(_on_faction_id_changed)


func _ready() -> void:
	layer = 128
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func _build_ui() -> void:
	# DebugRoot — 全屏锚定，不拦截输入
	_debug_root = Control.new()
	_debug_root.name = "DebugRoot"
	_debug_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_debug_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_debug_root)

	# 收起状态的展开按钮（右上角）
	_collapsed_button = Button.new()
	_collapsed_button.name = "CollapsedButton"
	_collapsed_button.text = "调试"
	_collapsed_button.custom_minimum_size = Vector2(64, 44)
	_collapsed_button.visible = false
	_collapsed_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_collapsed_button.pressed.connect(_on_collapse_toggle)
	_debug_root.add_child(_collapsed_button)

	# 右侧安全边距容器
	_right_margin = MarginContainer.new()
	_right_margin.name = "RightSafeArea"
	_right_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_right_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debug_root.add_child(_right_margin)

	# 面板
	_panel = PanelContainer.new()
	_panel.name = "DebugPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.04, 0.88)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.28, 0.18)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_panel.add_theme_stylebox_override("panel", style)
	_right_margin.add_child(_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 5)
	_panel.add_child(main_vbox)

	# 标题栏
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var title := Label.new()
	title.text = "V3 调试"
	title.add_theme_color_override("font_color", Color("c99648"))
	title.add_theme_font_size_override("font_size", 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var collapse_btn := Button.new()
	collapse_btn.text = "收起"
	collapse_btn.custom_minimum_size = Vector2(62, 34)
	collapse_btn.pressed.connect(_on_collapse_toggle)
	header.add_child(collapse_btn)
	main_vbox.add_child(header)

	# 信息区
	_camera_mode_label = _mk_label("", 12)
	main_vbox.add_child(_camera_mode_label)
	_hit_grid_label = _mk_label("", 12)
	main_vbox.add_child(_hit_grid_label)
	_hit_fog_label = _mk_label("", 12)
	main_vbox.add_child(_hit_fog_label)
	_resolution_label = _mk_label("", 11)
	_resolution_label.add_theme_color_override("font_color", Color("9a8e7c"))
	main_vbox.add_child(_resolution_label)

	# TabContainer
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_tab_container)

	# ======= 地图调试标签页 =======
	var map_scroll := ScrollContainer.new()
	map_scroll.name = "地图调试"
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_container.add_child(map_scroll)
	_map_vbox = VBoxContainer.new()
	_map_vbox.add_theme_constant_override("separation", 4)
	map_scroll.add_child(_map_vbox)

	_map_vbox.add_child(_mk_section("迷雾"))
	_fog_toggle = _mk_toggle("迷雾")
	_fog_toggle.pressed.connect(_on_fog_toggle)
	_map_vbox.add_child(_fog_toggle)

	var ir_row := _mk_slider_row("开局视野半径", 8, 80, 32, "_on_ir_changed")
	_initial_radius_slider = ir_row.get_child(0) as HSlider
	_initial_radius_label = ir_row.get_child(1) as Label
	_map_vbox.add_child(ir_row)

	var vr_row := _mk_slider_row("当前视野半径", 8, 80, 28, "_on_vr_changed")
	_vision_radius_slider = vr_row.get_child(0) as HSlider
	_vision_radius_label = vr_row.get_child(1) as Label
	_map_vbox.add_child(vr_row)

	var rcr_row := _mk_slider_row("揭示格子视野半径", 1, 60, 10, "_on_rcr_changed")
	_reveal_cursor_radius_slider = rcr_row.get_child(0) as HSlider
	_reveal_cursor_radius_label = rcr_row.get_child(1) as Label
	_map_vbox.add_child(rcr_row)

	# 阵营选择
	_map_vbox.add_child(_mk_section("当前玩家阵营"))
	_faction_label = _mk_label("森林", 13)
	_faction_label.add_theme_color_override("font_color", Color("c8a84e"))
	_map_vbox.add_child(_faction_label)

	var faction_row := HBoxContainer.new()
	faction_row.add_theme_constant_override("separation", 4)
	_map_vbox.add_child(faction_row)
	for faction in DemoPlayerContext.get_available_factions():
		var btn := Button.new()
		btn.text = DemoPlayerContext.get_faction_display_name(faction)
		btn.custom_minimum_size = Vector2(48, 38)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.set_meta("faction", faction)
		btn.pressed.connect(_on_faction_button_pressed.bind(faction))
		_faction_buttons.append(btn)
		faction_row.add_child(btn)
	_highlight_faction_button()

	_map_vbox.add_child(_mk_btn_row([["揭示格子","_on_reveal_at_cursor"],["设当前视野","_on_set_visible_at_cursor"]]))
	_map_vbox.add_child(_mk_btn_row([["全UNKNOWN","_on_set_all_unknown"],["全EXPLORED","_on_set_all_explored"]]))
	_map_vbox.add_child(_mk_btn_row([["全VISIBLE","_on_set_all_visible"],["重置探索","_on_reset_exploration"]]))

	_map_vbox.add_child(_mk_section("相机"))
	_map_vbox.add_child(_mk_btn_row([["经营3D","_on_switch_management"],["战争2.5D","_on_switch_battle"]]))

	# 地形视觉
	_map_vbox.add_child(_mk_section("地形视觉"))
	_grid_visual_toggle = _mk_toggle("格子线")
	_grid_visual_toggle.pressed.connect(_on_grid_visual_toggle)
	_map_vbox.add_child(_grid_visual_toggle)

	# 统计
	_stats_label = _mk_label("", 11)
	_stats_label.add_theme_color_override("font_color", Color("8a7e6c"))
	_map_vbox.add_child(_stats_label)

	# Chunk 诊断
	var diag_row := _mk_btn_row([["诊断黑Chunk","_on_diagnose_black_chunks"]])
	_map_vbox.add_child(diag_row)

	# ======= 建筑调试标签页 =======
	var bld_scroll := ScrollContainer.new()
	bld_scroll.name = "建筑调试"
	bld_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_container.add_child(bld_scroll)
	_building_vbox = VBoxContainer.new()
	_building_vbox.add_theme_constant_override("separation", 4)
	bld_scroll.add_child(_building_vbox)

	_city_select_label = _mk_label("选中建筑: -", 12)
	_building_vbox.add_child(_city_select_label)
	_city_footprint_label = _mk_label("占地: -", 12)
	_building_vbox.add_child(_city_footprint_label)
	_city_model_size_label = _mk_label("模型尺寸: -", 12)
	_building_vbox.add_child(_city_model_size_label)
	_city_platform_height_label = _mk_label("平台高度: -", 12)
	_building_vbox.add_child(_city_platform_height_label)

	_building_vbox.add_child(_mk_btn_row([["占地格","_on_toggle_footprint_show"],["平台范围","_on_toggle_platform_show"]]))
	_building_vbox.add_child(_mk_btn_row([["模型AABB","_on_toggle_aabb_show"],["迷雾区域","_on_toggle_fog_zone_show"]]))

	var hint := _mk_label("后期删除本文件及 MapArea 实例化代码。", 10)
	hint.add_theme_color_override("font_color", Color("4a4030"))
	_building_vbox.add_child(hint)

	_apply_layout()


func _apply_layout() -> void:
	var vs := get_viewport().get_visible_rect().size
	var panel_w := clampf(vs.x * PANEL_WIDTH_RATIO, PANEL_MIN_WIDTH, PANEL_MAX_WIDTH)

	_right_margin.begin_bulk_theme_override()
	_right_margin.add_theme_constant_override("margin_left", int(vs.x - panel_w - SAFE_MARGIN_R))
	_right_margin.add_theme_constant_override("margin_right", int(SAFE_MARGIN_R))
	_right_margin.add_theme_constant_override("margin_top", int(SAFE_MARGIN_V))
	_right_margin.add_theme_constant_override("margin_bottom", int(SAFE_MARGIN_V))
	_right_margin.end_bulk_theme_override()

	_panel.custom_minimum_size = Vector2(panel_w, 0)

	# 收起按钮定位
	_collapsed_button.position = Vector2(vs.x - SAFE_MARGIN_R - 76, SAFE_MARGIN_V + 4)
	_last_viewport_size = vs


func _on_viewport_size_changed() -> void:
	_apply_layout()


# ——— helpers ———

func _mk_label(text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("d8c6a4"))
	l.add_theme_font_size_override("font_size", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l

func _mk_section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color("b8963c"))
	l.add_theme_font_size_override("font_size", 13)
	return l

func _mk_toggle(text: String) -> Button:
	var b := Button.new()
	b.text = text + ": 开"
	b.custom_minimum_size = Vector2(0, 36)
	b.toggle_mode = true
	b.button_pressed = true
	return b

func _mk_slider_row(label_text: String, min_v: float, max_v: float, default_v: float, cb: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	var s := HSlider.new()
	s.min_value = min_v; s.max_value = max_v; s.value = default_v; s.step = 1
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(Callable(self, cb))
	row.add_child(s)
	var l := Label.new()
	l.text = "%s:%d" % [label_text, int(default_v)]
	l.add_theme_color_override("font_color", Color("ead9b7"))
	l.add_theme_font_size_override("font_size", 11)
	l.custom_minimum_size.x = 90
	row.add_child(l)
	return row

func _mk_btn_row(btns: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for bdef in btns:
		var b := Button.new()
		b.text = bdef[0]
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(Callable(self, bdef[1]))
		row.add_child(b)
	return row


# ——— process ———

func _process(_delta: float) -> void:
	_stats_counter += 1
	if _stats_counter >= 8:
		_stats_counter = 0
		_refresh_resolution()
		_refresh_stats()
		_refresh_hit_info()
		_refresh_building_info()

func _refresh_all() -> void:
	_refresh_button_states()
	_refresh_resolution()
	_refresh_stats()
	_refresh_hit_info()
	_refresh_building_info()

func _refresh_resolution() -> void:
	var vs := get_viewport().get_visible_rect().size
	var aspect := vs.x / maxf(1.0, vs.y)
	_resolution_label.text = "窗口:%dx%d  宽高比:%.2f" % [int(vs.x), int(vs.y), aspect]

func _refresh_stats() -> void:
	if _controller == null: return
	var snap := _controller.get_debug_snapshot()
	_stats_label.text = "迷雾 U:%d E:%d V:%d(%s) LOD:%d/%d/%d Chunk:%d活/%d队" % [
		int(snap.get("fog_unknown",0)), int(snap.get("fog_explored",0)), int(snap.get("fog_visible",0)),
		str(snap.get("fog_explored_ratio","0%")),
		int(snap.get("lod0_chunks",0)), int(snap.get("lod1_chunks",0)), int(snap.get("lod2_chunks",0)),
		int(snap.get("active_chunk_count",0)), int(snap.get("queued_chunk_count",0)),
	]

func _refresh_hit_info() -> void:
	if _map_world == null: return
	var grid := _map_world.last_hit_grid
	var d := _map_world.map_controller.map_data
	var valid := d != null and d.is_valid_grid(grid)
	_hit_grid_label.text = "命中格子: %s" % (str(grid) if valid else "-")
	if valid and d.fog_data != null:
		var fog_state := d.fog_data.get_state(grid)
		var state_name := "VISIBLE"
		match fog_state:
			FogData.FogState.UNKNOWN:
				state_name = "UNKNOWN"
			FogData.FogState.EXPLORED:
				state_name = "EXPLORED"
		_hit_fog_label.text = "格子迷雾: %s" % state_name
	else: _hit_fog_label.text = "格子迷雾: -"
	_camera_mode_label.text = "相机: %s" % _map_world.get_view_mode_display_name()

func _refresh_building_info() -> void:
	if _map_world == null or _map_world.get_map_controller() == null: return
	var d := _map_world.get_map_controller().map_data
	if d == null: return
	var cid := _map_world.get_selected_city_id()
	var sc := d.get_city_by_id(cid) if not cid.is_empty() else null
	if sc == null:
		_city_select_label.text = "选中建筑: 无(%d城)" % d.cities.size()
		_city_footprint_label.text = "占地: -"
		_city_model_size_label.text = "模型尺寸: -"
		_city_platform_height_label.text = "平台高度: -"
		return
	_city_select_label.text = "建筑: %s (role=%d)" % [sc.display_name, sc.city_role]
	_city_footprint_label.text = "占地: %s格 自然:%s" % [sc.footprint_size, sc.natural_footprint_size if sc.natural_footprint_size != Vector2i.ZERO else "?"]
	var ws := sc.get_world_footprint_size(d.cell_size)
	_city_model_size_label.text = "占地世界:%.1fx%.1f AABB:%s" % [ws.x, ws.y, sc.model_world_aabb.size if not sc.model_world_aabb.size.is_zero_approx() else "?"]
	var hs:=0.0; var c:=0; var r:=sc.get_occupied_grid_rect()
	for gy in range(r.position.y, r.end.y):
		for gx in range(r.position.x, r.end.x):
			if d.is_valid_grid(Vector2i(gx,gy)): hs+=d.get_height_at_grid(Vector2i(gx,gy)); c+=1
	_city_platform_height_label.text = "平台均高:%.2f(%d采样)" % [hs/maxf(1.0,c) if c>0 else 0.0, c]

func _refresh_button_states() -> void:
	if _controller == null: return
	_fog_toggle.button_pressed = _controller.fog_enabled
	_fog_toggle.text = "迷雾: " + ("开" if _controller.fog_enabled else "关")
	if _map_world != null and _grid_visual_toggle != null:
		_grid_visual_toggle.button_pressed = _map_world.is_grid_visual_enabled()
		_grid_visual_toggle.text = "格子线: " + ("开" if _map_world.is_grid_visual_enabled() else "关")


func _on_collapse_toggle() -> void:
	_collapsed = not _collapsed
	if _collapsed:
		# 收起：从树中移除面板，显示小入口按钮
		if _right_margin.is_inside_tree():
			_debug_root.remove_child(_right_margin)
		_collapsed_button.visible = true
		_collapsed_button.text = "调试"
	else:
		# 展开：添加面板回树中，隐藏小按钮
		if not _right_margin.is_inside_tree():
			_debug_root.add_child(_right_margin)
		_collapsed_button.visible = false


# ——— callbacks ———
func _on_fog_toggle() -> void:
	if _controller == null: return
	_controller.set_fog_enabled(_fog_toggle.button_pressed)
	_fog_toggle.text = "迷雾: " + ("开" if _controller.fog_enabled else "关")
func _on_grid_visual_toggle() -> void:
	if _map_world == null: return
	_map_world.set_grid_visual_enabled(_grid_visual_toggle.button_pressed)
	_grid_visual_toggle.text = "格子线: " + ("开" if _map_world.is_grid_visual_enabled() else "关")
func _on_ir_changed(v: float) -> void:
	_initial_radius_label.text = "开局视野半径:%d" % int(v)
	if _controller: _controller.debug_initial_reveal_radius = int(v)
func _on_vr_changed(v: float) -> void:
	_vision_radius_label.text = "当前视野半径:%d" % int(v)
	if _controller: _controller.debug_vision_radius = int(v); _controller.mark_fog_dirty()
func _on_rcr_changed(v: float) -> void:
	_reveal_cursor_radius_label.text = "揭示格子视野半径:%d" % int(v)
	if _controller: _controller.debug_reveal_at_cursor_radius = int(v)
func _on_faction_button_pressed(faction: StringName) -> void:
	# 同时更新 StringName 和 int faction_id
	if _player_context != null:
		_player_context.set_current_faction(faction)
	_update_fog_faction()

func _on_faction_changed(_previous: StringName, current: StringName) -> void:
	_faction_label.text = DemoPlayerContext.get_faction_display_name(current)
	_highlight_faction_button()

func _on_faction_id_changed(previous_faction_id: int, current_faction_id: int) -> void:
	# 切换前记录各阵营探索数据，验证数据隔离
	if _controller != null and _controller.map_data != null and _controller.map_data.fog_data != null:
		var fog := _controller.map_data.fog_data
		print("[FACTION_SWITCH] from=%d to=%d | before: forest=%d wetland=%d mountain=%d" % [
			previous_faction_id, current_faction_id,
			fog.get_explored_count(DemoPlayerContext.FactionId.FOREST),
			fog.get_explored_count(DemoPlayerContext.FactionId.WETLAND),
			fog.get_explored_count(DemoPlayerContext.FactionId.MOUNTAIN),
		])
	_update_fog_faction()

func _update_fog_faction() -> void:
	## 将当前玩家阵营 ID 同步到地图控制器的迷雾渲染，并触发迷雾重建
	if _controller != null and _player_context != null:
		_controller.current_fog_faction_id = _player_context.current_faction_id
		_controller.mark_fog_dirty()
		print("[DebugPanel] Fog faction updated to %d (%s)" % [_player_context.current_faction_id, DemoPlayerContext.get_faction_name_by_id(_player_context.current_faction_id)])

func _highlight_faction_button() -> void:
	var current := _player_context.current_faction if _player_context != null else &"森林"
	for btn in _faction_buttons:
		var f: StringName = btn.get_meta("faction", &"")
		if f == current:
			btn.disabled = true
		else:
			btn.disabled = false
func _on_reveal_at_cursor() -> void:
	print("[REVEAL_BUTTON] callback_entered=true")
	if _map_world == null:
		push_warning("[REVEAL_BUTTON] 失败：_map_world 为空")
		return
	var g: Vector2i = _map_world.last_hit_grid
	var d: DemoMapData = _map_world.map_controller.map_data
	if d == null:
		push_warning("[REVEAL_BUTTON] 失败：map_data 为空")
		return
	if not d.is_valid_grid(g):
		push_warning("[REVEAL_BUTTON] 失败：当前未选中有效格子（点击地图格子后再试，last_hit_grid=%s）" % str(g))
		return
	var f: FogData = d.fog_data
	if f == null:
		push_warning("[REVEAL_BUTTON] 失败：fog_data 为空")
		return
	# 优先级：揭示格子半径(默认10) > 开局揭示半径 > FogData 默认值
	var r: int = f.initial_reveal_radius
	if _controller.debug_initial_reveal_radius >= 0:
		r = _controller.debug_initial_reveal_radius
	if _controller.debug_reveal_at_cursor_radius >= 1:
		r = _controller.debug_reveal_at_cursor_radius
	# 合法性限制
	if r < 1:
		r = 10
	if r > 200:
		r = 200
	print("[REVEAL_BUTTON] faction=%d cell=%s radius=%d" % [_controller.current_fog_faction_id, g, r])
	_map_world.reveal_at_cursor(g, r)
func _on_set_visible_at_cursor() -> void:
	if _map_world == null: return
	var g := _map_world.last_hit_grid; var d := _map_world.map_controller.map_data
	if d == null or not d.is_valid_grid(g): return
	var f := d.fog_data; if f == null: return
	var r := f.vision_radius
	if _controller.debug_vision_radius >= 0: r = _controller.debug_vision_radius
	_map_world.set_visible_at_cursor(g, r)
func _on_set_all_unknown() -> void: if _map_world: _map_world.set_fog_all_unknown()
func _on_set_all_explored() -> void: if _map_world: _map_world.set_fog_all_explored()
func _on_set_all_visible() -> void: if _map_world: _map_world.set_fog_all_visible()
func _on_reset_exploration() -> void: if _map_world: _map_world.reset_exploration()
func _on_switch_management() -> void:
	if _map_world: _map_world.set_view_mode(MapCameraRig.ViewMode.MANAGEMENT_3D, Vector2(960, 540))
func _on_switch_battle() -> void:
	if _map_world: _map_world.set_view_mode(MapCameraRig.ViewMode.BATTLE_2_5D, Vector2(960, 540))
func _on_toggle_footprint_show() -> void: pass
func _on_toggle_platform_show() -> void: pass
func _on_toggle_aabb_show() -> void: pass
func _on_toggle_fog_zone_show() -> void: pass


func _on_diagnose_black_chunks() -> void:
	if _controller == null:
		return
	var active := _controller.active_chunks
	var invisible_but_visible_needed := 0
	var meshless := 0
	for coord_variant in active.keys():
		var chunk := active[coord_variant] as MapChunk
		if chunk == null:
			continue
		if chunk.runtime_state == MapChunk.ChunkRuntimeState.PRELOADED and chunk.lod_level <= MapChunk.LODLevel.LOD1:
			invisible_but_visible_needed += 1
		var terrain := chunk.get_node_or_null("Terrain") as MeshInstance3D
		if terrain == null or terrain.mesh == null:
			if chunk.runtime_state == MapChunk.ChunkRuntimeState.ACTIVE:
				meshless += 1
	print("[ChunkDiagnosis] hidden=%d meshless_active=%d active_total=%d" % [invisible_but_visible_needed, meshless, active.size()])
