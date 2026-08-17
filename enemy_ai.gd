extends CharacterBody2D

# ---------------------------------------------------------
# ENEMY AI: Idle -> Chase -> Attack (3-hit combo)
# ---------------------------------------------------------
# Node setup expected:
#
# Enemy (CharacterBody2D)                <- this script
# ├── CollisionShape2D                   (physical body collider)
# ├── AnimatedSprite2D                   (single sprite - flipped via flip_h)
# ├── DetectionArea (Area2D)             <- notices the player from a distance
# │   └── CollisionShape2D (CircleShape2D, large radius)
# ├── HurtboxArea2D (Area2D)             <- lets the PLAYER's hitbox damage this enemy
# │   └── CollisionShape2D
# ├── HitboxArea2D (Area2D)              <- this enemy's own attacks, damage the player
# │   └── CollisionShape2D
# └── AttackCooldownTimer (Timer)
#
# Your player node needs to be in the "player" group (Node > Groups tab)
# so this script can recognize it.
#
# Attack animation names must match exactly what's in your enemy's
# SpriteFrames (capitalization/spacing included).
#
# This assumes the sprite's default art faces RIGHT. If your art
# defaults to facing LEFT instead, flip the flip_h logic in
# _face_direction() (flagged with a comment below).
# ---------------------------------------------------------

enum State { IDLE, CHASE, ATTACK }

@onready var hitbox: Area2D = $HitboxArea2D
@onready var hitbox_shape: CollisionShape2D = $HitboxArea2D/CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var move_speed: float = 80.0
@export var attack_range: float = 180.0   # how close before it stops and swings
@export var attack_cooldown: float = 1.0  # seconds between combos (not between individual hits)
@export var max_health: int = 20

# --- Battery drop ---
@export var battery_pickup_scene: PackedScene  # assign BatteryPickup.tscn in the Inspector
@export var battery_drop_chance: float = 0.5   # 0.5 = 50% chance to drop on death

const IDLE_ANIM := "idle"
const WALK_ANIM := "run"

# The 3-hit combo, same idea as Raven's - unlike Raven though, the enemy
# AI just plays through all three automatically once it starts attacking,
# no input needed to chain them.
const ATTACK_ANIMS := ["Punch", "Kick", "Two handed swing"]
const ATTACK_DAMAGE := [3, 3, 5]  # damage for hits 1, 2, 3

# How far in front of the enemy the hitbox sits for each attack, and how
# big it is. Punch is short-range, kick reaches over twice as far. Tweak
# these numbers freely to match how the animations actually look.
const ATTACK_REACH := [20.0, 45.0, 35.0]                       # x-distance from center
const ATTACK_HITBOX_SIZE := [Vector2(16, 20), Vector2(30, 18), Vector2(38, 26)]  # width, height

var state: State = State.IDLE
var player: Node2D = null
var health: int
var can_attack: bool = true
var facing_right: bool = true
var combo_step: int = 0
var is_dead: bool = false


func _ready() -> void:
	health = max_health

	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.wait_time = attack_cooldown
	attack_cooldown_timer.timeout.connect(func(): can_attack = true)

	sprite.animation_finished.connect(_on_animation_finished)

	hitbox.monitoring = false
	hitbox.visible = false

	_face_direction(1.0)  # start facing right
	sprite.play(IDLE_ANIM)

	# body_entered won't fire if the player is ALREADY inside the detection
	# radius the moment this enemy spawns (e.g. right as an ambush starts) -
	# so explicitly check for that case once physics catches up.
	await get_tree().physics_frame
	_check_for_already_present_player()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_dead:
		velocity.x = 0
		move_and_slide()
		return

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			sprite.play(IDLE_ANIM)

		State.CHASE:
			if player == null:
				state = State.IDLE
				return

			var distance := global_position.distance_to(player.global_position)

			if distance <= attack_range:
				velocity = Vector2.ZERO
				if can_attack:
					_start_combo()
			else:
				var to_player := player.global_position - global_position
				var direction := to_player.normalized()
				velocity = direction * move_speed
				_face_direction(sign(to_player.x))
				sprite.play(WALK_ANIM)

		State.ATTACK:
			velocity = Vector2.ZERO  # stand still through the whole combo

	move_and_slide()


func _face_direction(direction: float) -> void:
	if direction > 0:
		facing_right = true
	elif direction < 0:
		facing_right = false

	# Flip the sprite. The default art faces LEFT, so flip when facing right.
	sprite.flip_h = facing_right


func _start_combo() -> void:
	state = State.ATTACK
	can_attack = false
	_play_attack(1)


func _play_attack(step: int) -> void:
	combo_step = step
	sprite.play(ATTACK_ANIMS[step - 1])
	_update_hitbox_for_attack(step)
	enable_hitbox()


func _update_hitbox_for_attack(step: int) -> void:
	var reach: float = ATTACK_REACH[step - 1]
	hitbox.position.x = reach if facing_right else -reach

	if hitbox_shape.shape is RectangleShape2D:
		hitbox_shape.shape.size = ATTACK_HITBOX_SIZE[step - 1]
	else:
		push_warning("HitboxArea2D's CollisionShape2D needs a RectangleShape2D for per-attack sizing to work.")


func _on_animation_finished() -> void:
	if sprite.animation == "Die":
		queue_free()
		return

	if sprite.animation not in ATTACK_ANIMS:
		return

	disable_hitbox()

	if combo_step < ATTACK_ANIMS.size():
		_play_attack(combo_step + 1)
	else:
		_end_combo()


func _end_combo() -> void:
	combo_step = 0
	state = State.CHASE if player != null else State.IDLE
	attack_cooldown_timer.start()  # cooldown applies between whole combos, not individual hits


# ---------------------------------------------------------
# DETECTION - connect these two signals from DetectionArea in the editor
# ---------------------------------------------------------

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		if state == State.IDLE:
			state = State.CHASE


func _check_for_already_present_player() -> void:
	for body in detection_area.get_overlapping_bodies():
		if body.is_in_group("player"):
			player = body
			if state == State.IDLE:
				state = State.CHASE
			return


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		if state != State.ATTACK:
			state = State.IDLE


# ---------------------------------------------------------
# HITBOX CONTROL (attacking the player)
# ---------------------------------------------------------

func enable_hitbox() -> void:
	hitbox.monitoring = true
	hitbox.visible = true


func disable_hitbox() -> void:
	hitbox.monitoring = false
	hitbox.visible = false


func _on_hitbox_area_2d_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target.has_method("take_damage"):
		target.take_damage(ATTACK_DAMAGE[combo_step - 1])


# ---------------------------------------------------------
# TAKING DAMAGE (from the player's attacks)
# ---------------------------------------------------------

func take_damage(amount: int) -> void:
	if is_dead:
		return

	health -= amount
	if health <= 0:
		_die()


func _die() -> void:
	is_dead = true
	state = State.IDLE
	can_attack = false
	disable_hitbox()
	sprite.play("Die")
	_maybe_drop_battery()


func _maybe_drop_battery() -> void:
	if battery_pickup_scene == null:
		return  # not assigned - just skip silently, no drop
	if randf() > battery_drop_chance:
		return  # didn't roll a drop this time

	var pickup := battery_pickup_scene.instantiate()
	get_parent().add_child(pickup)
	pickup.global_position = global_position
