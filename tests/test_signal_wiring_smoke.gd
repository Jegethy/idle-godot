## Test Signal Wiring: Verify game signals trigger analytics events
## 
## Smoke tests to ensure signal wiring is working correctly.

extends Node

func _ready() -> void:
	print("=== Running Signal Wiring Smoke Tests ===\n")
	
	# We need to manually instantiate AnalyticsWiring since we're in a test
	var wiring := preload("res://scripts/systems/AnalyticsWiring.gd").new()
	add_child(wiring)
	
	var all_passed := true
	
	# Test 1: Resource changed event
	all_passed = await test_resource_changed_signal() and all_passed
	
	# Test 2: Upgrade purchased event
	all_passed = await test_upgrade_purchased_signal() and all_passed
	
	# Test 3: Prestige performed event
	all_passed = await test_prestige_performed_signal() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All signal wiring tests passed!")
	else:
		print("✗ Some signal wiring tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_resource_changed_signal() -> bool:
	print("Test: Resource changed signal triggers analytics event")
	
	# Enable analytics
	AnalyticsService.set_enabled(true)
	await get_tree().process_frame
	
	# Clear events
	AnalyticsService.delete_all_data()
	
	# Trigger resource_changed signal
	if GameState:
		GameState.resource_changed.emit("gold", 1000.0)
	else:
		print("  ✗ GameState not available")
		AnalyticsService.set_enabled(false)
		return false
	
	# Wait a frame for event to be processed
	await get_tree().process_frame
	
	# Check for economy.resource_changed event
	var recent_events := AnalyticsService.get_recent_events()
	var found_event := false
	
	for event in recent_events:
		if event.get("event", "") == "economy.resource_changed":
			found_event = true
			
			# Verify event data
			var data = event.get("data", {})
			if data.get("id", "") != "gold":
				print("  ✗ Event data missing/incorrect resource id")
				AnalyticsService.set_enabled(false)
				return false
			
			if data.get("amount", 0.0) != 1000.0:
				print("  ✗ Event data missing/incorrect amount")
				AnalyticsService.set_enabled(false)
				return false
			
			break
	
	if not found_event:
		print("  ✗ economy.resource_changed event not found")
		AnalyticsService.set_enabled(false)
		return false
	
	AnalyticsService.set_enabled(false)
	print("  ✓ Resource changed signal wired correctly")
	return true

func test_upgrade_purchased_signal() -> bool:
	print("Test: Upgrade purchased signal triggers analytics event")
	
	# Enable analytics
	AnalyticsService.set_enabled(true)
	await get_tree().process_frame
	
	# Clear events
	AnalyticsService.delete_all_data()
	
	# Trigger upgrade_purchased signal
	if GameState:
		GameState.upgrade_purchased.emit("gold_boost", 5)
	else:
		print("  ✗ GameState not available")
		AnalyticsService.set_enabled(false)
		return false
	
	# Wait a frame for event to be processed
	await get_tree().process_frame
	
	# Check for upgrade.purchased event
	var recent_events := AnalyticsService.get_recent_events()
	var found_event := false
	
	for event in recent_events:
		if event.get("event", "") == "upgrade.purchased":
			found_event = true
			
			# Verify event data
			var data = event.get("data", {})
			if data.get("id", "") != "gold_boost":
				print("  ✗ Event data missing/incorrect upgrade id")
				AnalyticsService.set_enabled(false)
				return false
			
			if data.get("level", 0) != 5:
				print("  ✗ Event data missing/incorrect level")
				AnalyticsService.set_enabled(false)
				return false
			
			break
	
	if not found_event:
		print("  ✗ upgrade.purchased event not found")
		AnalyticsService.set_enabled(false)
		return false
	
	AnalyticsService.set_enabled(false)
	print("  ✓ Upgrade purchased signal wired correctly")
	return true

func test_prestige_performed_signal() -> bool:
	print("Test: Prestige performed signal triggers analytics event")
	
	# Enable analytics
	AnalyticsService.set_enabled(true)
	await get_tree().process_frame
	
	# Clear events
	AnalyticsService.delete_all_data()
	
	# Trigger prestige_performed signal
	if PrestigeService:
		PrestigeService.prestige_performed.emit(10, 50.0, 1)
	else:
		print("  ✗ PrestigeService not available")
		AnalyticsService.set_enabled(false)
		return false
	
	# Wait a frame for event to be processed
	await get_tree().process_frame
	
	# Check for prestige.performed event
	var recent_events := AnalyticsService.get_recent_events()
	var found_event := false
	
	for event in recent_events:
		if event.get("event", "") == "prestige.performed":
			found_event = true
			
			# Verify event data
			var data = event.get("data", {})
			if data.get("gained", 0) != 10:
				print("  ✗ Event data missing/incorrect gained")
				AnalyticsService.set_enabled(false)
				return false
			
			if data.get("total_essence", 0.0) != 50.0:
				print("  ✗ Event data missing/incorrect total_essence")
				AnalyticsService.set_enabled(false)
				return false
			
			if data.get("total_prestiges", 0) != 1:
				print("  ✗ Event data missing/incorrect total_prestiges")
				AnalyticsService.set_enabled(false)
				return false
			
			break
	
	if not found_event:
		print("  ✗ prestige.performed event not found")
		AnalyticsService.set_enabled(false)
		return false
	
	AnalyticsService.set_enabled(false)
	print("  ✓ Prestige performed signal wired correctly")
	return true
