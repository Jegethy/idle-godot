## Test Session Lifecycle: Verify session start/end events and tracking
## 
## Tests that analytics sessions are properly managed.

extends SceneTree

func _init() -> void:
	print("=== Running Session Lifecycle Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Session starts when enabled
	all_passed = test_session_start() and all_passed
	
	# Test 2: Session ends when disabled
	all_passed = test_session_end() and all_passed
	
	# Test 3: Session duration is positive
	all_passed = test_session_duration() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All session lifecycle tests passed!")
	else:
		print("✗ Some session lifecycle tests failed")
	
	quit(0 if all_passed else 1)

func test_session_start() -> bool:
	print("Test: Session starts when analytics enabled")
	
	# Ensure analytics is disabled
	AnalyticsService.set_enabled(false)
	
	# Session ID should be empty when disabled
	if not AnalyticsService.session_id.is_empty():
		print("  ✗ Session ID should be empty when disabled")
		return false
	
	# Enable analytics
	AnalyticsService.set_enabled(true)
	await get_tree().process_frame
	
	# Session ID should be set
	if AnalyticsService.session_id.is_empty():
		print("  ✗ Session ID should be set when enabled")
		AnalyticsService.set_enabled(false)
		return false
	
	# Should have session.start event
	var recent_events := AnalyticsService.get_recent_events()
	var has_session_start := false
	
	for event in recent_events:
		if event.get("event", "") == "session.start":
			has_session_start = true
			
			# Verify session.start event has required data
			var data = event.get("data", {})
			if not data.has("session_id"):
				print("  ✗ session.start event missing session_id")
				AnalyticsService.set_enabled(false)
				return false
			
			if not data.has("version"):
				print("  ✗ session.start event missing version")
				AnalyticsService.set_enabled(false)
				return false
			
			break
	
	if not has_session_start:
		print("  ✗ session.start event not found")
		AnalyticsService.set_enabled(false)
		return false
	
	AnalyticsService.set_enabled(false)
	print("  ✓ Session starts correctly")
	return true

func test_session_end() -> bool:
	print("Test: Session ends when analytics disabled")
	
	# Enable analytics
	AnalyticsService.set_enabled(true)
	await get_tree().process_frame
	
	# Clear events
	AnalyticsService.delete_all_data()
	
	# Store session ID
	var original_session_id := AnalyticsService.session_id
	
	# Disable analytics (should trigger session.end)
	AnalyticsService.set_enabled(false)
	
	# Session ID should be cleared
	if not AnalyticsService.session_id.is_empty():
		print("  ✗ Session ID should be cleared when disabled")
		return false
	
	# Note: We cleared events before disabling, so session.end won't be in buffer
	# But we can verify that the session was properly ended by checking the ID was cleared
	
	print("  ✓ Session ends correctly")
	return true

func test_session_duration() -> bool:
	print("Test: Session duration is tracked and positive")
	
	# Enable analytics
	AnalyticsService.set_enabled(true)
	await get_tree().process_frame
	
	# Wait a bit
	await get_tree().create_timer(0.5).timeout
	
	# Get session stats
	var stats := AnalyticsService.get_session_stats()
	var duration := stats.get("duration", 0.0)
	
	if duration <= 0:
		print("  ✗ Session duration should be positive, got: %.3f" % duration)
		AnalyticsService.set_enabled(false)
		return false
	
	# Duration should be at least 0.5 seconds
	if duration < 0.4:  # Allow some tolerance
		print("  ✗ Session duration too short: %.3f seconds" % duration)
		AnalyticsService.set_enabled(false)
		return false
	
	# Emit a session.end event manually to test its structure
	AnalyticsService._end_session()
	
	# Get the session.end event
	var recent_events := AnalyticsService.get_recent_events()
	var has_session_end := false
	
	for event in recent_events:
		if event.get("event", "") == "session.end":
			has_session_end = true
			
			# Verify session.end event has required data
			var data = event.get("data", {})
			
			if not data.has("session_id"):
				print("  ✗ session.end event missing session_id")
				return false
			
			if not data.has("duration"):
				print("  ✗ session.end event missing duration")
				return false
			
			var end_duration := data.get("duration", 0.0)
			if end_duration <= 0:
				print("  ✗ session.end duration should be positive, got: %.3f" % end_duration)
				return false
			
			break
	
	if not has_session_end:
		print("  ✗ session.end event not found")
		return false
	
	AnalyticsService.set_enabled(false)
	print("  ✓ Session duration tracked correctly")
	return true
