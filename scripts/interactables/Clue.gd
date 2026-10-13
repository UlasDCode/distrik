extends Interactable
## An examinable clue. Recorded in the journal on first examine, then removed from the world
## (and it won't reappear on a later visit).

@export var clue_id: String = ""
@export var title: String = "Clue"
@export_multiline var description: String = ""
@export var case_id: String = ""

var _bob := 0.0

func _ready() -> void:
	# Already found on an earlier visit? Don't show it again.
	if clue_id != "" and Cases.has_clue(clue_id):
		queue_free()
		return
	# Prologue clues don't linger on the streets once the prologue is closed.
	if case_id == "case1" and Game.has_flag("prologue_done"):
		queue_free()
		return
	prompt_text = ("Examine " + title) if title != "" else "Examine"
	add_to_group("ground_prop")
	super._ready()

func _process(delta: float) -> void:
	var s := get_node_or_null("Sprite2D")
	if s and s is Node2D:
		_bob += delta
		(s as Node2D).position.y = sin(_bob * 3.0) * 5.0

func interact() -> void:
	Cases.discover_clue(case_id, clue_id, title, description)
	queue_free()  # remove the on-the-ground marker once examined
