extends Node
## Save/load of story flags + clues. Autoload name: Save

const PATH := "user://save.json"

func has_save() -> bool:
	return FileAccess.file_exists(PATH)

## Read just the display metadata (phase + timestamp) without loading into game state.
func peek_meta() -> Dictionary:
	if not has_save():
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return {"phase": str(d.get("phase", "")), "time": str(d.get("time", ""))}

func save_game() -> void:
	var data := {
		"level": Scenes.current_level,
		"flags": Game.flags,
		"clues": Cases.clues,
		"solved": Cases.solved,
		"phase": Cases.phase_label(),
		"time": Time.get_datetime_string_from_system(false, true),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_game() -> void:
	if not has_save():
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	Game.flags = data.get("flags", {})
	Cases.clues = data.get("clues", {})
	Cases.solved = data.get("solved", {})
	var lvl: String = data.get("level", "alley")
	if lvl == "":
		lvl = "alley"
	Scenes.change_level(lvl, "start")

func clear() -> void:
	if has_save():
		DirAccess.remove_absolute(PATH)
