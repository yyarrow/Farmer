# 《青禾邑》Android 发布清单

当前候选版本：`0.15.1`（versionCode `18`）
包名：`com.qinghe.farmer`  
最低系统：Android 7.0（API 24）  
目标系统：Android API 36

## 1. 自动验收

在仓库根目录依次执行：

```bash
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/state_smoke.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/architecture_contract.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/full_flow.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/balance_sim.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/order_balance.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/city_placement_engine.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/art_alignment.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/city_grid.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/era_progression.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/era_battle_balance.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/imperial_battle_balance.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/medieval_battle_balance.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/sui_tang_battle_balance.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/late_imperial_battle_balance.gd --audio-driver Dummy
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/ui_smoke.gd --audio-driver Dummy
python3 tests/audio_assets.py
python3 tests/store_assets.py
python3 tools/android_lint_gate.py
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --path . --script tests/visual_capture.gd --audio-driver Dummy --display-driver macos --rendering-driver opengl3 --position 0,0
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --path . --script tests/visual_city_slots.gd --audio-driver Dummy --display-driver macos --rendering-driver opengl3 --position 0,0
```

所有命令必须以 0 退出，并分别出现相应的 `*_OK` 标记。Android lint 闸门固定核对 Godot 4.7 模板的20条已审阅警告；模板在通用资源中保留的 Android 12 系统启动页属性会触发一条 `NewApi`，只有同时存在 API 24–30 使用的无前缀兼容背景项时才允许这一条，任何新增 lint 类型、错误或数量变化都会失败。渲染截图位于 `.qa/`，除既有弹窗、季节和建筑检查外，还需人工核对存档启动首页，以及春秋至清十四时代主城与军务页的称谓、资源单位、兵种、辎重状态和背景一致；城景专项应输出 14 时代×空/半/满三种密度的 42 张画面，另有道路禁建、有效迁建和 v6 八建筑修复布局图。

长期平衡复核：

```bash
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/headless_playtest.gd -- --runs=50 --days=1450 --seed=20260717 --report=res://.qa/headless_0_12_1450d_final.json --strict
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

2026 年 7 月 16 日的 `0.7.0` 最终本地候选验证结果：AAB 41.9 MiB，SHA-256 `e9995ce3dd0ff8e2e605368eafc0e1d512fc04188d3a1fde7cfe7706d53975c0`；独立 APK 41.9 MiB，SHA-256 `c145a405fb2540fb9b7ea4f6caed00e59e4f950add66e88a51cef97bd3f01756`；AAB 派生通用 APK 89.5 MiB，SHA-256 `999b5b2f854acfea24d4ea878cf712da049476cba7b11e41a3442816204ea266`；上传证书 SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。AAB 和两个 APK 的全部 arm64 原生库均通过 16 KiB ELF/ZIP 对齐与 RELRO 检查，APK 与 AAB 均实际编译了 Android 13+ 单色主题图标，AAB 还包含显式的云备份与设备迁移排除规则。包内清单确认军令鼓点和四首 96 秒配乐已经随运行资源打包，正式包只含编译后的运行脚本，不含测试、文档、工具或商店素材。八张建筑图仍保留约三倍屏幕采样精度；春夏秋冬四首配乐共 384 秒，最差循环接缝为 0.0040，四个段落的最大相关性 0.6797、最大响度差 1.067 倍、内部衔接跳变 0.0144。540×960 真实渲染新增覆盖开场说明、状态化首战备忘、容量账簿与建筑下一阶预览，并继续覆盖四种阵令选择态、兵营旗阵、侦察边界与最长战报，均无文字截断。Android 35 冷启动、后台恢复与内存压力数据来自前一版 `0.5.0` 运行基线，本段不把它冒充为 `0.7.0` 实机证据；按本仓库只写边界，本轮没有改动仓库外模拟器状态。

2026 年 7 月 16 日的 `0.8.0` 本地候选验证结果：AAB 44.0 MiB，SHA-256 `2c755a17b50cfca68d6004a49a94ff5f5f19dc086d2a32bab91a5ad1cd666236`；独立 APK 44.1 MiB，SHA-256 `e8cb9a116befb3efac984e336ea9de349f44e2105f566b5c76522f88540c119c`；上传证书延续为 SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。AAB 通过 bundletool、arm64 单架构、16 KiB 页面/ZIP 对齐与 RELRO 验证；APK 通过版本9/0.8.0、包名、竖屏、权限、签名、主题图标、字体许可和开发文件排除检查。真实540×960渲染新增春秋三级城池缩放、横向巡视、战国精绘主城、战国军务与时代完成页；字体递归扫描覆盖全部子目录文案。无界面严格长测运行1000局×180日，全部进入战国，平衡警告和状态错误均为0；跨时代专项另完成12000次战国首战推演。ADB 检查时没有已启动设备；为遵守本轮仅修改仓库文件的边界，没有启动或改写仓库外 AVD，因此本段不把包结构验证写成新一轮实机证据。

2026年7月17日的`0.9.0`秦汉候选验证结果：AAB 48.2 MiB，SHA-256 `59bc0f143c01c02314bfcf98bd4581536e04bd3f015da3f97ef366020ab668b9`；独立 APK 48.3 MiB，SHA-256 `c7d37f483684770e7f951f65e09e1b4d8f46d738513ad8c84073766282c7a8c0`；上传证书延续为 SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。AAB通过bundletool、arm64单架构、16 KiB页面对齐与RELRO验证；APK通过版本10/0.9.0、包名、竖屏、权限、签名、主题图标和开发文件排除检查。真实540×960渲染覆盖四时代，并为秦汉各生成无遮挡的城建/军务画面和商店截图。秦汉六格专项共18000次战斗推演；四策略共400局×320日长期测试平衡警告0、状态错误0，三条正常路线抵达汉的比例为95%—100%。

2026年7月17日的`0.10.0`三国至南北朝候选验证结果：AAB 54.8 MiB，SHA-256 `a33965a907de88e44248f28d78f6218deb12040cbfbdc8a774370a4148e1d46d`；独立APK 54.8 MiB，SHA-256 `a53401027c271dc0d8e4f4a0ee397c932945e31e91f9e1a64c4b1566dca7b576`；上传证书延续为SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。AAB通过bundletool、arm64单架构、16 KiB页面对齐与RELRO验证；APK通过版本11/0.10.0、包名、竖屏、权限、签名、主题图标和开发文件排除检查。真实540×960渲染覆盖七时代，新增三国、晋、南北朝各一套无遮挡城建/军务画面；三时代九格专项共27000次战斗推演。四策略共200局×700日长期测试平衡警告0、状态错误0，三条正常路线抵达南北朝的比例为96%—100%。

2026年7月17日的`0.11.0`隋唐五代候选验证结果：AAB 61.0 MiB，SHA-256 `c0b4fdb15eb7152d4e37dd75cd597125867b65fd47a8ca79cec470a448784ff3`；独立APK 61.1 MiB，SHA-256 `bf860b7832047d90810da987ab3ac0f82553a5648f8a7c557706dc4056d411cd`；上传证书延续为SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。AAB通过bundletool、arm64单架构、16 KiB页面对齐与RELRO验证；APK通过版本12/0.11.0、包名、竖屏、权限、签名、主题图标和开发文件排除检查。真实540×960渲染覆盖十时代，新增隋、唐、五代各一套无遮挡城建/军务画面；三时代九格专项共27000次战斗推演。四策略共200局×950日长期测试平衡警告0、状态错误0，三条正常路线抵达五代的比例为94%—100%。

2026年7月17日的`0.12.0`宋元明清候选验证结果：AAB 68.3 MiB，SHA-256 `e898e9942612da553cf65abc54dc2e994c6c3995f662ea96f227ae69ea005c0d`；独立APK 68.3 MiB，SHA-256 `1ac03349cc651518492ac0f39b32f71c54dc3326031632b24a8607aa435efaf8`；上传证书延续为SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。AAB通过bundletool、arm64单架构、16 KiB页面对齐与RELRO验证；APK通过版本13/0.12.0、包名、竖屏、权限、签名、主题图标和开发文件排除检查。真实540×960渲染覆盖十四时代，新增宋、元、明、清各一套无遮挡城建/军务画面；四时代十二格专项共36000次战斗推演。四策略共200局×1450日长期严格测试平衡警告0、状态错误0，三条正常路线抵达清均为100%，稳定率为76%—84%，不设防路线抵达清与稳定率均为0%。

2026年7月17日的`0.13.0`自由城建与时代美术候选验证结果：AAB 141.4 MiB，SHA-256 `9cb1e1c11e1e1b9d3a4f9b5240e701b3eb0c91f4c50e706b8b53fdb47bee6040`；独立APK 141.5 MiB，SHA-256 `f8c085c690b2664a9e23551b2919aae3b8d135afa73646064e76276c857c79fa`；AAB派生通用APK 189.0 MiB，SHA-256 `71b7bdca2b841c368eb6e06cc0a1e74c59d61021ae3040c9c6f9c1fe2b02b26a`；上传证书仍为SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。三个包均通过签名、权限、arm64单架构、16 KiB页面/ZIP对齐、RELRO、竖屏、主题图标、字体许可和开发文件排除检查，AAB另通过bundletool，Android lint通过固定20条模板警告闸门。运行时包含十四时代×八建筑的112张四阶段透明素材，单阶段384 px、约为最大屏幕显示的三倍。真实540×960渲染除完整界面回归外，另生成十四时代的空城、六建筑和十二建筑共42张锚地验收图，背景地块、点击热区、落脚线、透视方向和HUD层级共享布局并逐时代核对。四策略共200局×1450日严格长测平衡警告0、状态错误0，三条正常路线抵达清均为100%，稳定率为76%—88%。ADB检查时没有已启动设备；遵守只修改仓库文件的边界，本轮没有启动仓库外AVD，因此不把包结构验收写成模拟器实机证据。

2026年7月18日的`0.14.0`网格城建候选验证结果：AAB 137.5 MiB，SHA-256 `511b85b360e255fe01a9b36fef0707c4ca4d70d384748664d2ae8583c93b2a71`；独立APK 137.5 MiB，SHA-256 `2a1383293a20cf1e10d4016915ca8d684434608ca586914e0d88db071e8eae6d`；上传证书延续为SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。两个包均通过版本15/0.14.0、签名、权限、arm64单架构、16 KiB页面/ZIP对齐、RELRO、竖屏、主题图标、字体许可和开发文件排除检查，AAB另通过bundletool，Android lint通过固定20条模板警告闸门。包内仅保留十四张连续空地地形，旧的固定锚地骨架不再导出。渲染验收覆盖十四时代×空/半/满三种密度共42张和道路禁建/有效迁建2张；15×12网格、12格大道、8种占地、12座最大容量、v5→v6迁移和异常坐标拒绝均通过专项测试。四策略共200局×1450日严格长测平衡警告0、状态错误0，三条正常路线抵达清均为100%，稳定率为74%—80%。ADB检查时没有已启动设备，本轮不写入模拟器冷启动证据。

2026年7月18日的`0.14.1`存档与启动修复候选验证结果：AAB 137.5 MiB，SHA-256 `698be12d7cd02513bbbe5b44c3829b17f4cd60905640d31e91ac97fdf17e81ca`；独立 APK 137.5 MiB，SHA-256 `03395aa7a16ea8aeaa0cac445bf77d63853f6905b0c0fafd607e1fdc488701c4`；上传证书延续为 SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。两个包均通过版本16/0.14.1、签名、权限、arm64单架构、16 KiB页面/ZIP对齐、RELRO、竖屏、主题图标、字体许可和开发文件排除检查，AAB另通过bundletool，Android lint仍为固定20条模板警告。v5/v6 存档升级到 v7 时只修复建筑网格位置，不改实例 ID、类型、等级、资源、军队或进度；八座存量建筑验收图覆盖大道两侧与三个纵深且无重叠。冷启动改为本地存档首页，自动档、三个手动档、新城邑与声音设置均可直接进入；选择进度前模拟和自动保存停止，回归测试核对原自动档字节不被预览状态覆盖。

2026年7月18日的`0.15.0`独立城建放置引擎候选验证结果：AAB 137.5 MiB，SHA-256 `aab4c22b335316778331e210ccadb52e8afc263b36e03f93af90a72eb758e3ac`；独立 APK 137.6 MiB，SHA-256 `3cdac108a97f2b661be631cd311e51efeaea55f9e65eea25454d4eefad1d363c`；上传证书延续为 SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。两个包均通过版本17/0.15.0、签名、权限、arm64单架构、16 KiB页面/ZIP对齐、RELRO、竖屏、主题图标、字体许可和开发文件排除检查，AAB另通过bundletool，Android lint仍为固定20条模板警告。纯放置引擎、建筑视觉档案、评分求解器和城景视口变换分层落地；6/9/12座布局均保持实例完整、严重院落冲突0，并限制大道遮挡、HUD越界和边缘裁切。真实渲染覆盖十四时代空/半/满城42张，另含战国九座最高阶段普通图与几何调试图。v5至v7旧档升级到v8只重排坐标，逐项保留建筑身份、等级、资源、军队和日期。本轮未连接或启动Android设备，因此不把包结构与本地渲染验收写成实机证据。

2026年7月19日的`0.15.1`建筑贴地修复候选验证结果：AAB 137.5 MiB，SHA-256 `d33636020e7727a9fd993fcf47dbca6a4c1f9e1cb9105ab6fb1d7169a5395f10`；独立 APK 137.6 MiB，SHA-256 `f94da83926509de007cfd2ecbb3d71960c5ce9fef02463167cca6847bd50f3cf`；上传证书延续为 SHA-256 `62837ae6fb7a7281d5ef5f39dcd9189db0ef8e1075b237a9e7f93a86e8eaae1f`。两个包均通过版本18/0.15.1、签名、权限、arm64单架构、16 KiB页面/ZIP对齐、RELRO、竖屏、主题图标、字体许可和开发文件排除检查，AAB另通过bundletool，Android lint仍为固定20条模板警告。新增逐帧素材接地点测量，贴图、点击区域和升级缩放统一绑定可见地面接点；十四时代×八建筑×四阶段共448帧通过自动贴地检查，最大原始透明底边为128像素。真实540×960渲染重新覆盖十四时代空/半/满城42张，战国最高阶段农田的素材接点与格子锚点重合，未重制现有建筑素材。本轮未连接或启动Android设备，因此不把包结构与本地渲染验收写成实机证据。

功能回归仍覆盖 720×1280 小屏、教程到第 3 日的新事件结算、系统返回键的教程与事件拦截、设置关闭、危险操作取消、退出确认取消和保存退出；教程状态可跨重启保留。音频自动测试额外覆盖四首曲目均为独立内容、循环点、换季双轨重叠、等功率淡化、战斗压低并发与旧曲释放。

本地 AAB 工程闸门已经通过；正式公开发布仍必须先上传 Play Console 内部测试轨道，并用 Play 实际分发的安装包完成冷启动、存档、战斗、音量、暂停/恢复和诊断导出实机检查。

当前目标 API 36 已满足 Google Play 自 2026 年 8 月 31 日起对新应用与更新的要求；16 KiB 闸门对应 2025 年 11 月 1 日起实施的 64 位设备兼容要求。参考官方的 [目标 API 要求](https://developer.android.com/google/play/requirements/target-sdk)、[16 KiB 页面兼容指南](https://developer.android.com/guide/practices/page-sizes)、Godot [Android 导出](https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_android.html) 与 [Gradle 构建](https://docs.godotengine.org/en/4.7/tutorials/export/android_gradle_build.html) 文档。

## 4. 人工实机验收

至少覆盖一台 Android 7—10 低端机或模拟器、一台 Android 14 以上真机，并逐项记录：

- 首次启动先显示存档首页；无存档、新建城邑、自动档继续、三个手动档切换、覆盖和删除；选择具体进度前日期不推进且自动档不改写；
- 首战备忘依次随补兵、建防、侦察和推演状态更新，首胜后消失；设置可重看说明，重新开始会恢复首次说明；
- 截断、字段类型损坏、人口/军籍越界、伤员队列不一致或事件选项异常时拒绝主存档并回退上一份有效备份；
- 应用切后台再恢复、锁屏恢复、强杀后恢复、离线启动；
- 系统返回键不能跳过教程、事件或战报；设置和二次确认可安全返回，主界面需先确认再保存退出；
- 停时状态不推进日期，主动推进后经济、季节、事件与敌袭只结算一次；
- 建造和每级升级的外观、粒子、当前/下一阶效果与账本同步变化；库存与仓容并列可读；水利、军民、伤营、近敌常驻状态及日结反馈准确；
- 春夏秋冬四首背景音乐无明显循环爆音，换季无突跳，音乐/音效/静音/振动设置重启后保留；
- 事件无资源时不能获得免费收益；守城与巡剿按兵种显示阵亡、负伤、敌损和余部，且战前兵力、损失与余部可以逐项核对；
- 四种守城阵令的推演、真实战损、战报、军令鼓点、兵营旗色与士卒队形同步变化；
- 全屏竖屏布局无系统栏遮挡，长中文与最小支持屏幕不溢出；
- 内嵌中文字体在无 CJK 系统字体的环境中也无缺字方框，OFL 许可证随安装包分发；
- 设置页可离线查看 Godot MIT、引擎第三方组件版权与许可全文，以及 Qinghe Sans SC 的 SIL OFL 1.1；
- 诊断报告只能由玩家主动导出，不会联网或自动上传。

开源许可页使用 Godot 当前运行时提供的许可与版权表，避免升级引擎后静态清单过期；实现依据 Godot 官方的[许可合规指南](https://docs.godotengine.org/en/stable/about/complying_with_licenses.html)。

## 5. 商店资料与合规

`store/` 已包含 512×512 应用图标、八张 1080×1920 实机比例截图、1024×500 宣传图、中文短说明和完整说明、版本说明、隐私政策正文及图片替代文字。截图覆盖三季城景、战国/秦/汉城郭、侦察推演和政令经营；素材规格与重新生成命令见 `store/README.md`，Play Console 填写顺序见 `store/play-console-checklist.md`。

公开发布前仍需发布主体人工完成：在 Play Console 完成开发者身份验证并登记 `com.qinghe.farmer` 包名，填写法定名称和客服邮箱、把隐私政策部署到无需登录的公开 HTTPS 地址、回答内容分级和目标年龄问卷、确认数据安全表、确认版权/商标归属、选择价格和国家/地区，并通过内部测试轨道。Android 开发者验证将从 2026 年 9 月起首先在新加坡、泰国、巴西和印度尼西亚实施，详见 Google 的 [Play Console 验证指南](https://developer.android.com/developer-verification/guides/pdf-guides/pdc-guide.pdf)。当前游戏离线运行，不请求联网权限；存档、设置和诊断均留在应用私有目录，诊断只能由玩家主动复制分享。

替换占位符后运行 `python3 tests/store_assets.py --strict-contact`；只有严格模式也通过，商店资料才可进入生产发布。

每次正式候选包都必须递增 versionCode、重跑本清单，并在 Git 中留下对应提交；不要复用已公开发布的版本码。
