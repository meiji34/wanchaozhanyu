---
name: 万朝战域 UI
description: 深色军事沙盘中的克制青铜指挥界面
colors:
  command-black: "oklch(0.16 0.008 70)"
  charcoal-surface: "oklch(0.22 0.014 70)"
  raised-bronze: "oklch(0.28 0.024 70)"
  order-amber: "oklch(0.50 0.124 70)"
  copper: "oklch(0.52 0.105 50)"
  parchment-ink: "oklch(0.93 0.020 80)"
  muted-ink: "oklch(0.76 0.018 75)"
  success: "oklch(0.65 0.10 145)"
  warning: "oklch(0.68 0.12 75)"
  error: "oklch(0.62 0.15 28)"
typography:
  headline:
    fontFamily: "System UI"
    fontSize: "32px"
    fontWeight: 700
    lineHeight: 1.2
  title:
    fontFamily: "System UI"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.25
  body:
    fontFamily: "System UI"
    fontSize: "18px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "System UI"
    fontSize: "16px"
    fontWeight: 600
    lineHeight: 1.25
rounded:
  control: "8px"
  panel: "8px"
spacing:
  xs: "8px"
  sm: "12px"
  md: "20px"
  lg: "32px"
components:
  button-primary:
    backgroundColor: "{colors.order-amber}"
    textColor: "{colors.parchment-ink}"
    rounded: "{rounded.control}"
    padding: "14px 24px"
  button-secondary:
    backgroundColor: "{colors.raised-bronze}"
    textColor: "{colors.parchment-ink}"
    rounded: "{rounded.control}"
    padding: "14px 24px"
  panel:
    backgroundColor: "{colors.charcoal-surface}"
    textColor: "{colors.parchment-ink}"
    rounded: "{rounded.panel}"
    padding: "20px"
---

# Design System: 万朝战域 UI

## Overview

**Creative North Star: “夜幕军帐中的青铜沙盘”**

玩家在暗色军帐中查看一张被青铜边界组织起来的沙盘。层级来自深浅表面、间距和少量琥珀色军令，不依赖纹理与复杂装饰。布局为移动端横屏服务，地图始终是最大的工作区，资源、任务与命令围绕地图排列。

界面拒绝霓虹、玻璃拟态、过度金光和伪造最终美术完成度。所有动效用于确认按下、选中、更新、加载和错误状态。

**Key Characteristics:**

- 深色、低饱和、可长时间阅读
- 琥珀色只用于当前选择和主要行动
- 控件与面板圆角均不超过八像素
- 触控优先，所有关键操作无需悬停
- 地图覆盖层只拦截真实可交互区域

## Colors

背景是近黑中性表面，青铜与琥珀表达命令层级，状态色只用于明确语义。

### Primary

- **军令琥珀**：用于主要按钮、当前选择、资源变化与焦点状态。

### Secondary

- **旧铜**：用于分隔、次级强调和古风结构线，不大面积填充。

### Neutral

- **军帐黑**：应用根背景。
- **炭灰表面**：面板与工具栏。
- **抬升青铜面**：输入框、次级按钮与选中前状态。
- **浅绢文字**：正文与标题。
- **旧绢文字**：说明、占位和次要元数据。

**The One Order Rule.** 单屏琥珀色面积保持克制，只标记最重要动作与当前状态。

## Typography

**Display Font:** 系统无衬线字体
**Body Font:** 系统无衬线字体

**Character:** 单一系统字体保证 Android 与 iOS 无外部依赖地稳定显示中文。标题依靠字号与字重形成层级，不使用装饰性字体。

### Hierarchy

- **Headline**（700，32px，1.2）：页面主标题。
- **Title**（700，24px，1.25）：面板标题与弹窗标题。
- **Body**（400，18px，1.4）：说明与任务内容，长文本控制在约 70 个字符宽。
- **Label**（600，16px，1.25）：按钮、资源名和短状态。

**The Read Before Ornament Rule.** 古风装饰绝不降低字号、对比度或文本间距。

## Elevation

默认不使用模糊大阴影。深度通过三层明度明确的表面和完整边框表达；弹窗使用纯色遮罩与更亮边界提升层级。

**The Tonal Layer Rule.** 只有弹窗与加载遮罩位于页面之上，普通面板不得依靠夸张阴影伪造层级。

## Components

### Buttons

- **Shape:** 稳定、轻微圆角（8px），最小高度 56px。
- **Primary:** 琥珀填充与深色文字，用于页面唯一的主要推进动作。
- **Hover / Focus:** 桌面悬停仅作补充；按下变暗，键盘焦点使用清晰描边。
- **Secondary / Ghost:** 青铜灰表面或透明表面，用于返回、取消和辅助入口。

### Chips

- **Style:** 状态文字配合低饱和语义底色，并附明确中文标签。
- **State:** 当前选中使用琥珀色边界和“当前”文字，不单靠颜色。

### Cards / Containers

- **Corner Style:** 面板圆角不超过 8px。
- **Background:** 炭灰或抬升青铜面。
- **Shadow Strategy:** 默认无阴影。
- **Border:** 完整的一像素低对比度青铜边界。
- **Internal Padding:** 20px，密集资源项允许 12px。

### Inputs / Fields

- **Style:** 深色填充、完整边框、8px 圆角，最小高度 58px。
- **Focus:** 琥珀色边界，不改变布局尺寸。
- **Error / Disabled:** 错误使用红色文字与完整边框；禁用状态降低亮度并保留可读标签。

### Navigation

顶部承载身份与资源，左侧任务在宽屏展开、窄横屏折叠，底部承载五个高频功能与“更多”，右侧只保留地图工具。地图在安全区域内全尺寸铺设，HUD 以边缘覆盖层叠加，不缩小关键触控面积。

### Map Area

地图区使用 `MapArea` 适配组件管理稳定的 `SubViewportContainer` 与 `SubViewport` 挂载点、选择快照、视角命令和失败回退。非交互覆盖层忽略输入，真实按钮与抽屉才拦截触摸。

## Do's and Don'ts

### Do:

- **Do** 保证核心按钮最小高度 56px，并位于安全区域内。
- **Do** 使用完整中文状态文本配合颜色。
- **Do** 将页面、数据、导航与通用弹窗保持独立。
- **Do** 让地图成为 HUD 中面积最大的区域。

### Don't:

- **Don't** 使用霓虹、玻璃拟态、过度金光或密集装饰。
- **Don't** 伪造最终美术完成度或下载未授权资源。
- **Don't** 用透明全屏控件吞掉地图触摸。
- **Don't** 使用侧边粗色条、巨大阴影或超过 8px 的面板圆角。
- **Don't** 依赖悬停解释功能，或只靠颜色表达服务器和任务状态。
