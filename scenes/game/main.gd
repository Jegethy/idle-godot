extends Control
## Main: Main game scene controller
## 
## Entry point for the game. MainHUD handles all UI.

func _ready() -> void:
	# Try to load saved game
	SaveSystem.load_game()
	
	print("Main scene ready")
