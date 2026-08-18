extends Area2D

# ---------------------------------------------------------
# BATTERY PICKUP
# ---------------------------------------------------------
# Scene setup:
#
# BatteryPickup (Area2D)     <- this script
# ├── CollisionShape2D
# └── Sprite2D                (assign your battery icon/art)
#
# Place instances of this scene around your level.
# ---------------------------------------------------------

@export var charge_amount: int = 1


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("add_battery_charge"):
		body.add_battery_charge(charge_amount)
		queue_free()
