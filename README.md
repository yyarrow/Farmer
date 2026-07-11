# 青禾邑

一款完全离线的安卓竖屏单机游戏，将种田经营、城邑建造、放置收益与轻量战争策略结合在一起。背景取材于架空的春秋战国时代，重点是乱世经营中的取舍，而不是复杂微操。

## 已实现

- 粮食、木材、石料、铜钱四资源实时生产
- 农田、林场、石场、民居、市集、仓廪、兵营、城垣八类建筑
- 市场买卖、三项政令、人口与民心系统
- 乡勇、弓手、战车三类军队及持续维持成本
- 边患、巡剿、周期守城战与战损
- 旱灾、流民、商队、斥候、丰收等随机事件
- 三阶段繁荣目标、离线收益和自动本地存档
- 原创竖屏国风主场景、轻动效、触觉反馈与短促编钟音色

## 运行

项目使用 Godot 4.7。仓库内附便携开发工具时，可直接执行：

```bash
./tools/godot/Godot.app/Contents/MacOS/Godot --path .
```

也可以用任意 Godot 4.7 安装打开 `project.godot`。

## 检查与构建

```bash
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/state_smoke.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug Android build/Qinghe.apk
```

安卓包名为 `com.qinghe.farmer`，最低 Android 7.0。存档只写入应用私有目录，不请求网络或其他敏感权限。

