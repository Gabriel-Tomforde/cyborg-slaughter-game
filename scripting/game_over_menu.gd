extends CanvasLayer

# ---------------------------------------------------------
# GAME OVER MENU
# ---------------------------------------------------------
# Scene setup (as a sibling to HUD in your level scene):
#
# GameOverMenu (CanvasLayer)           <- this script
# └── GameOverPanel (Control)          <- Full Rect, hidden by default
#     ├── DimBackground (ColorRect)    <- Full Rect, semi-transparent black
#     └── VBoxContainer                <- centered, holds the buttons
#         ├── Label ("Game Over")
#         ├── RestartButton (Button)
#         └── QuitButton (Button)
#
# Update title_screen_path below to match your actual start screen's path.
#
# No manual wiring needed - this finds Raven automatically via the
# "player" group and listens for her "died" signal.
# ---------------------------------------------------------

@onready var panel: Control = $GameOverPanel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton
@onready var quit_button: Button = $GameOverPanel/VBoxContainer/QuitButton

@export var title_screen_path: String = "res://StartScreen.tscn"  # update to your actual path


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working once the game is paused below
	panel.visible = false

	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("GameOverMenu couldn't find a node in the 'player' group.")
		return

	player.died.connect(_on_player_died)


func _on_player_died() -> void:
	panel.visible = true
	get_tree().paused = true  # freeze enemies/everything else once the game is over


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(title_screen_path)
