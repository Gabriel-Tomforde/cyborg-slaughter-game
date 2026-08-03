extends CharacterBody2D

# ---------------------------------------------------------
# SIMPLE ENEMY AI: Idle -> Chase -> Attack
# ---------------------------------------------------------
# Node setup expected (adjust @onready paths if yours differ):
#
# Enemy (CharacterBody2D)                <- this script
# ├── CollisionShape2D                   (physical body collider)
# ├── Sprite2D
# ├── AnimationPlayer                    (animations: "idle", "walk", "attack")
# ├── DetectionArea (Area2D)             <- notices the player from a distance
# │   └── CollisionShape2D (CircleShape2D, large radius)
# ├── HurtboxArea2D (Area2D)             <- lets the PLAYER's hitbox damage this enemy
# │   └── CollisionShape2D
# ├── HitboxArea2D (Area2D)              <- this enemy's own attack, damages the player
# │   └── CollisionShape2D
# └── AttackCooldownTimer (Timer)
#
# Your player node needs to be in the "player" group (Node > Groups tab)
# so this script can recognize it. It also needs a take_damage(amount)
# method for this enemy's attacks to actually do anything - flagged below.
# ---------------------------------------------------------

enum State { IDLE, CHASE, ATTACK }

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var hitbox: Area2D = $HitboxArea2D
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer

@export var move_speed: float = 80.0
@export var attack_range: float = 40.0    # how close before it stops and swings
@export var attack_cooldown: float = 1.0  # seconds between attacks
@export var damage: int = 8
@export var max_health: int = 30

var state: State = State.IDLE
var player: Node2D = null
var health: int
var can_attack: bool = true


func _ready() -> void:
	health = max_health

	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.wait_time = attack_cooldown
	attack_cooldown_timer.timeout.connect(func(): can_attack = true)

	anim_player.animation_finished.connect(_on_animation_finished)

	hitbox.monitoring = false
	hitbox.visible = false


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			anim_player.play("idle")

		State.CHASE:
			if player == null:
				state = State.IDLE
				return

			var distance := global_position.distance_to(player.global_position)

			if distance <= attack_range:
				velocity = Vector2.ZERO
				if can_attack:
					_start_attack()
			else:
				var direction := (player.global_position - global_position).normalized()
				velocity = direction * move_speed
				$Sprite2D.flip_h = direction.x < 0
				anim_player.play("walk")

		State.ATTACK:
			velocity = Vector2.ZERO  # stand still while swinging

	move_and_slide()


func _start_attack() -> void:
	state = State.ATTACK
	can_attack = false
	anim_player.play("attack")
	attack_cooldown_timer.start()


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		# Swing is done - go back to chasing (this re-checks distance next frame,
		# so it'll immediately attack again once the cooldown timer allows it).
		state = State.CHASE if player != null else State.IDLE


# ---------------------------------------------------------
# DETECTION - connect these two signals from DetectionArea in the editor
# ---------------------------------------------------------

func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		if state == State.IDLE:
			state = State.CHASE


func _on_detection_area_body_exited(body: Node2D) -> void:
	if body == player:
		player = null
		state = State.IDLE


# ---------------------------------------------------------
# HITBOX CONTROL (attacking the player)
# ---------------------------------------------------------
# Add Call Method track keys in the "attack" animation to call these
# at the right frames, same as we did for the player's combo.

func enable_hitbox() -> void:
	hitbox.monitoring = true
	hitbox.visible = true


func disable_hitbox() -> void:
	hitbox.monitoring = false
	hitbox.visible = false


func _on_hitbox_area_2d_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	# This calls take_damage() on the player - you'll need to add that
	# method to your player script (with a matching HurtboxArea2D) for
	# this to actually deal damage. Flagging this so it doesn't error silently.
	if target.has_method("take_damage"):
		target.take_damage(damage)


# ---------------------------------------------------------
# TAKING DAMAGE (from the player's attacks)
# ---------------------------------------------------------
# Connect the player's HitboxArea2D area_entered signal to detect THIS
# enemy's HurtboxArea2D - that's already handled on the player's side.
# This just needs a take_damage() method for the player to call into.

func take_damage(amount: int) -> void:
	health -= amount
	if health <= 0:
		queue_free()  # swap this for a death animation later if you want
