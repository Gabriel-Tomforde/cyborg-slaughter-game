extends Control

# ---------------------------------------------------------
# START SCREEN
# ---------------------------------------------------------
# Scene setup:
#
# StartScreen (Control)             <- this script, anchored full-rect
# ├── Background (TextureRect)      <- title_screen_background.png,
# │                                    anchored full-rect, Expand Mode set
# │                                    to "Keep Aspect Covered"
# └── PressStartLabel (Label)       <- "Press Any Key to Start"
#
# Set this scene as your project's Main Scene (Project Settings > General >
# Application > Run > Main Scene) so it's the first thing that loads.
#
# Update next_scene_path below to point at your actual level/game scene.
# ---------------------------------------------------------

@export var next_scene_path: String = "res://game.tscn"  # change to your level's actual path


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_start_game()
	elif event is InputEventMouseButton and event.pressed:
		_start_game()


func _start_game() -> void:
	get_tree().change_scene_to_file(next_scene_path)
