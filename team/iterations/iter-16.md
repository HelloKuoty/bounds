# 迭代纪要 · iter-16（执行轮）

## 起点
- 基线绿(tests 91 / smoke OK)。承接 iter-15 大评 **顾屿:程序化羊皮纸 shader**(主题最高杠杆代码项,顾屿明示可把氛围从 3.75 抬到 4;纯 shader 无资产)。

## 做了什么
- ✅ **程序化羊皮纸背景(顾屿)**:新建 `shaders/parchment.gdshader`——
  - FBM 值噪声(5 octave)= **低频做旧斑驳(stain)** + **拉伸成方向性的纸纤维纹(fibre)** + **暗斑(patches)**;暖 `base/high` 双色 ramp(`source_color` uniform 可调)。
  - 背景从"暖色平涂 + 暗角"升级为**有材质的旧纸**——正面回应顾屿"背景做旧 ≠ 羊皮纸,缺纤维/折痕纹理"。
  - 接入 `territory_view` 与 `run_map_view` 背景(`ColorRect.material`;**加载失败回退暖色平涂**,不崩)。
- ✅ +2 测试(`test_parchment_shader_loads` 验资源加载为 Shader / `test_background_uses_the_parchment_shader` 验背景挂了 ShaderMaterial)→ **93 绿**;smoke 通关;LOAD 无 shader 报错。

## 说明 / 边界
- **GLSL 保守**(`shader_type canvas_item`,基础 hash/value-noise/fbm,常量循环)以确保 GL Compatibility 渲染器可编译。
- **headless 不在 GPU 上编译/渲染 shader** → 视觉效果与 GPU 编译**需真人在网页版/真机确认**;结构测试已证明"资源加载 + 背景接线"无误。
- 顾屿"shader 可抬主题到 4"的代码项**已交付**;**真手绘插画仍是 4→5 的外部硬限**(代码触不到)。

## 遗留必修(回填 backlog 优先序)
1. 周棠:`!/!!/!!!` **离散强度分级** + **动效减弱开关**(前庭敏感);**iter-17 首选**。
2. 小鹿:名障镇"看穿本质"**独占醒悟演出**(屏震 + 徽记翻色)。
3. 吴老师:对照表加**"复盘引导脚本"**(doc)。
4. 林晚:顿悟揭示瞬间专属反馈(释然/痛两极已成)。
5. 〔4→5 外部硬限〕真插画、真录音 BGM/分层 ambient、真人心力/曲线/对比度实测。

## 分数趋势
- iter-15 大评:上手 3.83 / 深度 3.33 / 主题 3.75 / 推荐 3.42。16(羊皮纸)针对主题/氛围;iter-19 前后再大评复测。

## 下一拍
- iter-17 = 执行轮:周棠 `!/!!/!!!` 离散强度分级 + 动效减弱开关(无障碍闭环最后硬项之一)。
