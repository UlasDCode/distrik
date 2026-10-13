extends Node
## Runs dialogue trees (speaker, portrait, typewriter, branching choices).
## Autoload name: Dialogue

signal dialogue_started
signal dialogue_finished

const CHARS_PER_SEC := 45.0

# Portrait auto-bound by speaker name (a node's explicit "portrait" still wins).
const PORTRAITS := {
	"Detective": "res://assets/characters/portraits/detective.png",
	"Vera": "res://assets/characters/portraits/vera.png",
	"Kaito": "res://assets/characters/portraits/kaito.png",
	"Rook": "res://assets/characters/portraits/rook.png",
	"Mara": "res://assets/characters/portraits/mara.png",
	"Doc": "res://assets/characters/portraits/doc.png",
	"Patient": "res://assets/characters/portraits/patient.png",
	"Mei": "res://assets/characters/portraits/mei.png",
	"Clerk": "res://assets/characters/portraits/clerk.png",
	"Sable": "res://assets/characters/portraits/busker.png",
	"Aide": "res://assets/characters/portraits/aide.png",
	"Halloran": "res://assets/characters/portraits/halloran.png",
	"Kanzaki": "res://assets/characters/portraits/kanzaki.png",
}

var _active := false
var _nodes: Dictionary = {}
var _current_id := ""
var _revealing := false

var _layer: CanvasLayer
var _panel: Panel
var _name_label: Label
var _portrait: TextureRect
var _text_label: RichTextLabel
var _choices_box: VBoxContainer
var _continue_hint: Label

func is_active() -> bool:
	return _active

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)

	_panel = Panel.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 40
	_panel.offset_right = -40
	_panel.offset_top = -330
	_panel.offset_bottom = -24
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.09, 0.93)
	sb.border_color = Color(0.35, 0.9, 0.95, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_panel)

	_portrait = TextureRect.new()
	_portrait.position = Vector2(20, 20)
	_portrait.size = Vector2(170, 180)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_panel.add_child(_portrait)

	_name_label = Label.new()
	_name_label.position = Vector2(210, 14)
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_label.add_theme_color_override("font_color", Color(0.45, 0.95, 0.98))
	_panel.add_child(_name_label)

	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled = true
	_text_label.fit_content = true
	_text_label.scroll_active = false
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.position = Vector2(210, 50)
	_text_label.custom_minimum_size = Vector2(960, 0)
	_text_label.size = Vector2(960, 40)
	_text_label.add_theme_font_size_override("normal_font_size", 20)
	_panel.add_child(_text_label)

	_choices_box = VBoxContainer.new()
	_choices_box.position = Vector2(210, 120)
	_choices_box.custom_minimum_size = Vector2(960, 0)
	_choices_box.size = Vector2(960, 100)
	_choices_box.add_theme_constant_override("separation", 4)
	_panel.add_child(_choices_box)

	_continue_hint = Label.new()
	_continue_hint.text = "▼  [Space]"
	_continue_hint.anchor_left = 1.0
	_continue_hint.anchor_right = 1.0
	_continue_hint.anchor_top = 1.0
	_continue_hint.anchor_bottom = 1.0
	_continue_hint.offset_left = -130
	_continue_hint.offset_top = -34
	_continue_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_panel.add_child(_continue_hint)

	_panel.visible = false

func start(dialogue_id: String) -> void:
	if _active:
		return
	var path := "res://data/dialogues/%s.json" % dialogue_id
	if not FileAccess.file_exists(path):
		push_error("Dialogue not found: " + path)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Bad dialogue JSON: " + path)
		return
	_nodes = data
	_active = true
	Game.input_locked = true
	_panel.visible = true
	get_viewport().gui_release_focus()
	dialogue_started.emit()
	_goto("start")

func _goto(id: String) -> void:
	if id == "" or not _nodes.has(id):
		_finish()
		return
	_current_id = id
	var node: Dictionary = _nodes[id]
	if node.get("end", false):
		_finish()
		return
	# Conditional routing: {"branch": {"flag": "x", "yes": "a", "no": "b"}}
	if node.has("branch"):
		var b: Dictionary = node["branch"]
		var target := str(b.get("yes", "")) if Game.has_flag(str(b.get("flag", ""))) else str(b.get("no", ""))
		_goto(target)
		return
	# QTE minigame: {"qte": {"title","rounds","need","win","lose","set_win","set_lose"}}
	if node.has("qte"):
		_run_qte(node["qte"])
		return
	if node.has("set_flag"):
		Game.set_flag(str(node["set_flag"]))
	if node.has("set_flags"):
		for f in node["set_flags"]:
			Game.set_flag(str(f))
	if node.has("discover"):
		var c: Dictionary = node["discover"]
		Cases.discover_clue(c.get("case", ""), c.get("id", ""), c.get("title", ""), c.get("desc", ""))
	var speaker := str(node.get("speaker", ""))
	_name_label.text = speaker
	var ptex := str(node.get("portrait", ""))
	if ptex == "" and PORTRAITS.has(speaker):
		ptex = PORTRAITS[speaker]
	if ptex != "" and ResourceLoader.exists(ptex):
		_portrait.texture = load(ptex)
	else:
		_portrait.texture = null
	_show_text(node.get("text", ""))

## Hide the dialogue box, run the reflex QTE, apply win/lose flags, then route onward.
func _run_qte(q: Dictionary) -> void:
	_panel.visible = false
	var won: bool = await Combat.run(
		str(q.get("title", "")), int(q.get("rounds", 5)),
		int(q.get("need", 4)), float(q.get("window", 0.95)),
		str(q.get("bg", "")), str(q.get("foe", "")))
	_panel.visible = true
	if won and q.has("set_win"):
		Game.set_flag(str(q["set_win"]))
	if not won and q.has("set_lose"):
		Game.set_flag(str(q["set_lose"]))
	_goto(str(q.get("win", "")) if won else str(q.get("lose", "")))

func _show_text(t: String) -> void:
	_clear_choices()
	Audio.play_sfx("blip")
	_continue_hint.visible = false
	_text_label.visible = true
	_text_label.text = t
	_text_label.visible_characters = 0
	_revealing = true
	_reveal()

func _reveal() -> void:
	var total := _text_label.get_total_character_count()
	while _revealing and _text_label.visible_characters < total:
		_text_label.visible_characters += 1
		await get_tree().create_timer(1.0 / max(Audio.get_text_speed(), 1.0)).timeout
	_revealing = false
	_text_label.visible_characters = -1
	_on_text_done()

func _on_text_done() -> void:
	var node: Dictionary = _nodes.get(_current_id, {})
	if node.has("choices"):
		_show_choices(node["choices"])
	else:
		_continue_hint.visible = true

func _show_choices(choices: Array) -> void:
	_clear_choices()
	_continue_hint.visible = false
	# Flow the choices just below the rendered text so the two never overlap,
	# regardless of how many lines the prompt wrapped to.
	var text_bottom := _text_label.position.y + _text_label.get_content_height() + 12.0
	_choices_box.position.y = max(120.0, text_bottom)
	for ch in choices:
		if ch.has("requires") and not Game.has_flag(str(ch["requires"])):
			continue
		var b := Button.new()
		b.text = "▸ " + str(ch.get("text", "..."))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(_on_choice.bind(ch))
		_choices_box.add_child(b)
	# Safety: never leave the player with zero choices (would soft-lock the dialogue).
	if _choices_box.get_child_count() == 0:
		var fb := Button.new()
		fb.text = "▸ (Say nothing.)"
		fb.alignment = HORIZONTAL_ALIGNMENT_LEFT
		fb.focus_mode = Control.FOCUS_ALL
		fb.pressed.connect(_finish)
		_choices_box.add_child(fb)
	_choices_box.visible = true
	if _choices_box.get_child_count() > 0:
		(_choices_box.get_child(0) as Button).grab_focus()

func _on_choice(ch: Dictionary) -> void:
	if ch.has("set_flag"):
		Game.set_flag(str(ch["set_flag"]))
	if ch.has("discover"):
		var c: Dictionary = ch["discover"]
		Cases.discover_clue(c.get("case", ""), c.get("id", ""), c.get("title", ""), c.get("desc", ""))
	_clear_choices()
	_goto(str(ch.get("next", "")))

func _clear_choices() -> void:
	for c in _choices_box.get_children():
		c.queue_free()
	_choices_box.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("advance"):
		if _revealing:
			_revealing = false  # _reveal loop finalizes on next tick
			get_viewport().set_input_as_handled()
			return
		var node: Dictionary = _nodes.get(_current_id, {})
		if not node.has("choices"):
			get_viewport().set_input_as_handled()
			_goto(str(node.get("next", "")))

func _finish() -> void:
	_active = false
	_panel.visible = false
	_clear_choices()
	Game.input_locked = false
	dialogue_finished.emit()
