extends Node2D
class_name Level
## Parametric level. Set bg_scale + floor_frac per level; everything else is derived:
## the background is scaled/placed, ground + edge walls are generated, the player spawns
## with feet already on the floor (no fall-in), and rain toggles for exteriors.

@export var bg_scale: float = 1.4
@export var floor_frac: float = 0.9   # floor line as a fraction of scaled background height
@export var interior: bool = false
@export var char_scale: float = 5.0   # player sprite scale for this room (furniture-relative)

var ground_y: float = 0.0
var world_size: Vector2 = Vector2(1700, 1160)

func _ready() -> void:
	var bg: Sprite2D = get_node_or_null("Background")
	if bg and bg.texture:
		bg.scale = Vector2(bg_scale, bg_scale)
		world_size = bg.texture.get_size() * bg_scale
		bg.position = world_size * 0.5
	ground_y = world_size.y * floor_frac

	_make_ground()
	_make_walls()

	# Scale characters (NPCs / the finale) to this room's character scale, matching the player.
	# A character may carry `scale_mult` (e.g. a child) to size relative to the room scale.
	for n in get_tree().get_nodes_in_group("character"):
		if n is Node2D and is_ancestor_of(n):
			var m: float = 1.0
			if "scale_mult" in n:
				m = float(n.scale_mult)
			var cs: float = char_scale * m
			var cspr: Node = (n as Node2D).get_node_or_null("Sprite2D")
			if cspr and cspr is Node2D:
				# Scale to a consistent in-world height regardless of the sprite's native
				# resolution, so detailed models and the old 36px blobs both size correctly.
				var s := cs
				if cspr is Sprite2D and (cspr as Sprite2D).texture:
					s = (36.0 * cs) / max(float((cspr as Sprite2D).texture.get_height()), 1.0)
				(cspr as Node2D).scale = Vector2(s, s)
			var ccol: Node = (n as Node2D).get_node_or_null("CollisionShape2D")
			if ccol and ccol is CollisionShape2D and (ccol as CollisionShape2D).shape is RectangleShape2D:
				((ccol as CollisionShape2D).shape as RectangleShape2D).size = Vector2(14.0 * cs, 36.0 * cs)

	# Snap floor-standing props (NPCs, clues, exits) to the ground line.
	for n in get_tree().get_nodes_in_group("ground_prop"):
		if n is Node2D and is_ancestor_of(n):
			(n as Node2D).global_position.y = ground_y - _feet_offset(n)

	var player := get_node_or_null("Player")
	if player:
		# Per-room character scale: resize sprite + body collision to match furniture.
		var spr := player.get_node_or_null("Sprite")
		if spr and spr is Node2D:
			# Normalise to a consistent in-world height regardless of the sprite's native
			# resolution (detailed model vs old small frames).
			var ps := char_scale
			if spr is AnimatedSprite2D:
				var sf := (spr as AnimatedSprite2D).sprite_frames
				if sf and sf.get_frame_count("idle") > 0:
					var ft := sf.get_frame_texture("idle", 0)
					if ft:
						ps = (36.0 * char_scale) / max(float(ft.get_height()), 1.0)
			(spr as Node2D).scale = Vector2(ps, ps)
		var pcol := player.get_node_or_null("CollisionShape2D")
		if pcol and pcol is CollisionShape2D and (pcol as CollisionShape2D).shape is RectangleShape2D:
			((pcol as CollisionShape2D).shape as RectangleShape2D).size = Vector2(14.0 * char_scale, 36.0 * char_scale)

		var entry := get_node_or_null("Entries/" + Scenes.pending_entry)
		var x: float = (entry as Node2D).global_position.x if entry else world_size.x * 0.2
		player.global_position = Vector2(x, ground_y - _feet_offset(player))
		if "velocity" in player:
			player.velocity = Vector2.ZERO
		var cam: Camera2D = player.get_node_or_null("Camera2D")
		if cam:
			cam.limit_left = 0
			cam.limit_top = 0
			cam.limit_right = int(world_size.x)
			cam.limit_bottom = int(world_size.y)
		if player.has_method("snap_camera"):
			player.snap_camera()

	Atmosphere.set_rain(not interior)
	Audio.set_weather(interior)
	Audio.play_music(Scenes.current_level)

func _feet_offset(node: Node) -> float:
	var col := node.get_node_or_null("CollisionShape2D")
	if col and col is CollisionShape2D and (col as CollisionShape2D).shape is RectangleShape2D:
		return ((col as CollisionShape2D).shape as RectangleShape2D).size.y * 0.5
	return 72.0

func _make_ground() -> void:
	var g := StaticBody2D.new()
	g.collision_layer = 1
	g.collision_mask = 0
	g.position = Vector2(world_size.x * 0.5, ground_y + 40.0)
	var c := CollisionShape2D.new()
	var s := RectangleShape2D.new()
	s.size = Vector2(world_size.x + 800.0, 80.0)
	c.shape = s
	g.add_child(c)
	add_child(g)

func _make_walls() -> void:
	for side in [0.0, 1.0]:
		var w := StaticBody2D.new()
		w.collision_layer = 1
		w.collision_mask = 0
		w.position = Vector2(world_size.x * side, world_size.y * 0.5)
		var c := CollisionShape2D.new()
		var s := RectangleShape2D.new()
		s.size = Vector2(60.0, world_size.y + 600.0)
		c.shape = s
		w.add_child(c)
		add_child(w)

## World Y where a prop of the given pixel height (already scaled) should sit to touch the floor.
func floor_top() -> float:
	return ground_y
