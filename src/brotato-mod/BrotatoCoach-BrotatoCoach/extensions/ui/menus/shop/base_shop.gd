extends "res://ui/menus/shop/base_shop.gd"

const CoachCoordinator = preload("res://mods-unpacked/BrotatoCoach-BrotatoCoach/core/coach_coordinator.gd")

var _brotato_coach_button = null


func _ready():
	call_deferred("_brotato_coach_install_button")


func _brotato_coach_install_button():
	var parent = _brotato_coach_shop_button_parent()
	if parent == null:
		return
	if parent.get_node_or_null("BrotatoCoachShopButton") != null:
		return
	_brotato_coach_button = Button.new()
	_brotato_coach_button.name = "BrotatoCoachShopButton"
	_brotato_coach_button.text = "教练建议"
	_brotato_coach_button.focus_mode = Control.FOCUS_ALL
	parent.add_child(_brotato_coach_button)
	_brotato_coach_button.connect("pressed", self, "_brotato_coach_on_shop_pressed")
	var coordinator = CoachCoordinator.new()
	coordinator.record_shop_ready(self, _brotato_coach_shop_items())


func _brotato_coach_on_shop_pressed():
	var coordinator = CoachCoordinator.new()
	var shop_items = _brotato_coach_shop_items()
	var candidates = coordinator.build_shop_candidates(shop_items)
	var snapshot = coordinator.build_runtime_snapshot(self, "shop", candidates)
	coordinator.analyze_and_show(self, snapshot, "shop")


func _brotato_coach_shop_button_parent():
	if has_method("_get_reroll_button"):
		var button = call("_get_reroll_button", 0)
		if is_instance_valid(button):
			return button.get_parent()
	return null


func _brotato_coach_shop_items():
	if has_method("get_player_shop_items"):
		var items = call("get_player_shop_items", 0)
		if typeof(items) == TYPE_ARRAY:
			return items
	if has_method("_get_shop_items_container"):
		var container = call("_get_shop_items_container", 0)
		if is_instance_valid(container):
			var stored = container.get("_shop_items")
			if typeof(stored) == TYPE_ARRAY:
				return stored
	return []
