extends Node
## Level loading + fade transitions + player spawn. Autoload name: Scenes

const MENU := "res://scenes/ui/MainMenu.tscn"

var LEVELS := {
	"alley": "res://scenes/levels/Alley.tscn",
	"main_street": "res://scenes/levels/MainStreet.tscn",
	"downtown": "res://scenes/levels/Downtown.tscn",
	"subway": "res://scenes/levels/Subway.tscn",
	"cityhall": "res://scenes/levels/CityHall.tscn",
	"bar": "res://scenes/levels/Bar.tscn",
	"office": "res://scenes/levels/Office.tscn",
	"apartment": "res://scenes/levels/Apartment.tscn",
	"docks": "res://scenes/levels/Docks.tscn",
	"clinic": "res://scenes/levels/Clinic.tscn",
	"rooftop": "res://scenes/levels/Rooftop.tscn",
	"archive": "res://scenes/levels/Archive.tscn",
	"tower_lobby": "res://scenes/levels/TowerLobby.tscn",
	"penthouse": "res://scenes/levels/Penthouse.tscn",
}

# Player-facing display names (used on exit prompts + the map). Keep in sync with LEVELS.
const NAMES := {
	"alley": "the alley", "main_street": "Main Street", "downtown": "Downtown",
	"subway": "The Old Metro", "cityhall": "City Hall", "bar": "the Neon Dragon", "office": "the Office",
	"apartment": "the Apartment", "docks": "the Docks", "clinic": "Doc's Clinic",
	"rooftop": "the East Rooftops", "archive": "the Hall of Records",
	"tower_lobby": "the Tower Lobby", "penthouse": "Kanzaki's Penthouse",
}

func level_name(id: String) -> String:
	return NAMES.get(id, id)

# Act cards shown once on first entry (over the black transition). Populated for the main case.
const ACTS := {}

const MAIN_INTRO := [
	"They gave me a commendation for the alley case. A slip of paper, a handshake, forgotten by lunch.",
	"But that whistleblower's letter won't let me sleep. The docks. Whatever Kanzaki sank out there.",
	"One dead man was a warning. I'm going to find out what a syndicate is so afraid of.",
]

var current_level: String = ""
var pending_entry: String = "start"
var _fade: ColorRect
var _transitioning := false

func _ready() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 100
	add_child(cl)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_fade)
	_fade.modulate.a = 0.0  # menus/scenes visible by default

func change_level(level_id: String, entry: String = "start") -> void:
	if _transitioning:
		return
	if not LEVELS.has(level_id):
		push_error("SceneManager: unknown level '%s'" % level_id)
		return
	_transitioning = true
	Game.input_locked = true
	await _fade_to(1.0, 0.35)
	current_level = level_id
	pending_entry = entry
	get_tree().change_scene_to_file(LEVELS[level_id])
	await get_tree().process_frame
	await get_tree().process_frame
	# Act card on first entry, shown over the black screen before revealing the level.
	if ACTS.has(level_id) and not Game.has_flag("act_shown_" + level_id):
		Game.set_flag("act_shown_" + level_id)
		Narrator.show_card(ACTS[level_id][0], ACTS[level_id][1])
		await Narrator.finished
		Game.input_locked = true
	Atlas.mark_visited(level_id)
	# Autosave on arrival so closing the window mid-case never loses progress.
	Save.save_game()
	await _fade_to(0.0, 0.35)
	Game.input_locked = false
	_transitioning = false

func goto_menu() -> void:
	if _transitioning:
		return
	_transitioning = true
	Game.input_locked = true
	await _fade_to(1.0, 0.3)
	current_level = ""
	get_tree().change_scene_to_file(MENU)
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0, 0.3)
	Game.input_locked = false
	_transitioning = false

## Prologue is over -> bridge into the main case (one long, complex case).
func start_main_game() -> void:
	Game.set_flag("main_started")
	Narrator.show_lines(MAIN_INTRO)
	await Narrator.finished
	Narrator.show_card("DISTRIK", "The Kanzaki File")
	await Narrator.finished
	Narrator.show_card("ACT  I", "Follow the Water")
	await Narrator.finished
	change_level("office", "start")

func _fade_to(target_a: float, dur: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", target_a, dur)
	await t.finished
