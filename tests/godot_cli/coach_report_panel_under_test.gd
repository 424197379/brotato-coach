extends PanelContainer

var _body_label = null
var _summary_label = null
var _close_button = null
var _scroll = null
var _restore_focus_owner = null
var _host = null
var _closing = false


func _ready():
	set_process_input(true)


func set_host(host):
	if not is_instance_valid(host) or not (host is Control):
		return
	_host = host
	if not _host.is_connected("visibility_changed", self, "_on_host_visibility_changed"):
		_host.connect("visibility_changed", self, "_on_host_visibility_changed")
	if not _host.is_connected("tree_exiting", self, "_on_host_tree_exiting"):
		_host.connect("tree_exiting", self, "_on_host_tree_exiting")


func set_report(report, restore_focus = null):
	_restore_focus_owner = restore_focus
	if not is_instance_valid(_restore_focus_owner):
		_restore_focus_owner = _current_focus_owner()
	_build_ui()
	_summary_label.text = _summary_text(report.get("summary", {}))
	_body_label.bbcode_enabled = false
	_body_label.text = _render_report(report)
	call_deferred("_focus_initial_control")


func _build_ui():
	if _body_label != null:
		return
	anchor_left = 0.08
	anchor_top = 0.07
	anchor_right = 0.92
	anchor_bottom = 0.93
	margin_left = 0
	margin_top = 0
	margin_right = 0
	margin_bottom = 0
	focus_mode = Control.FOCUS_NONE
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.10, 0.16, 0.98)
	panel_style.border_color = Color(0.34, 0.55, 0.74, 1.0)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(4)
	panel_style.content_margin_left = 24
	panel_style.content_margin_top = 20
	panel_style.content_margin_right = 24
	panel_style.content_margin_bottom = 22
	add_stylebox_override("panel", panel_style)

	var content = Control.new()
	content.name = "CoachPanelContent"
	content.rect_min_size = Vector2(560, 360)
	add_child(content)

	var title = Label.new()
	title.name = "CoachReportTitle"
	title.text = "土豆教练"
	title.anchor_right = 1.0
	title.margin_right = -142
	title.margin_bottom = 34
	title.add_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	content.add_child(title)

	_close_button = Button.new()
	_close_button.name = "CoachReportCloseButton"
	_close_button.text = "关闭"
	_close_button.anchor_left = 1.0
	_close_button.anchor_right = 1.0
	_close_button.margin_left = -118
	_close_button.margin_top = -2
	_close_button.margin_right = 0
	_close_button.margin_bottom = 40
	_close_button.rect_min_size = Vector2(118, 42)
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.add_color_override("font_color", Color(0.94, 0.97, 1.0, 1.0))
	_close_button.connect("pressed", self, "_on_close_pressed")
	content.add_child(_close_button)

	_summary_label = Label.new()
	_summary_label.name = "CoachReportSummary"
	_summary_label.anchor_right = 1.0
	_summary_label.margin_top = 48
	_summary_label.margin_right = 0
	_summary_label.margin_bottom = 96
	_summary_label.autowrap = true
	_summary_label.add_color_override("font_color", Color(0.74, 0.85, 0.96, 1.0))
	content.add_child(_summary_label)

	_scroll = ScrollContainer.new()
	_scroll.name = "CoachReportScroll"
	_scroll.anchor_top = 0.0
	_scroll.anchor_right = 1.0
	_scroll.anchor_bottom = 1.0
	_scroll.margin_top = 112
	_scroll.margin_bottom = 0
	_scroll.rect_min_size = Vector2(520, 248)
	_scroll.focus_mode = Control.FOCUS_ALL
	content.add_child(_scroll)

	_body_label = RichTextLabel.new()
	_body_label.name = "CoachReportText"
	_body_label.fit_content_height = true
	_body_label.scroll_active = false
	_body_label.selection_enabled = true
	_body_label.rect_min_size = Vector2(520, 248)
	_body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_label.add_color_override("default_color", Color(0.88, 0.92, 0.97, 1.0))
	_body_label.add_constant_override("line_separation", 8)
	_scroll.add_child(_body_label)
	_link_panel_focus(_close_button, _scroll)


func _input(event):
	if not _closing and visible and event.is_action_pressed("ui_cancel"):
		_dismiss()
		var tree = get_tree()
		if tree != null:
			tree.set_input_as_handled()


func _on_close_pressed():
	_dismiss()


func _focus_initial_control():
	if not _closing and visible and is_instance_valid(_close_button):
		_close_button.grab_focus()


func _dismiss(restore_focus := true):
	if _closing:
		return
	_closing = true
	hide()
	set_process_input(false)
	# _restore_focus_owner.grab_focus() and queue_free() run together after the overlay is hidden.
	var should_restore_focus = restore_focus and _can_restore_focus_owner()
	call_deferred("_finish_dismiss", should_restore_focus)


func _finish_dismiss(restore_focus):
	var parent = get_parent()
	if is_instance_valid(parent):
		parent.remove_child(self)
	var can_restore_focus = restore_focus and _can_restore_focus_owner()
	if can_restore_focus:
		_restore_focus_owner.grab_focus()
	queue_free()


func _on_host_visibility_changed():
	if not is_instance_valid(_host) or not _host.is_visible_in_tree():
		_dismiss(false)


func _on_host_tree_exiting():
	_dismiss(false)


func _can_restore_focus_owner():
	if not is_instance_valid(_restore_focus_owner) or not (_restore_focus_owner is Control):
		return false
	if not _restore_focus_owner.is_inside_tree() or not _restore_focus_owner.visible:
		return false
	if is_instance_valid(_host) and _host is Control and not _host.visible:
		return false
	if _restore_focus_owner.focus_mode == Control.FOCUS_NONE:
		return false
	if _restore_focus_owner is BaseButton and _restore_focus_owner.disabled:
		return false
	return true


func _current_focus_owner():
	var viewport = get_viewport()
	if viewport == null or not viewport.has_method("gui_get_focus_owner"):
		return null
	var focus_owner = viewport.gui_get_focus_owner()
	if is_instance_valid(focus_owner) and focus_owner is Control:
		return focus_owner
	return null


func _link_panel_focus(first, second):
	if not _same_focus_container(first, second):
		return
	first.focus_next = first.get_path_to(second)
	first.focus_previous = first.get_path_to(second)
	second.focus_next = second.get_path_to(first)
	second.focus_previous = second.get_path_to(first)
	first.set("focus_neighbour_bottom", first.get_path_to(second))
	first.set("focus_neighbour_top", first.get_path_to(second))
	second.set("focus_neighbour_top", second.get_path_to(first))
	second.set("focus_neighbour_bottom", second.get_path_to(first))


func _same_focus_container(first, second):
	if not is_instance_valid(first) or not is_instance_valid(second):
		return false
	if not (first is Control) or not (second is Control):
		return false
	return first.get_parent() == second.get_parent() and first.is_inside_tree() and second.is_inside_tree()


func _render_report(report):
	var lines = []
	if report.get("shop_advice", []).size() > 0:
		lines.append("商店建议")
		for action in report.get("shop_advice", []):
			lines.append("- " + str(action.get("rank", "?")) + ". " + str(action.get("display_name", "未知候选")) + "：" + _action_text(str(action.get("action", ""))) + "，价格 " + str(action.get("price", 0)))
			lines.append("  依据: " + _reason_texts(action.get("reasons", [])))
		lines.append("\n")
	if report.get("stat_diagnosis", []).size() > 0:
		lines.append("属性缺口")
		for gap in report.get("stat_diagnosis", []):
			lines.append("- " + _stat_text(str(gap.get("stat_id", ""))) + "：当前 " + str(gap.get("current", 0)) + "，目标 " + _target_text(gap.get("target", {})) + "，第 " + str(gap.get("deadline_wave", "?")) + " 波前处理")
		lines.append("\n")
	var plans = report.get("plans", {})
	for key in ["wave_plus_3", "wave_plus_5"]:
		var plan = plans.get(key, {})
		lines.append(("未来 3 波" if key == "wave_plus_3" else "未来 5 波") + "：第 " + str(plan.get("deadline_wave", "?")) + " 波目标")
		lines.append("- 目标: " + _targets_text(plan.get("targets", {})))
		lines.append("- 优先: " + _list_text(plan.get("priorities", [])))
		lines.append("- 避免: " + _list_text(plan.get("avoid", [])))
		lines.append("\n")
	if report.get("run_review", null) != null:
		lines.append("复盘")
		for finding in report["run_review"].get("findings", []):
			lines.append("- " + _finding_text(finding))
			lines.append("  下一局规则: " + _next_run_rule_text(finding))
		lines.append("\n")
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
