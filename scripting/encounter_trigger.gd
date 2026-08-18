extends Area2D

# ---------------------------------------------------------
# ENCOUNTER TRIGGER
# ---------------------------------------------------------
# Spawns a group of enemies once the player walks into this zone.
#
# Scene setup:
#
# EncounterTrigger (Area2D)      <- this script
# ├── CollisionShape2D           (the trigger zone - make it wide enough
# │                                to catch Raven walking through)
# ├── SpawnPoint1 (Marker2D)
# ├── SpawnPoint2 (Marker2D)
# └── SpawnPoint3 (Marker2D)     (add as many as you want enemies)
#
# After adding this node to your level:
# 1. Assign your Enemy.tscn to "Enemy Scene" in the Inspector.
# 2. Drag each Marker2D (SpawnPoint1, etc.) into the "Spawn Points" array
#    in the Inspector, in the order you want them filled.
# 3. Position the Marker2D nodes in the 2D viewport wherever you want
#    each enemy to appear.
# ---------------------------------------------------------

@export var enemy_scene: PackedScene
@export var spawn_points: Array[Marker2D] = []

var has_triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if has_triggered:
		return
	if not body.is_in_group("player"):
		return

	has_triggered = true
	call_deferred("_spawn_enemies")

	set_deferred("monitoring", false)  # stop listening so this can't fire again


func _spawn_enemies() -> void:
	if enemy_scene == null:
		push_warning("EncounterTrigger has no enemy_scene assigned in the Inspector.")
		return

	for point in spawn_points:
		if point == null:
			continue
		var enemy := enemy_scene.instantiate()
		get_parent().add_child(enemy)
		enemy.global_position = point.global_position
