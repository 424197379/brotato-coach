extends Node

const RUNS_ROOT = "user://brotato_coach/runs"

var _run_id = ""
var _sequence = 0
var _last_shop_key = ""


func record_shop_snapshot(snapshot):
	_ensure_run()
	var key = _shop_key(snapshot)
	if key == _last_shop_key:
		return
	_last_shop_key = key
	_record_event("shop_observed", {"snapshot": snapshot})


func record_coach_requested(snapshot, entrance):
	_ensure_run()
	_record_event("coach_requested", {
		"entrance": entrance,
		"completed_wave": int(snapshot.get("completed_wave", 0)),
		"phase": str(snapshot.get("phase", "unknown"))
	})


func record_run_end(snapshot):
	_ensure_run()
	_record_event("run_ended", {"snapshot": snapshot})


func load_current_events():
	_ensure_run()
	var path = _events_path()
	var file = File.new()
	var result = {
		"events": [],
		"data_quality": {
			"warnings": [],
			"skipped_lines": []
		}
	}
	if not file.file_exists(path):
		result["data_quality"]["warnings"].append("event_log_missing")
		return result
	if file.open(path, File.READ) != OK:
		result["data_quality"]["warnings"].append("event_log_open_failed")
		return result
	var line_number = 0
	while not file.eof_reached():
		var line = file.get_line()
		line_number += 1
		if line.strip_edges() == "":
			continue
		var parsed = JSON.parse(line)
		if parsed.error == OK and typeof(parsed.result) == TYPE_DICTIONARY:
			result["events"].append(parsed.result)
		elif file.eof_reached():
			_add_warning(result, "truncated_tail")
		else:
			_add_warning(result, "invalid_jsonl_event")
			result["data_quality"]["skipped_lines"].append(line_number)
	file.close()
	return result


func current_run_dir():
	_ensure_run()
	return RUNS_ROOT + "/" + _run_id


func _record_event(event_type, payload):
	var dir = Directory.new()
	dir.make_dir_recursive(current_run_dir())
	var event = {
		"schema_version": "0.1.0",
		"run_id": _run_id,
		"sequence": _sequence,
		"captured_at_utc": _utc_now(),
		"event_type": event_type,
		"player_index": 0,
		"payload": payload
	}
	_sequence += 1
	var file = File.new()
	var err = file.open(_events_path(), File.READ_WRITE)
	if err != OK:
		err = file.open(_events_path(), File.WRITE)
	if err != OK:
		return
	file.seek_end()
	file.store_line(JSON.print(event))
	file.close()


func _ensure_run():
	if _run_id != "":
		return
	var character_id = "unknown"
	if RunData.has_method("get_player_character"):
		var character = RunData.get_player_character(0)
		character_id = _resource_id(character)
	_run_id = "run-" + str(OS.get_unix_time()) + "-" + character_id


func _events_path():
	return current_run_dir() + "/events.jsonl"


func _shop_key(snapshot):
	var parts = [str(snapshot.get("completed_wave", 0))]
	var shop = snapshot.get("shop", {})
	for candidate in shop.get("candidates", []):
		parts.append(str(candidate.get("slot", "")) + ":" + str(candidate.get("id", "")) + ":" + str(candidate.get("price", "")) + ":" + str(candidate.get("locked", false)))
	return PoolStringArray(parts).join("|")


func _utc_now():
	var dt = OS.get_datetime(true)
	return "%04d-%02d-%02dT%02d:%02d:%02dZ" % [
		dt.year,
		dt.month,
		dt.day,
		dt.hour,
		dt.minute,
		dt.second
	]


func _add_warning(result, warning):
	if not result["data_quality"]["warnings"].has(warning):
		result["data_quality"]["warnings"].append(warning)


func _resource_id(value):
	if value == null:
		return "unknown"
	if typeof(value) == TYPE_STRING:
		return value
	if typeof(value) == TYPE_OBJECT:
		for key in ["id", "my_id", "weapon_id", "item_id"]:
			var candidate = value.get(key)
			if candidate != null and str(candidate) != "":
				return str(candidate)
	return "unknown"
