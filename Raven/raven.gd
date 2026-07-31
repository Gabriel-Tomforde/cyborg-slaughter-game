extends CharacterBody2D

const SPEED = 160.0
const JUMP_VELOCITY = -300.0

# ---------------------------------------------------------
# COMBO SYSTEM (3 hits) - using two AnimatedSprite2D scenes
# ---------------------------------------------------------
# Node setup (confirmed structure):
#
# Raven (CharacterBody2D)                     <- this script
# ├── CollisionShape2D
# ├── SpriteLeft   (Node2D) > LeftAnimations   (AnimatedSprite2D)
# ├── SpriteRight  (Node2D) > RightAnimations  (AnimatedSprite2D)
# ├── HitboxArea2D (Area2D)
# │   └── CollisionShape2D
# └── ComboTimer (Timer)
#
# Animation names must match exactly what your teammate named them in
# each AnimatedSprite2D's SpriteFrames resource (check the "Animations"
# panel at the bottom of the editor when LeftAnimations/RightAnimations
# is selected - the exact spelling/spacing matters).
#
# Input Map: add an action called "attack" (Project Settings > Input Map).
# ---------------------------------------------------------

@onready var hitbox: Area2D = $HitboxArea2D
@onready var combo_timer: Timer = $ComboTimer
@onready var sprite_left: AnimatedSprite2D = $SpriteLeft/LeftAnimations
@onready var sprite_right: AnimatedSprite2D = $SpriteRight/RightAnimations
@onready var sprite_left_root: Node2D = $SpriteLeft
@onready var sprite_right_root: Node2D = $SpriteRight

@export var combo_window: float = 0.6  # seconds allowed to chain into the next hit

var combo_step: int = 0
var is_attacking: bool = false
var attack_queued: bool = false
var facing_right: bool = true
var hitbox_offset_x: float = 0.0

# Adjust these three to match your teammate's exact animation names.
const ATTACK_ANIMS := ["punch", "kick", "two handed swing"]
const UNARMED_DAMAGE := [3, 3, 5]  # damage for hits 1, 2, 3


func _ready() -> void:
	combo_timer.one_shot = true
	combo_timer.wait_time = combo_window

	sprite_left.animation_finished.connect(_on_animation_finished.bind(sprite_left))
	sprite_right.animation_finished.connect(_on_animation_finished.bind(sprite_right))

	hitbox.monitoring = false
	hitbox.visible = false
	hitbox_offset_x = abs(hitbox.position.x)

	_face_direction(1.0)  # start facing right
	_get_active_sprite().play("idle")


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	if not is_attacking:
		var direction := Input.get_axis("move_left", "move_right")
		if direction:
			velocity.x = direction * SPEED
			_face_direction(direction)
			_get_active_sprite().play("run")
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
			_get_active_sprite().play("idle")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()


func _get_active_sprite() -> AnimatedSprite2D:
	return sprite_right if facing_right else sprite_left


func _face_direction(direction: float) -> void:
	if direction > 0:
		facing_right = true
	elif direction < 0:
		facing_right = false
	sprite_right.visible = facing_right
	sprite_left.visible = not facing_right
	sprite_right_root.visible = facing_right
	sprite_left_root.visible = not facing_right
	hitbox.position.x = hitbox_offset_x if facing_right else -hitbox_offset_x


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_try_attack()


func _try_attack() -> void:
	if not is_attacking:
		_start_attack(1)
	elif combo_step < ATTACK_ANIMS.size():
		attack_queued = true


func _start_attack(step: int) -> void:
	is_attacking = true
	attack_queued = false
	combo_step = step

	var anim_name: String = ATTACK_ANIMS[step - 1]
	_get_active_sprite().play(anim_name)
	enable_hitbox()


func _on_animation_finished(sprite: AnimatedSprite2D) -> void:
	if sprite != _get_active_sprite():
		return  # ignore the inactive (hidden) sprite's signal

	var anim_name: String = sprite.animation
	if anim_name not in ATTACK_ANIMS:
		return

	disable_hitbox()

	if attack_queued and combo_step < ATTACK_ANIMS.size():
		_start_attack(combo_step + 1)
	else:
		_end_combo()


func _end_combo() -> void:
	is_attacking = false
	combo_step = 0
	attack_queued = false
	combo_timer.stop()
	_get_active_sprite().play("idle")


func enable_hitbox() -> void:
	hitbox.monitoring = true
	hitbox.visible = true


func disable_hitbox() -> void:
	hitbox.monitoring = false
	hitbox.visible = false


func _on_hitbox_area_2d_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target.has_method("take_damage"):
		target.take_damage(UNARMED_DAMAGE[combo_step - 1])
