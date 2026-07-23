extends Reference

const RulePackLoader = preload("res://mods-unpacked/BrotatoCoach-BrotatoCoach/core/rule_pack_loader.gd")
const OfflineRuleEngine = preload("res://mods-unpacked/BrotatoCoach-BrotatoCoach/core/offline_rule_engine.gd")
const CoachReportPanel = preload("res://mods-unpacked/BrotatoCoach-BrotatoCoach/ui/coach_report_panel.gd")


func analyze_and_show(owner, snapshot, entrance := "unknown", focus_return := null):
	var recorder = _recorder(owner)
	if recorder != null:
		if str(snapshot.get("phase", "")) == "run_end":
			recorder.record_run_end(snapshot)
			snapshot["history"] = recorder.load_current_events()
		recorder.record_coach_requested(snapshot, entrance)
	var loader = RulePackLoader.new()
	var engine = OfflineRuleEngine.new(loader.load_rule_pack())
	var report = engine.analyze(snapshot)
	_show_panel(owner, report, focus_return)


func record_shop_ready(owner, shop_items):
	var recorder = _recorder(owner)
	if recorder == null:
		return
	var candidates = build_shop_candidates(shop_items)
	var snapshot = build_runtime_snapshot(owner, "shop", candidates)
	recorder.record_shop_snapshot(snapshot)


func build_runtime_snapshot(owner, phase, shop_candidates := []):
	var snapshot = {
		"schema_version": "0.1.0",
		"phase": phase,
		"completed_wave": _current_wave(owner),
		"next_wave": _current_wave(owner) + 1,
		"run": {
			"character_id": _character_id(owner),
			"difficulty": _difficulty(owner),
			"is_endless": _is_endless(owner)
		},
		"player": {
			"level": _player_level(),
			"current_xp": _player_current_xp(),
			"materials": _player_gold(),
			"current_hp": _player_current_health(),
			"max_hp": _player_max_hp(),
			"stats": _read_stats(owner)
		},
		"weapons": _read_weapons(owner),
		"items": _read_items(owner),
		"active_sets": _read_sets(owner),
		"recent_waves": [],
		"shop": null,
		"data_quality": {
			"sources": ["runtime_state"],
			"warnings": []
		}
	}
	if phase == "shop":
		snapshot["shop"] = {
			"rerolls_this_shop": 0,
			"candidates": shop_candidates
		}
	return snapshot


func build_shop_candidates(shop_items):
	var candidates = []
	var slot = 0
	for shop_item in shop_items:
		if not is_instance_valid(shop_item):
			slot += 1
			continue
		var item_data = _object_get(shop_item, "item_data", null)
		var is_active = bool(_object_get(shop_item, "active", false))
		# Inactive controls remain in some shop containers after a buy or refresh animation.
		if item_data == null or not is_active:
			slot += 1
			continue
		var item_id = _resource_id(item_data)
		candidates.append({
			"slot": slot,
			"id": item_id,
			"display_name": _display_name(item_data, item_id),
			"kind": "weapon" if item_id.begins_with("weapon_") else "item",
			"tier": int(_object_get(item_data, "tier", _object_get(shop_item, "tier", 0))),
			"price": int(_object_get(shop_item, "value", 0)),
			"locked": bool(_object_get(shop_item, "locked", false)),
			"active": is_active,
			"sets": _string_array(_object_get(item_data, "sets", []))
		})
		slot += 1
	return candidates


func _show_panel(owner, report, focus_return := null):
	# Keep the overlay owned by the UI that opened it. Scene-root overlays survive
	# a pause menu closing and can otherwise block the game behind an empty frame.
	if not is_instance_valid(owner) or not (owner is Control):
		return
	var existing = owner.get_node_or_null("BrotatoCoachReportPanel")
	if existing != null:
		existing.hide()
		existing.queue_free()
	var panel = CoachReportPanel.new()
	panel.name = "BrotatoCoachReportPanel"
	owner.add_child(panel)
	panel.set_host(owner)
	panel.set_report(report, focus_return)


func _recorder(owner):
	var tree = owner.get_tree()
	if tree == null:
		return null
	var root = tree.get_root()
	if root == null:
		return null
	return root.get_node_or_null("BrotatoCoachRecorder")


func _current_wave(owner):
	return int(RunData.current_wave)


func _difficulty(owner):
	return int(RunData.current_difficulty)


func _is_endless(owner):
	return bool(RunData.is_endless_run)


func _character_id(owner):
	if RunData.has_method("get_player_character"):
		var character = RunData.get_player_character(0)
		return _resource_id(character)
	return "unknown"


func _player_level():
	if RunData.has_method("get_player_level"):
		return RunData.get_player_level(0)
	return _player_data_value("level", 0)


func _player_gold():
	if RunData.has_method("get_player_gold"):
		return RunData.get_player_gold(0)
	return _player_data_value("gold", 0)


func _player_max_hp():
	var effects = {}
	if RunData.has_method("get_player_effects"):
		effects = RunData.get_player_effects(0)
	if typeof(effects) == TYPE_DICTIONARY and effects.has(Keys.stat_max_hp_hash):
		return effects[Keys.stat_max_hp_hash]
	return _player_data_value("max_health", 0)


func _player_current_health():
	var player_data = _player_data()
	if typeof(player_data) == TYPE_DICTIONARY:
		return player_data.get("current_health", 0)
	if player_data != null:
		return player_data.current_health
	return 0


func _player_current_xp():
	var player_data = _player_data()
	if typeof(player_data) == TYPE_DICTIONARY:
		return player_data.get("current_xp", 0)
	if player_data != null:
		return player_data.current_xp
	return 0


func _player_data_value(key, fallback):
	var player_data = _player_data()
	return _object_get(player_data, key, fallback)


func _player_data():
	if typeof(RunData.players_data) == TYPE_ARRAY and RunData.players_data.size() > 0:
		return RunData.players_data[0]
	return null


func _read_stats(owner):
	var stats = {}
	var stat_hashes = {
		"max_hp": Keys.stat_max_hp_hash,
		"armor": Keys.stat_armor_hash,
		"dodge": Keys.stat_dodge_hash,
		"speed": Keys.stat_speed_hash,
		"luck": Keys.stat_luck_hash,
		"harvesting": Keys.stat_harvesting_hash,
		"melee_damage": Keys.stat_melee_damage_hash,
		"ranged_damage": Keys.stat_ranged_damage_hash,
		"elemental_damage": Keys.stat_elemental_damage_hash,
		"engineering": Keys.stat_engineering_hash,
		"percent_damage": Keys.stat_percent_damage_hash,
		"attack_speed": Keys.stat_attack_speed_hash,
		"crit_chance": Keys.stat_crit_chance_hash,
		"range": Keys.stat_range_hash,
		"hp_regeneration": Keys.stat_hp_regeneration_hash,
		"lifesteal": Keys.stat_lifesteal_hash,
		"curse": Keys.stat_curse_hash,
		"pickup_range": Keys.stat_pickup_range_hash,
		"xp_gain": Keys.stat_xp_gain_hash,
		"enemy_health": Keys.stat_enemy_health_hash,
		"enemy_damage": Keys.stat_enemy_damage_hash,
		"enemy_speed": Keys.stat_enemy_speed_hash,
		"number_of_enemies": Keys.stat_number_of_enemies_hash,
		"damage_against_bosses": Keys.stat_damage_against_bosses_hash,
		"explosion_damage": Keys.stat_explosion_damage_hash,
		"explosion_size": Keys.stat_explosion_size_hash,
		"hp_start_wave_percent": Keys.stat_hp_start_wave_percent_hash,
		"weapon_slots": Keys.stat_weapon_slots_hash
	}
	for key in stat_hashes.keys():
		stats[key] = Utils.get_stat(stat_hashes[key], 0)
	return stats


func _read_weapons(owner):
	if not RunData.has_method("get_player_weapons"):
		return []
	var weapons = []
	var raw_weapons = RunData.get_player_weapons(0)
	if typeof(raw_weapons) != TYPE_ARRAY:
		return weapons
	var slot = 0
	for weapon in raw_weapons:
		weapons.append({
			"id": _resource_id(weapon),
			"display_name": _display_name(weapon, _resource_id(weapon)),
			"slot": slot,
			"tier": int(_object_get(weapon, "tier", 0)),
			"damage_last_wave": float(_object_get(weapon, "dmg_dealt_last_wave", 0)),
			"sets": _string_array(_object_get(weapon, "sets", []))
		})
		slot += 1
	return weapons


func _read_items(owner):
	if not RunData.has_method("get_player_items"):
		return []
	var counts = {}
	var raw_items = RunData.get_player_items(0)
	if typeof(raw_items) != TYPE_ARRAY:
		return []
	for item in raw_items:
		var item_id = _resource_id(item)
		counts[item_id] = int(counts.get(item_id, 0)) + 1
	var items = []
	var ids = counts.keys()
	ids.sort()
	for item_id in ids:
		items.append({"id": item_id, "display_name": item_id, "count": counts[item_id]})
	return items


func _read_sets(owner):
	var player_data = _player_data()
	if typeof(player_data) == TYPE_DICTIONARY:
		return player_data.get("active_sets", {})
	if player_data != null:
		return player_data.active_sets
	return {}


func _resource_id(value):
	if value == null:
		return "unknown"
	if typeof(value) == TYPE_STRING:
		return value
	if typeof(value) == TYPE_DICTIONARY:
		for key in ["id", "my_id", "weapon_id", "item_id"]:
			if value.has(key):
				return str(value[key])
	if typeof(value) == TYPE_OBJECT:
		for key in ["id", "my_id", "weapon_id", "item_id"]:
			var candidate = _object_get(value, key, null)
			if candidate != null and str(candidate) != "":
				return str(candidate)
		var resource_path = _object_get(value, "resource_path", "")
		if str(resource_path) != "":
			return str(resource_path).get_file().get_basename()
	return "unknown"


func _display_name(value, fallback):
	var raw_name = _object_get(value, "name", "")
	if str(raw_name) != "":
		var translated = TranslationServer.translate(str(raw_name))
		if str(translated) != "":
			return str(translated)
	return fallback


func _object_get(object, key, fallback):
	if object == null:
		return fallback
	if typeof(object) == TYPE_DICTIONARY:
		return object.get(key, fallback)
	if typeof(object) == TYPE_OBJECT:
		var value = object.get(key)
		if value == null:
			return fallback
		return value
	return fallback


func _string_array(value):
	var result = []
	if typeof(value) != TYPE_ARRAY:
		return result
	for item in value:
		result.append(str(item))
	return result
