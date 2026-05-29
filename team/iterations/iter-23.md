# 迭代纪要 · iter-23（真人试玩热修 · 用户启动桌面版)

## 触发
- 用户"启动我看一下效果",真机(NVIDIA RTX 5070 / OpenGL 3.3 Compatibility)运行桌面版。

## 里程碑(真硬件首跑)
- 用户**完整走通主线**:渡口集市 → 账房 → 档案窖 → 两种话 → 两市 → 共井 → 渗坏 → **蔓沼**,exit 0 **无崩溃**。
- **羊皮纸 shader 在真显卡上编译通过**(headless 一直验不了的,这次确认 ✅);12 领地加载正常。
- 这一把是委员会一直缺的"真人试玩"的第一笔真实数据(机制流程层:跑通了)。

## 发现的 bug
- 退出日志:`WARNING: ObjectDB instances leaked at exit` → `--verbose` 定位为 **`AudioStreamWAV` + `AudioStreamPlaybackWAV`**,即 **iter-10 环境声床(循环 drone)**:它在真机上一直播放,退出瞬间 AudioServer 对活跃 playback 的回收是**异步**的,没有下一音频帧来 flush → 报泄漏。
- **headless 因 `_silent` 守卫从不播放声床,故 97~99 测试 + 烟雾一直照不到**——真人试玩首次暴露。

## 做了什么
- ✅ `AudioManager._exit_tree()`:teardown 时 `stop()` + 断流(正确卫生,**覆盖正常关窗退出**);+回归测试 `test_teardown_stops_the_bed`。→ **99 绿**,LOAD 0。
- 诊断结论(诚实):加了打印确认 `_exit_tree` **确被调用**;`stop()` / 断流 / 连 `_bed.free()` 都试过,`--quit-after` 急退下**残留告警依旧**——这是**引擎侧异步音频回收**(急退无帧可 flush)的已知良性现象。
- **判断**:告警**只在控制台、玩家永不可见,进程退出 OS 全回收,对游戏零影响**。不为一条控制台告警上"拦截关窗 + 延帧优雅退出"的侵入式 hack(且该 hack 无法 headless 自验,违"必须跑过验证")。保留正确 teardown 卫生即可。
- web 无关(浏览器关页不报 ObjectDB);未重导出。

## 下一拍
- 优先**接用户的视觉/手感反馈**(真机所见:羊皮纸/印章/徽记/颤动/暖光冷暗等)——这是推动"推荐"与真人调参的最高价值输入。
- 若无反馈,续 iter-24 = 推荐的代码杠杆:顾屿 shader polish(折痕/磨损/洇染/箔印)+ 阿May 连环关链。
