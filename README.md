# 界 / Bounds

> 一个**寓言式**单人策略解谜 Roguelike。你是一名司守,走入正在腐烂的国土,
> 靠"整理意义、划清边界、守护整体"对抗把万物糊成沼泽的熵增。
>
> 玩家从不听到一个软件术语——但整个游戏的物理定律,就是 DDD(领域驱动设计)的灵魂。
> **会玩 = 会建模。我们从不教,玩家自己悟。** 详见 [DESIGN.md](DESIGN.md)。

## 状态

**v0.1 地基** —— 项目骨架、核心棋盘物理(名/真意失稳、画界、陈腐时钟)、首关数据、
论点测试已就绪。后续按 [TASKS.md](TASKS.md) 推进。

## 关键文档

1. [DESIGN.md](DESIGN.md) — 游戏设计(寓言、机制、DDD 映射附录)
2. [CLAUDE.md](CLAUDE.md) — 项目规则(**第一铁律:禁词**)
3. [QUALITY_BAR.md](QUALITY_BAR.md) — "高完成度"勾选清单
4. [TASKS.md](TASKS.md) — 实现任务队列

## 验证命令

当前机器 Godot 不在 PATH:
`C:\Users\Jiang\AppData\Local\Microsoft\WinGet\Links\godot_console.exe`

```pwsh
$godot = "C:\Users\Jiang\AppData\Local\Microsoft\WinGet\Links\godot_console.exe"
& $godot --headless --import --path .            # 首次:建 .godot 缓存
& $godot --headless --quit --path .              # 项目加载
& $godot --headless --script res://tests/run_all.gd --path .   # 测试
```

## 这是什么的继任

《领域之殇》(poker-cc)的精神继任,但**反其道而行**:那个直白喊出每个 DDD 术语,
这个一个字都不说,让思想藏在玩法里。
