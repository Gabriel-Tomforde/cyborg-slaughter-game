extends Area2D

# ---------------------------------------------------------
# CANNON PROJECTILE
# ---------------------------------------------------------
# Scene setup:
#
# CannonProjectile (Area2D)     <- this script
# └── CollisionShape2D
# (add a Sprite2D too once you have art for it)
#
# Set as the cannon_projectile_scene in the Inspector on Raven.
# ---------------------------------------------------------

@export var speed: float = 400.0
@export var lifetime: float = 2.0  # seconds before it despawns if it hits nothing

var direction: Vector2 = Vector2.RIGHT  # set by whoever spawns this
var damage: int = 15                    # set by whoever spawns this


func _ready() -> void:
	area_entered.connect(_on_area_entered)

	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta


func _on_area_entered(area: Area2D) -> void:
	var target := area.get_parent()
	if target.has_method("take_damage"):
		target.take_damage(damage)
	queue_free()  # projectile disappears on hit, whether it damaged something or not
