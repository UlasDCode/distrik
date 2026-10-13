extends Node
## Clues, journal UI, case progress. Autoload name: Cases

signal clue_discovered(case_id, clue_id, title, desc)
signal case_solved(case_id)

var clues: Dictionary = {}   # clue_id -> {case, title, desc}
var solved: Dictionary = {}  # case_id -> true

var _layer: CanvasLayer
var _panel: Panel
var _list: VBoxContainer
var _toast: Label
var _objective: Label
var _tabs_box: HBoxContainer
var _open := false
var _tab := ""
var _unread: Dictionary = {}  # clue_id -> true, cleared when its tab is viewed

const ACT_ORDER := ["Prologue", "Act I", "Act II", "Act III"]

## Short phase label for the save/Continue UI (e.g. "Act II").
func phase_label() -> String:
	return _current_act()

## Which act a clue found right now belongs to (used to tab the journal).
func _current_act() -> String:
	if not Game.has_flag("main_started"):
		return "Prologue"
	if Game.has_flag("knows_coverup"):
		return "Act III"
	if Game.has_flag("knows_toxin"):
		return "Act II"
	return "Act I"

func current_objective() -> String:
	if Game.has_flag("main_started"):
		if Game.has_flag("knows_coverup"):
			if Game.has_flag("clue_reclamation_directive"):
				return "ACT III — Order R-9 ties the city itself to the harbor. Take it up Kanzaki Tower and end this."
			return "ACT III — Halloran's trail climbs past him. Dig the authorization out of the Hall of Records downtown."
		if Game.has_flag("lead_halloran"):
			return "Confront Halloran — the harbor inspector drinks alone on the east rooftops."
		if Game.has_flag("knows_toxin"):
			return "ACT II — someone signs this poison through. Ask Doc who clears the manifests."
		if Game.has_flag("clue_toxic_drums"):
			return "Get the sample analyzed — Doc's clinic, three blocks off the main drag."
		if Game.has_flag("knows_drums"):
			return "Crack open Container KZ-7 and see what Kanzaki's really sinking."
		if Game.has_flag("clue_docks_manifest"):
			return "Someone works these docks after dark. Find a witness."
		return "THE KANZAKI FILE — get to the docks and see what the syndicate is landing."
	if Game.has_flag("prologue_done"):
		return "The file's closed. Something bigger is pulling at you..."
	if Game.has_flag("kanzaki_paid") and Game.has_flag("clue_letter"):
		return "You have means and motive. Return to the office and name the killer."
	if Game.has_flag("kanzaki_paid"):
		return "Find the motive — search where the victim lived (the apartment off the alley)."
	if Game.has_flag("knows_kanzaki"):
		return "Dig into the name 'Kanzaki' at the Neon Dragon bar."
	return "Investigate the alley and question the locals."

var _last_objective := ""

func _ready() -> void:
	_build_ui()
	Game.flag_changed.connect(_on_flag_changed)
	_last_objective = current_objective()

func _on_flag_changed(flag, _value) -> void:
	# Major story beat -> Act II card once the toxin is confirmed (after that dialogue closes).
	if flag == "knows_toxin" and not Game.has_flag("act2_shown"):
		Game.set_flag("act2_shown")
		Dialogue.dialogue_finished.connect(_on_act2, CONNECT_ONE_SHOT)
	if flag == "knows_coverup" and not Game.has_flag("act3_shown"):
		Game.set_flag("act3_shown")
		Dialogue.dialogue_finished.connect(_on_act3, CONNECT_ONE_SHOT)
	var obj := current_objective()
	if obj != _last_objective:
		_last_objective = obj
		_show_toast("New objective:  " + obj)

func _on_act2() -> void:
	Narrator.show_card("ACT  II", "The Long Water")

func _on_act3() -> void:
	Narrator.show_card("ACT  III", "Bring the Rain")

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 95
	add_child(_layer)

	# Journal panel
	_panel = Panel.new()
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -360
	_panel.offset_right = 360
	_panel.offset_top = -260
	_panel.offset_bottom = 260
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.08, 0.96)
	sb.border_color = Color(0.9, 0.35, 0.8, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_panel)

	var title := Label.new()
	title.text = "CASE JOURNAL"
	title.position = Vector2(28, 20)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.45, 0.9))
	_panel.add_child(title)

	var hint := Label.new()
	hint.text = "[J] close"
	hint.position = Vector2(600, 26)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_panel.add_child(hint)

	_objective = Label.new()
	_objective.position = Vector2(28, 58)
	_objective.size = Vector2(680, 56)
	_objective.custom_minimum_size = Vector2(680, 0)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.add_theme_font_size_override("font_size", 17)
	_objective.add_theme_color_override("font_color", Color(0.55, 0.95, 0.7))
	_panel.add_child(_objective)

	_tabs_box = HBoxContainer.new()
	_tabs_box.position = Vector2(28, 120)
	_tabs_box.add_theme_constant_override("separation", 8)
	_panel.add_child(_tabs_box)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(28, 158)
	scroll.size = Vector2(690, 352)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(680, 0)
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)

	_panel.visible = false

	# Toast (clue-found popup)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.add_theme_color_override("font_color", Color(0.5, 0.98, 0.98))
	_toast.position = Vector2(40, 40)
	_toast.modulate.a = 0.0
	_layer.add_child(_toast)

func discover_clue(case_id, clue_id, title, desc) -> void:
	if clue_id == "" or clues.has(clue_id):
		return
	clues[clue_id] = {"case": case_id, "title": title, "desc": desc, "act": _current_act(),
		"location": Scenes.current_level}
	_unread[clue_id] = true
	Game.set_flag("clue_" + str(clue_id))
	clue_discovered.emit(case_id, clue_id, title, desc)
	_refresh_list()
	_show_toast("New clue:  " + str(title))
	Audio.play_sfx("clue")

func has_clue(clue_id) -> bool:
	return clues.has(clue_id)

## How many clues the player has recorded at a given level (for the map).
func clues_at(location: String) -> int:
	var n := 0
	for id in clues:
		if str(clues[id].get("location", "")) == location:
			n += 1
	return n

func clue_count(case_id := "") -> int:
	if case_id == "":
		return clues.size()
	var n := 0
	for k in clues:
		if clues[k]["case"] == case_id:
			n += 1
	return n

func solve_case(case_id) -> void:
	solved[case_id] = true
	case_solved.emit(case_id)

func _refresh_list() -> void:
	if _objective:
		_objective.text = "Objective:  " + current_objective()
	_rebuild_tabs()
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var any := false
	var viewed: Array = []
	for id in clues:
		var e: Dictionary = clues[id]
		if str(e.get("act", "")) != _tab:
			continue
		any = true
		var is_new: bool = _unread.has(id)
		var t := Label.new()
		t.text = ("◆ " + str(e["title"]) + ("   [NEW]" if is_new else ""))
		t.add_theme_font_size_override("font_size", 20)
		t.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35) if is_new else Color(0.5, 0.95, 0.98))
		_list.add_child(t)
		if is_new:
			viewed.append(id)
		var d := Label.new()
		d.text = "     " + str(e["desc"])
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(650, 0)
		d.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		_list.add_child(d)
		# Where it was found — ties each entry back to the district map.
		var loc := str(e.get("location", ""))
		if loc != "":
			var w := Label.new()
			w.text = "     ⌖ Found at:  " + Scenes.level_name(loc)
			w.add_theme_font_size_override("font_size", 14)
			w.add_theme_color_override("font_color", Color(0.55, 0.7, 0.8))
			_list.add_child(w)
	if not any:
		var empty := Label.new()
		empty.text = "No clues here yet. Keep investigating."
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
		_list.add_child(empty)
	# Clues are "read" once the player is actually looking at their tab.
	if _open:
		for id in viewed:
			_unread.erase(id)

func _rebuild_tabs() -> void:
	if _tabs_box == null:
		return
	var present := {}
	for id in clues:
		present[str(clues[id].get("act", ""))] = true
	var ordered: Array = []
	for a in ACT_ORDER:
		if present.has(a):
			ordered.append(a)
	if not present.has(_tab):
		_tab = str(ordered[-1]) if ordered.size() > 0 else ""
	for c in _tabs_box.get_children():
		c.queue_free()
	var counts := {}
	var unread_acts := {}
	for id in clues:
		var a2 := str(clues[id].get("act", ""))
		counts[a2] = int(counts.get(a2, 0)) + 1
		if _unread.has(id):
			unread_acts[a2] = true
	for a in ordered:
		var active: bool = (a == _tab)
		var b := Button.new()
		b.text = "%s  (%d)%s" % [a, int(counts.get(a, 0)), ("  •" if unread_acts.has(a) else "")]
		b.toggle_mode = true
		b.button_pressed = active
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 16)
		_style_tab(b, active)
		b.pressed.connect(_select_tab.bind(a))
		_tabs_box.add_child(b)

func _style_tab(b: Button, active: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	sb.set_border_width_all(1)
	if active:
		sb.bg_color = Color(0.9, 0.35, 0.8, 0.28)
		sb.border_color = Color(0.95, 0.45, 0.9, 0.9)
	else:
		sb.bg_color = Color(0.12, 0.12, 0.18, 0.6)
		sb.border_color = Color(0.35, 0.35, 0.45, 0.7)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var fc := Color(0.98, 0.7, 0.95) if active else Color(0.65, 0.68, 0.78)
	for cs in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(cs, fc)

func _select_tab(a: String) -> void:
	_tab = a
	_refresh_list()

func toggle_journal() -> void:
	# Don't stack over dialogue, a transition, or the map (they hold input_locked).
	if not _open and (Game.ui_blocked() or Game.input_locked):
		return
	_open = not _open
	_panel.visible = _open
	Game.input_locked = _open
	if _open:
		# Default to the current act's tab if it has clues.
		var cur := _current_act()
		for id in clues:
			if str(clues[id].get("act", "")) == cur:
				_tab = cur
				break
		_refresh_list()

func _show_toast(msg: String) -> void:
	_toast.text = msg
	_toast.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(_toast, "modulate:a", 1.0, 0.25)
	t.tween_interval(1.8)
	t.tween_property(_toast, "modulate:a", 0.0, 0.5)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("journal"):
		toggle_journal()
		get_viewport().set_input_as_handled()

func reset() -> void:
	clues.clear()
	solved.clear()
	_unread.clear()
	_refresh_list()
