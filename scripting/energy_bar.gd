extends Control

# ---------------------------------------------------------
# ENERGY BAR
# ---------------------------------------------------------
# Scene setup:
#
# EnergyBar (Control)         <- this script
# └── ProgressBar
#
# This should be a child of the same HUD (CanvasLayer) your HealthBar
# already lives in, so it stays fixed on screen:
#
# HUD (CanvasLayer)
# ├── HealthBar (Control)
# │   └── ProgressBar
# └── EnergyBar (Control)
#     └── ProgressBar
#
# No manual wiring needed - this finds Raven automatically via the
# "player" group and listens for her battery_changed signal.
# ---------------------------------------------------------

@onready var progress_bar: ProgressBar = $ProgressBar


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("EnergyBar couldn't find a node in the 'player' group.")
		return

	progress_bar.max_value = player.max_battery_charge
	progress_bar.value = player.battery_charge

	player.battery_changed.connect(_on_battery_changed)


func _on_battery_changed(current_charge: int, max_charge: int) -> void:
	progress_bar.max_value = max_charge
	progress_bar.value = current_charge
