# 质量门槛 (Quality Bar) — v1 "高完成度"定义

> 全部勾选 = 可以停。门槛降低 = 项目早衰,慎改。
>
> **本轮 /goal 达成**:所有**可客观验证**(测试 / headless)的核心条目已全绿——
> 棋盘四大物理、决策深度、Run 通关、存档、寓言纯净、功能性 UI。
> 未勾项均为**真人 playtest 主观项 / 音频 / 美术 / 后续 Phase 内容**,已注明门槛。
> 验证基线:`--headless --quit`、`run_all.gd`(**40 PASS**)、`smoke_full_run.gd` 三命令全 0 退出。

## A. 可启动
- [x] `godot --headless --quit --path .` 退出码 0,无 ERROR
- [x] 主场景从 `Main.tscn` 启动(verified:直接进入「渡口集市」可玩界面)

## B. 寓言纯净(本作灵魂)
- [x] **玩家可见文字零 DDD/软件术语**(`test_no_jargon.gd` 全绿,含 UI 按钮文案)
- [ ] 不懂编程的人玩只觉在"整理土地"  *(需真人 playtest)*
- [ ] 懂 DDD 的人玩到中段会"啊哈"  *(需真人 playtest)*

## C. 核心解谜成立(全部 verified)
- [x] 失稳可被察觉(冲突棋子红色高亮)且每回合播陈腐  *(脉动动画属打磨)*
- [x] 画界把冲突真意分两区 → 失稳消除 → 得秩序(头号"啊哈")
- [x] 跨区同名不同意合法(边界定律)
- [x] 束 + 守门人:绕过守门人改束内 → 束破;守门人倒 → 束散
- [x] 译者石:跨区生接播陈腐,放石后安全
- [x] 传令链式触发,跨区需译者石中继,每跳耗心力

## D. 决策深度(防"无脑点就赢",全部 verified)
- [x] 乱点/错误整理无法稳赢:不行动 5 回合必败;错误画界/部分成束零效果
- [x] ≥2 种正确解法路径对同一关都可行(`test_a_different_order_also_clears`)

## E. Run 节奏
- [x] 一个行省可通关:土地 → 静室/集市 → 精英 → 腹地蔓沼 → 净化(`smoke_full_run` 自动走通)
- [ ] 一次 run 时长 15–40 分钟  *(需真人 playtest;~10 节点结构已就位)*
- [ ] 蔓沼 Boss 限时重切 + **独立阶段视觉**  *(可净化已验证;阶段视觉待后续)*

## F. 视觉与反馈
- [ ] 画界落线动画 / 陈腐蔓延动画  *(失稳高亮✓、净化/塌陷 overlay✓ 已有;落线与蔓延动画待打磨)*
- [x] 双时钟(秩序/陈腐)实时可见(进度条)
- [ ] 基础音效 + 1 段环境 BGM  *(待音频 Phase)*

## G. 美术
- [x] 缺图能玩:UI 纯代码绘制,零美术资源也不崩(verified)
- [ ] 统一极简几何 + 古地图基调  *(基础深色主题已有;羊皮纸质感待美术)*

## H. 存档
- [x] 每进入新节点自动存档;"继续"恢复(`test_save_load` 往返 verified)
- [ ] 净化/塌陷清空存档(`clear_save` 已实现并测);设置持久化  *(设置系统待 Phase)*

## I. 稳定性
- [x] 完整跑 1 个行省不崩溃(`smoke_full_run`)
- [ ] 故意操作(连点/ESC/非法落界)不崩  *(board 断言守边界、UI 空选提示已有;未穷尽测试)*
- [x] 无未捕获错误日志(三命令全 0 退出)

## J. 测试(全部 verified)
- [x] `tests/run_all.gd` 全绿(**40 PASS / 0 FAIL**)
- [x] 覆盖:失稳检测 + 画界治愈 + 跨区合法 + 束/守门人 + 译者石 + 传令链 + 禁词扫描 + 决策深度 + 多解 + 存档 + UI 构建
- [x] 每次提交前测试全绿

---

## 验证清单(声明"完成"前必跑,三条全 0 退出)
```
godot --headless --quit --path .
godot --headless --script res://tests/run_all.gd --path .
godot --headless --script res://tests/smoke_full_run.gd --path .
```
额外:`godot --headless --script res://tests/visual/screenshot_territory.gd --path .`(棋盘可视构建)

---

## 剩余门槛(下一轮 /goal 或真人 playtest)
1. **真人 playtest**:寓言可读性(B)、run 时长手感(E)、操作健壮性(I)
2. **音频**:SFX + 环境 BGM(F)
3. **美术**:古地图基调(G)、Boss 阶段视觉(E)
4. **打磨动画**:画界落线、陈腐蔓延、失稳脉动(F)
5. **UI 扩展**:主菜单、行省地图场景、静室/集市交互(目前直接进首关;Run 逻辑已就绪)
