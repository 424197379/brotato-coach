# 黄金样本

这里保存真实对局形成的回归样本。每个样本至少包含：

- `README.md`：场景、数据覆盖和使用方式。
- `coach-snapshot.json` 或 `run-timeline.json`：规则引擎使用的统一输入。
- `expected-report.md`：人工教练给出的基准分析。
- `assertions.json`：自动测试必须命中的关键结论，不要求逐字复现文案。
- `provenance.md`：原始数据来源、恢复方式和已知缺口。

样本中的 Brotato、RunTracker 和 Mod 日志均为明文。原始文件可以保留完整游戏字段；
规则引擎不得依赖 Steam ID、玩家名或运行目录等与教练判断无关的字段。

## 当前样本

- `case-001-apprentice-endless-wave-30`：学徒无尽第 30 波失败复盘。
- `case-002-double-illusionist-wave-3`：双重幻术师第 3 波商店和阶段规划。
