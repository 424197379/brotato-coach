extends SceneTree

var _failures = []


func _init():
	call_deferred("_run")


func _run():
	if not InputMap.has_action("ui_cancel"):
		InputMap.add_action("ui_cancel")

	var panel_script = load("res://coach_report_panel_under_test.gd")
	if panel_script == null:
		_fail("could not load copied production panel script")
		_finish()
		return

	yield(_check_initial_focus_and_cancel(panel_script), "completed")
	yield(_check_host_hide_cleanup(panel_script), "completed")
	_finish()


func _check_initial_focus_and_cancel(panel_script):
	var host = Control.new()
	host.name = "HostForCancel"
	host.rect_min_size = Vector2(800, 600)
	get_root().add_child(host)

	var trigger = Button.new()
	trigger.name = "TriggerButton"
	trigger.text = "Trigger"
	trigger.focus_mode = Control.FOCUS_ALL
	trigger.rect_min_size = Vector2(100, 40)
	host.add_child(trigger)
	trigger.grab_focus()

	var panel = panel_script.new()
	panel.name = "BrotatoCoachReportPanel"
	host.add_child(panel)
	panel.set_host(host)
	panel.set_report(_sample_report(), trigger)
	yield(self, "idle_frame")
	yield(self, "idle_frame")

	var close_button = panel.get_node_or_null("CoachPanelContent/CoachReportCloseButton")
	_assert(is_instance_valid(close_button), "close button exists")
	if is_instance_valid(close_button):
		_assert(close_button.has_focus(), "close button receives initial focus")
	_assert(panel.get_parent() == host, "panel is hosted by triggering owner")

	var event = InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	panel._input(event)
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	yield(self, "idle_frame")

	_assert(not is_instance_valid(panel) or panel.get_parent() == null, "ui_cancel removes panel from host")
	if is_instance_valid(trigger):
		_assert(trigger.has_focus(), "ui_cancel restores trigger focus")
	host.queue_free()
	yield(self, "idle_frame")


func _check_host_hide_cleanup(panel_script):
	var host = Control.new()
	host.name = "HostForHide"
	host.rect_min_size = Vector2(800, 600)
	get_root().add_child(host)

	var trigger = Button.new()
	trigger.name = "TriggerButton"
	trigger.text = "Trigger"
	trigger.focus_mode = Control.FOCUS_ALL
	host.add_child(trigger)

	var panel = panel_script.new()
	panel.name = "BrotatoCoachReportPanel"
	host.add_child(panel)
	panel.set_host(host)
	panel.set_report(_sample_report(), trigger)
	yield(self, "idle_frame")
	yield(self, "idle_frame")

	host.hide()
	yield(self, "idle_frame")
	yield(self, "idle_frame")
	yield(self, "idle_frame")

	_assert(not is_instance_valid(panel) or panel.get_parent() == null, "host hide cleans up panel")
	host.queue_free()
	yield(self, "idle_frame")


func _sample_report():
	return {
		"schema_version": "0.1.0",
		"report_id": "godot-panel-contract",
		"snapshot_fingerprint": "sha256:runtime",
		"rule_pack_version": "brotato-1.1.15.4+coach.1",
		"summary": {
			"message_key": "report.summary.current_run_runtime",
			"severity": "info"
		},
		"shop_advice": [
			{
				"rank": 1,
				"display_name": "测试武器",
				"action": "buy_now",
				"price": 12,
				"reasons": [{"rule_id": "shop.generic.weapon_priority"}]
			}
		],
		"stat_diagnosis": [],
		"plans": {
			"wave_plus_3": {"deadline_wave": 7, "targets": {}, "priorities": [], "avoid": []},
			"wave_plus_5": {"deadline_wave": 9, "targets": {}, "priorities": [], "avoid": []}
		},
		"run_review": null,
		"warnings": [],
		"confidence": 0.75
	}


func _assert(condition, message):
	if not condition:
		_fail(message)


func _fail(message):
	_failures.append(message)
	printerr("FAIL: " + str(message))


func _finish():
	if _failures.empty():
		print("PASS: panel contract")
		quit(0)
	else:
		printerr("FAILURES: " + PoolStringArray(_failures).join("; "))
		quit(1)
