extends Node
## Pause overlay: Resume / Save / Quit to Menu. Autoload name: Pause

var _layer: CanvasLayer
var _saved_label: Label
var _paused := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 110
	add_child(_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.7)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	_layer.add_child(dim)

	var vb := VBoxContainer.new()
	vb.anchor_left = 0.5
	vb.anchor_right = 0.5
	vb.anchor_top = 0.5
	vb.anchor_bottom = 0.5
	vb.offset_left = -140
	vb.offset_right = 140
	vb.offset_top = -140
	vb.offset_bottom = 140
	vb.add_theme_constant_override("separation", 14)
	_layer.add_child(vb)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.45, 0.95, 0.98))
	vb.add_child(title)

	_add_button(vb, "Resume", _resume)
	_add_button(vb, "Save Game", _save)
	_add_button(vb, "Quit to Menu", _quit_menu)

	vb.add_child(_slider("Music", Audio.get_music_volume(), Audio.set_music_volume))
	vb.add_child(_slider("Effects", Audio.get_sfx_volume(), Audio.set_sfx_volume))
	vb.add_child(_slider("Text Speed", Audio.get_text_speed(), Audio.set_text_speed,
		Audio.TEXT_SPEED_MIN, Audio.TEXT_SPEED_MAX, 5.0))

	_saved_label = Label.new()
	_saved_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_saved_label.add_theme_color_override("font_color", Color(0.5, 0.98, 0.7))
	_saved_label.modulate.a = 0.0
	vb.add_child(_saved_label)

	_layer.visible = false

func _add_button(parent: Node, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 44)
	b.pressed.connect(func() -> void:
		Audio.play_sfx("select")
		cb.call())
	parent.add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if not _paused and Game.ui_blocked():
			return
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	_paused = not _paused
	get_tree().paused = _paused
	_layer.visible = _paused

func _resume() -> void:
	if _paused:
		toggle()

func _save() -> void:
	Save.save_game()
	_saved_label.text = "Saved."
	var t := create_tween()
	t.tween_property(_saved_label, "modulate:a", 1.0, 0.2)
	t.tween_interval(1.2)
	t.tween_property(_saved_label, "modulate:a", 0.0, 0.5)

func _slider(label_text: String, value: float, setter: Callable,
		mn: float = 0.0, mx: float = 1.0, stp: float = 0.05) -> VBoxContainer:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = stp
	s.value = value
	s.custom_minimum_size = Vector2(280, 18)
	s.value_changed.connect(setter)
	box.add_child(s)
	return box

func _quit_menu() -> void:
	Save.save_game()
	get_tree().paused = false
	_paused = false
	_layer.visible = false
	Scenes.goto_menu()
