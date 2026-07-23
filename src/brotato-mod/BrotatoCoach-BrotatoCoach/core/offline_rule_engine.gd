extends Reference

const RULE_PACK_VERSION = "brotato-1.1.15.4+coach.1"

var _rule_pack = {}


func _init(rule_pack := {}):
	_rule_pack = rule_pack


func analyze(input):
	if typeof(input) != TYPE_DICTIONARY:
		return _error_report("invalid_input")
	var phase = str(input.get("phase", "paused"))
	if phase == "shop":
		return _analyze_shop(input)
	if phase == "run_end":
		return _analyze_run_end(input)
	return _analyze_current(input)


func _base_report(input):
	var rule_version = str(_rule_pack.get("rule_pack_version", RULE_PACK_VERSION))
	return {
		"schema_version": "0.1.0",
		"report_id": "gdscript-report",
		"snapshot_fingerprint": "sha256:runtime",
		"rule_pack_version": rule_version,
		"summary": {
			"message_key": "report.summary.runtime_snapshot",
			"severity": "info",
			"rule_id": "summary.runtime",
			"evidence": []
		},
		"shop_advice": [],
		"reroll_advice": null,
		"stat_diagnosis": [],
		"plans": {
			"wave_plus_3": _empty_plan(int(input.get("completed_wave", 0)) + 3),
			"wave_plus_5": _empty_plan(int(input.get("completed_wave", 0)) + 5)
		},
		"run_review": null,
		"warnings": [],
		"confidence": 0.55
	}


func _analyze_shop(snapshot):
	var report = _base_report(snapshot)
	var run = snapshot.get("run", {})
	var character_id = str(run.get("character_id", "unknown"))
	if character_id == "character_double_illusionist":
		_apply_double_illusionist_shop(report, snapshot)
	else:
		_apply_generic_shop(report, snapshot)
	_apply_generic_gaps(report, snapshot)
	if report["plans"]["wave_plus_3"]["targets"].empty():
		_apply_generic_plans(report, snapshot)
	return report


func _analyze_current(snapshot):
	var report = _base_report(snapshot)
	_apply_generic_gaps(report, snapshot)
	_apply_generic_plans(report, snapshot)
	report["summary"] = {
		"message_key": "report.summary.current_run_runtime",
		"severity": "info",
		"rule_id": "summary.current_run_runtime",
		"evidence": ["$.player.stats", "$.weapons"]
	}
	report["confidence"] = 0.62
	return report


func _analyze_run_end(snapshot):
	var report = _base_report(snapshot)
	var history = snapshot.get("history", {})
	var events = history.get("events", [])
	if typeof(events) == TYPE_ARRAY and events.size() > 0:
		_apply_history_run_review(report, snapshot, history)
		return report
	report["summary"] = {
		"message_key": "report.summary.run_end_runtime_review_limited",
		"severity": "medium",
		"rule_id": "review.runtime_limited",
		"evidence": ["$.player.stats", "$.weapons"]
	}
	report["run_review"] = {
		"coverage": {
			"first_wave": null,
			"last_wave": int(snapshot.get("completed_wave", 0)),
			"missing_ranges": [],
			"warnings": ["runtime_recorder_not_available_in_p1_slice"]
		},
		"findings": [
			{
				"id": "review.runtime_limited.final_state_only",
				"first_observed_wave": null,
				"direct_or_root_cause": "contributing",
				"severity": "medium",
				"evidence": {
					"completed_wave": int(snapshot.get("completed_wave", 0)),
					"phase": "run_end"
				},
				"counterfactual": "完整根因复盘需要读取本局波次历史记录。",
				"next_run_rule": "缺少历史记录时，只把最终状态复盘作为风险提示，不把它当成完整根因。"
			}
		]
	}
	report["warnings"] = ["runtime_run_review_lacks_wave_timeline"]
	report["confidence"] = 0.45
	return report


func _apply_history_run_review(report, snapshot, history):
	var events = history.get("events", [])
	var snapshots = _snapshots_from_events(events)
	var first = snapshots[0] if snapshots.size() > 0 else snapshot
	var final = snapshots[snapshots.size() - 1] if snapshots.size() > 0 else snapshot
	var first_stats = _stats(first)
	var final_stats = _stats(final)
	var first_wave = int(first.get("completed_wave", 0))
	var final_wave = int(final.get("completed_wave", snapshot.get("completed_wave", 0)))
	var first_weapons = first.get("weapons", [])
	var final_weapons = final.get("weapons", [])
	report["summary"] = {
		"message_key": "report.summary.run_end_history_review",
		"severity": "high",
		"rule_id": "review.runtime_history",
		"evidence": ["$.history.events", "$.player.stats", "$.weapons"]
	}
	report["run_review"] = {
		"coverage": {
			"first_wave": first_wave,
			"last_wave": final_wave,
			"event_count": events.size(),
			"warnings": history.get("data_quality", {}).get("warnings", [])
		},
		"findings": [
			{
				"id": "review.runtime_history.defense_mobility_trend",
				"first_observed_wave": first_wave,
				"direct_or_root_cause": "root",
				"severity": "high" if float(final_stats.get("armor", 0)) < 6 or float(final_stats.get("speed", 0)) < 5 else "medium",
				"evidence": {
					"max_hp_start": first.get("player", {}).get("max_hp", first_stats.get("max_hp", 0)),
					"max_hp_final": final.get("player", {}).get("max_hp", final_stats.get("max_hp", 0)),
					"armor_start": first_stats.get("armor", 0),
					"armor_final": final_stats.get("armor", 0),
					"speed_start": first_stats.get("speed", 0),
					"speed_final": final_stats.get("speed", 0)
				},
				"counterfactual": "如果防御和移动在门槛波前补齐，结算阶段容错会更高。",
				"next_run_rule": "门槛波前优先补护甲、移速和生命，而不是继续买延迟收益。"
			},
			{
				"id": "review.runtime_history.damage_curse_weapon_trend",
				"first_observed_wave": first_wave,
				"direct_or_root_cause": "contributing",
				"severity": "medium",
				"evidence": {
					"percent_damage_start": first_stats.get("percent_damage", 0),
					"percent_damage_final": final_stats.get("percent_damage", 0),
					"curse_start": first_stats.get("curse", 0),
					"curse_final": final_stats.get("curse", 0),
					"weapon_damage_start": _weapon_damage_total(first_weapons),
					"weapon_damage_final": _weapon_damage_total(final_weapons),
					"weapon_count_start": first_weapons.size(),
					"weapon_count_final": final_weapons.size()
				},
				"counterfactual": "如果输出增长和武器贡献没有追上诅咒带来的风险，最终波会被放大。",
				"next_run_rule": "提高诅咒前先确认武器贡献和单体输出已经形成闭环。"
			},
			{
				"id": "review.runtime_history.final_state_trigger",
				"first_observed_wave": final_wave,
				"direct_or_root_cause": "direct",
				"severity": "high",
				"evidence": {
					"current_hp": final.get("player", {}).get("current_hp", 0),
					"max_hp": final.get("player", {}).get("max_hp", final_stats.get("max_hp", 0)),
					"completed_wave": final_wave
				},
				"counterfactual": "最终状态只能解释直接触发点，早期根因要结合前面事件趋势判断。",
				"next_run_rule": "复盘时分开看早期成长断档和最终死亡触发点。"
			}
		]
	}
	report["warnings"] = history.get("data_quality", {}).get("warnings", [])
	report["confidence"] = 0.72


func _apply_double_illusionist_shop(report, snapshot):
	var rules = _rule_pack.get("double_illusionist_wave_3", {})
	report["summary"] = rules.get("summary", {
		"message_key": "report.summary.healthy_early_double_illusionist",
		"severity": "info",
		"rule_id": "summary.double_illusionist.wave_3"
	}).duplicate(true)
	report["summary"]["evidence"] = ["$.completed_wave", "$.shop.candidates"]
	var order = rules.get("shop_order", [])
	var buy_now = {}
	for item_id in rules.get("buy_now", []):
		buy_now[str(item_id)] = true
	var shop = snapshot.get("shop", {})
	var candidates = _sorted_shop_candidates(shop.get("candidates", []))
	var materials = int(snapshot.get("player", {}).get("materials", 0))
	var planned_cost = 0
	for candidate in candidates:
		if buy_now.has(str(candidate.get("id", ""))):
			planned_cost += int(candidate.get("price", 0))
	var actions = []
	for candidate in candidates:
		var item_id = str(candidate.get("id", "unknown"))
		var action = "lock"
		if buy_now.has(item_id) and planned_cost <= materials:
			action = "buy_now"
		actions.append({
			"item_id": item_id,
			"display_name": str(candidate.get("display_name", item_id)),
			"action": action,
			"rank": _rank_for(order, item_id, actions.size() + 1),
			"price": int(candidate.get("price", 0)),
			"reasons": _reason_entries(rules, item_id),
			"reason_codes": rules.get("reason_codes", {}).get(item_id, []),
			"tradeoffs": [{
				"rule_id": "tradeoff.occupies_shop_slot" if action == "lock" else "tradeoff.spends_materials_now",
				"evidence": ["$.shop.candidates", "$.player.materials"]
			}],
			"confidence": 0.9
		})
	actions.sort_custom(self, "_sort_by_rank")
	report["shop_advice"] = actions
	report["reroll_advice"] = {
		"action": "do_not_reroll_before_buying",
		"budget_after_buys": materials - planned_cost,
		"rule_id": "shop.reroll.preserve_priority_candidates"
	}
	_apply_rule_gaps(report, snapshot, rules)
	_apply_rule_plans(report, snapshot, rules)
	report["confidence"] = 0.86


func _apply_generic_shop(report, snapshot):
	var candidates = _sorted_shop_candidates(snapshot.get("shop", {}).get("candidates", []))
	var materials = int(snapshot.get("player", {}).get("materials", 0))
	var spent = 0
	var rank = 1
	for candidate in candidates:
		var price = int(candidate.get("price", 0))
		var action = "skip"
		if spent + price <= materials and str(candidate.get("id", "")).begins_with("weapon_"):
			action = "buy_now"
			spent += price
		elif price > 0 and price <= materials:
			action = "defer"
		report["shop_advice"].append({
			"item_id": str(candidate.get("id", "unknown")),
			"display_name": str(candidate.get("display_name", candidate.get("id", "未知候选"))),
			"action": action,
			"rank": rank,
			"price": price,
			"reasons": [{"rule_id": "shop.generic.weapon_priority", "evidence": ["$.shop.candidates"]}],
			"reason_codes": ["shop.generic.weapon_priority"],
			"tradeoffs": [],
			"confidence": 0.55
		})
		rank += 1


func _apply_rule_gaps(report, snapshot, rules):
	var stats = _stats(snapshot)
	var completed_wave = int(snapshot.get("completed_wave", 0))
	report["stat_diagnosis"] = []
	for gap_rule in rules.get("stat_gaps", []):
		var stat_id = str(gap_rule.get("stat_id", "unknown"))
		var current = 0
		if str(gap_rule.get("current_path", "")) == "recovery":
			current = max(float(stats.get("hp_regeneration", 0)), float(stats.get("lifesteal", 0)))
		else:
			current = float(stats.get(str(gap_rule.get("current_path", stat_id)), 0))
		report["stat_diagnosis"].append({
			"stat_id": stat_id,
			"current": current,
			"target": gap_rule.get("target", {}),
			"deadline_wave": completed_wave + int(gap_rule.get("deadline_offset", 3)),
			"severity": str(gap_rule.get("severity", "medium")),
			"dimensions": gap_rule.get("dimensions", []),
			"rule_id": str(gap_rule.get("rule_id", "gap.unknown")),
			"evidence": ["$.player.stats", "$.player.stats_at_wave_3_end"]
		})


func _apply_rule_plans(report, snapshot, rules):
	var completed_wave = int(snapshot.get("completed_wave", 0))
	var plans = rules.get("plans", {})
	var plus_3 = plans.get("wave_plus_3", {})
	var plus_5 = plans.get("wave_plus_5", {})
	report["plans"]["wave_plus_3"] = _plan_from_rule(completed_wave + 3, plus_3)
	report["plans"]["wave_plus_5"] = _plan_from_rule(completed_wave + 5, plus_5)
	if plus_5.has("reference_wave"):
		report["plans"]["wave_plus_5"]["reference_wave"] = plus_5["reference_wave"]


func _apply_generic_gaps(report, snapshot):
	if report["stat_diagnosis"].size() > 0:
		return
	var stats = _stats(snapshot)
	var completed_wave = int(snapshot.get("completed_wave", 0))
	var checks = [
		{"stat_id": "armor", "current": float(stats.get("armor", 0)), "target": {"min": 4}, "dimensions": ["survival"]},
		{"stat_id": "speed", "current": float(stats.get("speed", 0)), "target": {"min": 5}, "dimensions": ["mobility", "survival"]},
		{"stat_id": "percent_damage", "current": float(stats.get("percent_damage", 0)), "target": {"min": 0}, "dimensions": ["damage"]}
	]
	for check in checks:
		if float(check["current"]) < float(check["target"].values()[0]):
			report["stat_diagnosis"].append({
				"stat_id": check["stat_id"],
				"current": check["current"],
				"target": check["target"],
				"deadline_wave": completed_wave + 3,
				"severity": "medium",
				"dimensions": check["dimensions"],
				"rule_id": "gap.generic." + str(check["stat_id"]),
				"evidence": ["$.player.stats"]
			})


func _apply_generic_plans(report, snapshot):
	var completed_wave = int(snapshot.get("completed_wave", 0))
	report["plans"]["wave_plus_3"] = {
		"deadline_wave": completed_wave + 3,
		"targets": {
			"armor": {"min": 4},
			"speed": {"min": 5},
			"recovery": {"min_sources": 1}
		},
		"priorities": ["weapons", "armor", "speed", "recovery"],
		"avoid": ["do_not_reroll_before_resolving_high_value_shop_items"],
		"fallback": ["if data is incomplete, keep advice conservative"]
	}
	report["plans"]["wave_plus_5"] = {
		"deadline_wave": completed_wave + 5,
		"targets": {
			"max_hp": {"min": 30},
			"armor": {"min": 6},
			"percent_damage": {"min": 0}
		},
		"priorities": ["damage", "survival", "economy"],
		"avoid": ["avoid_delayed_payoff_before_elite_or_boss_waves"],
		"fallback": ["buy immediate survivability when under target"]
	}


func _empty_plan(deadline_wave):
	return {
		"deadline_wave": deadline_wave,
		"targets": {},
		"priorities": [],
		"avoid": [],
		"fallback": []
	}


func _plan_from_rule(deadline_wave, plan_rule):
	return {
		"deadline_wave": deadline_wave,
		"targets": plan_rule.get("targets", {}),
		"priorities": plan_rule.get("priorities", []),
		"avoid": plan_rule.get("avoid", []),
		"fallback": plan_rule.get("fallback", [])
	}


func _stats(snapshot):
	var player = snapshot.get("player", {})
	if typeof(player.get("stats", null)) == TYPE_DICTIONARY:
		return player["stats"]
	if typeof(player.get("stats_at_wave_3_end", null)) == TYPE_DICTIONARY:
		return player["stats_at_wave_3_end"]
	return {}


func _snapshots_from_events(events):
	var snapshots = []
	for event in events:
		if typeof(event) != TYPE_DICTIONARY:
			continue
		var payload = event.get("payload", {})
		if typeof(payload) != TYPE_DICTIONARY:
			continue
		var snapshot = payload.get("snapshot", null)
		if typeof(snapshot) == TYPE_DICTIONARY:
			snapshots.append(snapshot)
	return snapshots


func _weapon_damage_total(weapons):
	var total = 0.0
	if typeof(weapons) != TYPE_ARRAY:
		return total
	for weapon in weapons:
		if typeof(weapon) == TYPE_DICTIONARY:
			total += float(weapon.get("damage_last_wave", 0))
	return total


func _sorted_shop_candidates(candidates):
	var result = []
	if typeof(candidates) == TYPE_ARRAY:
		for candidate in candidates:
			if typeof(candidate) == TYPE_DICTIONARY:
				result.append(candidate)
	result.sort_custom(self, "_sort_by_slot")
	return result


func _sort_by_slot(a, b):
	return int(a.get("slot", 0)) < int(b.get("slot", 0))


func _sort_by_rank(a, b):
	return int(a.get("rank", 99)) < int(b.get("rank", 99))


func _rank_for(order, item_id, fallback):
	for index in range(order.size()):
		if str(order[index]) == item_id:
			return index + 1
	return fallback


func _reason_entries(rules, item_id):
	var entries = []
	for code in rules.get("reason_codes", {}).get(item_id, []):
		entries.append({
			"rule_id": str(code),
			"evidence": ["$.shop.candidates", "$.weapons", "$.player.stats"]
		})
	if entries.empty():
		entries.append({"rule_id": "shop.generic.known_candidate", "evidence": ["$.shop.candidates"]})
	return entries


func _error_report(code):
	var report = _base_report({})
	report["summary"]["message_key"] = "report.error." + str(code)
	report["summary"]["severity"] = "critical"
	report["warnings"] = [str(code)]
	report["confidence"] = 0
	return report
