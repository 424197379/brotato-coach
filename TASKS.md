# Tasks

## Active

- [ ] P0：在最新 ZIP 中实机验收第 4 波刷新后的实时商店建议，以及暂停/结算菜单的手柄正反导航、关闭后焦点恢复和战斗中打开暂停分析后的面板清理。
- [ ] P7：实机验证通过后发布 Steam Workshop 公测版。

## Waiting On

- 实际 ModLoader 的手柄输入栈和场景切换仍需人工操作确认；Godot CLI 仅覆盖面板生命周期、取消事件和焦点恢复合同。

## Next

- [ ] 实现商店建议的第一版确定性评分模型。
- [ ] 实现属性缺口和未来 3/5 波目标模型。
- [ ] 实现更完整的波次级记录器和结算因果链。
- [ ] 增加更多角色和真实局样本校准阈值。

## Someday

- [ ] 原版角色规则库。
- [ ] 建立更多 GitHub Issue/PR 贡献样本并持续校准规则。

## Done

- [x] 建立独立工程目录。
- [x] 建立产品需求和验收标准。
- [x] 确定离线确定性规则核心。
- [x] 建立主控、开发、测试三个独立会话。
- [x] 初始化独立 Git 仓库。
- [x] 完成 `TECHNICAL_DESIGN.md` 和 `DATA_CONTRACT.md`。
- [x] 完成 RunTracker、Brotato 扩展点和代码来源研究。
- [x] 保存双重幻术师第 3 波原始明文数据与基准分析。
- [x] 恢复学徒第 30 波时间线、证据与基准复盘。
- [x] 建立开发/测试会话的首次交接记录。
- [x] 分发 `JSON Schema + 外部规则引擎骨架` 给开发会话并确认收到。
- [x] 分发 `黄金样本验收 + 测试矩阵` 给测试会话并确认收到。
- [x] 修正 P1 MVP 定义：游戏内按钮闭环为完成条件，外部 CLI 仅作开发/回归工具。
- [x] 记录无 Godot CLI 时临时外部运行时决策。
- [x] 定义并实现 `CoachSnapshot`、`CoachEvent`、`CoachReport` JSON Schema。
- [x] 实现外部样本加载器、原生小写 `nan` 兼容、确定性规则引擎和 CLI。
- [x] 实现公开 JSONL 事件加载入口，支持 BOM、尾部损坏恢复、中间坏行跳过、未知事件保留和 sequence gap 警告。
- [x] 实现本地 `BrotatoCoach` Mod 游戏内垂直切片。
- [x] 统一内部 Mod ID 为 `BrotatoCoach-BrotatoCoach`，ZIP 产物为 `BrotatoCoach.zip`。
- [x] 修正 ModLoader ZIP 结构为 `mods-unpacked/BrotatoCoach-BrotatoCoach/...`。
- [x] 修正运行时读取：使用全局 `RunData`、`Utils`、`Keys` 和 `players_data`，避免零值面板。
- [x] 商店、暂停和结算入口注入离线分析按钮与共用中文结果面板。
- [x] 加入最小明文记录器，写入 `user://brotato_coach/runs/<run_id>/events.jsonl`。
- [x] 结算复盘优先读取本局历史事件，无历史时才降级 final-state。
- [x] 建立黄金样本自动化验收、静态 Mod 验收和 UI/Mod 兼容性测试矩阵。
- [x] P1 自动化复验通过：35 PASS / 0 FAIL / 0 GAP。
- [x] 增加 GitHub 开源许可证、贡献指南、Issue/PR 模板和 CI。
- [x] P0：修复商店实时 `ShopItem` 读取与确定性通用候选回退；保留 case-002 第 3 波专项建议，自动验收 `39 PASS / 0 FAIL / 0 GAP`。
- [x] P0：修复暂停和结算入口的双向手柄焦点链及报告面板关闭后的焦点恢复；新包已由 ModLoader 加载并安装三处扩展。
- [x] P0：修复暂停分析的宿主生命周期，防止空黑框残留；修复商店/结算报告关闭后的手柄焦点恢复，并将取消事件消费、宿主退出和焦点回退纳入 Godot CLI 回归，独立验收 `43 PASS / 0 FAIL / 0 GAP`。
- [x] P1：已使用既有 profile 的本地 ZIP 路径部署 P0 修复，并保留原 ZIP 备份；未修改 profile 或存档。
- [x] P1：ModLoader/game log 已确认本地 ZIP 加载、`BrotatoCoach` 初始化和三处 UI extension 安装；无教练相关错误。
