extends Interactable
## An NPC the player can talk to. Set npc_name + dialogue_id per instance.

@export var npc_name: String = "Stranger"
@export var dialogue_id: String = ""
@export var sprite_path: String = ""
@export var post_dialogue_id: String = ""   # generic line once this NPC is "done"
@export var done_flag: String = ""           # when true, use post_dialogue_id (defaults to prologue_done)
@export var scale_mult: float = 1.0          # per-NPC size vs the room's char_scale (e.g. a child < 1.0)

func _ready() -> void:
	prompt_text = ("Talk to " + npc_name) if npc_name != "" else "Talk"
	add_to_group("ground_prop")
	add_to_group("character")
	super._ready()
	if sprite_path != "":
		var s := get_node_or_null("Sprite2D")
		if s and s is Sprite2D and ResourceLoader.exists(sprite_path):
			(s as Sprite2D).texture = load(sprite_path)
	# Level.gd sets the sprite's final scale in the parent's _ready (which runs after ours),
	# so start the idle breathing deferred to read the correct base scale.
	call_deferred("_start_idle")

## Subtle procedural "breathing" so standing NPCs read as alive, not as statues.
func _start_idle() -> void:
	var s := get_node_or_null("Sprite2D")
	if not (s and s is Node2D):
		return
	var base_y: float = (s as Node2D).scale.y
	if base_y <= 0.0:
		return
	var t := create_tween().set_loops()
	t.tween_property(s, "scale:y", base_y * 1.03, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(s, "scale:y", base_y, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.set_speed_scale(randf_range(0.82, 1.18))  # desync so they don't all breathe in lockstep

func interact() -> void:
	var id := dialogue_id
	var done := Game.has_flag(done_flag) if done_flag != "" else Game.has_flag("prologue_done")
	if done and post_dialogue_id != "":
		id = post_dialogue_id
	if id != "":
		Dialogue.start(id)
