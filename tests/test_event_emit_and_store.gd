## Test Event Emit and Store: Verify events are emitted and stored correctly
## 
## Tests that events are properly stored in EventStore and ring buffer.

extends SceneTree

func _init() -> void:
	print("=== Running Event Emit and Store Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Emit events and check storage
	all_passed = test_emit_and_store() and all_passed
	
	# Test 2: Ring buffer size limit
	all_passed = test_ring_buffer_limit() and all_passed
	
	# Test 3: Event structure validation
	all_passed = test_event_structure() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All event emit and store tests passed!")
	else:
		print("✗ Some event emit and store tests failed")
	
	quit(0 if all_passed else 1)

func test_emit_and_store() -> bool:
	print("Test: Emit events and verify storage")
	
	# Enable analytics
	AnalyticsService.set_enabled(true)
	await get_tree().process_frame
	
	# Clear any existing events
	AnalyticsService.delete_all_data()
	
	# Emit 3 test events
	AnalyticsService.emit_event("test.event1", {"value": 1})
	AnalyticsService.emit_event("test.event2", {"value": 2})
	AnalyticsService.emit_event("test.event3", {"value": 3})
	
	# Get recent events
	var recent_events := AnalyticsService.get_recent_events()
	
	# Should have at least 3 events (plus session.start)
	if recent_events.size() < 3:
		print("  ✗ Expected at least 3 events, got %d" % recent_events.size())
		AnalyticsService.set_enabled(false)
		return false
	
	# Verify event data
	var found_event1 := false
	var found_event2 := false
	var found_event3 := false
	
	for event in recent_events:
		var event_name = event.get("event", "")
		if event_name == "test.event1":
			found_event1 = true
			if event.get("data", {}).get("value", 0) != 1:
				print("  ✗ Event1 data incorrect")
				AnalyticsService.set_enabled(false)
				return false
		elif event_name == "test.event2":
			found_event2 = true
		elif event_name == "test.event3":
			found_event3 = true
	
	if not (found_event1 and found_event2 and found_event3):
		print("  ✗ Not all test events found in buffer")
		AnalyticsService.set_enabled(false)
		return false
	
	AnalyticsService.set_enabled(false)
	print("  ✓ Events emitted and stored correctly")
	return true

func test_ring_buffer_limit() -> bool:
	print("Test: Ring buffer respects size limit")
	
	# Create a custom EventStore with small buffer
	var store := EventStore.new()
	store.ring_buffer_max_size = 5
	
	# Add 10 events
	for i in range(10):
		var event := {
			"ts": Time.get_unix_time_from_system(),
			"session_id": "test",
			"event": "test.event",
			"ver": 1,
			"seq": i,
			"data": {"value": i}
		}
		store.add_to_ring_buffer(event)
	
	# Buffer should only have last 5 events
	if store.ring_buffer.size() != 5:
		print("  ✗ Ring buffer size should be 5, got %d" % store.ring_buffer.size())
		return false
	
	# Should have events 5-9
	var first_event_value = store.ring_buffer[0].get("data", {}).get("value", -1)
	if first_event_value != 5:
		print("  ✗ Ring buffer should have event 5 first, got %d" % first_event_value)
		return false
	
	print("  ✓ Ring buffer respects size limit")
	return true

func test_event_structure() -> bool:
	print("Test: Event structure validation")
	
	# Valid event
	var valid_event := {
		"ts": Time.get_unix_time_from_system(),
		"session_id": "test-session",
		"event": "test.valid",
		"ver": 1,
		"seq": 1,
		"data": {"key": "value"}
	}
	
	if not Anonymizer.validate_event(valid_event):
		print("  ✗ Valid event failed validation")
		return false
	
	# Invalid event - missing ts
	var invalid_event1 := {
		"session_id": "test-session",
		"event": "test.invalid",
		"data": {}
	}
	
	if Anonymizer.validate_event(invalid_event1):
		print("  ✗ Invalid event (missing ts) passed validation")
		return false
	
	# Invalid event - missing data
	var invalid_event2 := {
		"ts": Time.get_unix_time_from_system(),
		"session_id": "test-session",
		"event": "test.invalid"
	}
	
	if Anonymizer.validate_event(invalid_event2):
		print("  ✗ Invalid event (missing data) passed validation")
		return false
	
	# Invalid event - data is not a Dictionary
	var invalid_event3 := {
		"ts": Time.get_unix_time_from_system(),
		"session_id": "test-session",
		"event": "test.invalid",
		"data": "not a dictionary"
	}
	
	if Anonymizer.validate_event(invalid_event3):
		print("  ✗ Invalid event (data not Dictionary) passed validation")
		return false
	
	print("  ✓ Event structure validation working correctly")
	return true
