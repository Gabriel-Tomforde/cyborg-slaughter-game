extends CharacterBody2D

const SPEED = 130.0
const JUMP_VELOCITY = -300.0

# ---------------------------------------------------------
# COMBO SYSTEM (3 hits)
# ---------------------------------------------------------
# Node setup expected (adjust paths if yours differ):
#
# CharacterBody2D (this script)
# ├── AnimationPlayer   (animations: "idle", "attack1", "attack2", "attack3")
# ├── Sprite2D / AnimatedSprite2D
# ├── HitboxArea2D (Area2D + CollisionShape2D)
# └── ComboTimer (Timer)
#
# Input Map: add an action called "attack" (Project Settings > Input Map).
# ---------------------------------------------------------

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $HitboxArea2D
@onready var combo_timer: Timer = $ComboTimer

@export var combo_window: float = 0.6  # seconds allowed to chain into the next hit

var combo_step: int = 0
var is_attacking: bool = false
var attack_queued: bool = false

const ATTACK_ANIMS := ["attack1", "attack2", "attack3"]
const UNARMED_DAMAGE := [3, 3, 5]  # punch damage for hits 1, 2, 3


func _ready() -> void:
	combo_timer.one_shot = true
	combo_timer.wait_time = combo_window
	anim_player.animation_finished.connect(_on_animation_finished)

	hitbox.monitoring = false
	hitbox.visible = false


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	if not is_attacking:
		var direction := Input.get_axis("ui_left", "ui_right")
		if direction:
			velocity.x = direction * SPEED
			$Sprite2D.flip_h = direction < 0
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()


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
	anim_player.play(anim_name)
	combo_timer.start()


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name not in ATTACK_ANIMS:
		return

	if attack_queued and combo_step < ATTACK_ANIMS.size() and not combo_timer.is_stopped():
		_start_attack(combo_step + 1)
	else:
		_end_combo()


func _end_combo() -> void:
	is_attacking = false
	combo_step = 0
	attack_queued = false
	combo_timer.stop()
	anim_player.play("idle")


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
