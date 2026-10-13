extends Node
## Global rain + neon glow, persists across every scene. Autoload name: Atmosphere

var _layer: CanvasLayer
var _rain: CPUParticles2D
var _world_env: WorldEnvironment

var _flash: ColorRect

func _ready() -> void:
	_setup_glow()
	_setup_vignette()
	_setup_lightning()
	_setup_rain()

func _setup_lightning() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 9
	add_child(cl)
	_flash = ColorRect.new()
	_flash.color = Color(0.82, 0.86, 1.0, 1.0)
	_flash.anchor_right = 1.0
	_flash.anchor_bottom = 1.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	cl.add_child(_flash)

func lightning() -> void:
	if not _flash:
		return
	var t := create_tween()
	t.tween_property(_flash, "modulate:a", 0.45, 0.05)
	t.tween_property(_flash, "modulate:a", 0.0, 0.15)
	t.tween_property(_flash, "modulate:a", 0.30, 0.06)
	t.tween_property(_flash, "modulate:a", 0.0, 0.3)

func _setup_vignette() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 7
	add_child(cl)
	var r := ColorRect.new()
	r.anchor_right = 1.0
	r.anchor_bottom = 1.0
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
void fragment() {
	float d = distance(UV, vec2(0.5));
	float a = smoothstep(0.35, 0.85, d) * 0.55;
	COLOR = vec4(0.0, 0.0, 0.04, a);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	r.material = mat
	cl.add_child(r)

func _setup_glow() -> void:
	_world_env = WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.05
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.8
	env.glow_hdr_scale = 2.0
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 1.0)
	env.set_glow_level(4, 1.0)
	_world_env.environment = env
	add_child(_world_env)

func _setup_rain() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 8
	add_child(_layer)
	_rain = CPUParticles2D.new()
	_rain.texture = load("res://assets/ui/rain.png")
	_rain.amount = 340
	_rain.lifetime = 1.1
	_rain.preprocess = 1.1
	_rain.position = Vector2(640, -40)
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.emission_rect_extents = Vector2(780, 8)
	_rain.direction = Vector2(0.12, 1)
	_rain.spread = 3.0
	_rain.gravity = Vector2(0, 300)
	_rain.initial_velocity_min = 820.0
	_rain.initial_velocity_max = 980.0
	_rain.scale_amount_min = 1.0
	_rain.scale_amount_max = 1.7
	_rain.color = Color(0.75, 0.85, 0.95, 0.5)
	_layer.add_child(_rain)

func set_rain(on: bool) -> void:
	if _rain:
		_rain.emitting = on
		# Hide instantly so in-flight streaks don't linger into interiors during the fade.
		_rain.visible = on
		if not on:
			_rain.restart()
			_rain.emitting = false

func set_glow(on: bool) -> void:
	if _world_env and _world_env.environment:
		_world_env.environment.glow_enabled = on
