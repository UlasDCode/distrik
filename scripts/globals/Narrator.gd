extends Node
## Full-screen narration cards (intro / ending). Autoload name: Narrator

signal finished

var _layer: CanvasLayer
var _rect: ColorRect
var _label: RichTextLabel
var _hint: Label
var _lines: Array = []
var _idx := 0
var _active := false
var _title: Label
var _subtitle: Label
var _card_mode := false

func _ready() -> void:
	_build()

func is_active() -> bool:
	return _active

func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 105
	add_child(_layer)
	_rect = ColorRect.new()
	_rect.color = Color(0.02, 0.02, 0.05, 1.0)
	_rect.anchor_right = 1.0
	_rect.anchor_bottom = 1.0
	_layer.add_child(_rect)
	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.anchor_left = 0.16
	_label.anchor_right = 0.84
	_label.anchor_top = 0.34
	_label.anchor_bottom = 0.66
	_label.add_theme_font_size_override("normal_font_size", 28)
	_label.add_theme_color_override("default_color", Color(0.85, 0.9, 0.95))
	_rect.add_child(_label)
	_hint = Label.new()
	_hint.text = "[Space] continue"
	_hint.anchor_left = 1.0
	_hint.anchor_top = 1.0
	_hint.offset_left = -220
	_hint.offset_top = -50
	_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_rect.add_child(_hint)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.anchor_right = 1.0
	_title.anchor_top = 0.30
	_title.anchor_bottom = 0.48
	_title.add_theme_font_size_override("font_size", 92)
	_title.add_theme_color_override("font_color", Color(0.5, 0.95, 0.98))
	_rect.add_child(_title)
	_title.visible = false

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle.anchor_right = 1.0
	_subtitle.anchor_top = 0.50
	_subtitle.anchor_bottom = 0.60
	_subtitle.add_theme_font_size_override("font_size", 34)
	_subtitle.add_theme_color_override("font_color", Color(0.9, 0.4, 0.8))
	_rect.add_child(_subtitle)
	_subtitle.visible = false

	_layer.visible = false

func show_lines(lines: Array) -> void:
	_lines = lines
	_idx = 0
	_active = true
	_card_mode = false
	_layer.visible = true
	_label.visible = true
	_title.visible = false
	_subtitle.visible = false
	Game.input_locked = true
	# Release focus so a lingering menu button doesn't eat the advance key.
	get_viewport().gui_release_focus()
	_render()

## Cinematic title / act card: big title + subtitle, auto-advances after `hold` seconds.
func show_card(title_text: String, subtitle_text: String, hold: float = 2.6) -> void:
	_active = true
	_card_mode = true
	_layer.visible = true
	Game.input_locked = true
	get_viewport().gui_release_focus()
	_label.visible = false
	_hint.visible = false
	_title.text = title_text
	_subtitle.text = subtitle_text
	_title.visible = true
	_subtitle.visible = true
	_title.modulate.a = 0.0
	_subtitle.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_title, "modulate:a", 1.0, 0.9)
	t.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.9)
	t.tween_interval(hold)
	t.tween_property(_title, "modulate:a", 0.0, 0.9)
	t.parallel().tween_property(_subtitle, "modulate:a", 0.0, 0.9)
	t.tween_callback(_finish_card)

func _finish_card() -> void:
	_title.visible = false
	_subtitle.visible = false
	_card_mode = false
	_active = false
	_layer.visible = false
	Game.input_locked = false
	finished.emit()

func _render() -> void:
	if _idx >= _lines.size():
		_finish()
		return
	_label.text = "[center]" + str(_lines[_idx]) + "[/center]"

func _unhandled_input(event: InputEvent) -> void:
	if not _active or _card_mode:
		return
	if event.is_action_pressed("advance"):
		get_viewport().set_input_as_handled()
		_idx += 1
		_render()

func _finish() -> void:
	_active = false
	_layer.visible = false
	Game.input_locked = false
	finished.emit()
