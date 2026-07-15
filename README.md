# 青禾邑

一款完全离线的安卓竖屏单机游戏，将种田经营、城邑建造、放置收益与轻量战争策略结合在一起。背景取材于架空的春秋战国时代，重点是乱世经营中的取舍，而不是复杂微操。

## 已实现

- 粮秣（石）、木料（车）、石料（方）、财货（枚）四资源及逐日收支账簿
- 农田、林场、石场、民居、市集、仓廪、兵营、城垣八类建筑
- 市场买卖、三项政令、人口与民心系统
- 民口转军籍、军籍容量、乡勇/弓手/车士按人计数及可见维持费
- 持续存在的敌军编成、侦察、巡剿、守城推演与三回合战斗
- 按兵种结算的阵亡、伤员、2～4 日康复与伤营粮药支出
- 旱灾、流民、商队、斥候、丰收等随机事件
- 三阶段繁荣目标、离线收益和自动本地存档
- 暂停、1×、2×、推进一日及事件/敌袭自动停时
- 每季12日的四时历法；农收、采集、赋税、冬粮和事件池随季节变化并在账簿中公开
- 原创竖屏国风主场景、轻动效、触觉反馈与短促编钟音色
- 48 秒原创五声音阶国风音乐，以 2 秒交叉衔接无缝循环；战斗音效会短暂压低背景音乐
- 总音量、背景音乐、操作音效滑杆及静音设置，设置写入带损坏恢复且拖动时不反复刷盘
- 八类建筑四阶段外观，建造、升级、交易、征兵、政令和战斗场景动效
- 自动存档、三个手动存档槽及载入、覆盖、删除、重新开始确认；写入采用临时文件与上一版备份，损坏时自动恢复
- 完全本地的操作埋点、异常退出检测、引擎日志与诊断报告复制导出

## 运行

项目使用 Godot 4.7。仓库内附便携开发工具时，可直接执行：

```bash
./tools/godot/Godot.app/Contents/MacOS/Godot --path .
```

也可以用任意 Godot 4.7 安装打开 `project.godot`。

## 检查与构建

```bash
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/state_smoke.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/full_flow.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/balance_sim.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/headless_playtest.gd -- --runs=1000 --days=60
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/ui_smoke.gd
python3 tests/audio_assets.py
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug Android build/Qinghe.apk
```

安卓包名为 `com.qinghe.farmer`，当前版本 `0.3.0`，最低 Android 7.0。旧版存档读取时会自动迁移为按人计数的新军籍和新资源制。存档和诊断只写入应用私有目录，不请求网络权限。诊断报告由玩家主动复制后发送，不会自动上传。

当前经济、建筑、军队和敌袭公式见 [`docs/BALANCE.md`](docs/BALANCE.md)。
无界面自动玩家的策略、指标和最近一次 4000 局结果见 [`docs/HEADLESS_PLAYTEST.md`](docs/HEADLESS_PLAYTEST.md)。批量测试支持 runs、days、seed、policy、report 和 strict 参数，默认在 .qa/ 生成 JSON 与 Markdown 完整报告。

## 重新生成原创音频

```bash
python3 tools/generate_audio.py
```

脚本只使用 Python 标准库，离线合成主题音乐和所有操作音效。
