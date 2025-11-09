extends PanelContainer
## UpgradesPanel: Displays all upgrades with multi-buy support and tooltips
## 
## Shows upgrade details, costs, and allows bulk purchasing.

@onready var upgrades_list: VBoxContainer = %UpgradesList
@onready var multi_buy_option: OptionButton = %MultiBuyOption

var upgrade_rows: Dictionary = {}  # {upgrade_id: {container: HBox, labels: {...}, buttons: [...]}}
var current_multi_buy := 1
var tooltip: Control = null

func _ready() -> void:
	# Connect to signals
	UpgradeService.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.resource_changed.connect(_on_resource_changed)
	
	# Setup multi-buy options
	_setup_multi_buy_options()
	
	# Setup upgrades UI
	_setup_upgrades_ui()

func set_tooltip_node(tooltip_node: Control) -> void:
	tooltip = tooltip_node

func _setup_multi_buy_options() -> void:
	multi_buy_option.clear()
	multi_buy_option.add_item("x1", 0)
	multi_buy_option.add_item("x10", 1)
	multi_buy_option.add_item("x100", 2)
	multi_buy_option.add_item("Max", 3)
	multi_buy_option.selected = 0
	multi_buy_option.item_selected.connect(_on_multi_buy_changed)

func _on_multi_buy_changed(index: int) -> void:
	match index:
		0: current_multi_buy = 1
		1: current_multi_buy = 10
		2: current_multi_buy = 100
		3: current_multi_buy = -1  # Max
	_update_all_upgrades()

func _setup_upgrades_ui() -> void:
	# Clear existing
	for child in upgrades_list.get_children():
		child.queue_free()
	upgrade_rows.clear()
	
	# Create UI for each unlocked upgrade
	for upgrade_id in GameState.upgrades:
		var upgrade: UpgradeModel = GameState.upgrades[upgrade_id]
		if upgrade.unlocked:
			_create_upgrade_row(upgrade)

func _create_upgrade_row(upgrade: UpgradeModel) -> void:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 5)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	row.add_child(margin)
	
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(hbox)
	
	# Upgrade info (left side)
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	# Name and level
	var name_label := Label.new()
	name_label.text = upgrade.display_name + " (Level: 0)"
	info_vbox.add_child(name_label)
	
	# Cost and delta
	var details_label := Label.new()
	details_label.add_theme_font_size_override("font_size", 12)
	details_label.modulate = Color(0.8, 0.8, 0.8)
	info_vbox.add_child(details_label)
	
	# Buy buttons (right side)
	var buy_button := Button.new()
	buy_button.text = "Buy (1)"
	buy_button.custom_minimum_size = Vector2(120, 0)
	buy_button.pressed.connect(_on_buy_pressed.bind(upgrade.id))
	hbox.add_child(buy_button)
	
	upgrades_list.add_child(row)
	
	upgrade_rows[upgrade.id] = {
		"container": row,
		"name_label": name_label,
		"details_label": details_label,
		"buy_button": buy_button
	}
	
	# Setup hover for tooltip
	row.mouse_entered.connect(_on_upgrade_hover.bind(upgrade.id))
	row.mouse_exited.connect(_on_upgrade_unhover)
	
	# Update display
	_update_upgrade_display(upgrade.id)

func _update_upgrade_display(upgrade_id: String) -> void:
	if not upgrade_rows.has(upgrade_id):
		return
	
	var upgrade: UpgradeModel = GameState.upgrades[upgrade_id]
	var row := upgrade_rows[upgrade_id]
	
	# Determine purchase quantity
	var quantity := current_multi_buy
	if quantity == -1:  # Max
		quantity = UpgradeService.compute_max_purchase(upgrade_id)
	
	# Update name and level
	row["name_label"].text = "%s (Level: %d)" % [upgrade.display_name, upgrade.level]
	
	# Calculate costs and delta
	var cost := UpgradeService.compute_bulk_cost(upgrade_id, quantity)
	var delta := UpgradeService.compute_bulk_delta(upgrade_id, quantity)
	
	# Update details
	var cost_str := NumberFormatter.format_short(cost)
	var delta_str := NumberFormatter.format_short(delta)
	row["details_label"].text = "Cost: %s | Δ/sec: +%s" % [cost_str, delta_str]
	
	# Update button
	var can_afford := GameState.can_afford("gold", cost)
	row["buy_button"].disabled = not can_afford or quantity == 0
	
	if current_multi_buy == -1:
		row["buy_button"].text = "Buy Max (%d)" % quantity
	else:
		row["buy_button"].text = "Buy (%d)" % quantity

func _update_all_upgrades() -> void:
	for upgrade_id in upgrade_rows:
		_update_upgrade_display(upgrade_id)

func _on_buy_pressed(upgrade_id: String) -> void:
	var quantity := current_multi_buy
	if quantity == -1:  # Max
		quantity = UpgradeService.compute_max_purchase(upgrade_id)
	
	if quantity > 0:
		var success := UpgradeService.buy_upgrade(upgrade_id, quantity)
		if success:
			_flash_upgrade_row(upgrade_id)

func _flash_upgrade_row(upgrade_id: String) -> void:
	if not upgrade_rows.has(upgrade_id):
		return
	
	var row := upgrade_rows[upgrade_id]["container"] as PanelContainer
	
	# Create a tween to flash the background
	var tween := create_tween()
	var original_modulate := row.modulate
	tween.tween_property(row, "modulate", Color(1.5, 1.5, 1.0), 0.1)
	tween.tween_property(row, "modulate", original_modulate, 0.3)

func _on_upgrade_purchased(_upgrade_id: String, _new_level: int) -> void:
	_update_all_upgrades()

func _on_resource_changed(_resource_id: String, _new_amount: float) -> void:
	# Update affordability
	_update_all_upgrades()

func _on_upgrade_hover(upgrade_id: String) -> void:
	if not tooltip:
		return
	
	var upgrade: UpgradeModel = GameState.upgrades[upgrade_id]
	var quantity := current_multi_buy
	if quantity == -1:
		quantity = UpgradeService.compute_max_purchase(upgrade_id)
	
	# Build tooltip content
	var content := "[b]%s[/b]\n" % upgrade.display_name
	content += "Current Level: %d\n" % upgrade.level
	
	# Current contribution
	if upgrade.type == UpgradeModel.UpgradeType.RATE:
		var contribution := upgrade.base_bonus * upgrade.level
		content += "Current: +%s/sec\n" % NumberFormatter.format_short(contribution)
	else:
		var multiplier := 1.0 + upgrade.base_bonus * upgrade.level
		content += "Current: x%.2f\n" % multiplier
	
	content += "\n[b]Next Level:[/b]\n"
	var next_cost := upgrade.get_current_cost()
	var next_delta := UpgradeService.compute_bulk_delta(upgrade_id, 1)
	content += "Cost: %s\n" % NumberFormatter.format_short(next_cost)
	content += "Δ/sec: +%s\n" % NumberFormatter.format_short(next_delta)
	
	if quantity > 1:
		content += "\n[b]Bulk Purchase (x%d):[/b]\n" % quantity
		var bulk_cost := UpgradeService.compute_bulk_cost(upgrade_id, quantity)
		var bulk_delta := UpgradeService.compute_bulk_delta(upgrade_id, quantity)
		content += "Total Cost: %s\n" % NumberFormatter.format_short(bulk_cost)
		content += "Total Δ/sec: +%s" % NumberFormatter.format_short(bulk_delta)
	
	var mouse_pos := get_viewport().get_mouse_position()
	tooltip.show_tooltip(content, mouse_pos)

func _on_upgrade_unhover() -> void:
	if tooltip:
		tooltip.hide_tooltip()
