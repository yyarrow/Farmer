# 代码架构

当前重构以“保留 `State` 公共 API、把可变状态与纯规则分开”为原则。场景和测试仍可调用原有接口，数值系统则可以脱离界面进行固定种子模拟。

```mermaid
flowchart TD
    Main["main.gd\n界面协调"] --> State["game_state.gd\n状态门面与流程编排"]
    Main --> UI["ui/\n组件、格式化、首战引导"]
    Main --> Visuals["city_visuals.gd\n城景状态与反馈"]
    State --> Era["data/era_schema.gd + data/eras/\n时代规范与配置"]
    State --> Systems["systems/\n经济、战斗、发展纯规则"]
    State --> Persistence["persistence/\n原子写入、校验、迁移"]
    Visuals --> Layout["city_placement/\n网格、自动道路、独立城防、评分求解与视口"]
    Layout --> Roads["road_network.gd\n2× 微网格与自动接路"]
    Layout --> Defense["defense_layout.gd\n城域边界、城门与墙段"]
    Layout --> Facade["data/city_layout.gd\n兼容门面"]
```

## 边界

- `src/game_state.gd`：唯一的运行时状态门面，负责日期推进、行为编排、信号、音效和埋点；启动阶段保持会话未激活，只有玩家明确载入或新建进度后才运行模拟与自动存档；旧调用方无需改名。
- `src/data/era_registry.gd`：时代顺序与配置入口；`State` 只通过注册表切换目录。
- `src/data/era_schema.gd`：时代配置 V2 的规范化层，为称谓、辎重、经济倍率、战役间隔、市易、政令和叙事提供完整默认值；旧目录缺字段时仍可安全读取。
- `src/data/eras/`：春秋至清的十四套目录分别声明城池等级、建筑、兵种、敌军、阵令、资源单位、绘卷背景、事件、辎重、战役节奏、经济和初始值。工厂方法每次返回独立可变数据。
- `src/systems/`：不读取全局单例的纯规则。经济账本、容量、交易、战斗和繁荣度均可无界面调用。
- `src/persistence/`：存档文件原子替换和备份恢复、结构/跨字段校验、旧版本迁移；`State` 只保留兼容门面和错误埋点。
- `src/ui/`：统一颜色与组件、数值文案格式化、首战状态引导；`main.gd` 负责页面生命周期和交互连接。
- `src/city_placement/`：独立纯放置引擎。`placement_engine.gd` 定义 15×12 等距宏网格、逻辑占地、最高等级视觉包围盒、院落安全带和 HUD 安全区；`road_network.gd` 在 2× 微网格上从每栋建筑的显式入口确定性接到城门，不持久化道路；`defense_layout.gd` 按 6/9/12 容量生成城域边界、城门、墙段与角楼；`building_profiles.gd` 和 `footprint_templates.gd` 管理成长尺寸与标准菱形基座；`art_alignment.gd` 提取透明素材的可见地面接点；`placement_solver.gd` 以硬碰撞和软拥挤评分安排城池；`city_view_transform.gd` 统一镜头缩放与横向巡视边界。
- `src/data/city_layout.gd`：基础设施感知的兼容门面，保留旧 API、v5 十二槽位 ID 和旧档入口；渲染、触控、放置、迁建、存档与校验均从这里消费同一份位置、城门避让和道路可达性真相。

## 扩展约束

时代与城池双成长已经落地。每个新朝代提供与 `spring_autumn.gd` 同结构的目录配置，并在 `era_registry.gd` 中登记顺序；注册表先经 `EraSchema.normalize()` 补全配置，时代切换器只改变当前目录，不把朝代判断散落到经济、战斗或 UI。三个内部兵种 ID 只表示近战、远射、机动三个可跨时代继承的军籍角色；显示名称、计数单位、编制称谓、战力、维持、征募、敌军称谓及辎重负载均由时代配置决定。四个资源 ID 同理保持稳定，玩家看到的名称、简称和计量单位可随时代改变。城池等级是同一时代内的空间成长，配置建设容量、繁荣目标、城景缩放与可见范围；容量提升同时扩大网格可建区域。

经济、辎重与战役节奏都由正式系统消费配置，而不只是换文案：`EconomySystem` 应用各时代生产倍率、仓容、人口与军籍容量；`BattleSystem` 读取当前兵种的近战/远射参数；`State.get_logistics_status()` 根据仓廪、市易、采运设施与各兵种负载计算承载率，超载会实际降低训练效能；`battle_pacing` 控制时代化的围城间隔与败后整顿。UI、存档校验和无界面玩家共享这些入口。

存档 v5 在 v4 的 `era_id`、`era_progress` 与 `city_level` 之上新增 `building_instances`；v6 将固定槽位改为 `grid_origin` 网格坐标；v7 修复早期迁移的前排拥挤；v8 由视觉求解器按最高等级外观、院落间距和界面安全区重排；v9 将城垣迁移为独立 `defense_level`，移除普通建筑中的 wall 实例，并把其他建筑重排到不占城门且可自动接路的位置。迁移不修改普通建筑实例 ID、类型、等级或经营数值；求解失败时拒绝覆盖原档。道路完全由当前建筑入口与城门派生，不写入存档；同类生产建筑可重复营造，独立城防不占 6/9/12 普通建设容量，`buildings` 聚合值只供经济和旧 API 兼容。当前格式校验同时拒绝逻辑重叠、城门冲突、道路不可达和严重视觉冲突。

新增规则应先进入 `systems/` 并通过无界面测试，再由 `State` 编排，最后接入 UI 和城景反馈。存档字段变化必须提升格式版本并在 `save_migrator.gd` 中提供迁移。
