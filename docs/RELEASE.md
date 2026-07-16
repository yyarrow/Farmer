# 《青禾邑》Android 发布清单

当前候选版本：`0.5.0`（versionCode `6`）
包名：`com.qinghe.farmer`  
最低系统：Android 7.0（API 24）  
目标系统：Android API 36

## 1. 自动验收

在仓库根目录依次执行：

```bash
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/state_smoke.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/full_flow.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/balance_sim.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/ui_smoke.gd --audio-driver Dummy
python3 tests/audio_assets.py
python3 tests/store_assets.py
python3 tools/android_lint_gate.py
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --path . --script tests/visual_capture.gd --audio-driver Dummy --display-driver macos --rendering-driver opengl3 --position 0,0
```

所有命令必须以 0 退出，并分别出现 `STATE_SMOKE_OK`、`FULL_FLOW_OK`、`BALANCE_SIM_OK`、`UI_SMOKE_OK`、`AUDIO_ASSETS_OK`、`STORE_ASSETS_OK`、`ANDROID_LINT_GATE_OK` 和 `VISUAL_CAPTURE_OK`。Android lint 闸门固定核对 Godot 4.7 模板的 20 条已审阅警告；模板在通用资源中保留的 Android 12 系统启动页属性会触发一条 `NewApi`，只有同时存在 API 24–30 使用的无前缀兼容背景项时才允许这一条，任何新增 lint 类型、错误或数量变化都会失败。渲染截图位于 `.qa/`，需人工检查文字无截断、退出确认与最长事件选项弹窗不遮挡关键操作、春秋冬色调可辨认、建筑 0—5 级均有可见差异，并核对侦察前不显示胜算/伤亡、侦察后才解锁精确推演、可施行政令显示实际收益、无效果政令显示原因且按钮不可用。

长期平衡复核：

```bash
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/headless_playtest.gd -- --runs=1000 --days=60 --policy=all --seed=20260715 --strict
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/headless_playtest.gd -- --runs=250 --days=180 --policy=all --seed=20260715 --strict
```

要求零状态不变量错误；均衡、屯田、尚武三种策略均可持续发展，贪进策略明显更危险，尚武策略不得在首战与整体守城胜率上同时劣于均衡策略。

## 2. 签名 APK

首次在一台受信任的发布机上执行：

```bash
python3 tools/create_release_keystore.py
python3 tools/build_release_apk.py
```

第一条命令在被 Git 忽略的 `.release/` 中生成上传密钥和随机密码，若文件已存在会拒绝覆盖。第二条命令构建 `build/Qinghe-release.apk`，并自动验证：

- 版本、包名、最低/目标 SDK；
- 仅含 `arm64-v8a`；
- 不含 debuggable 标记；
- 仅声明振动权限，不声明网络权限；
- APK Signature Scheme v2 签名有效；
- Android 13+ 单色主题图标已实际编译进 APK；
- 两个 arm64 原生库的每个 ELF `LOAD` 段均按 16 KiB 对齐并启用 RELRO，APK 的未压缩原生库也通过 16 KiB ZIP 对齐；
- 签名证书属于 `Qinghe Game`，不是 Godot 调试证书。

构建成功会打印 APK 与签名证书的 SHA-256。将 `.release/` 的两个文件加密备份到至少两个独立位置，绝不能提交到 Git、聊天或公开存储。丢失密钥可能导致无法向同一安装渠道发布后续更新。

## 3. Google Play AAB

发布机需准备与编辑器完全一致的 Godot 4.7 `android_source.zip`，放在 Godot 的 `4.7.stable` 导出模板目录中；同时把 Google 官方 [bundletool 1.18.3](https://github.com/google/bundletool/releases/tag/1.18.3) JAR 放到被 Git 忽略的 `.home/bundletool.jar`。脚本固定校验模板 SHA-256 `2dcb079f64b6cf9103cce273f42d1d5a4f52bc28d83a215579100fe568d6779c` 和 bundletool SHA-256 `a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29`。首次 Gradle 构建需要访问官方依赖源，依赖只缓存到仓库内 `.home/.gradle/`。

构建并验证可上传的签名 AAB：

```bash
python3 tools/build_release_aab.py
```

额外模拟 Play 交付链，生成并验证通用 APK：

```bash
python3 tools/build_release_aab.py --universal-apk
```

三个 Android 导出预设都使用独立的主图标、自适应背景、自适应前景和单色主题层，符合 Android 官方的[自适应图标规范](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)。脚本会按需安装被 Git 忽略的 `android/build/` Gradle template，幂等启用 Godot 4.7 已接入的 Android 13+ 预测性返回回调，并按 Android 官方的[自动备份规则](https://developer.android.com/identity/data/autobackup)显式排除云备份和设备迁移，保持与“数据只留在当前设备”的隐私承诺一致；随后自动检查 ZIP 完整性、arm64 架构、版本、包名、SDK、权限、启动入口、竖屏、预测性返回、AAB 中实际编译的主题图标和本地数据规则、非调试状态、JAR 签名和上传证书，再调用 `bundletool validate`。原生兼容闸门还会检查 AAB 声明 `PAGE_ALIGNMENT_16K`、每个 arm64 ELF 的 16 KiB `LOAD` 对齐及 RELRO。`--universal-apk` 还会生成 `build/Qinghe-universal.apks`，提取 `build/Qinghe-from-aab.apk`，再执行与正式 APK 相同的清单、签名和 16 KiB ZIP 对齐验证。脚本不会打印签名密码。

2026 年 7 月 16 日的 `0.5.0` 最终本地候选验证结果：AAB 38.0 MiB，SHA-256 `e194b1a88e1db2937bc9895ce4e09a540bfe4482237777e0cf6c2c4c37f0e3af`；独立 APK 38.0 MiB，SHA-256 `66aa02dc9b9b298ea1d0d0581fcb972aee68d353cacfc24dda57218f9bd0f73c`；AAB 派生通用 APK 84.7 MiB，SHA-256 `3556a60e1ef4e6a5227c61f0be10f358e8e59409738a992ea703d8aadafc960c`；上传证书 SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。AAB 和两个 APK 的全部 arm64 原生库均通过 16 KiB ELF/ZIP 对齐与 RELRO 检查，APK 与 AAB 均实际编译了 Android 13+ 单色主题图标，AAB 还包含显式的云备份与设备迁移排除规则。八张建筑图仍保留约三倍屏幕采样精度；春夏秋冬四首配乐共 192 秒，最差循环接缝为 0.0040。同一代码版 AAB 派生包在 Android 35 清数据冷启动为 250 ms，普通热恢复为 67 ms；同版本前序压力复核的设置页 PSS 约 170 MiB，`RUNNING_CRITICAL` 内存压力后热恢复为 127 ms。1080×2400 教程、设置、音量、存档和退出确认均无截断；系统返回键不能跳过教程、可关闭设置、并在主界面打开保存退出确认；启用预测性返回后对应 Android 警告已消失。SwiftShader 模拟器切后台时仍可能记录已断开绘图表面的 `EGL_BAD_SURFACE`，但 Godot、AndroidRuntime 与原生崩溃日志以及 crash buffer 均为空，未见崩溃、ANR 或 Godot 脚本错误，仍须按下文在实体设备复核后台恢复。

功能回归仍覆盖 720×1280 小屏、教程到第 3 日的新事件结算、系统返回键的教程与事件拦截、设置关闭、危险操作取消、退出确认取消和保存退出；教程状态可跨重启保留。音频自动测试额外覆盖四首曲目均为独立内容、循环点、换季双轨重叠、等功率淡化、战斗压低并发与旧曲释放。

本地 AAB 工程闸门已经通过；正式公开发布仍必须先上传 Play Console 内部测试轨道，并用 Play 实际分发的安装包完成冷启动、存档、战斗、音量、暂停/恢复和诊断导出实机检查。

当前目标 API 36 已满足 Google Play 自 2026 年 8 月 31 日起对新应用与更新的要求；16 KiB 闸门对应 2025 年 11 月 1 日起实施的 64 位设备兼容要求。参考官方的 [目标 API 要求](https://developer.android.com/google/play/requirements/target-sdk)、[16 KiB 页面兼容指南](https://developer.android.com/guide/practices/page-sizes)、Godot [Android 导出](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_android.html) 与 [Gradle 构建](https://docs.godotengine.org/en/4.7/tutorials/export/android_gradle_build.html) 文档。

## 4. 人工实机验收

至少覆盖一台 Android 7—10 低端机或模拟器、一台 Android 14 以上真机，并逐项记录：

- 首次启动、无存档启动、旧存档迁移、三个存档槽切换、覆盖和删除；
- 截断、字段类型损坏、人口/军籍越界、伤员队列不一致或事件选项异常时拒绝主存档并回退上一份有效备份；
- 应用切后台再恢复、锁屏恢复、强杀后恢复、离线启动；
- 系统返回键不能跳过教程、事件或战报；设置和二次确认可安全返回，主界面需先确认再保存退出；
- 停时状态不推进日期，主动推进后经济、季节、事件与敌袭只结算一次；
- 建造和每级升级的外观、粒子、数值与账本同步变化；水利、军民、伤营、近敌常驻状态及日结反馈准确；
- 春夏秋冬四首背景音乐无明显循环爆音，换季无突跳，音乐/音效/静音/振动设置重启后保留；
- 事件无资源时不能获得免费收益，战斗兵力与伤亡账目可读；
- 全屏竖屏布局无系统栏遮挡，长中文与最小支持屏幕不溢出；
- 内嵌中文字体在无 CJK 系统字体的环境中也无缺字方框，OFL 许可证随安装包分发；
- 诊断报告只能由玩家主动导出，不会联网或自动上传。

## 5. 商店资料与合规

`store/` 已包含 512×512 应用图标、五张 1080×1920 实机比例截图、1024×500 宣传图、中文短说明和完整说明、版本说明、隐私政策正文及图片替代文字。截图覆盖三季城景、侦察推演和政令经营；素材规格与重新生成命令见 `store/README.md`，Play Console 填写顺序见 `store/play-console-checklist.md`。

公开发布前仍需发布主体人工完成：在 Play Console 完成开发者身份验证并登记 `com.qinghe.farmer` 包名，填写法定名称和客服邮箱、把隐私政策部署到无需登录的公开 HTTPS 地址、回答内容分级和目标年龄问卷、确认数据安全表、确认版权/商标归属、选择价格和国家/地区，并通过内部测试轨道。Android 开发者验证将从 2026 年 9 月起首先在新加坡、泰国、巴西和印度尼西亚实施，详见 Google 的 [Play Console 验证指南](https://developer.android.com/developer-verification/guides/pdf-guides/pdc-guide.pdf)。当前游戏离线运行，不请求联网权限；存档、设置和诊断均留在应用私有目录，诊断只能由玩家主动复制分享。

替换占位符后运行 `python3 tests/store_assets.py --strict-contact`；只有严格模式也通过，商店资料才可进入生产发布。

每次正式候选包都必须递增 versionCode、重跑本清单，并在 Git 中留下对应提交；不要复用已公开发布的版本码。
