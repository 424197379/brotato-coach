# Tasks

## Active

- [ ] P1：待 Brotato 退出后，备份 ModLoader profile 并注册本地 `BrotatoCoach.zip`。
- [ ] P1：以 ModLoader/game log 验证本地 Mod 加载、三个 UI 入口、面板焦点和存档安全。
- [ ] P7：实机验证通过后发布 Steam Workshop 公测版。

## Waiting On

- Brotato.exe 退出后才能安全修改 `mod_user_profiles.json` 或通过 ModLoader 注册本地 ZIP。
- 本机无 Godot 3.x CLI，GDScript 编译和 UI 行为需要真实游戏加载日志验证。

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
