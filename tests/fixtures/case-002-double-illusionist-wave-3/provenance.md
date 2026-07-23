# 数据来源

## 原始文件

| 样本文件 | 本机来源 | 最后写入时间 |
|---|---|---|
| `source-runtracker.json` | `<BrotatoUserData>/brotato_run_tracker_pending/live_run.json` | 2026-07-24 00:08:41 +08:00 |
| `source-brotato-state.json` | `<BrotatoUserData>/<redacted-steam-id>/run_v3_0.json` | 2026-07-24 00:09:20 +08:00 |

两份文件在玩家仍停留于第 3 波商店时复制。公开样本已脱敏玩家平台 ID 和玩家名，不保留
Steam ID、玩家名或本机路径。

## 归一化规则

- 波次战斗数据、武器伤害、每波属性和道具来自 RunTracker 第 3 波记录。
- 当前商店材料、等级、生命和 XP 来自 RunTracker 顶层实时状态与 Brotato `players_data[0]`。
- 商店候选、阶级和当前价格来自 Brotato `shop_items[0]`。
- `nan` 是 Brotato 原生状态允许出现的字面值；原始文件保持不变，读取适配器负责兼容。
- `coach-snapshot.json` 只选取当前教练功能需要的字段，不替代两份原始证据。

## 基准报告来源

`expected-report.md` 来自同一 Codex 任务中基于上述两份文件给出的人工分析，保留原始判断，
只对标点、空格和标题做了工程文档格式整理。
