extends "res://ui/menus/ingame/ingame_main_menu.gd"

const CoachCoordinator = preload("res://mods-unpacked/BrotatoCoach-BrotatoCoach/core/coach_coordinator.gd")

var _brotato_coach_button = null


func _ready():
	call_deferred("_brotato_coach_install_button")


func _brotato_coach_install_button():
	var resume_button = _brotato_coach_resume_button()
	if not is_instance_valid(resume_button):
		return
	var parent = resume_button.get_parent()
	if parent == null:
		return
	if parent.get_node_or_null("BrotatoCoachPauseButton") != null:
		return
	var following = _brotato_coach_next_focusable_sibling(parent, resume_button)
	_brotato_coach_button = Button.new()
	_brotato_coach_button.name = "BrotatoCoachPauseButton"
	_brotato_coach_button.text = "分析当前局"
	_brotato_coach_button.focus_mode = Control.FOCUS_ALL
	parent.add_child_below_node(resume_button, _brotato_coach_button)
	_brotato_coach_link_vertical_focus(resume_button, _brotato_coach_button, following)
	_brotato_coach_button.connect("pressed", self, "_brotato_coach_on_pressed")


func _brotato_coach_on_pressed():
	var coordinator = CoachCoordinator.new()
	var snapshot = coordinator.build_runtime_snapshot(self, "paused", [])
	coordinator.analyze_and_show(self, snapshot, "pause", _brotato_coach_button)


func _brotato_coach_resume_button():
	var resume_button = get("_resume_button")
	if is_instance_valid(resume_button):
		return resume_button
	var found = find_node("ResumeButton", true, false)
	if is_instance_valid(found):
		return found
	return null


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


func _brotato_coach_link_vertical_focus(previous, current, following):
	var parent = current.get_parent() if is_instance_valid(current) else null
	if not _brotato_coach_is_sibling_focus_control(parent, previous) or not _brotato_coach_is_sibling_focus_control(parent, current):
		return
	if _brotato_coach_can_rewrite_focus_path(previous, "focus_next", parent):
		previous.focus_next = previous.get_path_to(current)
	current.focus_previous = current.get_path_to(previous)
	_brotato_coach_set_neighbour(parent, previous, "focus_neighbour_bottom", current)
	_brotato_coach_set_neighbour(parent, current, "focus_neighbour_top", previous)
	if not _brotato_coach_is_sibling_focus_control(parent, following):
		return
	current.focus_next = current.get_path_to(following)
	if _brotato_coach_can_rewrite_focus_path(following, "focus_previous", parent):
		following.focus_previous = following.get_path_to(current)
	_brotato_coach_set_neighbour(parent, current, "focus_neighbour_bottom", following)
	_brotato_coach_set_neighbour(parent, following, "focus_neighbour_top", current)


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
