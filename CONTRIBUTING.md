# 参与贡献

土豆教练欢迎规则建议、Bug 报告、真实对局样本和代码贡献。

## 提交 Issue

- Bug：提供 Brotato、ModLoader、土豆教练和相关内容 Mod 的版本。
- 规则建议：说明角色、波次、当前构筑、建议结论和判断依据。
- 兼容性问题：附上 `modloader.log` 中与土豆教练相关的错误，不要上传整个游戏目录。
- 新对局样本：说明数据覆盖范围和缺失波次，不得补造没有记录的数据。

## 提交 Pull Request

1. 从 `main` 创建功能分支。
2. 保持规则核心、游戏适配器和 UI 解耦。
3. 不复制许可证不明的 Workshop Mod 或 Brotato 游戏源码。
4. 不修改现有黄金样本来掩盖回归；确需修订时必须更新 provenance 和校验值。
5. 运行构建与验收：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\build_mod_zip.ps1
python tests\p1_acceptance.py
```

6. 在 PR 中列出修改文件、验证结果、兼容性风险和未验证项。

## 规则贡献

每条规则至少需要：

- 稳定 `rule_id` 或 `reason_code`
- 适用游戏/Mod 版本
- 输入证据字段
- 正向收益与主要代价
- 至少一个回归样本或最小测试

阈值必须使用区间并说明适用波次，不能只凭单局经验永久写死。

## 代码风格

- GDScript 保持 Godot 3.x 兼容。
- Python 外部工具优先使用标准库，新增依赖前说明必要性。
- 运行时不联网、不调用外部进程、不修改 Brotato 存档。
- 不在 `_process` 中采集全量状态。
