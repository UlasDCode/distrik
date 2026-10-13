extends Node
## Themed, act-aware district map. Autoload name: Atlas
## Locations are nodes, exits are edges; nodes reveal as the acts progress, the current
## location and the current objective are highlighted. Toggle with [M]. No art — code-drawn.

# id -> {pos (within the 700x470 map field), label, reveal (flag; "" = always)}
const NODES := {
	"office":      {"pos": Vector2(110, 80),  "label": "Office",       "reveal": ""},
	"alley":       {"pos": Vector2(110, 210), "label": "The Alley",    "reveal": ""},
	"bar":         {"pos": Vector2(50, 330),  "label": "Neon Dragon",  "reveal": ""},
	"apartment":   {"pos": Vector2(180, 340), "label": "Apartment",    "reveal": ""},
	"main_street": {"pos": Vector2(300, 210), "label": "Main Street",  "reveal": "main_started"},
	"subway":      {"pos": Vector2(235, 280), "label": "Old Metro",    "reveal": "main_started"},
	"docks":       {"pos": Vector2(320, 400), "label": "The Docks",    "reveal": "main_started"},
	"clinic":      {"pos": Vector2(430, 330), "label": "Doc's Clinic", "reveal": "clue_toxic_drums"},
	"rooftop":     {"pos": Vector2(430, 100), "label": "East Rooftops","reveal": "lead_halloran"},
	"downtown":    {"pos": Vector2(540, 210), "label": "Downtown",     "reveal": "knows_coverup"},
	"cityhall":    {"pos": Vector2(470, 300), "label": "City Hall",    "reveal": "knows_coverup"},
	"archive":     {"pos": Vector2(560, 370), "label": "Hall of Records","reveal": "knows_coverup"},
	"tower_lobby": {"pos": Vector2(630, 120), "label": "Tower Lobby",  "reveal": "clue_reclamation_directive"},
	"penthouse":   {"pos": Vector2(660, 30),  "label": "Kanzaki Tower","reveal": "clue_reclamation_directive"},
}

const EDGES := [
	["office", "alley"], ["alley", "bar"], ["alley", "apartment"],
	["alley", "main_street"],
	["main_street", "docks"], ["main_street", "clinic"], ["main_street", "rooftop"],
	["main_street", "subway"], ["main_street", "downtown"],
	["downtown", "archive"], ["downtown", "cityhall"], ["downtown", "tower_lobby"], ["tower_lobby", "penthouse"],
]

const FIELD_ORIGIN := Vector2(40, 150)  # where the map field sits inside the panel

var _layer: CanvasLayer
var _panel: Panel
var _draw: Control
var _title: Label
var _labels: Dictionary = {}
var _open := false
var _pulse := 0.0
var _visited: Dictionary = {}   # level_id -> true, so unvisited leads stand out

## Called by SceneManager on every arrival.
func mark_visited(level_id: String) -> void:
	if level_id != "":
		_visited[level_id] = true

func reset() -> void:
	_visited.clear()

func _ready() -> void:
	_build_ui()
	set_process(false)

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 96
	add_child(_layer)

	_panel = Panel.new()
	_panel.anchor_left = 0.5; _panel.anchor_right = 0.5
	_panel.anchor_top = 0.5; _panel.anchor_bottom = 0.5
	_panel.offset_left = -390; _panel.offset_right = 390
	_panel.offset_top = -320; _panel.offset_bottom = 320
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.07, 0.97)
	sb.border_color = Color(0.35, 0.9, 0.95, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	_panel.add_theme_stylebox_override("panel", sb)
	_layer.add_child(_panel)

	var title := Label.new()
	title.text = "DISTRIK  —  DISTRICT MAP"
	title.position = Vector2(30, 20)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.5, 0.95, 0.98))
	_panel.add_child(title)

	_title = Label.new()  # act / objective subline
	_title.position = Vector2(30, 62)
	_title.size = Vector2(720, 40)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override("font_size", 17)
	_title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.7))
	_panel.add_child(_title)

	var hint := Label.new()
	hint.text = "[M] close"
	hint.position = Vector2(670, 26)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	_panel.add_child(hint)

	var legend := Label.new()
	legend.text = "◆ you are here      ◇ your lead      ○ not yet visited      ◆N evidence found"
	legend.position = Vector2(30, 596)
	legend.add_theme_font_size_override("font_size", 14)
	legend.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	_panel.add_child(legend)

	_draw = Control.new()
	_draw.position = FIELD_ORIGIN
	_draw.size = Vector2(700, 470)
	_draw.draw.connect(_render)
	_panel.add_child(_draw)

	for id in NODES:
		var l := Label.new()
		l.text = str(NODES[id]["label"])
		l.add_theme_font_size_override("font_size", 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(NODES[id]["pos"]) + Vector2(-55, 14)
		l.size = Vector2(110, 18)
		_draw.add_child(l)
		_labels[id] = l

	_panel.visible = false

## Which location the player's current objective points at (gets the ◇ marker).
func _target() -> String:
	if not Game.has_flag("main_started"):
		return "alley"
	if Game.has_flag("passed_rook"):
		return "penthouse"
	if Game.has_flag("clue_reclamation_directive"):
		return "tower_lobby"
	if Game.has_flag("knows_coverup"):
		return "archive"
	if Game.has_flag("knows_toxin") or Game.has_flag("lead_halloran"):
		return "rooftop"
	if Game.has_flag("clue_toxic_drums"):
		return "clinic"
	return "docks"

func _revealed(id: String) -> bool:
	var rf := str(NODES[id]["reveal"])
	return rf == "" or Game.has_flag(rf)

func _act_label() -> String:
	if not Game.has_flag("main_started"):
		return "Prologue — the district you know."
	if Game.has_flag("knows_coverup"):
		return "Act III — the trail climbs downtown, to the Records and the Tower."
	if Game.has_flag("knows_toxin"):
		return "Act II — someone signs the poison through. The east rooftops."
	return "Act I — follow the water to the harbor."

func toggle() -> void:
	# Don't stack over dialogue, a transition, or the journal (they hold input_locked).
	if not _open and (Game.ui_blocked() or Game.input_locked):
		return
	_open = not _open
	_panel.visible = _open
	Game.input_locked = _open
	set_process(_open)
	if _open:
		_refresh()

func _process(delta: float) -> void:
	_pulse += delta
	_draw.queue_redraw()

func _refresh() -> void:
	_title.text = _act_label()
	var tgt := _target()
	for id in NODES:
		var lab: Label = _labels[id]
		var shown := _revealed(id)
		lab.visible = shown
		if shown:
			# Append an evidence tally for locations where the player has found clues.
			var found: int = Cases.clues_at(id)
			lab.text = str(NODES[id]["label"]) + ("   ◆%d" % found if found > 0 else "")
			if Scenes.current_level == id:
				lab.add_theme_color_override("font_color", Color(0.5, 0.98, 0.98))
			elif id == tgt:
				lab.add_theme_color_override("font_color", Color(0.98, 0.6, 0.92))
			else:
				lab.add_theme_color_override("font_color", Color(0.72, 0.76, 0.85))
	_draw.queue_redraw()

func _render() -> void:
	var tgt := _target()
	# Edges first (behind the nodes).
	for e in EDGES:
		if _revealed(e[0]) and _revealed(e[1]):
			var a: Vector2 = NODES[e[0]]["pos"]
			var b: Vector2 = NODES[e[1]]["pos"]
			_draw.draw_line(a, b, Color(0.3, 0.55, 0.7, 0.5), 2.0)
	# Nodes.
	for id in NODES:
		if not _revealed(id):
			continue
		var p: Vector2 = NODES[id]["pos"]
		var is_here: bool = Scenes.current_level == id
		var is_tgt: bool = id == tgt
		var seen: bool = _visited.has(id)
		var col := Color(0.45, 0.75, 0.85)
		if is_here:
			col = Color(0.5, 0.98, 0.98)
		elif is_tgt:
			col = Color(0.98, 0.55, 0.9)
		elif not seen:
			col = Color(0.5, 0.55, 0.68)   # never been there yet
		# node dot — filled once visited, hollow while it's still just a name on the map
		_draw.draw_circle(p, 7.0, Color(0.06, 0.07, 0.11))
		_draw.draw_arc(p, 7.0, 0.0, TAU, 24, col, 2.0)
		if seen or is_here:
			_draw.draw_circle(p, 3.0, col)
		# pulsing ring for "you are here" and the current lead
		if is_here or is_tgt:
			var r := 12.0 + sin(_pulse * 3.5) * 3.0
			var ring := col
			ring.a = 0.5
			_draw.draw_arc(p, r, 0.0, TAU, 28, ring, 1.5)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		toggle()
		get_viewport().set_input_as_handled()
