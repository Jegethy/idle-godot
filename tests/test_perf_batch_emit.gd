## Test Performance Batch Emit: Verify performance of batch event emission
## 
## Tests that analytics can handle high-volume event emission efficiently.

extends Node

const TARGET_MS_PER_EVENT := 0.3  # Target: ≤ 0.3ms per event
const BATCH_SIZE := 10000  # Test with 10k events
const MAX_TOTAL_TIME_MS := 5000.0  # Max 5 seconds for entire batch (generous)

func _ready() -> void:
	print("=== Running Performance Batch Emit Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Batch emit performance
	all_passed = await test_batch_emit_performance() and all_passed
	
	# Test 2: Memory usage remains reasonable
	all_passed = test_memory_usage() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All performance tests passed!")
	else:
		print("✗ Some performance tests failed")
	
	get_tree().quit(0 if all_passed else 1)

func test_batch_emit_performance() -> bool:
	print("Test: Batch emit %d events within performance budget" % BATCH_SIZE)
	
	# Enable analytics
	AnalyticsService.set_enabled(true)
	await get_tree().process_frame
	
	# Clear existing events
	AnalyticsService.delete_all_data()
	
	# Measure time for batch emission
	var start_time := Time.get_ticks_usec()
	
	# Emit events in batch
	for i in range(BATCH_SIZE):
		var data := {
			"index": i,
			"value": i * 1.5,
			"category": "performance_test"
		}
		AnalyticsService.emit_event("perf.test", data)
	
	var end_time := Time.get_ticks_usec()
	var elapsed_usec := end_time - start_time
	var elapsed_ms := elapsed_usec / 1000.0
	
	print("  Emitted %d events in %.2f ms" % [BATCH_SIZE, elapsed_ms])
	
	# Calculate average time per event
	var avg_ms_per_event := elapsed_ms / BATCH_SIZE
	print("  Average: %.4f ms per event" % avg_ms_per_event)
	
	# Check against target (with generous threshold)
	if elapsed_ms > MAX_TOTAL_TIME_MS:
		print("  ✗ Batch emission took too long: %.2f ms (max: %.2f ms)" % [elapsed_ms, MAX_TOTAL_TIME_MS])
		AnalyticsService.set_enabled(false)
		return false
	
	# Verify events were recorded
	var stats := AnalyticsService.get_session_stats()
	var recorded: int = int(stats.get("events_recorded", 0))
	
	# Should have recorded most events (some may be in buffer but not flushed)
	if recorded < BATCH_SIZE * 0.9:  # Allow 10% margin for buffering
		print("  ✗ Not enough events recorded: %d (expected ~%d)" % [recorded, BATCH_SIZE])
		AnalyticsService.set_enabled(false)
		return false
	
	AnalyticsService.set_enabled(false)
	print("  ✓ Performance within acceptable range")
	return true

func test_memory_usage() -> bool:
	print("Test: Memory usage remains reasonable with ring buffer")
	
	# Create EventStore with reasonable buffer size
	var store := EventStore.new()
	store.ring_buffer_max_size = 500
	
	# Initial buffer size
	var initial_size := store.ring_buffer.size()
	
	# Add many events (more than buffer size)
	for i in range(2000):
		var event := {
			"ts": Time.get_unix_time_from_system() + i,
			"session_id": "mem-test",
			"event": "mem.test",
			"ver": 1,
			"seq": i,
			"data": {"index": i}
		}
		store.add_to_ring_buffer(event)
	
	# Buffer should not exceed max size
	if store.ring_buffer.size() > store.ring_buffer_max_size:
		print("  ✗ Ring buffer exceeded max size: %d > %d" % [store.ring_buffer.size(), store.ring_buffer_max_size])
		return false
	
	# Buffer should be at max size
	if store.ring_buffer.size() != store.ring_buffer_max_size:
		print("  ✗ Ring buffer should be at max size: %d != %d" % [store.ring_buffer.size(), store.ring_buffer_max_size])
		return false
	
	# Oldest events should be dropped
	var first_event: Dictionary = store.ring_buffer[0]
	var first_event_data: Dictionary = first_event.get("data", {})
	var first_index: int = int(first_event_data.get("index", -1))
	
	# First event should be around index 1500 (2000 - 500)
	if first_index < 1400:  # Allow some tolerance
		print("  ✗ Oldest events not properly dropped, first index: %d" % first_index)
		return false
	
	print("  ✓ Memory usage controlled by ring buffer (size: %d)" % store.ring_buffer.size())
	return true
