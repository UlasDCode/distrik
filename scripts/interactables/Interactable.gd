extends Area2D
class_name Interactable
## Base for anything the player can interact with. Shows a floating [E] prompt when near.

@export var prompt_text: String = "Examine"

var _prompt: Label
var _base_scale := Vector2.ONE
var _pulse := false
var _pt := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitorable = true
	monitoring = false
	_prompt = get_node_or_null("Prompt")
	if _prompt:
		_prompt.text = "[E] " + prompt_text
		# Center the prompt on this interactable so any-length text stays put over it.
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.offset_left = -220.0
		_prompt.offset_right = 220.0
		_prompt.visible = false
	var s := get_node_or_null("Sprite2D")
	if s and s is Node2D:
		_base_scale = (s as Node2D).scale

func set_highlighted(on: bool) -> void:
	if _prompt:
		_prompt.visible = on
	_pulse = on
	if not on:
		var s := get_node_or_null("Sprite2D")
		if s and s is Node2D:
			(s as Node2D).scale = _base_scale

func _process(delta: float) -> void:
	if _pulse:
		var s := get_node_or_null("Sprite2D")
		if s and s is Node2D:
			_pt += delta
			(s as Node2D).scale = _base_scale * (1.0 + sin(_pt * 8.0) * 0.06)

func interact() -> void:
	pass  # override in subclasses
