extends Node

const MOD_NAME = "BrotatoCoach"
const MOD_DIR = "BrotatoCoach-BrotatoCoach/"
const EXT_DIR = "res://mods-unpacked/" + MOD_DIR + "extensions/"
const CoachRecorder = preload("res://mods-unpacked/BrotatoCoach-BrotatoCoach/core/coach_recorder.gd")


func _init():
	_install_extensions()


func _install_extensions():
	var extensions = [
		EXT_DIR + "ui/menus/shop/base_shop.gd",
		EXT_DIR + "ui/menus/ingame/ingame_main_menu.gd",
		EXT_DIR + "ui/menus/run/end_run.gd"
	]
	for script_path in extensions:
		ModLoaderMod.install_script_extension(script_path)


func _ready():
	_ensure_recorder()
	ModLoaderLog.info("Loaded offline coach entry points.", MOD_NAME)


func _ensure_recorder():
	var root = get_tree().get_root()
	if root.get_node_or_null("BrotatoCoachRecorder") != null:
		return
	var recorder = CoachRecorder.new()
	recorder.name = "BrotatoCoachRecorder"
	root.call_deferred("add_child", recorder)
