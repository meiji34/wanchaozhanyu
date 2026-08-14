# 阵营一最新十二兵种 Godot 4.7.1 资产包

本目录是十二个 Blender 静态模块化单位的 Godot 运行时交付。选择规则是“每个逻辑兵种目录取最高 `_vNNN` 版本”，不是按修改时间机械截取十二个物理文件。因此弓兵使用 V005，其余十一项使用 V003。

## 目录结构

```text
faction_01/
├─ 01_worker/                 # GLB + Godot .import
├─ 02_sword_shield/
├─ 03_spearman/
├─ 04_halberdier/
├─ 05_light_cavalry/
├─ 06_heavy_infantry/
├─ 07_horse_archer/
├─ 08_heavy_cavalry/
├─ 09_archer/
├─ 10_crossbowman/
├─ 11_scout/
├─ 12_marine/
├─ qa/
│  ├─ blender_source_audit.json
│  ├─ blender_export_report.json
│  ├─ blender_roundtrip_report.json
│  └─ godot_import_report.json
├─ package_manifest.json
└─ README.md
```

可编辑 `.blend` 仍保留在：

`res://art/blender/faction1_pixel_roster_upgrade_20260810/roles/`

## 格式配对

| Blender 内容 | Godot / GLB 结果 |
|---|---|
| 每角色最高版本 `.blend` | 每角色一个自包含 glTF 2.0 Binary `.glb` |
| `UNIT_F1_*_ROOT` 与模块根 | `Node3D` 层级，保留人物、武器、道具、坐骑和马具分组 |
| Socket / Grip Empty | `Node3D` 挂点 |
| Mesh | `MeshInstance3D` |
| 重骑兵的 18 个 Curve | 导出时烘焙为 `MeshInstance3D` |
| Blender 材质参数 | GLB 内嵌 PBR 材质；本包没有外部贴图依赖 |
| LOD | 源文件无 authored LOD，Godot `.import` 也关闭自动 LOD 生成 |
| 预览相机与灯光 | 不导出 |
| Armature / Action | 源文件不存在，因此不伪造骨骼或动画 |

Godot 不允许 Node 名包含 `:`、`.` 等字符，导入时会把它们规范化为 `_`。涉及的精确名称映射记录在 `package_manifest.json` 的每项 `godot.node_name_mapping` 中。

## 坐标与尺度

- Blender：`1 BU = 1 m`、`+Z` 向上、角色正面 `-Y`。
- GLB：Y-up。
- Godot：`+Y` 向上、角色正面 `-Z`、根缩放为正且保持 `1.0`。
- Godot 会在外部 GLB 的 `UNIT_F1_*_ROOT` 外增加一层 PackedScene 包装根；模块化单位根仍完整保留在其下。

## 在 Godot 中使用

保持当前 `res://map/assets/models/units/faction_01/` 路径，打开 Godot 4.7.1 后等待导入完成。`.godot/` 是可重建缓存，不属于资产包。

本包已在一个使用相同 `res://` 路径的隔离 Godot 4.7.1 Mobile 项目中完成 12/12 导入与实例化验证。当前目标项目还会扫描 `art/` 下的离线 `.blend`，但本机 Godot 的 Blender importer 路径尚未配置，因此整项目首次扫描会先被这个与 GLB 无关的问题阻塞。正式集成前应在 Godot Editor Settings 配置 Blender 可执行文件，或另行评审后用 `.gdignore` 隔离离线美术源；本次没有改动这项项目设置。

```gdscript
const WORKER_SCENE: PackedScene = preload(
    "res://map/assets/models/units/faction_01/01_worker/chr_f1_worker_pixel_v003.glb"
)

var worker := WORKER_SCENE.instantiate()
add_child(worker)

var assembly_root := worker.find_child("UNIT_F1_WORKER_V003_ROOT", true, false)
```

本包只完成格式转换与可导入配对，没有创建角色业务场景、碰撞体、骨骼、动画、导航或游戏逻辑。

## 验证状态

- Blender 5.2.0 LTS 源审计：12/12 无硬失败。
- Blender 干净 GLB 重导入：12/12 通过；层级、名称、三角面、材质和包围盒保持一致。
- Godot 4.7.1 Mobile 隔离项目（相同 `res://` 路径）导入并实例化：12/12 通过。
- 总计：12 个 GLB，2,436,320 字节，903 个运行时几何节点，24,968 个三角面。

轻骑兵源文件的 9 个开放带状/盔顶网格会被通用审计报告为非流形警告；冻结的 V003 报告把它们记录为无硬失败的已知开放结构，本次打包没有修改源拓扑。详情见 `qa/blender_source_audit.json`。

## 后续提交边界

未来提交 GitHub 时提交本目录的展开文件，不要把本地 ZIP 与展开目录同时提交，也不要提交 `.godot/` 缓存。当前工作区不是 Git 仓库，项目文档明确禁止在这里初始化 Git；应先取得正确的 GitHub 克隆，再复制本目录并进行提交。
