extends Interactable
## The prologue's case-solving point. Any accusation closes the prologue, cues the ending
## text, then bridges into the main game.

@export var dialogue_id: String = "accuse"
@export var done_flag: String = "prologue_done"

const ENDING_RIGHT := [
	"You file the report with Kanzaki's name on it. Their people will bury it by morning.",
	"But the truth doesn't wash off. Not for me. Not this time.",
	"One case closed. The rain keeps falling.",
	"[color=#5ee6e6]— THE RAIN NEVER STOPS —[/color]",
]

const ENDING_WRONG := [
	"You sign the file and close it. The name on it stares back, and it won't quite settle.",
	"Maybe you got it right. Maybe the real killer's still out there, somewhere in the rain.",
	"You'll never be sure. That kind of doubt has a way of following a man.",
	"Case closed, maybe. The rain keeps falling either way.",
	"[color=#5ee6e6]— THE RAIN NEVER STOPS —[/color]",
]

func _ready() -> void:
	if Game.has_flag(done_flag):
		# Prologue already closed — this point doesn't belong to the main-game office.
		queue_free()
		return
	prompt_text = "Make the accusation"
	add_to_group("ground_prop")
	super._ready()

func interact() -> void:
	# Can't accuse anyone without evidence.
	if Cases.clue_count() == 0:
		Dialogue.start("accuse_noevidence")
		return
	Dialogue.dialogue_finished.connect(_after_dialogue, CONNECT_ONE_SHOT)
	Dialogue.start(dialogue_id)

func _after_dialogue() -> void:
	if Game.has_flag(done_flag):
		Audio.play_music("ending")
		Narrator.finished.connect(_to_main_game, CONNECT_ONE_SHOT)
		var lines: Array = ENDING_RIGHT if Game.has_flag("prologue_right") else ENDING_WRONG
		Narrator.show_lines(lines)

func _to_main_game() -> void:
	Scenes.start_main_game()
