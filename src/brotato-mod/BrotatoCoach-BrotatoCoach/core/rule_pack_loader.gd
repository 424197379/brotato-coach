extends Reference

const RULE_PACK_PATH = "res://mods-unpacked/BrotatoCoach-BrotatoCoach/rules/rule-pack-0.1.0.json"


func load_rule_pack():
	var file = File.new()
	if not file.file_exists(RULE_PACK_PATH):
		return {
			"rule_pack_version": "brotato-1.1.15.4+coach.1",
			"warnings": ["rule_pack_file_missing"]
		}
	var err = file.open(RULE_PACK_PATH, File.READ)
	if err != OK:
		return {
			"rule_pack_version": "brotato-1.1.15.4+coach.1",
			"warnings": ["rule_pack_file_open_failed"]
		}
	var text = file.get_as_text()
	file.close()
	var parsed = JSON.parse(text)
	if parsed.error != OK or typeof(parsed.result) != TYPE_DICTIONARY:
		return {
			"rule_pack_version": "brotato-1.1.15.4+coach.1",
			"warnings": ["rule_pack_json_parse_failed"]
		}
	return parsed.result
