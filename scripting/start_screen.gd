extends Control

# ---------------------------------------------------------
# START SCREEN
# ---------------------------------------------------------
# Scene setup:
#
# StartScreen (Control)                <- this script, Full Rect
# ├── Background (TextureRect)         <- title_screen_background.png, Full Rect
# ├── ButtonContainer (VBoxContainer)  <- centered on screen
# │   ├── StartButton (Button)
# │   ├── CreditsButton (Button)
# │   └── ExitButton (Button)
# └── CreditsPanel (Control)           <- Full Rect, hidden by default
#     ├── DimBackground (ColorRect)    <- Full Rect, semi-transparent black
#     └── VBoxContainer                <- centered
#         ├── CreditsLabel (Label)     <- your credits text
#         └── BackButton (Button)
#
# Set this scene as your project's Main Scene (Project Settings > General >
# Application > Run > Main Scene).
#
# Update next_scene_path below to point at your actual level/game scene.
# No signal connections needed in the editor - buttons are wired in code.
# ---------------------------------------------------------

@onready var start_button: Button = $ButtonContainer/StartButton
@onready var credits_button: Button = $ButtonContainer/CreditsButton
@onready var exit_button: Button = $ButtonContainer/ExitButton
@onready var credits_panel: Control = $CreditsPanel
@onready var back_button: Button = $CreditsPanel/VBoxContainer/BackButton

@export var next_scene_path: String = "res://Game.tscn"  # change to your level's actual path


func _ready() -> void:
	credits_panel.visible = false

	start_button.pressed.connect(_on_start_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	back_button.pressed.connect(_on_back_pressed)


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file(next_scene_path)


func _on_credits_pressed() -> void:
	credits_panel.visible = true


func _on_back_pressed() -> void:
	credits_panel.visible = false


func _on_exit_pressed() -> void:
	get_tree().quit()
