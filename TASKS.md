# 实现任务清单（按依赖排序）

> 从上往下做。每完成一项打 `[x]`。任一项做完、进入下一项前,先跑
> `godot --headless --quit --path .` 确认没破坏现有功能。详见 [DESIGN.md](DESIGN.md)。

## Phase 0: 地基(本次已立）

- [x] 新项目 `project.godot` + autoload(EventBus, TerritoryDatabase）
- [x] 移植测试骨架(run_all.gd, test_helpers.gd）
- [x] 设计文档:DESIGN / CLAUDE(含禁词铁律)/ QUALITY_BAR / TASKS
- [x] 数据类:`PieceData`, `TerritoryData`
- [x] 核心棋盘模型 `board_state.gd`:名/真意失稳检测、画界、陈腐时钟、秩序
- [x] 首个真实关卡数据 `data/territories.json`(渡口集市)
- [x] **论点测试** `test_board_thesis.gd`:超载的名→陈腐;画界分离→治愈+秩序;跨区同名不同意合法
- [x] `test_territory_data.gd`:JSON 加载、id 唯一、字段合法

## Phase 1: 棋盘物理补全(核心动词)

- [x] **T1.1** 成束 + 守门人:`bundle(piece_ids, guardian)`;外部改束内成员须经守门人,绕过则散架(test_bundle)
- [x] **T1.2** 守门人倒下 → 整束散架(成员受创,筹码散落)+ 测试
- [x] **T1.3** 译者石:跨区生接播陈腐;有译者石则安全 + 测试(test_translator)
- [x] **T1.4** 传令:升传令 + 链式触发(限链长,每跳耗心力)+ 测试(test_herald)
- [ ] **T1.5** 陈腐蔓延:沿不清的界/超载的名扩散到邻近棋子 + 测试(当前为全局时钟,蔓延扩散待加)
- [~] **T1.6** 心力经济:传令链每跳耗心力已实现并测;成束/重塑消耗待加
- [x] **T1.7** `test_no_jargon.gd`:扫描所有玩家可见字符串(含 UI),命中禁词表即 FAIL

## Phase 2: 棋盘 UI（结构策略解谜的"手感"）

- [x] **T2.1** `TerritoryView`(代码构造):棋子按区域分组渲染,名 + label 可视
- [~] **T2.2** 画界交互:当前为"点选棋子 + 画界按钮";拖拽/框选 + 落界发光线待打磨
- [x] **T2.3** 失稳可视:冲突棋子红色高亮;解决后熄灭(脉动动画待打磨)
- [x] **T2.4** 陈腐 / 秩序双槽 HUD + 回合推进按钮
- [x] **T2.5** 成束/译者石按钮交互(传令交互待 UI 扩展)
- [x] **T2.6** 净化 / 塌陷 overlay 结算
- 验证:`test_territory_view.gd`(结构)+ `tests/visual/screenshot_territory.gd`(入树构建)

## Phase 3: Run 与节点

- [x] **T3.1** `GameState`:行省进度、心力、存档(start_new_run / enter_node 自动存档 / load_save)
- [x] **T3.2** `RunManager`:行省地图生成 + 节点类型(土地/精英/静室/集市/腹地)
- [ ] **T3.3** `RunMap.tscn` 可视节点图、可达性、玩家移动(逻辑已就绪,UI 待建)
- [ ] **T3.4** 节点场景路由:静室/集市交互(目前 Main 直接进首关)
- [x] **T3.5** 完整 run smoke 测试(`smoke_full_run.gd` 自动走通行省到 Boss)

## Phase 4: 主菜单 / Meta / 音频美术

- [ ] **T4.1** 主菜单 / 设置 / 存档继续
- [ ] **T4.2** `AudioManager`(移植)+ 基础音效占位
- [ ] **T4.3** 程序占位美术(缺图不崩)
- [ ] **T4.4** 教程关:纯视觉教"画界"

## Phase 5: 打磨

- [ ] **T5.1** 难度曲线 / 数值平衡
- [ ] **T5.2** 异常路径(连点、ESC、窗口尺寸)不崩
- [ ] **T5.3** `QUALITY_BAR.md` 逐项打勾
- [ ] **T5.4** README + 操作说明

---

## 信号架构(已落地)

- **棋盘信号在 `BoardState` 自身**(模型自包含,不依赖全局单例):`piece_placed`、`piece_removed`、
  `region_split`、`bundle_formed`、`guardian_fell`、`translator_placed`、`herald_emitted`、
  `insight_changed`、`instability_detected`、`concord_changed`、`blight_changed`、
  `territory_cleared`、`territory_failed`。控制器/UI 连接 board 并按需转接。
- **`EventBus` 只管 run/UI 作用域**:`run_started`、`node_entered`、`run_ended`、`toast`。
- 经验:顶层 `--script` 编译期看不到 autoload 全局标识符 → 模型保持无全局依赖,既是好架构也避免该坑。
