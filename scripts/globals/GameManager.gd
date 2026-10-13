extends Node
## Global game state + input registration. Autoload name: Game

signal flag_changed(flag: String, value)

var flags: Dictionary = {}
var input_locked: bool = false

func _ready() -> void:
	_register_inputs()

func _register_inputs() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action("interact", [KEY_E])
	_add_action("journal", [KEY_J, KEY_TAB])
	_add_action("map", [KEY_M])
	_add_action("pause", [KEY_ESCAPE])
	_add_action("advance", [KEY_SPACE, KEY_ENTER, KEY_E])

func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func set_flag(flag: String, value = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)

func get_flag(flag: String, default = false):
	return flags.get(flag, default)

func has_flag(flag: String) -> bool:
	return flags.get(flag, false) == true

## True when a modal flow owns input (dialogue, narration/cards, or a scene transition).
func ui_blocked() -> bool:
	return Dialogue.is_active() or Narrator.is_active() or Scenes._transitioning

func reset() -> void:
	flags.clear()
	input_locked = false
