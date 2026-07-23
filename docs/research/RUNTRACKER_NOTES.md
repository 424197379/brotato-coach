# RunTracker 研究记录

研究对象：Brotato RunTracker `1.2.3`
Workshop 包：`<SteamLibrary>/steamapps/workshop/content/1942280/3751601322/RunTracker-BrotatoRunTracker.zip`
研究方式：本地只读源码审查
日期：2026-07-24

## 1. 结论

RunTracker 已经验证了波次级聚合记录的可行性，适合作为行为参考和开发期数据源，但不应成为
土豆教练的运行时硬依赖。当前包内没有找到明确许可证，因此在取得作者许可前不能复制或重新
发布其源码。

土豆教练采用 clean-room 实现：记录公开可观察的生命周期、输入输出和数据需求，自行编写
最小适配器、记录器和序列化代码。

## 2. 已观察的生命周期

### `mod_main.gd`

- 安装脚本扩展。
- 创建追踪器根节点。

### `extensions/singletons/run_data.gd`

- `on_wave_start()`：通知新局/新波次开始。
- `on_wave_end()`：记录波次结算、步数和每把武器的上一波伤害。
- `add_gold()`、`remove_gold()`：聚合经济变化。
- `add_weapon_dmg_dealt()`：聚合武器伤害。

### `run_tracker/run_tracker.gd`

- `on_wave_started()`：创建波次骨架。
- `on_wave_ready()`：延迟读取完整状态。
- `_finalize_wave()`：完成波次对象。
- `_send_run()`：进入上传与归档流程。

### 其他扩展

- `base_shop.gd`：记录重掷次数和成本。
- `retry_wave.gd`：处理同一波重试。
- `end_run.gd`：区分结算和重试。

## 3. 可借鉴的设计

- 在波次生命周期边界采集，避免每帧扫描。
- 波次开始先创建骨架，节点稳定后再补齐状态。
- 用 `run_id + wave + retry` 去重。
- 武器伤害直接读取 `dmg_dealt_last_wave`。
- 最后一波失败也要结算成可分析记录。
- 本局使用稳定 ID，最终汇总由波次记录生成。

这些是架构思想，不复制具体函数、类名布局或实现代码。

## 4. 不复用的部分

- HTTP 上传器和后台工作线程。
- Steam 身份、玩家名和平台账号处理。
- 上传失败队列。
- 大型单文件序列化器。
- 对 `enemy.gd`、`boss.gd`、`neutral.gd`、`player.gd` 的高冲突扩展。
- 每次命中、击杀或敌人实例级事件。

## 5. RunTracker 数据能力

现有 `live_run.json` 提供：

- 每波属性、武器、物品和套装。
- 武器上一波伤害。
- 经济、重掷、受伤、回复、击杀和步数聚合。
- 追踪物品效果。
- 重试、精英和 Boss 结果。

开发期可以直接把它转换为 `CoachSnapshot` 和 `CoachRun`，用于规则回归。

## 6. 与教练需求的缺口

RunTracker 的 `base_shop.gd` 主要记录重掷和成本，不保存当前商店四个候选的完整状态。
商店建议还需要：

- 候选资源 ID。
- 当前实际价格。
- 锁定、激活和已购买状态。
- 当前玩家材料。
- 购买前后的武器合成和套装变化。

Brotato 原生 `run_v3_0.json` 会保存 `shop_items`、`locked_shop_items`、重掷和免费重掷；
游戏内则应直接读取当前 `ShopItem` 实例，尤其是 `ShopItem.value`。

## 7. 兼容性风险

- 已观察到敌人脚本扩展与 Boss 静态类型关系冲突。土豆教练不扩展敌人层级。
- RunTracker 的私有根节点和函数不是稳定 API，不得调用。
- RunTracker 更新或未安装时，土豆教练仍必须完整运行。
- 本地旧外部分析原型曾优先选择归档旧局而不是更新的 `live_run.json`；正式导入器必须按
  `run_id`、数据阶段和采集时间选择输入，不能只按文件名优先级。

## 8. 推荐的最小适配面

若要记录与分析，只需要自行实现：

- `RunData` 波次开始/结束适配。
- `BaseShop` 当前商店读取和按钮入口。
- `RetryWave` 重试标记。
- `EndRun` 最终结算。

网络、Steam 身份和敌人事件全部排除。
