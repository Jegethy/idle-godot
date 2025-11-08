extends Control
## MainDebug: Main scene with debug panel for testing

func _ready() -> void:
	print("Main debug scene ready")
	# Try to load saved game
	SaveSystem.load_game()
