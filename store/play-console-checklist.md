# Google Play Console 提交清单

此表把仓库中已经有证据的答案与必须由发布主体决定的事项分开，避免在后台凭感觉填写。

## 可由当前构建直接确认

- 应用类型：游戏；分类建议：策略。
- 包名：`com.qinghe.farmer`；版本：`0.14.0`；versionCode：`15`。
- 最低 Android 7.0 / API 24；目标 API 36；仅 arm64-v8a。目标版本满足 Google Play 自 2026 年 8 月 31 日起的新应用与更新要求。
- 两个原生库均通过 16 KiB ELF `LOAD` 对齐、RELRO 与派生 APK ZIP 对齐检查；AAB 声明 `PAGE_ALIGNMENT_16K`。
- 发布包：`build/Qinghe.aab`；必须先启用 Play App Signing，并妥善保管 `.release/` 中的上传密钥。
- 登录或受限访问：无；所有玩法离线可用。
- 广告：无。
- 应用内购买与订阅：无。
- 网络权限：无；Android 清单只声明振动权限。
- 自动收集或共享：无。存档、设置和滚动诊断记录只留在应用私有目录；AAB 明确排除 Android 云备份和设备迁移，诊断仅在玩家主动复制后，才可能由玩家通过其他应用发送。
- 商店文案：`listing-zh-CN.md`；版本说明：`release-notes-zh-CN.txt`。
- 图标、宣传图、八张截图及替代文字：见 `README.md`。
- 隐私政策正文：`privacy-policy.md`。
- 开源许可：游戏设置页可离线查看 Godot MIT、引擎第三方组件版权/许可全文及字体 SIL OFL 1.1。

## 必须由发布主体填写或确认

- 开发者/发行主体法定名称、公开客服邮箱、客服电话或网站（如适用）。
- 在 Play Console 完成开发者身份验证并登记 `com.qinghe.farmer` 包名；Android 开发者验证将从 2026 年 9 月起首先在新加坡、泰国、巴西和印度尼西亚实施。
- 隐私政策的公开 HTTPS 地址；页面必须无需登录即可访问，正文应与仓库版本一致。
- 免费或付费、发布国家/地区、默认语言及版权/商标归属。
- 目标年龄。建议按普通青少年及成人策略游戏审视，但最终范围属于发行决定。
- 内容分级问卷。游戏含文字化战争、兵力、阵亡和伤员，无血腥画面；必须依据各地区问卷原文如实确认。
- 数据安全表。提交前再次核对最终 AAB 是否仍无网络权限和第三方 SDK；若以后增加联网或分析功能，必须同步修改代码、政策和后台披露。
- 面向儿童、新闻、政府、金融、健康等特殊声明：根据真实发行定位回答，不能沿用占位答案。

## 发布顺序

1. 在 Play Console 完成开发者身份验证、创建应用并登记包名，启用 Play App Signing，再上传 AAB。
2. 完成商品详情、应用内容、内容分级、目标受众、数据安全和隐私政策页面。
3. 先发内部测试；从 Play 实际下载并在至少一台 Android 14+ 真机验证冷启动、覆盖更新、暂停不流逝、推进一天、建筑升级、市场、战斗、音量持久化、三个存档槽和诊断导出。
4. 修完预发布报告中的崩溃、ANR、兼容性和布局问题；重新提交时递增 versionCode。
5. 通过封闭/开放测试后再采用分阶段生产发布，先观察崩溃率、ANR 和用户反馈，再逐步扩大覆盖。

政策核对来源：Google 官方的 [目标 API 要求](https://developer.android.com/google/play/requirements/target-sdk)、[16 KiB 页面兼容指南](https://developer.android.com/guide/practices/page-sizes) 与 [Play Console Android 开发者验证指南](https://developer.android.com/developer-verification/guides/pdf-guides/pdc-guide.pdf)。
