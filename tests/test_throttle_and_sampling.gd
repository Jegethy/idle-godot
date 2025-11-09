## Test Throttle and Sampling: Verify sampling and throttling work correctly
## 
## Tests that event sampling rates and throttle windows are respected.

extends SceneTree

func _init() -> void:
	print("=== Running Throttle and Sampling Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Sampling at 0.0 drops all events
	all_passed = test_zero_sampling() and all_passed
	
	# Test 2: Throttling prevents rapid events
	all_passed = test_throttling() and all_passed
	
	# Test 3: Session sampling
	all_passed = test_session_sampling() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All throttle and sampling tests passed!")
	else:
		print("✗ Some throttle and sampling tests failed")
	
	quit(0 if all_passed else 1)

func test_zero_sampling() -> bool:
	print("Test: Sampling at 0.0 drops all events")
	
	# Enable analytics
	AnalyticsService.set_enabled(true)
	await get_tree().process_frame
	
	# Set sampling to 0.0 for a specific event type
	AnalyticsService.event_sample_overrides["test.sampled"] = 0.0
	
	# Clear events
	AnalyticsService.delete_all_data()
	
	# Emit events
	for i in range(10):
		AnalyticsService.emit_event("test.sampled", {"value": i})
	
	# Check that no events were recorded (only session.start should exist)
	var recent_events := AnalyticsService.get_recent_events()
	var sampled_count := 0
	for event in recent_events:
		if event.get("event", "") == "test.sampled":
			sampled_count += 1
	
	if sampled_count > 0:
		print("  ✗ Expected 0 sampled events, got %d" % sampled_count)
		AnalyticsService.set_enabled(false)
		return false
	
	# Check drops counter
	var stats := AnalyticsService.get_session_stats()
	var drops := stats.get("events_dropped", 0)
	if drops != 10:
		print("  ✗ Expected 10 dropped events, got %d" % drops)
		AnalyticsService.set_enabled(false)
		return false
	
	# Clean up
	AnalyticsService.event_sample_overrides.erase("test.sampled")
	AnalyticsService.set_enabled(false)
	
	print("  ✓ Zero sampling drops all events")
	return true

func test_throttling() -> bool:
	print("Test: Throttling prevents rapid events")
	
	# Enable analytics
	AnalyticsService.set_enabled(true)
	await get_tree().process_frame
	
	# Set throttle window to 1 second for test event
	AnalyticsService.throttle_windows["test.throttled"] = 1.0
	
	# Clear events
	AnalyticsService.delete_all_data()
	
	# Emit events rapidly (should only record first one)
	for i in range(5):
		AnalyticsService.emit_event("test.throttled", {"value": i})
	
	# Count throttled events
	var recent_events := AnalyticsService.get_recent_events()
	var throttled_count := 0
	for event in recent_events:
		if event.get("event", "") == "test.throttled":
			throttled_count += 1
	
	# Should only have 1 event (the first one) due to throttling
	if throttled_count != 1:
		print("  ✗ Expected 1 throttled event, got %d" % throttled_count)
		AnalyticsService.set_enabled(false)
		return false
	
	# Wait for throttle window to expire
	await get_tree().create_timer(1.1).timeout
	
	# Emit another event (should succeed)
	AnalyticsService.emit_event("test.throttled", {"value": 99})
	
	# Count again
	recent_events = AnalyticsService.get_recent_events()
	throttled_count = 0
	for event in recent_events:
		if event.get("event", "") == "test.throttled":
			throttled_count += 1
	
	# Should now have 2 events
	if throttled_count != 2:
		print("  ✗ Expected 2 throttled events after window, got %d" % throttled_count)
		AnalyticsService.set_enabled(false)
		return false
	
	# Clean up
	AnalyticsService.throttle_windows.erase("test.throttled")
	AnalyticsService.set_enabled(false)
	
	print("  ✓ Throttling works correctly")
	return true

func test_session_sampling() -> bool:
	print("Test: Session sampling rate")
	
	# Session sampling is always 1.0 in current implementation
	# (controlled by enabled flag), so we just verify the behavior
	
	# Disabled = no events
	AnalyticsService.set_enabled(false)
	var result := AnalyticsService.emit_event("test.session", {"value": 1})
	
	if result:
		print("  ✗ Event should not be emitted when disabled")
		return false
	
	# Enabled = events recorded
	AnalyticsService.set_enabled(true)
	await get_tree().process_frame
	
	result = AnalyticsService.emit_event("test.session", {"value": 2})
	
	if not result:
		print("  ✗ Event should be emitted when enabled")
		AnalyticsService.set_enabled(false)
		return false
	
	AnalyticsService.set_enabled(false)
	print("  ✓ Session sampling working correctly")
	return true
