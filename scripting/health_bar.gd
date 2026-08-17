extends Control

# ---------------------------------------------------------
# HEALTH BAR
# ---------------------------------------------------------
# Scene setup:
#
# HealthBar (Control)         <- this script
# └── ProgressBar
#
# This whole thing should be a child of a CanvasLayer in your level,
# so it stays fixed on screen instead of moving/zooming with the camera:
#
# HUD (CanvasLayer)
# └── HealthBar (Control)
#     └── ProgressBar
#
# No manual wiring needed in the Inspector - this finds Raven automatically
# via the "player" group and listens for her health_changed signal.
# ---------------------------------------------------------

@onready var progress_bar: ProgressBar = $ProgressBar


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("HealthBar couldn't find a node in the 'player' group.")
		return

	progress_bar.max_value = player.max_health
	progress_bar.value = player.health

	player.health_changed.connect(_on_health_changed)


func _on_health_changed(current_health: int, max_health: int) -> void:
	progress_bar.max_value = max_health
	progress_bar.value = current_health
