extends Node
## Themed reflex QTE minigame. Autoload name: Combat
## The fight fills the screen: the current LOCATION as the backdrop, the two combatants drawn
## from their real sprites (so it always matches the characters, place, and weather), reacting
## to each exchange. The QTE controls sit in a bottom bar. Some beats GLITCH — the arrow
## flickers to a wrong direction before settling, the protagonist's failing cyberware turned
## against him. Await Combat.run(...) -> bool (won). Non-blocking to game progression.

const DIRS := ["left", "right", "up", "down"]
const GLYPH := {"left": "◄", "right": "►", "up": "▲", "down": "▼"}
const KEYMAP := {
	KEY_LEFT: "left", KEY_A: "left",
	KEY_RIGHT: "right", KEY_D: "right",
	KEY_UP: "up", KEY_W: "up",
	KEY_DOWN: "down", KEY_S: "down",
}
const HERO_SPRITE := "res://assets/characters/model_detective.png"

signal _beat_done(hit)

var _layer: CanvasLayer
var _bg: TextureRect
var _dim: ColorRect
var _hero: TextureRect
var _foe: TextureRect
var _panel: Panel
var _title: Label
var _prompt: Label
var _bar: ProgressBar
var _counter: Label
var _feedback: Label
var _hint: Label

var _hero_home := Vector2.ZERO
var _foe_home := Vector2.ZERO
var _active := false
var _beat_active := false
var _expected := ""
var _hits := 0

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 108
	add_child(_layer)

	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layer.add_child(_bg)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.02, 0.05, 0.55)
	_layer.add_child(_dim)

	_foe = _make_fighter(true)
	_hero = _make_fighter(false)
	_layer.add_child(_foe)
	_layer.add_child(_hero)

	# Bottom control bar
	_panel = Panel.new()
	_panel.anchor_left = 0.0; _panel.anchor_right = 1.0
	_panel.anchor_top = 1.0; _panel.anchor_bottom = 1.0
	_panel.offset_left = 0; _panel.offset_right = 0
	_panel.offset_top = -196; _panel.offset_bottom = 0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.06, 0.94)
	sb.border_color = Color(0.95, 0.35, 0.45, 0.9)
	sb.border_width_top = 2
	_panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_panel)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.anchor_right = 1.0
	_title.offset_top = 12
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color(0.98, 0.5, 0.55))
	_panel.add_child(_title)

	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt.anchor_right = 1.0
	_prompt.offset_top = 34
	_prompt.offset_bottom = 118
	_prompt.add_theme_font_size_override("font_size", 72)
	_prompt.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0))
	_panel.add_child(_prompt)

	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.anchor_left = 0.5; _feedback.anchor_right = 0.5
	_feedback.offset_left = -300; _feedback.offset_right = 300
	_feedback.offset_top = -110
	_feedback.add_theme_font_size_override("font_size", 44)
	_feedback.modulate.a = 0.0
	_panel.add_child(_feedback)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0.0; _bar.max_value = 100.0; _bar.value = 100.0
	_bar.anchor_left = 0.0; _bar.anchor_right = 1.0
	_bar.offset_left = 60; _bar.offset_right = -60
	_bar.offset_top = 128; _bar.offset_bottom = 142
	var fbar := StyleBoxFlat.new()
	fbar.bg_color = Color(0.4, 0.95, 0.98); fbar.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fbar)
	var bbar := StyleBoxFlat.new()
	bbar.bg_color = Color(0.12, 0.12, 0.16); bbar.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("background", bbar)
	_panel.add_child(_bar)

	_counter = Label.new()
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter.anchor_right = 1.0
	_counter.offset_top = 150
	_counter.add_theme_font_size_override("font_size", 16)
	_counter.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
	_panel.add_child(_counter)

	_hint = Label.new()
	_hint.text = "◄ ► ▲ ▼  or  A D W S"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.anchor_right = 1.0
	_hint.offset_top = 172
	_hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	_panel.add_child(_hint)

	_layer.visible = false

func _make_fighter(is_foe: bool) -> TextureRect:
	var t := TextureRect.new()
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	t.custom_minimum_size = Vector2(180, 320)
	t.size = Vector2(180, 320)
	# Foe on the right facing left (flip), hero on the left facing right.
	t.position = Vector2(820, 210) if is_foe else Vector2(280, 210)
	if is_foe:
		t.scale = Vector2(-1, 1)
		t.pivot_offset = Vector2(90, 160)
	return t

func is_active() -> bool:
	return _active

## Run a bout. bg_path = location backdrop; foe_sprite = the opponent's body sprite.
func run(title_text: String, rounds: int = 5, need: int = 4, window: float = 0.95,
		bg_path: String = "", foe_sprite: String = "") -> bool:
	if _active:
		return false
	_hits = 0
	_active = true
	_title.text = title_text
	_feedback.modulate.a = 0.0
	_bg.texture = (load(bg_path) if bg_path != "" and ResourceLoader.exists(bg_path) else null)
	_hero.texture = (load(HERO_SPRITE) if ResourceLoader.exists(HERO_SPRITE) else null)
	_foe.texture = (load(foe_sprite) if foe_sprite != "" and ResourceLoader.exists(foe_sprite) else null)
	_hero.modulate = Color.WHITE
	_foe.modulate = Color.WHITE
	_hero_home = _hero.position
	_foe_home = _foe.position
	_layer.visible = true
	Game.input_locked = true
	await get_tree().create_timer(0.7).timeout  # brace
	for i in rounds:
		_counter.text = "%d / %d landed" % [_hits, rounds]
		var d: String = DIRS[randi() % DIRS.size()]
		var glitch: bool = (i > 0) and (randf() < 0.4)
		var hit: bool = await _do_beat(d, window, glitch)
		if hit:
			_hits += 1
		_flash("HIT" if hit else "MISS", hit)
		_swing(hit)
		await get_tree().create_timer(0.35).timeout
	_counter.text = "%d / %d landed" % [_hits, rounds]
	await get_tree().create_timer(0.5).timeout
	_active = false
	_layer.visible = false
	return _hits >= need

# A landed beat knocks the foe back; a miss rocks the hero.
func _swing(hit: bool) -> void:
	var who: TextureRect = _foe if hit else _hero
	var home: Vector2 = _foe_home if hit else _hero_home
	var dir: float = 1.0 if hit else -1.0
	who.modulate = Color(1.0, 0.5, 0.55) if hit else Color(1.0, 0.6, 0.4)
	var t := create_tween()
	t.tween_property(who, "position:x", home.x + 34.0 * dir, 0.09).set_trans(Tween.TRANS_BACK)
	t.tween_property(who, "position:x", home.x, 0.22)
	t.parallel().tween_property(who, "modulate", Color.WHITE, 0.3)

func _do_beat(d: String, window: float, glitch: bool) -> bool:
	_expected = d
	_prompt.text = GLYPH[d]
	_prompt.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0))
	_bar.value = 100.0
	_beat_active = true
	if glitch:
		_glitch_flicker(d)
	var t := create_tween()
	t.tween_property(_bar, "value", 0.0, window)
	t.tween_callback(func() -> void:
		if _beat_active:
			_resolve(false))
	var hit: bool = await _beat_done
	return hit

func _glitch_flicker(real: String) -> void:
	var wrong: String = DIRS[(DIRS.find(real) + 1 + (randi() % 3)) % DIRS.size()]
	var t := create_tween()
	t.tween_callback(func() -> void:
		_prompt.text = GLYPH[wrong]
		_prompt.add_theme_color_override("font_color", Color(1.0, 0.3, 0.4)))
	t.tween_interval(0.09)
	t.tween_callback(func() -> void:
		_prompt.text = GLYPH[real]
		_prompt.add_theme_color_override("font_color", Color(0.4, 1.0, 1.0)))
	t.tween_interval(0.08)
	t.tween_callback(func() -> void:
		_prompt.text = GLYPH[wrong]
		_prompt.add_theme_color_override("font_color", Color(1.0, 0.3, 0.4)))
	t.tween_interval(0.07)
	t.tween_callback(func() -> void:
		if _beat_active:
			_prompt.text = GLYPH[real]
			_prompt.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0)))

func _resolve(hit: bool) -> void:
	if not _beat_active:
		return
	_beat_active = false
	_beat_done.emit(hit)

func _flash(text: String, good: bool) -> void:
	_feedback.text = text
	_feedback.add_theme_color_override("font_color",
		Color(0.5, 1.0, 0.6) if good else Color(1.0, 0.4, 0.45))
	_feedback.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(_feedback, "modulate:a", 0.0, 0.4)

func _input(event: InputEvent) -> void:
	if not _beat_active:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var dir: String = KEYMAP.get((event as InputEventKey).keycode, "")
		if dir != "":
			get_viewport().set_input_as_handled()
			_resolve(dir == _expected)
