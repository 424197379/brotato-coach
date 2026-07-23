extends "res://ui/menus/shop/base_shop.gd"

const CoachCoordinator = preload("res://mods-unpacked/BrotatoCoach-BrotatoCoach/core/coach_coordinator.gd")

var _brotato_coach_button = null


func _ready():
	call_deferred("_brotato_coach_install_button")


func _brotato_coach_install_button():
	var anchor = _brotato_coach_reroll_button()
	if not is_instance_valid(anchor):
		return
	var parent = anchor.get_parent()
	if parent == null:
		return
	if parent.get_node_or_null("BrotatoCoachShopButton") != null:
		return
	var following = _brotato_coach_next_focusable_sibling(parent, anchor)
	_brotato_coach_button = Button.new()
	_brotato_coach_button.name = "BrotatoCoachShopButton"
	_brotato_coach_button.text = "教练建议"
	_brotato_coach_button.focus_mode = Control.FOCUS_ALL
	parent.add_child_below_node(anchor, _brotato_coach_button)
	_brotato_coach_link_horizontal_focus(anchor, _brotato_coach_button, following)
	_brotato_coach_button.connect("pressed", self, "_brotato_coach_on_shop_pressed")
	var coordinator = CoachCoordinator.new()
	coordinator.record_shop_ready(self, _brotato_coach_live_shop_items())


func _brotato_coach_on_shop_pressed():
	var coordinator = CoachCoordinator.new()
	# Read the current ShopItem nodes on every click. The ready-time recorder is not an advice cache.
	var shop_items = _brotato_coach_live_shop_items()
	var candidates = coordinator.build_shop_candidates(shop_items)
	var snapshot = coordinator.build_runtime_snapshot(self, "shop", candidates)
	coordinator.analyze_and_show(self, snapshot, "shop", _brotato_coach_button)


func _brotato_coach_reroll_button():
	if has_method("_get_reroll_button"):
		var button = call("_get_reroll_button", 0)
		if is_instance_valid(button):
			return button
	return null


func _brotato_coach_live_shop_items():
	# BaseShop's current container is authoritative. Do not fall back to archive-like data when it exists.
	if has_method("_get_shop_items_container"):
		var container = call("_get_shop_items_container", 0)
		if is_instance_valid(container):
			var stored = _brotato_coach_property_value(container, "_shop_items", null)
			var stored_items = _brotato_coach_filter_live_shop_items(stored)
			if stored_items.size() > 0:
				return stored_items
			return _brotato_coach_filter_live_shop_items(container.get_children())
	# Compatibility fallback for BaseShop variants without the current-container helper.
	if has_method("get_player_shop_items"):
		return _brotato_coach_filter_live_shop_items(call("get_player_shop_items", 0))
	return []


func _brotato_coach_filter_live_shop_items(values):
	var result = []
	if typeof(values) != TYPE_ARRAY:
		return result
	for value in values:
		if _brotato_coach_is_live_shop_item(value):
			result.append(value)
	return result


func _brotato_coach_is_live_shop_item(value):
	if typeof(value) != TYPE_OBJECT or not is_instance_valid(value):
		return false
	return _brotato_coach_has_property(value, "item_data") and _brotato_coach_has_property(value, "value") and _brotato_coach_has_property(value, "locked") and _brotato_coach_has_property(value, "active")


func _brotato_coach_property_value(object, property_name, fallback):
	if typeof(object) != TYPE_OBJECT or not is_instance_valid(object):
		return fallback
	for descriptor in object.get_property_list():
		if str(descriptor.get("name", "")) == property_name:
			return object.get(property_name)
	return fallback


func _brotato_coach_has_property(object, property_name):
	if typeof(object) != TYPE_OBJECT or not is_instance_valid(object):
		return false
	for descriptor in object.get_property_list():
		if str(descriptor.get("name", "")) == property_name:
			return true
	return false


func _brotato_coach_next_focusable_sibling(parent, anchor):
	var configured = anchor.get_node_or_null(anchor.focus_next)
	if _brotato_coach_is_sibling_focus_control(parent, configured) and configured != anchor:
		return configured
	var after_anchor = false
	for child in parent.get_children():
		if child == anchor:
			after_anchor = true
			continue
		if after_anchor and _brotato_coach_is_sibling_focus_control(parent, child):
			return child
	return null


func _brotato_coach_link_horizontal_focus(previous, current, following):
	var parent = current.get_parent() if is_instance_valid(current) else null
	if not _brotato_coach_is_sibling_focus_control(parent, previous) or not _brotato_coach_is_sibling_focus_control(parent, current):
		return
	if _brotato_coach_can_rewrite_focus_path(previous, "focus_next", parent):
		previous.focus_next = previous.get_path_to(current)
	current.focus_previous = current.get_path_to(previous)
	_brotato_coach_set_neighbour(parent, previous, "focus_neighbour_right", current)
	_brotato_coach_set_neighbour(parent, current, "focus_neighbour_left", previous)
	if not _brotato_coach_is_sibling_focus_control(parent, following):
		return
	current.focus_next = current.get_path_to(following)
	if _brotato_coach_can_rewrite_focus_path(following, "focus_previous", parent):
		following.focus_previous = following.get_path_to(current)
	_brotato_coach_set_neighbour(parent, current, "focus_neighbour_right", following)
	_brotato_coach_set_neighbour(parent, following, "focus_neighbour_left", current)


func _brotato_coach_set_neighbour(parent, control, property_name, target):
	if _brotato_coach_is_sibling_focus_control(parent, control) and _brotato_coach_is_sibling_focus_control(parent, target):
		control.set(property_name, control.get_path_to(target))


func _brotato_coach_is_sibling_focus_control(parent, control):
	return parent != null and is_instance_valid(control) and control is Control and control.is_inside_tree() and control.get_parent() == parent and control.focus_mode != Control.FOCUS_NONE


func _brotato_coach_can_rewrite_focus_path(control, property_name, parent):
	var path = control.get(property_name)
	if str(path) == "":
		return true
	var configured = control.get_node_or_null(path)
	return _brotato_coach_is_sibling_focus_control(parent, configured)
