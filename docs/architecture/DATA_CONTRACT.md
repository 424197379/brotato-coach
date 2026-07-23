# 数据契约

版本：0.1.0
编码：UTF-8
格式：明文 JSON / JSONL

## 1. 设计原则

- 所有字段使用稳定 ASCII 标识，显示文本由本地化层提供。
- 数值使用游戏实际值，不把 `0`、缺失字段和未知值混为一谈。
- 同一对象中的数组必须有稳定排序规则。
- 原始 Mod 字段可以保留，但规则核心只读取标准字段。
- 所有结论携带规则 ID、证据路径和置信度。
- 旧日志必须能通过 `schema_version` 迁移或明确拒绝。

## 2. 文件布局

```text
runs/<run_id>/
  manifest.json
  events.jsonl
  run-summary.json
  reports/
    wave-003-shop.json
    run-end.json
```

运行时不加密。默认不上传。Steam ID、玩家名和本机路径不是教练输入，不应由正式记录器采集；
第三方原始样本若已有这些字段可以原样保留。

## 3. 通用头

每个事件和快照包含：

```json
{
  "schema_version": "0.1.0",
  "run_id": "local-uuid",
  "sequence": 7,
  "captured_at_utc": "2026-07-23T16:08:41Z",
  "game_version": "1.1.15.4",
  "recorder_version": "0.1.0",
  "rule_pack_version": "brotato-1.1.15.4+coach.1"
}
```

`sequence` 在单局内严格递增。读取器不得依赖文件修改时间确定事件顺序。

## 4. CoachEvent

JSONL 每行一个事件：

```json
{
  "schema_version": "0.1.0",
  "run_id": "local-uuid",
  "sequence": 7,
  "captured_at_utc": "2026-07-23T16:08:41Z",
  "event_type": "wave_completed",
  "player_index": 0,
  "payload": {}
}
```

支持的 `event_type`：

| 事件 | 必需内容 |
|---|---|
| `run_started` | 角色、难度、模式、已启用 DLC 和 Mod 摘要 |
| `wave_started` | 波次、材料、属性、物品、武器和套装 |
| `wave_completed` | 波次结果、经济、伤害、受伤、回复和武器贡献 |
| `shop_observed` | 当前候选、实际价格、锁定状态和重掷次数 |
| `coach_requested` | 快照指纹、入口和报告 ID |
| `wave_retried` | 波次和累计重试次数 |
| `run_ended` | 胜负、死亡信息、最终状态和完整度 |

未知事件必须被忽略并保留，不能导致整个文件读取失败。

## 5. CoachSnapshot

```json
{
  "schema_version": "0.1.0",
  "phase": "shop",
  "completed_wave": 3,
  "next_wave": 4,
  "run": {
    "character_id": "character_double_illusionist",
    "difficulty": 1,
    "is_endless": false
  },
  "player": {
    "level": 3,
    "current_xp": 38,
    "materials": 76,
    "current_hp": 16,
    "max_hp": 16,
    "stats": {}
  },
  "weapons": [],
  "items": [],
  "active_sets": {},
  "recent_waves": [],
  "shop": null,
  "data_quality": {}
}
```

### 5.1 阶段

`phase` 枚举：

- `wave_start`
- `wave_end`
- `shop`
- `paused`
- `run_end`

`completed_wave` 表示已完成的最高波次。`next_wave` 表示继续游戏将进入的波次。两者不能由
UI 标题字符串推断。

### 5.2 属性

标准属性键：

```text
max_hp armor dodge speed luck harvesting
melee_damage ranged_damage elemental_damage engineering
percent_damage attack_speed crit_chance range
hp_regeneration lifesteal curse pickup_range xp_gain
enemy_health enemy_damage enemy_speed number_of_enemies
damage_against_bosses explosion_damage explosion_size
hp_start_wave_percent weapon_slots
```

未知 Mod 属性放入 `extra_stats`，键使用原始稳定 ID。字段缺失表示“未采集/未知”，数值 `0`
表示已采集且确实为零。

### 5.3 武器

```json
{
  "id": "weapon_sword_paladin_1",
  "tier": 0,
  "slot": 2,
  "damage_last_wave": 93,
  "cursed": false,
  "sets": ["extatonion_set_slashing"],
  "scaling": [
    {"stat": "melee_damage", "coefficient": 1.0},
    {"stat": "armor", "coefficient": 1.0}
  ]
}
```

`id` 保留完整资源 ID，包括阶级后缀。需要合并同类武器时另用 `base_id`，不得通过删除最后
两个字符猜测。

### 5.4 物品

```json
{
  "id": "item_extra_stomach",
  "count": 1,
  "tier": 3,
  "cursed": false,
  "tracked_value": 102
}
```

重复物品合并为 `count`。需要逐实例诅咒因子时使用 `instances`，不能丢失不同实例状态。

### 5.5 商店

```json
{
  "rerolls_this_shop": 0,
  "paid_rerolls": 0,
  "reroll_cost": 5,
  "candidates": [
    {
      "slot": 0,
      "id": "weapon_new_katana_2",
      "kind": "weapon",
      "tier": 1,
      "price": 31,
      "locked": false,
      "active": true
    }
  ]
}
```

`price` 必须来自当前 `ShopItem.value`。候选按 `slot` 升序。锁定后价格是否保持由游戏状态
直接记录，不由分析器重新计算。

### 5.6 波次摘要

```json
{
  "wave": 3,
  "cleared": true,
  "duration_seconds": 20,
  "materials_start": 5,
  "materials_gained": 71,
  "materials_end": 76,
  "damage_dealt": 341,
  "damage_taken": 0,
  "healing": 0,
  "retries": 0,
  "weapon_damage": {
    "weapon_shadow_katana_2": 126
  }
}
```

只存聚合值。召唤物、物品和环境伤害按稳定来源 ID 汇总，不存每次伤害事件。

## 6. CoachReport

```json
{
  "schema_version": "0.1.0",
  "report_id": "local-uuid",
  "snapshot_fingerprint": "sha256:...",
  "rule_pack_version": "brotato-1.1.15.4+coach.1",
  "summary": {
    "message_key": "report.summary.healthy_early_build",
    "severity": "info"
  },
  "shop_advice": [],
  "stat_diagnosis": [],
  "plans": {
    "wave_plus_3": {},
    "wave_plus_5": {}
  },
  "run_review": null,
  "warnings": [],
  "confidence": 0.91
}
```

### 6.1 商店动作

```json
{
  "item_id": "weapon_new_katana_2",
  "action": "buy_now",
  "rank": 1,
  "price": 31,
  "reasons": [
    {
      "rule_id": "shop.distinct_weapon.slot_gain",
      "evidence": [
        "$.weapons",
        "$.shop.candidates[0]"
      ]
    }
  ],
  "tradeoffs": [],
  "confidence": 0.96
}
```

`action` 枚举：`buy_now`、`lock`、`defer`、`skip`。刷新建议单独存于 `reroll_advice`。

### 6.2 属性缺口

```json
{
  "stat_id": "speed",
  "current": 0,
  "target": {"min": 5, "max": 8},
  "deadline_wave": 6,
  "severity": "high",
  "dimensions": ["survival", "mobility"],
  "rule_id": "gap.autobattle.speed_buffer"
}
```

### 6.3 复盘结论

每条复盘结论包含：

- `first_observed_wave`
- `direct_or_root_cause`
- `severity`
- `evidence`
- `counterfactual`
- `next_run_rule`

直接死因和早期根因必须分开，不能只输出死亡波描述。

## 7. 数据完整度

```json
{
  "coverage": {
    "first_wave": 19,
    "last_wave": 30,
    "missing_ranges": [[1, 18]]
  },
  "sources": ["native_state", "game_log"],
  "exact_fields": ["stats", "weapons"],
  "derived_fields": ["shop_spend_approx"],
  "warnings": ["original_wave_30_backups_overwritten"]
}
```

报告必须根据完整度降低置信度。不得根据最终快照虚构缺失波次的购买历史。

## 8. 确定性

快照指纹生成前：

1. 对象键按字典序序列化。
2. 物品按 `id`，武器按 `slot`，商店按 `slot` 排序。
3. 删除显示文本、本机路径和时间戳。
4. 保留所有影响规则的数值。

相同快照指纹和规则版本必须生成字节级一致的结构化报告。Markdown 呈现允许因本地化版本变化，
但不得改变结构化动作和证据。

## 9. 错误恢复

- JSONL 最后一行损坏：丢弃最后一行，标记 `truncated_tail`。
- 中间行损坏：跳过该行，记录序号缺口并降低置信度。
- 未知字段：保留并忽略。
- 缺少必需字段：禁用对应分析分区，不影响其他分区。
- 写入失败：停止本局教练记录，显示可关闭警告，不修改游戏存档。
