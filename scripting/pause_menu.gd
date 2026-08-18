extends CanvasLayer

# ---------------------------------------------------------
# PAUSE MENU
# ---------------------------------------------------------
# Scene setup (as a sibling to HUD in your level scene):
#
# PauseMenu (CanvasLayer)              <- this script
# └── PausePanel (Control)             <- Full Rect, hidden by default
#     ├── DimBackground (ColorRect)    <- Full Rect, semi-transparent black
#     └── VBoxContainer                <- centered, holds the buttons
#         ├── Label ("Paused")
#         ├── ResumeButton (Button)
#         ├── RestartButton (Button)
#         └── QuitButton (Button)
#
# Update title_screen_path below to match your actual start screen's path.
#
# Pressing Escape (the default "ui_cancel" action) toggles the pause.
# ---------------------------------------------------------

@onready var panel: Control = $PausePanel
@onready var resume_button: Button = $PausePanel/VBoxContainer/ResumeButton
@onready var restart_button: Button = $PausePanel/VBoxContainer/RestartButton
@onready var quit_button: Button = $PausePanel/VBoxContainer/QuitButton

@export var title_screen_path: String = "res://scenes/start_screen.tscn"  # update to your actual path


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working while the game is paused
	panel.visible = false

	resume_button.pressed.connect(_on_resume_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	panel.visible = get_tree().paused


func _on_resume_pressed() -> void:
	get_tree().paused = false
	panel.visible = false


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(title_screen_path)
