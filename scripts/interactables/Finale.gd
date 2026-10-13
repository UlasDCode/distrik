extends Interactable
## The finale confrontation (Kanzaki). Starts the confrontation dialogue; the chosen ending
## rolls its narration, a "THE END" card, then returns to the menu.

@export var dialogue_id: String = "kanzaki_intro"
@export var sprite_path: String = ""

const ENDINGS := {
	"ending_expose": [
		"You walk the file into the one newsroom Kanzaki doesn't own yet.",
		"They arrest him on a Tuesday. He smiles for the cameras — his parent corporation drafted his legal replacement before you ever reached the precinct. The cuffs are a costume change.",
		"The low districts get a face to hate. It's more than they had yesterday, and you tell yourself that counts for something.",
		"You gave them the man. You could never give them the machine that will simply hire the next one.",
		"[color=#5ee6e6]— THE RAIN NEVER STOPS —[/color]",
	],
	"ending_bribe": [
		"You take the number. It's obscene — enough to fix the arm, the eye, the lung the city has been slowly repossessing.",
		"You upgrade your failing cyberware with blood money and sleep, for once, without the servo ticking. You don't file the report.",
		"Your next assignment arrives on Reclamation Board letterhead. You didn't beat the system tonight. You accepted a promotion inside it.",
		"[color=#e65ea0]— THE RAIN NEVER STOPS —[/color]",
	],
	"ending_violence": [
		"It's over before he finishes the sentence. One round, and the man who was only ever an invoice is a stain on his own priceless view.",
		"It feels like justice — for exactly as long as it takes the elevator to reach the lobby.",
		"Somewhere above, the Board's conference call doesn't even pause to note the vacancy. You were never fighting a man. You were fighting an arithmetic, and the numbers don't grieve.",
		"[color=#e6e65e]— THE RAIN NEVER STOPS —[/color]",
	],
	"ending_thirddoor": [
		"You don't file R-9. You sell it — to the Zheng cartel, who have wanted Kanzaki's harbor for years.",
		"By month's end the district's neon burns crimson where it used to burn green. New flag on the trucks, new name on the very same city tender.",
		"The water level doesn't drop. The body count doesn't change. You walked out rich, and all you moved was the colour of the light.",
		"[color=#9e7bff]— THE RAIN NEVER STOPS —[/color]",
	],
	"ending_board": [
		"You don't take his deal or his life. You take the one thing he can't buy back: the name buried in the Board's own minutes — the councillor they 'reassigned' the day after she voted no.",
		"By dawn your credentials are revoked, your accounts frozen, and quiet corporate drones are already asking your neighbours when they last saw you. You are a loose thread the machine has begun, calmly, to pull.",
		"It's a lonely, likely-fatal road against a hydra that files its murders in triplicate. But a named thing can be hunted — and for the first time tonight, someone up there should be the one who can't sleep.",
		"[color=#5ee6e6]— THE RAIN NEVER STOPS —[/color]",
	],
	"ending_walkaway": [
		"You don't accuse him. You don't draw. You fold R-9 back into your coat and turn for the elevator while he's still talking.",
		"At home you lock it in the rusted bottom drawer of a desk you'll never sell, and you lie in the dark listening to the ceiling leak into a bucket that's already mostly full.",
		"Some doors you just close again, quietly. You tell yourself it's mercy. Mostly it's a man too tired to change tomorrow's weather.",
		"[color=#8a8f99]— THE RAIN NEVER STOPS —[/color]",
	],
}

# Appended when the player uncovered Reclamation Order R-9 — the truth that the
# poisoning was city policy, and that removing Kanzaki changes nothing structural.
const SYSTEMIC_CODA := [
	"You think of Order R-9, sitting in your coat like a stone. The Reclamation Board will express its shock. It will shred the order, name a cleaner contractor, and by spring the drums go back in the water.",
	"Forty thousand people were crossed out in a ledger before Kanzaki ever bid on them. You solved a murder tonight. The city will go on committing the larger one on schedule.",
]

func _ready() -> void:
	prompt_text = "Confront"
	add_to_group("ground_prop")
	add_to_group("character")
	super._ready()
	if sprite_path != "":
		var s := get_node_or_null("Sprite2D")
		if s and s is Sprite2D and ResourceLoader.exists(sprite_path):
			(s as Sprite2D).texture = load(sprite_path)
	call_deferred("_start_idle")

## Subtle breathing so Kanzaki reads as alive during the confrontation.
func _start_idle() -> void:
	var s := get_node_or_null("Sprite2D")
	if not (s and s is Node2D):
		return
	var base_y: float = (s as Node2D).scale.y
	if base_y <= 0.0:
		return
	var t := create_tween().set_loops()
	t.tween_property(s, "scale:y", base_y * 1.03, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(s, "scale:y", base_y, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.set_speed_scale(randf_range(0.82, 1.18))

func interact() -> void:
	Dialogue.dialogue_finished.connect(_after_dialogue, CONNECT_ONE_SHOT)
	Dialogue.start(dialogue_id)

# Optional evidence for the Kanzaki file — how thoroughly the player worked the case.
const CASE_EVIDENCE := [
	"docks_manifest", "toxic_drums", "drag_marks", "press_badge", "clinic_ledger",
	"halloran_flask", "kanzaki_threat", "renner_notes", "district_map", "reclamation_directive",
]

func _case_recap_lines() -> Array:
	var found := 0
	for id in CASE_EVIDENCE:
		if Cases.has_clue(id):
			found += 1
	var total := CASE_EVIDENCE.size()
	var verdict := ""
	var coda := ""
	if found >= total:
		verdict = "Airtight"
		coda = "You didn't leave him a thread to pull. Every piece, accounted for."
	elif found >= total - 2:
		verdict = "Solid"
		coda = "Enough to bury him twice over. A loose end or two, but nothing that saves him."
	elif found >= total - 4:
		verdict = "Workable"
		coda = "It'll hold — if the right people are brave enough to read it."
	else:
		verdict = "Thin"
		coda = "You got him. But a sharp lawyer could make this rain disappear."
	return [
		"[color=#5ee6e6]CASE FILE — THE KANZAKI FILE[/color]\n\n" +
		"Evidence recovered:  %d / %d\n" % [found, total] +
		"[color=#e6e65e]Verdict:  %s[/color]\n\n" % verdict +
		coda,
	]

# Personalized epilogue beats keyed on what the player learned and how it ended.
func _epilogue_lines(ending_key: String) -> Array:
	var out: Array = []
	# Mei's fate hinges on whether Kanzaki's money keeps flowing to Halloran.
	if Game.has_flag("knows_halloran_daughter"):
		var money_stops: bool = ending_key in [
			"ending_expose", "ending_violence", "ending_board", "ending_thirddoor"]
		if money_stops:
			out.append("[i]Epilogue.[/i]  With Kanzaki's money gone, so is Halloran's. His daughter Mei leaves the clinic under a sheet before the month is out. You didn't sign her death — you just couldn't afford to stop it.")
		else:
			out.append("[i]Epilogue.[/i]  Kanzaki keeps paying, so Mei keeps breathing — kept alive on money wrung from the same poison in her blood. The cruelest mercy in a city built out of them.")
	# Renner's story only sees daylight in the public reckoning.
	if Game.has_flag("clue_press_badge") or Game.has_flag("clue_renner_notes"):
		if ending_key == "ending_expose":
			out.append("[i]Epilogue.[/i]  Renner's byline runs at last — posthumous, page one. The courier got his story. It cost him everything and saved no one, but his name is finally in the ink.")
		else:
			out.append("[i]Epilogue.[/i]  Renner's notebook stays in your drawer. His story never runs — one more thing the harbor closed its mouth over.")
	return out

func _after_dialogue() -> void:
	var lines: Array = []
	var chosen := ""
	for key in ENDINGS:
		if Game.has_flag(key):
			lines = ENDINGS[key]
			chosen = key
			break
	if lines.is_empty():
		return  # backed out without choosing an ending
	Audio.play_music("ending")
	Narrator.finished.connect(_to_end_card, CONNECT_ONE_SHOT)
	# Assemble: ending body -> (systemic coda) -> (personalized epilogue) -> closing card line.
	var body: Array = lines.duplicate()
	var tail = body.pop_back()  # the "— THE RAIN NEVER STOPS —" line
	# The Third Door and Name-the-Board endings already make the systemic point in-body.
	if Game.has_flag("knows_directive") and chosen != "ending_thirddoor" and chosen != "ending_board":
		body.append_array(SYSTEMIC_CODA)
	body.append_array(_epilogue_lines(chosen))
	body.append(tail)
	# Lead with the detective's case-file recap, then roll the chosen ending.
	Narrator.show_lines(_case_recap_lines() + body)

func _to_end_card() -> void:
	Narrator.finished.connect(_to_menu, CONNECT_ONE_SHOT)
	Narrator.show_card("THE END", "DISTRIK — The Kanzaki File")

func _to_menu() -> void:
	# Case closed — wipe the save so "Continue" doesn't drop the player back into the finale.
	Save.clear()
	Scenes.goto_menu()
