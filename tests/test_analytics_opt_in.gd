## Test Analytics Opt-In: Verify analytics is disabled by default
## 
## Tests that analytics is OFF by default and requires explicit opt-in.

extends Node

func _ready() -> void:
	print("=== Running Analytics Opt-In Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Analytics disabled by default
	all_passed = test_analytics_disabled_by_default() and all_passed
	
	# Test 2: No events recorded when disabled
	all_passed = test_no_events_when_disabled() and all_passed
	
	# Test 3: Events recorded when enabled
	all_passed = await test_events_when_enabled() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All analytics opt-in tests passed!")
	else:
		print("✗ Some analytics opt-in tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_analytics_disabled_by_default() -> bool:
	print("Test: Analytics disabled by default")
	
	if AnalyticsService.enabled:
		print("  ✗ Analytics should be disabled by default")
		return false
	
	print("  ✓ Analytics disabled by default")
	return true

func test_no_events_when_disabled() -> bool:
	print("Test: No events recorded when disabled")
	
	# Ensure analytics is disabled
	AnalyticsService.set_enabled(false)
	
	# Try to emit an event
	var result := AnalyticsService.emit_event("test.event", {"value": 123})
	
	if result:
		print("  ✗ Event should not be emitted when disabled")
		return false
	
	# Check that no events were recorded
	var stats: Dictionary = AnalyticsService.get_session_stats()
	var event_count: int = int(stats.get("events_recorded", 0))
	if event_count > 0:
		print("  ✗ Event count should be 0 when disabled, got %d" % event_count)
		return false
	
	print("  ✓ No events recorded when disabled")
	return true

func test_events_when_enabled() -> bool:
	print("Test: Events recorded when enabled")
	
	# Enable analytics
	AnalyticsService.set_enabled(true)
	
	# Wait a frame for session to start
	await get_tree().process_frame
	
	# Emit an event
	var result := AnalyticsService.emit_event("test.event", {"value": 456})
	
	if not result:
		print("  ✗ Event should be emitted when enabled")
		return false
	
	# Check that event was recorded
	var stats_2: Dictionary = AnalyticsService.get_session_stats()
	var event_count: int = int(stats_2.get("events_recorded", 0))
	if event_count == 0:
		print("  ✗ Event count should be > 0 when enabled")
		return false
	
	# Disable analytics again
	AnalyticsService.set_enabled(false)
	
	print("  ✓ Events recorded when enabled (count: %d)" % event_count)
	return true
