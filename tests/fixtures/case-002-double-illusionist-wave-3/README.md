# Case 002：双重幻术师第 3 波

## 场景

- 阶段：第 3 波结束后的商店。
- 角色：`character_double_illusionist`。
- 难度：危险 1，非无尽。
- 目标：验证商店购买顺序、不同武器计数、属性缺口和未来 3/5 波规划。

## 文件

- `source-runtracker.json`：RunTracker v1.2.3 的原始 `live_run.json`，原样明文副本。
- `source-brotato-state.json`：Brotato 原生 `run_v3_0.json`，原样明文副本。
- `coach-snapshot.json`：从两份原始文件归一化后的最小教练输入。
- `expected-report.md`：当时给玩家的完整分析文案。
- `assertions.json`：规则引擎回归测试的关键断言。
- `provenance.md`：采集时间和字段来源。
- `checksums.sha256`：两份原始文件的 SHA-256。

原始 RunTracker 文件的每波快照发生在波次边界，商店中的当前生命、等级、材料和四个候选
来自顶层实时状态与 Brotato 原生运行状态。因此 `wave_3_end.max_hp` 为 15，而商店当前生命上限
为 16，两者代表不同时间点，不是数据冲突。
