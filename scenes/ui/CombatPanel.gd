extends PanelContainer
## CombatPanel: UI for wave-based combat system
## 
## Displays current wave info, player stats, enemy list, combat log,
## and buttons to start wave or run fast simulation.

@onready var wave_label: Label = %WaveLabel
@onready var player_stats_label: Label = %PlayerStatsLabel
@onready var enemy_list_container: VBoxContainer = %EnemyListContainer
@onready var combat_log: RichTextLabel = %CombatLog
@onready var start_wave_button: Button = %StartWaveButton
@onready var fast_sim_button: Button = %FastSimButton
@onready var summary_label: Label = %SummaryLabel

var enemy_rows: Array[Dictionary] = []

func _ready() -> void:
	# Connect signals
	CombatSystem.combat_started.connect(_on_combat_started)
	CombatSystem.combat_event.connect(_on_combat_event)
	CombatSystem.combat_finished.connect(_on_combat_finished)
	
	# Connect buttons
	start_wave_button.pressed.connect(_on_start_wave_pressed)
	fast_sim_button.pressed.connect(_on_fast_sim_pressed)
	
	# Initial update
	_update_ui()

func _update_ui() -> void:
	# Update wave info
	var current_wave := GameState.current_wave
	wave_label.text = "Current Wave: %d" % current_wave
	
	# Update player stats
	var stats := _get_player_stats_text()
	player_stats_label.text = stats
	
	# Enable/disable buttons based on combat state
	start_wave_button.disabled = CombatSystem.combat_active
	fast_sim_button.disabled = CombatSystem.combat_active
	
	# Clear summary if no combat
	if not CombatSystem.combat_active:
		summary_label.text = ""

func _get_player_stats_text() -> String:
	var essence := GameState.essence
	var essence_bonus := 1.0 + BalanceConstants.COMBAT_ESSENCE_MULTIPLIER * sqrt(essence)
	
	var attack := GameState.player_stats.attack * essence_bonus
	var defense := GameState.player_stats.defense * essence_bonus
	var crit_chance := GameState.player_stats.crit_chance * 100.0
	var crit_mult := GameState.player_stats.crit_multiplier
	var speed := GameState.player_stats.combat_speed
	
	return "Attack: %.1f | Defense: %.1f | Crit: %.1f%% (%.1fx) | Speed: %.1fx | Essence Bonus: %.2fx" % [
		attack, defense, crit_chance, crit_mult, speed, essence_bonus
	]

func _on_start_wave_pressed() -> void:
	var wave_index := GameState.current_wave
	CombatSystem.start_wave(wave_index)
	
	# Clear log and enemy list
	combat_log.clear()
	_add_log_line("[b]Wave %d started (Interactive Mode)[/b]" % wave_index)
	
	# Start ticking
	set_process(true)

func _on_fast_sim_pressed() -> void:
	var wave_index := GameState.current_wave
	
	# Clear log
	combat_log.clear()
	_add_log_line("[b]Wave %d started (Fast Simulation)[/b]" % wave_index)
	
	# Run fast simulation
	var result := CombatSystem.fast_simulate_wave(wave_index)
	
	# Display result is handled by _on_combat_finished signal

func _process(_delta: float) -> void:
	# Tick combat in interactive mode
	if CombatSystem.combat_active:
		CombatSystem.simulate_tick()
		_update_enemy_list()
		_update_player_hp()

func _on_combat_started(wave_index: int, seed: int) -> void:
	_add_log_line("Combat started! Wave: %d, Seed: %d" % [wave_index, seed])
	_update_ui()
	_update_enemy_list()

func _on_combat_event(event: Dictionary) -> void:
	var event_type: String = event.get("type", "")
	
	match event_type:
		"hit":
			var attacker: String = event.get("attacker", "")
			var target: String = event.get("target", "")
			var damage: float = event.get("damage", 0.0)
			var is_crit: bool = event.get("crit", false)
			
			var crit_text := " [color=yellow]CRIT![/color]" if is_crit else ""
			_add_log_line("%s hit %s for %.1f damage%s" % [attacker, target, damage, crit_text])
		
		"defeated":
			var enemy_name: String = event.get("enemy", "Enemy")
			_add_log_line("[color=green]%s defeated![/color]" % enemy_name)

func _on_combat_finished(result: Dictionary) -> void:
	var victory: bool = result.get("victory", false)
	var time: float = result.get("time", 0.0)
	var enemies_defeated: int = result.get("enemies_defeated", 0)
	var damage_dealt: float = result.get("damage_dealt", 0.0)
	var damage_taken: float = result.get("damage_taken", 0.0)
	var dps: float = result.get("dps", 0.0)
	
	if victory:
		_add_log_line("[b][color=green]VICTORY![/color][/b]")
		
		# Display rewards
		var rewards: Dictionary = result.get("rewards", {})
		var gold: float = rewards.get("gold", 0.0)
		var items: Array = rewards.get("items", [])
		
		_add_log_line("Gold gained: +%.2f" % gold)
		
		if items.size() > 0:
			_add_log_line("Items dropped:")
			for item_dict in items:
				var item_id: String = item_dict.get("item_id", "")
				var quantity: int = item_dict.get("quantity", 0)
				_add_log_line("  - %s x%d" % [item_id, quantity])
	else:
		var reason: String = result.get("failure_reason", "Unknown")
		_add_log_line("[b][color=red]DEFEAT![/color][/b] - %s" % reason)
	
	# Summary
	summary_label.text = "Time: %.2fs | Enemies: %d | Damage: %.1f | Taken: %.1f | DPS: %.1f" % [
		time, enemies_defeated, damage_dealt, damage_taken, dps
	]
	
	# Stop processing
	set_process(false)
	
	# Update UI
	_update_ui()

func _update_enemy_list() -> void:
	# Clear existing rows
	for child in enemy_list_container.get_children():
		child.queue_free()
	enemy_rows.clear()
	
	# Create row for each active enemy
	for enemy in CombatSystem.current_enemies:
		var row := _create_enemy_row(enemy)
		enemy_rows.append(row)

func _create_enemy_row(enemy: Dictionary) -> Dictionary:
	var hbox := HBoxContainer.new()
	
	# Enemy name
	var name_label := Label.new()
	name_label.text = enemy.get("name", "Enemy")
	name_label.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(name_label)
	
	# HP bar
	var hp_progress := ProgressBar.new()
	hp_progress.custom_minimum_size = Vector2(200, 20)
	hp_progress.max_value = enemy.get("max_hp", 100.0)
	hp_progress.value = enemy.get("hp", 100.0)
	hp_progress.show_percentage = false
	hbox.add_child(hp_progress)
	
	# HP text
	var hp_label := Label.new()
	hp_label.text = "%.0f / %.0f" % [enemy.get("hp", 0.0), enemy.get("max_hp", 0.0)]
	hp_label.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(hp_label)
	
	enemy_list_container.add_child(hbox)
	
	return {
		"enemy": enemy,
		"hbox": hbox,
		"hp_progress": hp_progress,
		"hp_label": hp_label
	}

func _update_player_hp() -> void:
	# Update player HP display (if we add it to UI)
	pass

func _add_log_line(text: String) -> void:
	combat_log.append_text(text + "\n")
	
	# Auto-scroll to bottom
	await get_tree().process_frame
	combat_log.scroll_to_line(combat_log.get_line_count() - 1)
