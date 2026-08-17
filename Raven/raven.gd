extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal died
signal battery_changed(current_charge: int, max_charge: int)

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
@onready var hitbox_shape: CollisionShape2D = $HitboxArea2D/CollisionShape2D
@onready var combo_timer: Timer = $ComboTimer
@onready var sprite_left: AnimatedSprite2D = $SpriteLeft/LeftAnimations
@onready var sprite_right: AnimatedSprite2D = $SpriteRight/RightAnimations
@onready var sprite_left_root: Node2D = $SpriteLeft
@onready var sprite_right_root: Node2D = $SpriteRight

@export var combo_window: float = 0.6  # seconds allowed to chain into the next hit
@export var max_health: int = 100

# --- Battery / cannon attack ---
@export var max_battery_charge: int = 5
@export var cannon_cost: int = 1          # charge used per shot
@export var cannon_damage: int = 15
@export var cannon_projectile_scene: PackedScene  # assign CannonProjectile.tscn in the Inspector
@export var cannon_anim_name: String = "arm cannon"  # match your teammate's spelling exactly

var battery_charge: int = 2  # starts with a small charge, rest comes from pickups

var combo_step: int = 0
var is_attacking: bool = false
var attack_queued: bool = false
var facing_right: bool = true
var current_hitbox_reach: float = 20.0  # kept in sync with facing even while not attacking
var health: int
var is_dead: bool = false

# Adjust these three to match your teammate's exact animation names.
const ATTACK_ANIMS := ["punch", "kick", "two handed swing"]
const UNARMED_DAMAGE := [5, 5, 7]  # damage for hits 1, 2, 3

# How far in front of Raven the hitbox sits for each attack, and how big
# it is. Punch is short-range, kick reaches farther, the swing reaches
# farthest and is a bit wider too. Tweak freely to match the animations.
const ATTACK_REACH := [100.0, 140.0, 110.0]                    # x-distance from center
const ATTACK_HITBOX_SIZE := [Vector2(16, 20), Vector2(28, 20), Vector2(40, 30)]  # width, height


func _ready() -> void:
	health = max_health
	health_changed.emit(health, max_health)
	battery_changed.emit(battery_charge, max_battery_charge)

	combo_timer.one_shot = true
	combo_timer.wait_time = combo_window

	sprite_left.animation_finished.connect(_on_animation_finished.bind(sprite_left))
	sprite_right.animation_finished.connect(_on_animation_finished.bind(sprite_right))

	hitbox.monitoring = false
	hitbox.visible = false

	_face_direction(1.0)  # start facing right
	_get_active_sprite().play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

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
	hitbox.position.x = current_hitbox_reach if facing_right else -current_hitbox_reach


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		_try_attack()
	elif event.is_action_pressed("arm cannon"):
		_try_cannon_attack()


func _try_attack() -> void:
	if is_dead:
		return
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
	_update_hitbox_for_attack(step)
	enable_hitbox()


func _try_cannon_attack() -> void:
	if is_dead or is_attacking:
		return  # don't interrupt a melee swing (or fire while dead)
	if battery_charge < cannon_cost:
		return  # not enough charge - nothing happens (add a UI/sound cue later if you want)

	is_attacking = true
	battery_charge -= cannon_cost
	battery_changed.emit(battery_charge, max_battery_charge)
	_get_active_sprite().play(cannon_anim_name)
	_fire_cannon_projectile()


func _fire_cannon_projectile() -> void:
	if cannon_projectile_scene == null:
		push_warning("cannon_projectile_scene isn't assigned in the Inspector yet.")
		return

	var projectile := cannon_projectile_scene.instantiate()
	get_parent().add_child(projectile)

	var spawn_offset := Vector2(30, 0) if facing_right else Vector2(-30, 0)
	projectile.global_position = global_position + spawn_offset
	projectile.direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	projectile.damage = cannon_damage


func add_battery_charge(amount: int) -> void:
	battery_charge = min(battery_charge + amount, max_battery_charge)
	battery_changed.emit(battery_charge, max_battery_charge)


func _update_hitbox_for_attack(step: int) -> void:
	var reach: float = ATTACK_REACH[step - 1]
	current_hitbox_reach = reach
	hitbox.position.x = reach if facing_right else -reach

	if hitbox_shape.shape is RectangleShape2D:
		hitbox_shape.shape.size = ATTACK_HITBOX_SIZE[step - 1]
	else:
		push_warning("HitboxArea2D's CollisionShape2D needs a RectangleShape2D for per-attack sizing to work.")


func _on_animation_finished(sprite: AnimatedSprite2D) -> void:
	if sprite != _get_active_sprite():
		return  # ignore the inactive (hidden) sprite's signal

	var anim_name: String = sprite.animation

	if anim_name == cannon_anim_name:
		_end_combo()  # cannon shot is a single animation - just return to idle
		return

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


func take_damage(amount: int) -> void:
	if is_dead:
		return

	health = max(health - amount, 0)
	health_changed.emit(health, max_health)

	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	is_attacking = false
	disable_hitbox()
	_get_active_sprite().play("die")
	died.emit()
	# Add whatever should happen next here later - a game over screen,
	# disabling input permanently, a respawn, etc.
