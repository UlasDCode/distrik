extends CharacterBody2D
class_name Player

const SPEED := 240.0
const JUMP_VELOCITY := -430.0
const GRAVITY := 1000.0

@onready var sprite: AnimatedSprite2D = $Sprite

var _nearby: Array = []
var _current: Interactable = null

const MODEL := "res://assets/characters/model_detective.png"

var _step_t := 0.0
var _bob_t := 0.0

func _ready() -> void:
	_build_frames()
	$Interactor.area_entered.connect(_on_area_entered)
	$Interactor.area_exited.connect(_on_area_exited)

func _build_frames() -> void:
	# Single detailed model; walk feel comes from a procedural bob + footstep timer.
	var sf := SpriteFrames.new()
	var tex := load(MODEL)
	for anim in ["idle", "walk"]:
		sf.add_animation(anim)
		sf.set_animation_loop(anim, true)
		sf.add_frame(anim, tex)
	sprite.sprite_frames = sf
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var dir := 0.0
	if not Game.input_locked:
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
		dir = Input.get_axis("move_left", "move_right")

	if dir != 0.0:
		velocity.x = dir * SPEED
		sprite.flip_h = dir < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)

	var moving := dir != 0.0 and is_on_floor()
	var want := "walk" if moving else "idle"
	if sprite.sprite_frames and sprite.animation != want:
		sprite.play(want)

	# Procedural walk feel: a small vertical bob + footsteps on a stride timer.
	if moving:
		_bob_t += delta * 11.0
		sprite.position.y = -absf(sin(_bob_t)) * 3.0
		_step_t += delta
		if _step_t >= 0.28:
			_step_t = 0.0
			Audio.play_step()
	else:
		_bob_t = 0.0
		_step_t = 0.0
		sprite.position.y = move_toward(sprite.position.y, 0.0, 60.0 * delta)

	move_and_slide()
	_update_current()

func _unhandled_input(event: InputEvent) -> void:
	if Game.input_locked:
		return
	if event.is_action_pressed("interact") and _current != null:
		_current.interact()
		get_viewport().set_input_as_handled()

func _on_area_entered(a: Area2D) -> void:
	if a is Interactable and not _nearby.has(a):
		_nearby.append(a)

func _on_area_exited(a: Area2D) -> void:
	if _nearby.has(a):
		_nearby.erase(a)
		if a == _current:
			a.set_highlighted(false)
			_current = null

func _update_current() -> void:
	var best: Interactable = null
	var best_d := 1e20
	for it in _nearby:
		if not is_instance_valid(it):
			continue
		var d := global_position.distance_to(it.global_position)
		if d < best_d:
			best_d = d
			best = it
	if best != _current:
		if _current != null:
			_current.set_highlighted(false)
		_current = best
		if _current != null:
			_current.set_highlighted(true)

func snap_camera() -> void:
	$Camera2D.reset_smoothing()
