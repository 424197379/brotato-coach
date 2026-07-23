# 土豆教练

面向 Brotato 的本地离线游戏教练 Mod。

项目把人工对局分析工程化为可复用的确定性规则，并提供游戏内按钮式分析：

- 商店购买建议
- 当前属性缺陷诊断
- 未来 3 波与未来 5 波发展规划
- 角色专属玩法建议
- 每局结束后的全流程复盘

游戏内不调用大语言模型，不联网。分析核心采用确定性、可解释、可测试的离线规则引擎；
数据只在商店、分析请求和结算边界低频采集。

## 致谢与来源边界

本项目显著参考了 Brotato RunTracker 的思路和可观察行为：波次级聚合记录、商店/结算生命周期、
武器上一波伤害、经济与属性趋势等设计都受 RunTracker 启发。RunTracker 也作为开发期黄金样本
来源之一，帮助确认哪些局内数据对复盘最有价值。

土豆教练不捆绑 RunTracker 源码，也不把 RunTracker 作为运行时依赖；实现采用独立代码和独立
规则数据。相关研究记录见 [RunTracker 研究](docs/research/RUNTRACKER_NOTES.md) 和
[代码来源边界](docs/research/CODE_PROVENANCE.md)。

## MVP 状态

`v0.1.0-mvp` 已实现：

- 商店“教练建议”
- 暂停菜单“分析当前局”
- 结算界面“复盘本局”
- 中文可滚动结果面板
- 明文 JSONL 轻量记录器
- 外部样本分析 CLI

自动验收结果为 **35 PASS / 0 FAIL / 0 GAP**。当前发布是预发布版；维护者环境已确认
ModLoader 能识别并加载 ZIP，三处 UI 扩展完成安装且无土豆教练错误。更完整的实机游玩验证仍在推进。

## 功能概览

- **商店建议**：读取当前商店候选、实际价格、锁定状态和玩家材料，输出立即购买、锁定、
  稍后购买或跳过建议。
- **属性诊断**：指出当前最重要的输出、生存、回复、移动或经济缺口，并附带目标区间。
- **未来规划**：同时给出未来 3 波和未来 5 波的发展目标。
- **结算复盘**：读取本局明文 JSONL 事件，比较生命、护甲、移速、输出、诅咒和武器贡献趋势；
  没有历史记录时降级为最终状态复盘。
- **外部回归工具**：可对黄金样本生成确定性 JSON 和 Markdown 报告，便于调试规则。

## 安装

常规公开安装方案将通过 Steam 创意工坊发布：

- Steam 创意工坊链接：待补充

当前预发布 ZIP 主要用于维护者验证。Brotato 集成版的 ModLoader 当前只枚举 Steam API 返回的
已订阅创意工坊目录；本地验证时，需要把 `BrotatoCoach.zip` 与一个已订阅项目目录并列放置，
再由当前 ModLoader 配置引用该 ZIP。公开用户请等待 Steam 创意工坊版本。

如果 ModLoader 日志出现错误，请在 GitHub Issues 提交最小复现和相关日志片段。

## 构建与测试

需要 PowerShell 和 Python 3.10+：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_mod_zip.ps1
python tests\p1_acceptance.py
```

构建产物为 `src/brotato-mod/dist/BrotatoCoach.zip`。

分析黄金样本：

```powershell
python src\external-tools\analyze_fixture.py `
  tests\fixtures\case-002-double-illusionist-wave-3
```

## 文档

- [产品需求](docs/requirements/PRODUCT_REQUIREMENTS.md)
- [验收标准](docs/requirements/ACCEPTANCE_CRITERIA.md)
- [技术设计](docs/architecture/TECHNICAL_DESIGN.md)
- [数据契约](docs/architecture/DATA_CONTRACT.md)
- [RunTracker 研究](docs/research/RUNTRACKER_NOTES.md)
- [Brotato 扩展点](docs/research/BROTATO_SOURCE_NOTES.md)
- [代码来源边界](docs/research/CODE_PROVENANCE.md)
- [路线图](docs/roadmap/ROADMAP.md)
- [架构决策](docs/decisions/ADR-0001-offline-deterministic-core.md)
- [明文日志决策](docs/decisions/ADR-0002-plaintext-local-logs.md)
- [黄金样本](tests/fixtures/README.md)

## 路线图

- **v0.1.x**：完成更多真实游戏交互验证，修复 ModLoader 兼容性问题，发布 Steam 创意工坊版本。
- **P2**：扩展波次级记录器，提升结算复盘的因果链质量。
- **P3**：支持更多原版角色和常见 Mod 角色，建立更完整的角色规则库。
- **P4**：完善 UI 文案、手柄焦点、本地化和异常提示。
- **P5**：扩大真实跑局样本，校准阈值，准备 Workshop 公测。

## 目录

```text
土豆教练/
  docs/                  产品、架构、研究和路线图
  src/coach-core/        与游戏 UI 解耦的离线规则核心
  src/brotato-mod/       Brotato/ModLoader 适配与游戏内 UI
  src/external-tools/    开发期外部分析和调试工具
  tests/fixtures/        真实局内、商店和结算黄金样本
  scripts/               构建脚本
```

## 贡献

欢迎提交 Bug、兼容性反馈、角色规则和真实对局样本。请先阅读
[CONTRIBUTING.md](CONTRIBUTING.md)。第三方 Mod 或游戏源码只有在许可证明确允许时才能进入仓库。

## 数据

运行记录采用明文 JSON/JSONL，默认只保存在本机，不上传网络。正式记录器不需要 Steam ID、
玩家名或本机路径；仓库中的黄金样本用于回归测试。

## 许可证

项目原创代码采用 [MIT License](LICENSE)。Brotato、ModLoader 和第三方 Workshop Mod
属于各自权利人；本仓库不捆绑其源码或游戏资源。
