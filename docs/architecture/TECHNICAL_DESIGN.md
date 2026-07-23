# 土豆教练技术设计

版本：0.1
状态：P0 基线
日期：2026-07-24

## 1. 技术目标

第一版必须在 Brotato 游戏内提供完全离线、按按钮触发的教练分析，同时保留外部分析工具用于
规则开发和回归测试。外部 CLI 不是用户闭环；P1 MVP 的完成条件包含商店、暂停菜单和结算界面
三个游戏内入口。记录器只采集教练判断所需的波次聚合数据，不记录逐帧移动、逐次命中或敌人实例。

技术基线：

- Brotato：`1.1.15.4`
- 游戏资源：Godot 3.7 格式
- 本地工具：Godot 3.6.1
- RunTracker 研究版本：`1.2.3`
- ModLoader：使用脚本扩展与翻译注册能力，不修改游戏 PCK
- 本机开发限制：当前没有可用于 headless 项目测试的独立 Godot 3.x CLI；不得把 `Brotato.exe`
  当作编辑器或测试运行时。

## 2. 架构

```text
Game UI Adapter
      |
      v
CoachCoordinator --------------------+
      |                              |
      +--> CoachStateReader          +--> AdvicePresenter
      |         |                    |
      +--> CoachRecorder             |
      |         |                    |
      +--> OfflineRuleEngine --------+
               |
               +--> Character Profiles
               +--> Item/Weapon Knowledge
               +--> Wave Target Curves
               +--> Explanation Templates
```

### 2.1 模块职责

| 模块 | 职责 | 禁止事项 |
|---|---|---|
| `Game UI Adapter` | 注入按钮、打开/关闭面板、处理键鼠和手柄焦点 | 不做规则计算，不读写存档 |
| `CoachCoordinator` | 组织采集、缓存、分析和呈现 | 不包含角色特例 |
| `CoachStateReader` | 从 `RunData`、`Utils` 和当前商店节点生成标准快照 | 不调用会重置全局状态的函数 |
| `CoachRecorder` | 在生命周期边界写明文 JSONL 和最终汇总 | 不上传网络，不记录每次命中 |
| `OfflineRuleEngine` | 对纯 Dictionary 输入生成结构化报告 | 不访问场景树，不依赖 ModLoader |
| `AdvicePresenter` | 用本地模板呈现报告 | 不重新判断购买逻辑 |

规则核心必须能在 Godot 之外由固定 JSON 样本调用。游戏适配器、外部工具和测试程序共用
相同的数据契约和规则版本。

### 2.2 临时外部运行时

P1 开发和回归工具可临时使用 Node.js/TypeScript 或其他轻量外部运行时，原因是本机没有稳定
可调用的 Godot 3.x CLI。该运行时只允许用于读取黄金样本、执行回归、生成 JSON/Markdown 报告
和构建本地 Mod ZIP。

游戏内分析仍必须由 GDScript 执行，不调用 Node、AI、网络服务或本机外部进程。规则数据、
`reason_codes`、schema 和纯数据算法必须与 GDScript 适配层解耦，避免 CLI 与 Mod 维护两套业务
规则。

## 3. 游戏内入口

### 3.1 商店分析

扩展候选：`res://ui/menus/shop/base_shop.gd`

- 在 `_ready()` 后延迟一帧定位 `_get_reroll_button(0).get_parent()`。
- 在重掷按钮所在工具栏加入 `CoachAdviceButton`。
- 点击时读取当前四个 `ShopItem` 实例并立即分析。
- 购买、锁定或重掷后，使当前分析缓存失效。
- 注入必须去重；若其他 Mod 已扩展同一脚本，应遵守 ModLoader 继承链，不手动调用父 `_ready()`。

读取顺序：

1. `_get_shop_items_container(player_index)`
2. `get_player_shop_items(player_index)`
3. `ShopItemsContainer._shop_items`
4. 若接口失效则隐藏按钮并记录兼容性警告

商店价格必须读取 `ShopItem.value`，不能根据物品基础价值自行重算。角色修正、折扣、
通货膨胀和其他 Mod 都可能改变实际价格。

### 3.2 局中分析

扩展候选：`res://ui/menus/ingame/ingame_main_menu.gd`

- 在暂停菜单 `_resume_button.get_parent()` 中加入 `CoachAdviceButton`。
- 仅在游戏已暂停时创建快照和面板。
- 若没有可用的商店候选，只输出当前属性缺口、构筑判断和未来规划。
- 注入必须去重；已知 `_wl-WaveInfo` 会扩展该入口，失败时降级并记录警告。

### 3.3 结算复盘

扩展候选：`res://ui/menus/run/end_run.gd`

- `_ready()` 是正常失败、胜利和放弃的统一入口。
- 在 `%NewRunButton` 或 `_new_run_button.get_parent()` 所在按钮行加入
  `CoachReviewButton`。
- 点击时读取本局记录，输出最早成长断档、直接失败原因和下一局改进规则。
- “重试本波”不得被误判为整局结束。
- 注入必须去重；已知 RunTracker 会扩展该入口，失败时降级并记录警告。

## 4. 状态读取

稳定候选：

- `RunData.current_wave/current_difficulty/nb_of_waves/retries`
- `RunData.get_player_character/level/xp/gold`
- `RunData.get_player_current_health/max_health`
- `RunData.get_player_items/weapons/sets/banned_items`
- `RunData.tracked_item_effects`
- `Utils.get_stat(Keys.stat_*_hash, player_index)`
- 武器 `dmg_dealt_last_wave/tier/weapon_id/sets`
- 当前 `ShopItem.item_data/value/wave_value/locked/active`

读取器只读取现有状态。不得调用 `LinkedStats.reset_player()`、重新应用角色效果或任何会改变
缓存、随机数、商品价格、材料和存档的函数。

## 5. 记录策略

记录器使用事件驱动，不启用 `_process`：

| 边界 | 事件 | 内容 |
|---|---|---|
| 新局创建 | `run_started` | 版本、角色、难度、规则包 |
| 波次开始 | `wave_started` | 商店结束后的实际出战属性、装备和材料 |
| 波次结束 | `wave_completed` | 伤害、受伤、回复、经济、武器贡献、重试 |
| 用户点击分析 | `coach_requested` | 当前快照指纹和可选商店候选 |
| 本波重试 | `wave_retried` | 波次、次数、是否回滚到同一构筑 |
| 整局结束 | `run_ended` | 结果、最终状态和数据完整度 |

单局数据写入 `events.jsonl`，每行是一个独立 JSON 对象。最后生成 `run-summary.json`。
若崩溃导致最后一行不完整，加载器丢弃最后一行并保留前面所有有效事件，不接触 Brotato 存档。

## 6. 离线规则引擎

处理管线：

```text
CoachSnapshot
  -> CoverageResolver
  -> BuildClassifier
  -> ShopAdvisor
  -> StatGapAnalyzer
  -> HorizonPlanner
  -> RunReviewer
  -> CoachReport
```

### 6.1 商店建议

对每个候选生成：

- `buy_now`、`lock`、`skip` 或 `defer`
- 购买顺序与预算变化
- 构筑收益、套装阈值、合成收益和机会成本
- 正向理由、主要代价和置信度

使用受预算约束的组合选择，不把单项高分直接拼成超预算购买单。未知 Mod 商品只能使用通用
属性变化和标签规则，不能输出虚构效果。

### 6.2 属性诊断

每个缺口必须包含：

- 当前值和目标区间
- 适用时间窗
- 输出、生存、回复、移动或经济维度
- 与角色、武器或当前阶段的关联
- 证据字段和规则 ID

### 6.3 未来规划

同时输出 `current_wave + 3` 和 `current_wave + 5` 的区间目标。目标覆盖武器结构、输出、
生存、回复、移动和经济。达不到理想目标时必须给出保守降级方案。

### 6.4 结算复盘

复盘按时间线检测：

1. 最早持续偏离目标曲线的波次。
2. 风险属性增长是否转化为收益，例如诅咒、敌人数和开局生命惩罚。
3. 武器贡献是否长期失衡。
4. 成长引擎与延迟收益是否在硬门槛前兑现。
5. 死亡波的直接触发点和更早的运营根因。

## 7. 缓存与状态指纹

相同状态和规则版本必须产生相同报告。缓存键由以下字段组成：

- `snapshot_schema_version`
- `rule_pack_version`
- 当前波次、角色、材料和属性
- 物品、武器、套装和商店候选的稳定排序摘要
- 已记录波次摘要哈希

购买、出售、合成、锁定、重掷、升级和进入新波次都会使缓存失效。不得把显示文本、节点实例
ID 或本机路径放入指纹。

## 8. 性能预算

- 战斗空闲新增平均每帧开销：接近 0
- 单次状态采集目标：`< 5 ms`，硬上限 `12 ms`
- 规则计算目标：`< 3 ms`，P0 验收上限 `100 ms`
- 面板首次构建：`< 16 ms`
- 单局日志目标：`< 2 MB`
- 文件写入：仅生命周期边界，失败时降级并继续游戏

## 9. 兼容性

- 不扩展 `enemy.gd`、`boss.gd`、`unit.gd`、`neutral.gd`。
- 第一版避免扩展已被多个 Mod 占用的 `main.gd`。
- 扩展脚本的 `_ready()` 不手动调用父 `_ready()`；ModLoader 会处理分层生命周期。
- 覆盖普通行为时只调用一次父实现。
- UI 定位依次使用公开方法、已知节点路径、同类按钮父容器。
- 注入失败时隐藏教练入口并写警告，不阻止游戏启动。
- 未知角色或商品降低置信度并使用通用规则。
- RunTracker、ModOptions 和自动战斗 Mod 都是可选集成，不是硬依赖。

## 10. 目录与发布

开发工程：

```text
src/coach-core/       纯规则与模板
src/brotato-mod/      ModLoader 适配、记录器和 UI
src/external-tools/   样本导入与报告工具
data/schemas/         数据契约
data/rules/           版本化规则
tests/fixtures/       真实黄金样本
```

Workshop 包：

```text
mods-unpacked/BrotatoCoach/
  manifest.json
  mod_main.gd
  adapters/
  core/
  recorder/
  rules/
  ui/
  translations/
```

发布前必须验证纯净环境、当前常用 Mod 环境、RunTracker 开/关、键鼠/手柄、失败/胜利/放弃/
重试和无尽模式。第三方源码在许可证未确认前不得进入发布包。

本机 Brotato 正在运行时，不得覆盖已加载 Mod、不得修改 `mod_user_profiles.json`、不得重启游戏。
应先在工程内构建 ZIP，待游戏退出后再备份 profile 并注册本地 ZIP 路径。

## 11. 第一阶段实施顺序

1. 固定 `CoachSnapshot`、`CoachEvent` 和 `CoachReport` 数据契约。
2. 用两个黄金样本实现外部规则引擎最小闭环。
3. 完成轻量记录器，只写波次聚合事件。
4. 注入商店按钮并输出本地面板。
5. 注入暂停菜单和结算按钮。
6. 扩大角色规则库与真实样本数量。
