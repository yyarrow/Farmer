# 青禾邑

一款完全离线的安卓竖屏单机游戏，将种田经营、城邑建造、放置收益与轻量战争策略结合在一起。当前成长线贯通春秋、战国、秦、汉、三国、晋、南北朝、隋、唐与五代，重点是乱世经营中的取舍，而不是复杂微操。

## 已实现

- 粮秣（石）、木料（车）、石料（方）、财货（枚）四资源及逐日收支账簿
- 农田、林场、石场、民居、市集、仓廪、兵营、城垣八类建筑
- 市场买卖、三项政令、人口与民心系统
- 民口转军籍、军籍容量、乡勇/弓手/车士按人计数及可见维持费
- 持续存在的敌军编成、侦察、巡剿、守城推演与三回合战斗
- 持重、坚壁、雁行、锋矢四种守城阵令；兵种构成与风险偏好会改变真实杀伤、战损和推演结果
- 按兵种结算并在战报中逐项对账的阵亡、伤员、余部与敌损；伤员 2～4 日康复并消耗伤营粮药
- 旱灾、水患、寒赈、流民、商队、百工、流言、征粮、斥候与丰收十类随机事件，且不会连续重复
- 城池等级与时代积累两条独立成长线；每个时代的城池阶段会逐步开放 6～10 个建筑用地
- 主城随城池等级扩大并可左右拖动巡视；已实现的十个时代均有独立绘卷背景，以及各自的城建、资源、军制、阵令、敌军与事件文案
- 发展、主动推进日期、巡剿与守城共同积累时代进度；时代更迭保留城池、人口、物资与军队规模
- 稳定内部兵种/资源 ID 与可配置呈现分离；隋以漕河转输，唐以馆驿漕运，五代以藩镇转饷，兵种、单位、辎重和建筑均随时代换制
- 离线收益和自动本地存档
- 首战前按实际状态推进的非阻塞备忘：补兵、建防、侦察、推演；重新开局会恢复说明，也可从设置随时重看
- 暂停、1×、2×、推进一日及事件/敌袭自动停时
- 每季12日的四时历法；农收、采集、赋税、冬粮和事件池随季节变化并在账簿中公开
- 原创竖屏国风主场景、轻动效、触觉反馈与短促编钟音色
- 内嵌 Noto Sans SC 中文字体，不依赖手机厂商字体；字体按 SIL OFL 1.1 合规随包分发
- 设置页内置可滚动的开源许可页，离线展示 Godot MIT、引擎第三方版权/许可与字体 OFL
- 春夏秋冬四首原创五声音阶国风音乐（共 384 秒，每季 96 秒并含四个发展段落），每首以 2 秒交叉衔接无缝循环，换季时 2.4 秒平滑切换；战斗音效会短暂压低背景音乐
- 总音量、背景音乐、操作音效、静音和触觉反馈设置，设置写入带损坏恢复且拖动时不反复刷盘
- 八类建筑六级可辨外观，卡片逐项显示本季产出、仓容、军籍、训练或减伤的当前值与下一阶真实值；建造、升级、买卖、征兵、政令、巡剿、日结、事件和战斗都有对应城景反馈，水利、军民、伤营与近敌状态会持续留在地图上
- 阵令切换有独立军令鼓点，兵营旗色与士卒队形会持续映射当前守城部署
- 建筑图按手机实际显示尺寸保留三倍采样精度，降低低端设备常驻纹理与安装包负担
- 自动存档、三个手动存档槽及载入、覆盖、删除、重新开始确认；写入采用临时文件与上一版备份，截断、结构损坏或跨字段状态矛盾时自动恢复
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
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/architecture_contract.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/full_flow.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/balance_sim.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/order_balance.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/era_progression.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/era_battle_balance.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/imperial_battle_balance.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/medieval_battle_balance.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/sui_tang_battle_balance.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/headless_playtest.gd -- --runs=250 --days=180
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/ui_smoke.gd
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --path . --script tests/visual_capture.gd --audio-driver Dummy --display-driver macos --rendering-driver opengl3
python3 tests/audio_assets.py
python3 tests/store_assets.py
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --export-debug Android build/Qinghe.apk
```

安卓包名为 `com.qinghe.farmer`，当前版本 `0.11.0`，最低 Android 7.0。旧版存档读取时会依次迁移为按人计数的军籍/资源制和 v4 时代/城池双成长存档；既有进度默认归入春秋并按日期、城建、城池与战绩推导时代积累。没有阵令字段的旧档默认使用「持重」。存档和诊断只写入应用私有目录，不请求网络权限。诊断报告由玩家主动复制后发送，不会自动上传。

首次生成本机发布签名并构建不可调试的 ARM64 正式 APK：

```bash
python3 tools/create_release_keystore.py
python3 tools/build_release_apk.py
```

构建并验证 Google Play AAB；追加参数会同时模拟 Play 交付并验证派生 APK：

```bash
python3 tools/build_release_aab.py
python3 tools/build_release_aab.py --universal-apk
```

私钥和随机密码只保存在被 Git 忽略的 `.release/`，脚本不会覆盖已有签名身份。必须把该目录安全备份；丢失上传密钥会影响后续更新。AAB 构建需要官方 Godot 4.7 Android Gradle template 和 Google bundletool，具体准备、验收和 Play Console 外部门槛见 [`docs/RELEASE.md`](docs/RELEASE.md)。

Google Play 图标、宣传图、截图、中文文案和隐私政策草案位于 [`store/`](store/README.md)。

当前经济、建筑、军队和敌袭公式见 [`docs/BALANCE.md`](docs/BALANCE.md)。
当前模块边界与朝代扩展约束见 [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)。
无界面自动玩家的策略、指标和最近一次长期结果见 [`docs/HEADLESS_PLAYTEST.md`](docs/HEADLESS_PLAYTEST.md)。批量测试支持 runs、days、seed、policy、report 和 strict 参数，默认在 .qa/ 生成 JSON 与 Markdown 完整报告。

## 重新生成原创音频

```bash
python3 tools/generate_audio.py
```

脚本只使用 Python 标准库，离线合成主题音乐和所有操作音效。
