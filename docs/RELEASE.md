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
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --path . --script tests/visual_capture.gd --audio-driver Dummy --display-driver macos --rendering-driver opengl3 --position 0,0
```

所有命令必须以 0 退出，并分别出现 `STATE_SMOKE_OK`、`FULL_FLOW_OK`、`BALANCE_SIM_OK`、`UI_SMOKE_OK`、`AUDIO_ASSETS_OK` 和 `VISUAL_CAPTURE_OK`。渲染截图位于 `.qa/`，需人工检查文字无截断、弹窗不遮挡关键操作、春秋冬色调可辨认、建筑 0—5 级均有可见差异。

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

## 3. Google Play AAB 闸门

Google Play 新应用需提交 AAB。Godot 的 AAB 导出依赖项目内的 Android Gradle Build template；当前仓库没有该模板，因此签名 APK 可用于本地验收和其他 APK 渠道，但在完成下列事项前不得宣称 Google Play 包已经就绪：

1. 使用与编辑器完全一致的 Godot 4.7 Android build template；
2. 在 Godot 中安装 Gradle build template，确认生成 `res://android/build`；
3. 新增签名 AAB 导出预设并输出 `build/Qinghe.aab`；
4. 用 `bundletool validate` 校验 AAB；
5. 在 Play Console 内部测试轨道安装，完成冷启动、存档、战斗、音量、暂停/恢复和诊断导出实机检查。

参考：Godot 官方的 [Android 导出](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_android.html) 与 [Gradle 构建](https://docs.godotengine.org/en/4.7/tutorials/export/android_gradle_build.html) 文档。

## 4. 人工实机验收

至少覆盖一台 Android 7—10 低端机或模拟器、一台 Android 14 以上真机，并逐项记录：

- 首次启动、无存档启动、旧存档迁移、三个存档槽切换、覆盖和删除；
- 应用切后台再恢复、锁屏恢复、强杀后恢复、离线启动；
- 停时状态不推进日期，主动推进后经济、季节、事件与敌袭只结算一次；
- 建造和每级升级的外观、粒子、数值与账本同步变化；
- 背景音乐无明显循环爆音，音乐/音效/振动开关重启后保留；
- 事件无资源时不能获得免费收益，战斗兵力与伤亡账目可读；
- 全屏竖屏布局无系统栏遮挡，长中文与最小支持屏幕不溢出；
- 诊断报告只能由玩家主动导出，不会联网或自动上传。

## 5. 商店资料与合规

公开发布前还需准备并人工确认：应用图标、至少两张手机截图、1024×500 宣传图、中文短说明和完整说明、内容分级问卷、目标年龄、数据安全表、隐私政策公开链接、客服邮箱以及版权/商标归属。当前游戏离线运行，不请求联网权限；存档、设置和诊断均留在应用私有目录，诊断只能由玩家主动复制分享。

每次正式候选包都必须递增 versionCode、重跑本清单，并在 Git 中留下对应提交；不要复用已公开发布的版本码。
