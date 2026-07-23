# Brotato 与 ModLoader 扩展点

游戏版本：`1.1.15.4`
PCK：`<SteamLibrary>/steamapps/common/Brotato/Brotato.pck`
日期：2026-07-24

## 1. 研究边界

本记录用于确认可以只读访问的状态和低冲突 UI 注入位置。游戏资源与脚本只用于本地兼容性
研究，不复制到土豆教练仓库或 Workshop 包。

## 2. ModLoader 能力

已确认可用：

- `install_script_extension`
- `add_translation`
- `is_mod_loaded`

脚本扩展遵循 ModLoader 的继承链：

- `_ready()` 扩展不手动调用 `._ready()`。
- 覆盖普通方法时必须只调用一次父实现。
- 同一路径存在多个扩展时，应避免依赖加载顺序和其他 Mod 私有字段。

## 3. 推荐 UI 扩展点

### 商店

脚本：`res://ui/menus/shop/base_shop.gd`

- `_get_reroll_button(0).get_parent()` 可定位商店工具栏。
- `_get_shop_items_container(player_index)` 可取得当前玩家商店容器。
- `ShopItem.item_data/value/wave_value/locked/active` 提供分析所需候选状态。

### 暂停菜单

脚本：`res://ui/menus/ingame/ingame_main_menu.gd`

- `_resume_button.get_parent()` 可定位按钮容器。
- 只在暂停状态创建分析快照。

### 结算

脚本：`res://ui/menus/run/end_run.gd`

- `%NewRunButton` 或 `_new_run_button.get_parent()` 可定位底部操作行。
- 该入口覆盖胜利、失败和放弃，需要排除“重试本波”。

## 4. 推荐状态接口

- `RunData.current_wave/current_difficulty/nb_of_waves/retries`
- `RunData.get_player_character/level/xp/gold`
- `RunData.get_player_current_health/max_health`
- `RunData.get_player_items/weapons/sets/banned_items`
- `RunData.tracked_item_effects`
- `Utils.get_stat(Keys.stat_*_hash, player_index)`

读取器不得调用重算或重置全局状态的方法。原生状态文件包含小写 `nan` 的可能性，外部导入器
需要兼容，游戏内读取器则直接读取 Dictionary。

## 5. 冲突面

当前环境已有多个 Mod 扩展 `main.gd`，因此第一版避免使用它。高风险脚本：

- `enemy.gd`
- `boss.gd`
- `unit.gd`
- `neutral.gd`
- `main.gd`

第一版只扩展三个 UI/结算脚本与必要的 `RunData` 生命周期，降低与内容和自动战斗 Mod 的冲突。

## 6. 降级策略

1. 优先调用已知方法。
2. 方法不可用时查找已知节点路径。
3. 节点路径变化时查找同类按钮父容器。
4. 全部失败则不注入按钮并写警告。
5. 记录器或 UI 失败不得阻止游戏启动、继续、结算或保存。

## 7. 待验证

- 所有入口在键鼠和手柄焦点导航中的顺序。
- 合作模式每个 `player_index` 的商店和报告归属。
- 商店动画期间读取候选的最早稳定时点。
- 无尽、重试、放弃和胜利的结算事件区别。
- 当前常用 16 个 Mod 同时启用时的脚本扩展顺序。
