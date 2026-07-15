# 《青禾邑》Android 发布清单

当前候选版本：`0.4.0`（versionCode `5`）  
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
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --path . --script tests/visual_capture.gd --audio-driver Dummy --display-driver macos --rendering-driver opengl3 --position 0,0
```

所有命令必须以 0 退出，并分别出现 `STATE_SMOKE_OK`、`FULL_FLOW_OK`、`BALANCE_SIM_OK`、`UI_SMOKE_OK`、`AUDIO_ASSETS_OK`、`STORE_ASSETS_OK` 和 `VISUAL_CAPTURE_OK`。渲染截图位于 `.qa/`，需人工检查文字无截断、退出确认与最长事件选项弹窗不遮挡关键操作、春秋冬色调可辨认、建筑 0—5 级均有可见差异。

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

脚本会按需安装被 Git 忽略的 `android/build/` Gradle template，并自动检查 ZIP 完整性、arm64 架构、版本、包名、SDK、权限、启动入口、竖屏、非调试状态、JAR 签名和上传证书；随后调用 `bundletool validate`。`--universal-apk` 还会生成 `build/Qinghe-universal.apks`，提取 `build/Qinghe-from-aab.apk`，再执行与正式 APK 相同的清单和签名验证。脚本不会打印签名密码。

2026 年 7 月 16 日的本地候选验证结果：四季配乐版 AAB 37.8 MiB，SHA-256 `552e23ae678e3276426c4214a90662375c9a98a9c38c827256aa285034909cd9`；独立 APK SHA-256 `d27466cafcd24ca3d7f1d22947f81d87fc06657fc6007fe1fd41f29f5cdac501`，AAB 派生 APK SHA-256 `ae509d78771762a9f1edb79dfd84a2bc027891ce7a4989d833ec8ffbb2ea1974`，上传证书 SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。八张建筑图仍保留约三倍屏幕采样精度；春夏秋冬四首配乐共 192 秒，最差循环接缝为 0.0040。Android 35 清数据冷启动为 209 ms，设置页 PSS 约 158 MiB，`RUNNING_CRITICAL` 内存压力后的热恢复为 36 ms；1080×2400 设置页、音量项和四时换曲说明均无截断。切后台瞬间 SwiftShader 模拟器记录过一次已断开绘图表面的 `EGL_BAD_SURFACE`，恢复稳定后的进程错误级日志为空，未见崩溃、ANR 或 Godot 脚本错误，仍须按下文在实体设备复核后台恢复。

功能回归仍覆盖 720×1280 小屏、教程到第 3 日的新事件结算、系统返回键的教程与事件拦截、设置关闭、危险操作取消、退出确认取消和保存退出；教程状态可跨重启保留。音频自动测试额外覆盖四首曲目均为独立内容、循环点、换季双轨重叠、等功率淡化、战斗压低并发与旧曲释放。

本地 AAB 工程闸门已经通过；正式公开发布仍必须先上传 Play Console 内部测试轨道，并用 Play 实际分发的安装包完成冷启动、存档、战斗、音量、暂停/恢复和诊断导出实机检查。

参考：Godot 官方的 [Android 导出](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_android.html) 与 [Gradle 构建](https://docs.godotengine.org/en/4.7/tutorials/export/android_gradle_build.html) 文档。

## 4. 人工实机验收

至少覆盖一台 Android 7—10 低端机或模拟器、一台 Android 14 以上真机，并逐项记录：

- 首次启动、无存档启动、旧存档迁移、三个存档槽切换、覆盖和删除；
- 应用切后台再恢复、锁屏恢复、强杀后恢复、离线启动；
- 系统返回键不能跳过教程、事件或战报；设置和二次确认可安全返回，主界面需先确认再保存退出；
- 停时状态不推进日期，主动推进后经济、季节、事件与敌袭只结算一次；
- 建造和每级升级的外观、粒子、数值与账本同步变化；
- 春夏秋冬四首背景音乐无明显循环爆音，换季无突跳，音乐/音效/静音/振动设置重启后保留；
- 事件无资源时不能获得免费收益，战斗兵力与伤亡账目可读；
- 全屏竖屏布局无系统栏遮挡，长中文与最小支持屏幕不溢出；
- 内嵌中文字体在无 CJK 系统字体的环境中也无缺字方框，OFL 许可证随安装包分发；
- 诊断报告只能由玩家主动导出，不会联网或自动上传。

## 5. 商店资料与合规

`store/` 已包含 512×512 应用图标、三张 1080×1920 实机比例截图、1024×500 宣传图、中文短说明和完整说明、版本说明、隐私政策正文及图片替代文字。素材规格与重新生成命令见 `store/README.md`，Play Console 填写顺序见 `store/play-console-checklist.md`。

公开发布前仍需发布主体人工完成：填写法定名称和客服邮箱、把隐私政策部署到无需登录的公开 HTTPS 地址、回答内容分级和目标年龄问卷、确认数据安全表、确认版权/商标归属、选择价格和国家/地区，并通过内部测试轨道。当前游戏离线运行，不请求联网权限；存档、设置和诊断均留在应用私有目录，诊断只能由玩家主动复制分享。

替换占位符后运行 `python3 tests/store_assets.py --strict-contact`；只有严格模式也通过，商店资料才可进入生产发布。

每次正式候选包都必须递增 versionCode、重跑本清单，并在 Git 中留下对应提交；不要复用已公开发布的版本码。
