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

## MVP 状态

`v0.1.0-mvp` 已实现：

- 商店“教练建议”
- 暂停菜单“分析当前局”
- 结算界面“复盘本局”
- 中文可滚动结果面板
- 明文 JSONL 轻量记录器
- 外部样本分析 CLI

自动验收结果为 **35 PASS / 0 FAIL / 0 GAP**。当前发布是预发布版，尚待维护者环境完成
Brotato 实机加载验证。

## 安装

1. 完全退出 Brotato。
2. 从 [GitHub Releases](https://github.com/424197379/brotato-coach/releases) 下载
   `BrotatoCoach.zip`。
3. 备份 Brotato 存档和 `mod_user_profiles.json`。
4. 通过 Brotato ModLoader 注册本地 ZIP。
5. 启动游戏后检查商店、暂停菜单和结算界面的土豆教练按钮。

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
