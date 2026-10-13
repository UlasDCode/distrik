extends Node
## Entry point. Normal launch -> main menu. Pass `-- --act1` to jump straight into Act 1 (testing).

func _ready() -> void:
	await get_tree().process_frame
	if _debug_act1():
		Game.set_flag("prologue_done")
		Game.set_flag("prologue_right")
		Game.set_flag("main_started")
		Scenes.change_level("office", "start")
		return
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")

func _debug_act1() -> bool:
	return "--act1" in OS.get_cmdline_user_args() or "--act1" in OS.get_cmdline_args()
