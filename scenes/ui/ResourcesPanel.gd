extends PanelContainer
## ResourcesPanel: Displays all unlocked resources with amounts and rates
## 
## Updates via signals, no per-frame polling.

@onready var resources_list: VBoxContainer = %ResourcesList

var resource_labels: Dictionary[String, Dictionary] = {}  # {resource_id: {amount_label: Label, rate_label: Label}}

func _ready() -> void:
	# Connect to signals
	GameState.resource_changed.connect(_on_resource_changed)
	Economy.rates_updated.connect(_on_rates_updated)
	
	# Setup initial UI
	_setup_resources_ui()
	
	# Initial update
	_update_all_resources()

func _setup_resources_ui() -> void:
	# Clear existing
	for child in resources_list.get_children():
		child.queue_free()
	resource_labels.clear()
	
	# Create UI for each unlocked resource
	for resource_id in GameState.resources:
		var resource: ResourceModel = GameState.resources[resource_id]
		if resource.unlocked:
			_create_resource_row(resource)

func _create_resource_row(resource: ResourceModel) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# Resource name
	var name_label := Label.new()
	name_label.text = resource.display_name
	name_label.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(name_label)
	
	# Spacer
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	# Amount
	var amount_label := Label.new()
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(amount_label)
	
	# Rate
	var rate_label := Label.new()
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rate_label.custom_minimum_size = Vector2(120, 0)
	hbox.add_child(rate_label)
	
	resources_list.add_child(hbox)
	
	resource_labels[resource.id] = {
		"amount_label": amount_label,
		"rate_label": rate_label,
		"hbox": hbox
	}
	
	# Update display
	_update_resource_display(resource.id)

func _update_resource_display(resource_id: String) -> void:
	if not resource_labels.has(resource_id):
		return
	
	var resource: ResourceModel = GameState.resources[resource_id]
	var labels: Dictionary = resource_labels[resource_id]
	
	# Format amount
	labels["amount_label"].text = NumberFormatter.format_short(resource.amount)
	
	# Format rate
	var rate := Economy.get_per_second_rate(resource_id)
	labels["rate_label"].text = NumberFormatter.format_short(rate) + "/sec"

func _update_all_resources() -> void:
	for resource_id in resource_labels:
		_update_resource_display(resource_id)

func _on_resource_changed(resource_id: String, _new_amount: float) -> void:
	_update_resource_display(resource_id)
	
	# Check if we need to add any newly unlocked resources
	if not resource_labels.has(resource_id):
		var resource: ResourceModel = GameState.resources.get(resource_id)
		if resource and resource.unlocked:
			_create_resource_row(resource)

func _on_rates_updated() -> void:
	_update_all_resources()
