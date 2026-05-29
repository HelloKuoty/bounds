# 界 / Bounds — Project Guidance

> 一个**寓言式**策略解谜游戏。玩家从头到尾听不到一个软件术语,但他为了赢必须亲手实践
> DDD(领域驱动设计)的核心思想:划清边界、守护必须一致的整体、在边界翻译、对抗"糊成一团"的熵增。
> **会玩 = 会建模。我们从不教,玩家自己悟。**

## 🔴 第一铁律:寓言纯净 (No Jargon Reaches the Player)

**任何 DDD / 软件工程术语都不得出现在玩家可见的任何地方**——卡牌名、UI 文字、教程、提示、成就、Boss 名、音效字幕,一律禁止下列词(及其等价物):

> 实体 / 值对象 / 聚合 / 聚合根 / 限界上下文 / 上下文映射 / 防腐层 / 领域事件 / 领域服务 /
> 仓储 / 工厂 / 规约 / Saga / CQRS / 事件溯源 / 通用语言 / 技术债 / 充血 / 贫血 / 大泥球 /
> Entity / Aggregate / Bounded Context / Domain Event / Repository ...

玩家只见**寓言词**(见下表)。如果某段文案"一眼能看出在讲 DDD",它就是 bug。
**判定方法**:`tests/` 里有一个 `test_no_jargon.gd`,扫描所有玩家可见字符串(JSON 的 label/intro/name/flavor + UI 文本常量),命中禁词表即 FAIL。新增文案前先想:旷野里的村民会这么说话吗?

### 寓言词汇表(玩家面 ↔ 建造者面)

| 玩家看到的(寓言,可出现) | 我们心里知道的(DDD,**禁止出现**) |
|---|---|
| 生灵 (living thing) | 实体 Entity |
| 筹码 (token) | 值对象 Value Object |
| 名 / 真名 (name/true-name) | 通用语言中的"词" |
| 真意 (meaning) | 概念语义 |
| 界 / 画界 (boundary/wall) | 限界上下文 Bounded Context |
| 束 / 成束 (bundle) | 聚合 Aggregate |
| 守门人 (guardian) | 聚合根 Aggregate Root |
| 传令 / 涟漪 (herald/ripple) | 领域事件 Domain Event |
| 译者石 (translator-stone) | 防腐层 ACL / 上下文映射 |
| 腹地 (heartland) | 核心域 Core Domain |
| 陈腐 / 蔓沼 (rot / the sprawl) | 技术债 / 大泥球 |
| 秩序 (concord) | 良好建模的整洁度 |
| 重塑 (reshape) | 重构 Refactoring |

## 技术栈

- **引擎**: Godot 4.3+(GDScript,非 C#)。当前机器装的是 4.6.3。
- **平台**: Windows / macOS / Linux 桌面(PC 优先)
- **数据**: JSON 驱动(`data/*.json`),运行时加载到轻量数据类
- **架构**: 信号驱动(`EventBus`)+ autoload 单例。`EventBus` 在代码层就是"领域事件"骨架——
  内部架构与主题一致是本项目美学(但这条只对我们成立,玩家不知道)。

### Autoload 单例(随功能推进逐步加入,不预留空壳)
| 名称 | 职责 | 状态 |
|---|---|---|
| `EventBus` | 全局信号总线 | ✅ |
| `TerritoryDatabase` | 加载 `data/territories.json` | ✅ |
| `GameState` | run 持久状态(行省进度、心力、持有工具、存档) | ⏳ 待 run 循环 |
| `RunManager` | 行省地图生成、节点状态 | ⏳ 待 run 循环 |
| `AudioManager` | 音效/音乐 | ⏳ 待音频 |

## 目录约定

```
scenes/      # .tscn,按场景类型分子目录
scripts/
  autoload/  # 单例
  data/      # 轻量数据类 (PieceData, TerritoryData)
  board/     # 棋盘物理(核心:board_state.gd)
  ui/        # UI 控件
data/         # JSON 数据
assets/       # art/, audio/, fonts/
tests/        # GDScript 测试
```

## 编码规范(沿用,务必遵守)

- GDScript:snake_case 变量/函数,PascalCase 类型名
- 信号名用过去式:`region_split`、`territory_cleared`、`instability_detected`
- 单文件通常 < 300 行;超过就拆
- **不要**写防御性废代码。内部相信参数有效;在边界(JSON 加载、用户输入)做校验
- **不要**为不存在的机制预留分支/信号/autoload。`match` 没匹配到就 `assert(false, "...")`
- **不要**写 `_TODO: implement later` 占位函数——要么实现,要么不放
- 注释只在*为什么*不明显时写

## 验证方法(每次代码改动后)

当前机器 Godot 二进制(不在 PATH):
`C:\Users\Jiang\AppData\Local\Microsoft\WinGet\Links\godot_console.exe`
首次改动后若报 "Could not find type ...",先跑一次 `--import` 建 `.godot/` 缓存再验证。

1. `godot --headless --quit --path .` — 项目能加载(退出 0,无 ERROR)
2. `godot --headless --script res://tests/run_all.gd --path .` — 测试全绿
3. 视觉改动:写 GDScript 截图测试到 `tests/visual/`,或在说明里标注需人工 playtest

**不要**只读代码就声称"实现完成"。必须跑过 Godot。

## 不要做的事

- 不要让任何 DDD 术语泄露到玩家面(见铁律)
- 不要重命名/删除已实现且被引用的数据 id(JSON 的 id 是契约)
- 不要为"以后可能用到"加抽象。三处复制好过提前提取
- 不要在没读 [DESIGN.md](DESIGN.md) 的情况下改核心机制
- 不要 commit 大量未实现的 stub
- 这是 poker-cc(《领域之殇》)的精神继任,但**反其道而行**:那个直白说术语,这个一个字都不说
