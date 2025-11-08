extends Control
## MainHUD: Root HUD container for all UI panels
## 
## Manages layout and connections between panels and tooltip.

@onready var tooltip: Control = %Tooltip
@onready var upgrades_panel: Control = %UpgradesPanel

func _ready() -> void:
	# Pass tooltip reference to upgrades panel
	if upgrades_panel and upgrades_panel.has_method("set_tooltip_node"):
		upgrades_panel.set_tooltip_node(tooltip)
