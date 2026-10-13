extends Interactable
## A doorway/edge that moves the player to another level.

@export var target_level: String = ""
@export var target_entry: String = "start"
@export var requires_flag: String = ""   # if set, this exit only exists once the flag is true
@export_multiline var travel_note: String = ""  # optional narration shown before the transition

func _ready() -> void:
	if requires_flag != "" and not Game.has_flag(requires_flag):
		queue_free()
		return
	# Tell the player where this door leads, e.g. "[E] Go to the Docks".
	prompt_text = ("Go to " + Scenes.level_name(target_level)) if target_level != "" else "Enter"
	add_to_group("ground_prop")
	super._ready()

func interact() -> void:
	if target_level == "":
		return
	Audio.play_sfx("door")
	if travel_note != "":
		Narrator.show_lines([travel_note])
		await Narrator.finished
	Scenes.change_level(target_level, target_entry)
