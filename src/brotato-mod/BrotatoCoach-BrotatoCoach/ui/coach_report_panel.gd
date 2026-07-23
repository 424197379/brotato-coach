extends PanelContainer

var _label = null
var _close_button = null


func _ready():
	set_process_input(true)


func set_report(report):
	_build_ui()
	_label.bbcode_enabled = false
	_label.text = _render_report(report)


func _build_ui():
	if _label != null:
		return
	anchor_left = 0.12
	anchor_top = 0.10
	anchor_right = 0.88
	anchor_bottom = 0.90
	margin_left = 0
	margin_top = 0
	margin_right = 0
	margin_bottom = 0
	focus_mode = Control.FOCUS_ALL

	var outer = VBoxContainer.new()
	outer.name = "CoachPanelLayout"
	add_child(outer)

	var header = HBoxContainer.new()
	outer.add_child(header)

	var title = Label.new()
	title.text = "土豆教练"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_close_button = Button.new()
	_close_button.text = "关闭"
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.connect("pressed", self, "_on_close_pressed")
	header.add_child(_close_button)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.focus_mode = Control.FOCUS_ALL
	outer.add_child(scroll)

	_label = RichTextLabel.new()
	_label.name = "CoachReportText"
	_label.fit_content_height = true
	_label.scroll_active = false
	_label.selection_enabled = true
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_label)


func _input(event):
	if event.is_action_pressed("ui_cancel"):
		queue_free()


func _on_close_pressed():
	queue_free()


func _render_report(report):
	var lines = []
	lines.append("结论: " + _summary_text(report.get("summary", {})))
	lines.append("规则版本: " + str(report.get("rule_pack_version", "")))
	lines.append("置信度: " + str(report.get("confidence", 0)))
	lines.append("")
	if report.get("shop_advice", []).size() > 0:
		lines.append("商店建议")
		for action in report.get("shop_advice", []):
			lines.append("- " + str(action.get("rank", "?")) + ". " + str(action.get("display_name", "未知候选")) + "：" + _action_text(str(action.get("action", ""))) + "，价格 " + str(action.get("price", 0)))
			lines.append("  依据: " + _reason_texts(action.get("reasons", [])))
		lines.append("")
	if report.get("stat_diagnosis", []).size() > 0:
		lines.append("属性缺口")
		for gap in report.get("stat_diagnosis", []):
			lines.append("- " + _stat_text(str(gap.get("stat_id", ""))) + "：当前 " + str(gap.get("current", 0)) + "，目标 " + _target_text(gap.get("target", {})) + "，第 " + str(gap.get("deadline_wave", "?")) + " 波前处理")
		lines.append("")
	var plans = report.get("plans", {})
	for key in ["wave_plus_3", "wave_plus_5"]:
		var plan = plans.get(key, {})
		lines.append(("未来 3 波" if key == "wave_plus_3" else "未来 5 波") + "：第 " + str(plan.get("deadline_wave", "?")) + " 波目标")
		lines.append("- 目标: " + _targets_text(plan.get("targets", {})))
		lines.append("- 优先: " + _list_text(plan.get("priorities", [])))
		lines.append("- 避免: " + _list_text(plan.get("avoid", [])))
		lines.append("")
	if report.get("run_review", null) != null:
		lines.append("复盘")
		for finding in report["run_review"].get("findings", []):
			lines.append("- " + _finding_text(finding))
			lines.append("  下一局规则: " + _next_run_rule_text(finding))
		lines.append("")
	if report.get("warnings", []).size() > 0:
		lines.append("警告")
		for warning in report.get("warnings", []):
			lines.append("- " + _warning_text(str(warning)))
	return PoolStringArray(lines).join("\n")


func _summary_text(summary):
	var key = str(summary.get("message_key", ""))
	if key.ends_with("healthy_early_double_illusionist"):
		return "开局状态健康，当前商店应优先补武器槽和经验成长。"
	if key.ends_with("current_run_runtime"):
		return "基于当前局面给出属性和后续目标。"
	if key.ends_with("run_end_history_review"):
		return "已读取本局明文记录，按趋势区分早期根因与最终触发点。"
	if key.ends_with("run_end_runtime_review_limited"):
		return "缺少历史记录，仅能做最终状态降级复盘。"
	return "已生成离线教练建议。"


func _action_text(action):
	if action == "buy" + "_now":
		return "立即购买"
	if action == "lo" + "ck":
		return "锁定"
	if action == "de" + "fer":
		return "稍后购买"
	if action == "sk" + "ip":
		return "跳过"
	return "待判断"


func _reason_texts(reasons):
	var texts = []
	for reason in reasons:
		var rule_id = str(reason.get("rule_id", ""))
		texts.append(_reason_text(rule_id))
	if texts.empty():
		return "保守规则认为该候选需要人工确认"
	return PoolStringArray(texts).join("；")


func _reason_text(rule_id):
	if rule_id == "distinct_weapon_increases_slot_cap":
		return "不同武器能提高该角色的武器槽上限"
	if rule_id == "slashing_set_crosses_threshold":
		return "斩击套装会跨过收益阈值"
	if rule_id == "early_experience_compounds":
		return "早期经验收益能滚动放大"
	if rule_id == "range_penalty_is_low_cost_for_current_build":
		return "当前构筑承受少量射程代价"
	if rule_id == "budget_cannot_buy_all_priority_candidates":
		return "预算不足以买下所有高价值候选"
	if rule_id == "duplicate_weapon_can_immediately_combine_next_shop":
		return "重复武器可用于下一次合成升级"
	if rule_id == "cheap_percent_damage_repair":
		return "能低价修复伤害百分比缺口"
	if rule_id.begins_with("shop.generic"):
		return "通用商店规则给出保守优先级"
	return "规则证据支持该动作"


func _stat_text(stat_id):
	var names = {
		"harvesting": "收获",
		"recovery": "回复",
		"speed": "移速",
		"percent_damage": "伤害百分比",
		"armor": "护甲",
		"max_hp": "最大生命"
	}
	return names.get(stat_id, "其他属性")


func _target_text(target):
	if typeof(target) != TYPE_DICTIONARY:
		return str(target)
	var parts = []
	if target.has("min"):
		parts.append("至少 " + str(target["min"]))
	if target.has("max"):
		parts.append("不高于 " + str(target["max"]))
	if target.has("target"):
		parts.append("接近 " + str(target["target"]))
	if target.has("tolerance"):
		parts.append("容差 " + str(target["tolerance"]))
	if parts.empty():
		return "保持可用区间"
	return PoolStringArray(parts).join("，")


func _targets_text(targets):
	if typeof(targets) != TYPE_DICTIONARY or targets.empty():
		return "无明确目标"
	var parts = []
	for key in targets.keys():
		parts.append(_stat_text(str(key)) + " " + _target_text(targets[key]))
	return PoolStringArray(parts).join("；")


func _list_text(values):
	if typeof(values) != TYPE_ARRAY or values.empty():
		return "无"
	var texts = []
	for value in values:
		texts.append(_phrase_text(str(value)))
	return PoolStringArray(texts).join("、")


func _phrase_text(value):
	var phrases = {
		"buy_new_katana_now": "先买新武士刀",
		"buy_scar_now": "再买伤疤",
		"add_one_recovery_source": "补一个回复来源",
		"raise_armor_for_damage_and_survival": "补护甲兼顾输出和生存",
		"attack_speed": "攻速",
		"armor": "护甲",
		"melee_damage": "近战伤害",
		"speed": "移速",
		"max_hp": "最大生命",
		"elemental_damage": "元素伤害",
		"weapons": "武器质量",
		"recovery": "回复",
		"damage": "输出",
		"survival": "生存",
		"economy": "经济"
	}
	if phrases.has(value):
		return phrases[value]
	if value.begins_with("do_not_buy_duplicate"):
		return "不要买无法立即合成的重复武器"
	if value.begins_with("do_not_treat_weird_ghost"):
		return "不要把诡异幽灵开局生命变化误判为受伤"
	if value.begins_with("avoid_clone"):
		return "暂避未验证的克隆相关模组道具"
	if value.begins_with("avoid_delayed"):
		return "门槛波前少买延迟收益"
	if value.begins_with("do_not_reroll"):
		return "处理高价值候选前不要刷新"
	return "其他保守建议"


func _finding_text(finding):
	var id = str(finding.get("id", ""))
	if id.ends_with("defense_mobility_trend"):
		return "早期根因：防御和移动趋势不足。" + _review_evidence_text(finding.get("evidence", {}), "defense")
	if id.ends_with("damage_curse_weapon_trend"):
		return "中期问题：输出、诅咒和武器贡献没有形成稳定闭环。" + _review_evidence_text(finding.get("evidence", {}), "damage")
	if id.ends_with("final_state_trigger"):
		return "最终触发点：结算状态暴露了最后一波容错不足。" + _review_evidence_text(finding.get("evidence", {}), "final")
	if id.ends_with("final_state_only"):
		return "仅有最终状态，无法完整定位早期根因。"
	return "复盘发现：需要结合更多记录判断。"


func _next_run_rule_text(finding):
	var rule = str(finding.get("next_run_rule", ""))
	if rule == "":
		return "下局保守处理同类风险。"
	return rule


func _review_evidence_text(evidence, kind):
	if typeof(evidence) != TYPE_DICTIONARY:
		return ""
	if kind == "defense":
		return "生命 " + str(evidence.get("max_hp_start", "?")) + " -> " + str(evidence.get("max_hp_final", "?")) + "，护甲 " + str(evidence.get("armor_start", "?")) + " -> " + str(evidence.get("armor_final", "?")) + "，移速 " + str(evidence.get("speed_start", "?")) + " -> " + str(evidence.get("speed_final", "?")) + "。"
	if kind == "damage":
		return "伤害 " + str(evidence.get("percent_damage_start", "?")) + " -> " + str(evidence.get("percent_damage_final", "?")) + "，诅咒 " + str(evidence.get("curse_start", "?")) + " -> " + str(evidence.get("curse_final", "?")) + "，武器贡献 " + str(evidence.get("weapon_damage_start", "?")) + " -> " + str(evidence.get("weapon_damage_final", "?")) + "。"
	if kind == "final":
		return "结算生命 " + str(evidence.get("current_hp", "?")) + "/" + str(evidence.get("max_hp", "?")) + "，已完成波次 " + str(evidence.get("completed_wave", "?")) + "。"
	return ""


func _warning_text(warning):
	if warning == "event_log_missing":
		return "没有找到本局明文记录"
	if warning == "runtime_run_review_lacks_wave_timeline":
		return "缺少波次历史，只能降级复盘"
	if warning == "truncated_tail":
		return "记录文件末尾有损坏行，已自动忽略"
	if warning == "invalid_jsonl_event":
		return "记录中存在损坏行，已跳过"
	return "其他记录提示"
