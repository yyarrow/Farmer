# 《青禾邑》商店素材

本目录保存 Google Play 简体中文商品详情页的可提交素材。PNG 均由仓库内脚本生成，不依赖网络服务。

## 图像

| 文件 | 尺寸与格式 | 图片替代文字 |
| --- | --- | --- |
| `icon-512.png` | 512×512，RGBA PNG | 米金底色的青禾邑图标，朱红圆印中是一座长出双叶的古代城门。 |
| `feature-graphic.png` | 1024×500，RGB PNG | 春日古邑绘卷，左侧题有青禾邑和四时耕战，一邑春秋，右侧展现城镇与田野。 |
| `screenshots/01-spring-city.png` | 1080×1920，RGB PNG | 春季城邑总览，展示粮木石币、八类建筑、敌军预警和竖屏经营界面。 |
| `screenshots/02-autumn-city.png` | 1080×1920，RGB PNG | 秋季成熟城邑，建筑已升级，金黄田野中显示经营资源和守城压力。 |
| `screenshots/03-winter-city.png` | 1080×1920，RGB PNG | 冬季雪景城邑，展示四季色调、完整建筑外观和持续的军政经营。 |
| `screenshots/04-military-intelligence.png` | 1080×1920，RGB PNG | 军务页展示侦察后的敌我兵力、守城阵令、精确胜算与预计伤亡。 |
| `screenshots/05-governance-policy.png` | 1080×1920，RGB PNG | 政事页展示轻徭薄赋、犒赏三军的资源成本、实际收益与城邑晋升。 |
| `screenshots/06-warring-city.png` | 1080×1920，RGB PNG | 战国县城总览，展示扩展后的夯土城郭、密集坊署、赤旗军阵与战国建筑称谓。 |

替代文字均少于 140 个字符，可直接填写到 Play Console 的对应素材项。

重新生成：

```bash
HOME="$PWD/.home" ./tools/godot/Godot.app/Contents/MacOS/Godot \
  --path . --script tools/generate_store_assets.gd --audio-driver Dummy \
  --display-driver macos --rendering-driver opengl3
```

脚本以 `assets/icon.svg` 和 `.qa/visual_*.png` 为来源；先运行 `tests/visual_capture.gd` 可更新六张实际游戏截图。所有商店素材都被 Android 导出预设排除，不会增大安装包。

## 文案与合规

- `listing-zh-CN.md`：应用名称、简短说明、完整说明、分类和关键词。
- `release-notes-zh-CN.txt`：首个公开候选版本的更新说明。
- `privacy-policy.md`：与当前离线实现相符的隐私政策正文。

正式提交前必须把文案中的开发者法定名称、客服邮箱和隐私政策公开 HTTPS 地址替换为真实信息。内容分级、目标年龄和数据安全表必须由发布主体在 Play Console 内确认，不能用占位值发布。
