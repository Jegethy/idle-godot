extends PanelContainer
## Tooltip: Displays detailed information on hover
## 
## Shows upgrade details, effects, and projections.

@onready var content_label: RichTextLabel = %ContentLabel

var is_visible_flag := false

func _ready() -> void:
	hide()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func show_tooltip(content: String, position: Vector2) -> void:
	content_label.clear()
	content_label.append_text(content)
	
	# Position the tooltip near the mouse but ensure it stays on screen
	global_position = position + Vector2(10, 10)
	
	# Adjust if tooltip would go off screen
	var viewport_size := get_viewport_rect().size
	if global_position.x + size.x > viewport_size.x:
		global_position.x = position.x - size.x - 10
	if global_position.y + size.y > viewport_size.y:
		global_position.y = position.y - size.y - 10
	
	show()
	is_visible_flag = true

func hide_tooltip() -> void:
	hide()
	is_visible_flag = false

func _process(_delta: float) -> void:
	# Follow mouse position when visible
	if is_visible_flag:
		var mouse_pos := get_viewport().get_mouse_position()
		global_position = mouse_pos + Vector2(10, 10)
		
		# Keep on screen
		var viewport_size := get_viewport_rect().size
		if global_position.x + size.x > viewport_size.x:
			global_position.x = mouse_pos.x - size.x - 10
		if global_position.y + size.y > viewport_size.y:
			global_position.y = mouse_pos.y - size.y - 10
