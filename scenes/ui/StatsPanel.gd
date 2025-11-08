extends PanelContainer
## StatsPanel: Displays player statistics (read-only)
## 
## Shows player stats like idle rate multiplier and combat stats.

@onready var stats_list: VBoxContainer = %StatsList

func _ready() -> void:
	_setup_stats_ui()

func _setup_stats_ui() -> void:
	# Clear existing
	for child in stats_list.get_children():
		child.queue_free()
	
	# Add player stats
	_add_stat_row("Idle Rate Multiplier", "x%.2f" % GameState.player_stats.idle_rate_multiplier)
	_add_stat_row("Attack", str(GameState.player_stats.attack))
	_add_stat_row("Defense", str(GameState.player_stats.defense))
	_add_stat_row("Crit Chance", "%.1f%%" % (GameState.player_stats.crit_chance * 100))

func _add_stat_row(stat_name: String, stat_value: String) -> void:
	var hbox := HBoxContainer.new()
	
	var name_label := Label.new()
	name_label.text = stat_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)
	
	var value_label := Label.new()
	value_label.text = stat_value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value_label)
	
	stats_list.add_child(hbox)
