# ADR-0002：临时外部运行时与游戏内闭环边界

状态：已接受
日期：2026-07-24

## 背景

P1 需要同时支持黄金样本回归和游戏内可触发闭环。本机没有可用于 headless 项目测试的独立
Godot 3.x CLI，`Brotato.exe` 只是游戏导出程序，不能作为编辑器或外部测试运行时使用。

同时，用户确认外部 CLI 不能替代 MVP，因为没有游戏内 UI 就无法在真实游玩中触发建议。

## 决策

P1 外部开发和回归工具可以临时使用 Node.js/TypeScript 或其他轻量运行时。该运行时只用于：

- 读取黄金样本和原始日志。
- 执行离线回归。
- 输出稳定 JSON 和 Markdown 报告。
- 构建本地 Mod ZIP。

游戏内 MVP 必须由本地 `BrotatoCoach` Mod 提供，且所有游戏内分析在 GDScript 中执行。
游戏内代码不得调用外部 Node、AI、网络或本机进程。

规则数据、schema、`reason_codes` 和纯数据算法必须与运行时解耦，使 CLI 和 GDScript 适配层使用
同源规则，不维护两套业务判断。

## 运行与安装约束

当前 Brotato 正在运行时，不得覆盖已加载 Mod、不得修改 `mod_user_profiles.json`、不得重启游戏。
本轮只能在工程内构建 ZIP，并输出待游戏退出后的备份、注册和验证步骤。

ModLoader 当前通过 `mod_user_profiles.json` 的 `zip_path` 加载 Workshop ZIP/PCK；本地 Mod 注册前
必须先备份 profile。

## 后果

- 外部 CLI 能较快形成可回归的报告闭环，但不计为用户可用 MVP。
- GDScript Mod 仍需实现商店、暂停和结算三个按钮，以及共用结果面板。
- 缺少 Godot CLI 时，游戏内脚本只能通过静态检查、打包检查和待游戏退出后的真实加载日志验证。
