extends "res://ui/menus/ingame/ingame_main_menu.gd"

const CoachCoordinator = preload("res://mods-unpacked/BrotatoCoach-BrotatoCoach/core/coach_coordinator.gd")

var _brotato_coach_button = null


func _ready():
	call_deferred("_brotato_coach_install_button")


func _brotato_coach_install_button():
	var parent = _brotato_coach_button_parent()
	if parent == null:
		return
	if parent.get_node_or_null("BrotatoCoachPauseButton") != null:
		return
	_brotato_coach_button = Button.new()
	_brotato_coach_button.name = "BrotatoCoachPauseButton"
	_brotato_coach_button.text = "分析当前局"
	_brotato_coach_button.focus_mode = Control.FOCUS_ALL
	parent.add_child(_brotato_coach_button)
	_brotato_coach_button.connect("pressed", self, "_brotato_coach_on_pressed")


func _brotato_coach_on_pressed():
	var coordinator = CoachCoordinator.new()
	var snapshot = coordinator.build_runtime_snapshot(self, "paused", [])
	coordinator.analyze_and_show(self, snapshot, "pause")


func _brotato_coach_button_parent():
	var resume_button = get("_resume_button")
	if is_instance_valid(resume_button):
		return resume_button.get_parent()
	var found = find_node("ResumeButton", true, false)
	if is_instance_valid(found):
		return found.get_parent()
	return null
