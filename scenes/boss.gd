extends CharacterBody2D

# ---------------------------------------------------------
# BOSS AI: Idle -> Chase -> (Melee combo OR Cannon shot) -> back to Chase
# ---------------------------------------------------------
# Based on the regular Enemy AI, with two differences:
#   1. Higher stats (health/damage), tuned via the exports below.
#   2. A ranged cannon attack (same idea as Raven's) used when the boss
#      is too far away to melee but still within cannon_range.
#
# Node setup - identical to the regular Enemy, nothing extra required:
#
# Boss (CharacterBody2D)                 <- this script
# ├── CollisionShape2D
# ├── AnimatedSprite2D
# ├── DetectionArea (Area2D)
# │   └── CollisionShape2D
# ├── HurtboxArea2D (Area2D)
# │   └── CollisionShape2D
# ├── HitboxArea2D (Area2D)
# │   └── CollisionShape2D
# └── AttackCooldownTimer (Timer)
#
# Your player node needs to be in the "player" group, same as before.
#
# Attack animation names (melee AND cannon) must match exactly what's in
# the boss's SpriteFrames - capitalization/spacing included.
# ---------------------------------------------------------

enum State { IDLE, CHASE, ATTACK }

@onready var hitbox: Area2D = $HitboxArea2D
@onready var hitbox_shape: CollisionShape2D = $HitboxArea2D/CollisionShape2D
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sfx_player: AudioStreamPlayer2D = $SFXPlayer

@export var move_speed: float = 80.0
@export var attack_range: float = 180.0   # how close before it melees instead of shooting
@export var attack_cooldown: float = 1.0  # seconds between melee combos
@export var max_health: int = 120         # a lot higher than the regular enemy's 20

# --- Attack sound effects (one per combo hit, same order as ATTACK_ANIMS) ---
@export var attack_sfx: Array[AudioStream] = []

# --- Cannon attack (ranged, used at mid-range) ---
@export var cannon_range: float = 500.0        # beyond attack_range, up to this distance
@export var cannon_damage: int = 15
@export var cannon_cooldown: float = 2.5
@export var cannon_projectile_scene: PackedScene  # assign CannonProjectile.tscn in the Inspector
@export var cannon_anim_name: String = "arm cannon"  # match the boss's exact animation name

# --- Battery drop ---
@export var battery_pickup_scene: PackedScene
@export var battery_drop_chance: float = 1.0  # bosses can drop guaranteed on death if you want

const IDLE_ANIM := "idle"
const WALK_ANIM := "run"

const ATTACK_ANIMS := ["Punch", "Kick", "Two handed swing"]
const ATTACK_DAMAGE := [10, 10, 15]  # noticeably harder-hitting than the regular enemy

const ATTACK_REACH := [20.0, 45.0, 35.0]
const ATTACK_HITBOX_SIZE := [Vector2(16, 20), Vector2(30, 18), Vector2(38, 26)]

var state: State = State.IDLE
var player: Node2D = null
var health: int
var can_attack: bool = true
var can_use_cannon: bool = true
var facing_right: bool = true
var combo_step: int = 0
var is_dead: bool = false
var is_using_cannon: bool = false

@onready var cannon_cooldown_timer: Timer = Timer.new()


func _ready() -> void:
	health = max_health

	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.wait_time = attack_cooldown
	attack_cooldown_timer.timeout.connect(func(): can_attack = true)

	# Built in code instead of the editor, since this is boss-specific and
	# not part of the regular enemy's expected node setup.
	add_child(cannon_cooldown_timer)
	cannon_cooldown_timer.one_shot = true
	cannon_cooldown_timer.wait_time = cannon_cooldown
	cannon_cooldown_timer.timeout.connect(func(): can_use_cannon = true)

	sprite.animation_finished.connect(_on_animation_finished)

	hitbox.monitoring = false
	hitbox.visible = false

	_face_direction(1.0)
	sprite.play(IDLE_ANIM)

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
			velocity.x = 0
			sprite.play(IDLE_ANIM)

		State.CHASE:
			if player == null:
				state = State.IDLE
				return

			var distance := global_position.distance_to(player.global_position)
			var to_player := player.global_position - global_position

			if distance <= attack_range:
				velocity.x = 0
				_face_direction(sign(to_player.x))
				if can_attack:
					_start_combo()
			elif distance <= cannon_range:
				velocity.x = 0
				_face_direction(sign(to_player.x))
				if can_use_cannon:
					_start_cannon_attack()
				elif can_attack:
					# cannon's on cooldown - close the distance instead of standing idle
					var horizontal_direction: float = sign(to_player.x)
					velocity.x = horizontal_direction * move_speed
					sprite.play(WALK_ANIM)
			else:
				var horizontal_direction: float = sign(to_player.x)
				velocity.x = horizontal_direction * move_speed
				_face_direction(horizontal_direction)
				sprite.play(WALK_ANIM)

		State.ATTACK:
			velocity.x = 0

	move_and_slide()


func _face_direction(direction: float) -> void:
	if direction > 0:
		facing_right = true
	elif direction < 0:
		facing_right = false

	sprite.flip_h = facing_right


# ---------------------------------------------------------
# MELEE COMBO
# ---------------------------------------------------------

func _start_combo() -> void:
	state = State.ATTACK
	can_attack = false
	_play_attack(1)


func _play_attack(step: int) -> void:
	combo_step = step
	sprite.play(ATTACK_ANIMS[step - 1])
	_update_hitbox_for_attack(step)
	_play_attack_sfx(step)
	enable_hitbox()


func _play_attack_sfx(step: int) -> void:
	if step - 1 < attack_sfx.size() and attack_sfx[step - 1] != null:
		sfx_player.stream = attack_sfx[step - 1]
		sfx_player.play()


func _update_hitbox_for_attack(step: int) -> void:
	var reach: float = ATTACK_REACH[step - 1]
	hitbox.position.x = reach if facing_right else -reach

	if hitbox_shape.shape is RectangleShape2D:
		hitbox_shape.shape.size = ATTACK_HITBOX_SIZE[step - 1]
	else:
		push_warning("HitboxArea2D's CollisionShape2D needs a RectangleShape2D for per-attack sizing to work.")


func _end_combo() -> void:
	combo_step = 0
	state = State.CHASE if player != null else State.IDLE
	attack_cooldown_timer.start()


# ---------------------------------------------------------
# CANNON ATTACK (ranged)
# ---------------------------------------------------------

func _start_cannon_attack() -> void:
	state = State.ATTACK
	can_use_cannon = false
	is_using_cannon = true
	sprite.play(cannon_anim_name)
	_fire_cannon_projectile()
	cannon_cooldown_timer.start()


func _fire_cannon_projectile() -> void:
	if cannon_projectile_scene == null:
		push_warning("cannon_projectile_scene isn't assigned on the boss in the Inspector yet.")
		return

	var projectile := cannon_projectile_scene.instantiate()
	get_parent().add_child(projectile)

	var spawn_offset := Vector2(30, 0) if facing_right else Vector2(-30, 0)
	projectile.global_position = global_position + spawn_offset
	projectile.direction = Vector2.RIGHT if facing_right else Vector2.LEFT
	projectile.damage = cannon_damage


func _end_cannon_attack() -> void:
	is_using_cannon = false
	state = State.CHASE if player != null else State.IDLE


# ---------------------------------------------------------
# ANIMATION HANDLING (routes to melee, cannon, or death)
# ---------------------------------------------------------

func _on_animation_finished() -> void:
	if sprite.animation == "Die":
		queue_free()
		return

	if sprite.animation == cannon_anim_name:
		disable_hitbox()
		_end_cannon_attack()
		return

	if sprite.animation not in ATTACK_ANIMS:
		return

	disable_hitbox()

	if combo_step < ATTACK_ANIMS.size():
		_play_attack(combo_step + 1)
	else:
		_end_combo()


# ---------------------------------------------------------
# DETECTION
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
# HITBOX CONTROL
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
# TAKING DAMAGE / DEATH
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
	can_use_cannon = false
	disable_hitbox()
	sprite.play("Die")
	_maybe_drop_battery()


func _maybe_drop_battery() -> void:
	if battery_pickup_scene == null:
		return
	if randf() > battery_drop_chance:
		return

	var pickup := battery_pickup_scene.instantiate()
	get_parent().add_child(pickup)
	pickup.global_position = global_position
