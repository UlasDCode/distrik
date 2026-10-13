extends Control
## Title screen. New Game / Continue / Quit.

var _new_btn: Button
var _confirm_new := false

const INTRO := [
	"The rain hasn't stopped in nine years.",
	"My left hand stutters when it's cold — cheap department cyberware, rejecting a little more of me each winter. The city repossesses a man slowly, in installments.",
	"They pulled a body out of the alley off Kessler Street. No wallet, no name, no one who'll talk.",
	"Just me, the neon, and a city that already forgot him.",
	"Let's find out who he was — and who wanted him gone.",
]

func _ready() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/backgrounds/city_overlook.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)

	# Subtle bottom-weighted darkening so the title/buttons stay readable over the vista.
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.06, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var title := Label.new()
	title.text = "DISTRIK"
	title.position = Vector2(120, 150)
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.5, 0.95, 0.98))
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "a rain-soaked detective story"
	subtitle.position = Vector2(126, 262)
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.4, 0.8))
	add_child(subtitle)

	var vb := VBoxContainer.new()
	vb.position = Vector2(130, 360)
	vb.add_theme_constant_override("separation", 12)
	add_child(vb)

	_new_btn = _add_button(vb, "New Game", _new_game)
	if Save.has_save():
		_add_button(vb, "Continue", _continue)
		var meta := Save.peek_meta()
		var sub := str(meta.get("phase", ""))
		if str(meta.get("time", "")) != "":
			sub += "  ·  " + str(meta.get("time", ""))
		if sub.strip_edges() != "":
			var ml := Label.new()
			ml.text = sub
			ml.add_theme_font_size_override("font_size", 14)
			ml.add_theme_color_override("font_color", Color(0.6, 0.85, 0.9))
			vb.add_child(ml)
	_add_button(vb, "Quit", func(): get_tree().quit())

	vb.add_child(_make_slider("Music", Audio.get_music_volume(), Audio.set_music_volume))
	vb.add_child(_make_slider("Effects", Audio.get_sfx_volume(), Audio.set_sfx_volume))
	vb.add_child(_make_slider("Text Speed", Audio.get_text_speed(), Audio.set_text_speed,
		Audio.TEXT_SPEED_MIN, Audio.TEXT_SPEED_MAX, 5.0))

	Audio.play_music("menu")
	Audio.set_weather(false, true)

func _make_slider(label_text: String, value: float, setter: Callable,
		mn: float = 0.0, mx: float = 1.0, stp: float = 0.05) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(240, 0)
	var l := Label.new()
	l.text = label_text
	l.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = stp
	s.value = value
	s.custom_minimum_size = Vector2(240, 18)
	s.value_changed.connect(setter)
	box.add_child(s)
	return box

func _add_button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func() -> void:
		Audio.play_sfx("select")
		cb.call())
	parent.add_child(b)
	return b

func _new_game() -> void:
	# Guard against wiping an existing save on an accidental click — require confirmation.
	if Save.has_save() and not _confirm_new:
		_confirm_new = true
		if _new_btn:
			_new_btn.text = "Erase saved progress?"
			_new_btn.add_theme_color_override("font_color", Color(0.95, 0.5, 0.5))
		return
	get_viewport().gui_release_focus()
	Game.reset()
	Cases.reset()
	Atlas.reset()
	Save.clear()
	Narrator.finished.connect(_after_intro, CONNECT_ONE_SHOT)
	Narrator.show_lines(INTRO)

func _after_intro() -> void:
	Narrator.finished.connect(_after_prologue_card, CONNECT_ONE_SHOT)
	Narrator.show_card("PROLOGUE", "The Rain Never Stops")

func _after_prologue_card() -> void:
	Scenes.change_level("alley", "start")

func _continue() -> void:
	Save.load_game()
