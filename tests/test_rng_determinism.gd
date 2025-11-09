## Test RNG Determinism: Verify seeded RNG produces consistent results
## 
## Tests that the RNGService generates identical sequences with the same seed.

extends SceneTree

func _init() -> void:
	print("=== Running RNG Determinism Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Same seed produces same sequence
	all_passed = test_same_seed_same_sequence() and all_passed
	
	# Test 2: Different seeds produce different sequences
	all_passed = test_different_seeds_different_sequences() and all_passed
	
	# Test 3: Seed reset produces same sequence
	all_passed = test_seed_reset() and all_passed
	
	# Test 4: Weighted random is deterministic
	all_passed = test_weighted_random_deterministic() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All RNG determinism tests passed!")
	else:
		print("✗ Some RNG determinism tests failed")
	
	quit(0 if all_passed else 1)

func test_same_seed_same_sequence() -> bool:
	print("Test: Same seed produces same sequence")
	
	var seed_value := 12345
	
	# First run
	RNGService.set_seed(seed_value)
	var sequence1: Array[float] = []
	for i in range(10):
		sequence1.append(RNGService.randf())
	
	# Second run with same seed
	RNGService.set_seed(seed_value)
	var sequence2: Array[float] = []
	for i in range(10):
		sequence2.append(RNGService.randf())
	
	# Compare sequences
	for i in range(10):
		if abs(sequence1[i] - sequence2[i]) > 0.0001:
			print("  ✗ Sequences differ at index %d: %.6f vs %.6f" % [i, sequence1[i], sequence2[i]])
			return false
	
	print("  ✓ Same seed produces identical sequences")
	return true

func test_different_seeds_different_sequences() -> bool:
	print("Test: Different seeds produce different sequences")
	
	# First seed
	RNGService.set_seed(12345)
	var val1 := RNGService.randf()
	
	# Different seed
	RNGService.set_seed(54321)
	var val2 := RNGService.randf()
	
	if abs(val1 - val2) < 0.0001:
		print("  ✗ Different seeds produced same value: %.6f" % val1)
		return false
	
	print("  ✓ Different seeds produce different values")
	return true

func test_seed_reset() -> bool:
	print("Test: Seed reset produces same sequence")
	
	var seed_value := 99999
	
	# Generate some values
	RNGService.set_seed(seed_value)
	var first_val := RNGService.randf()
	RNGService.randf()
	RNGService.randf()
	
	# Reset to same seed
	RNGService.set_seed(seed_value)
	var reset_val := RNGService.randf()
	
	if abs(first_val - reset_val) > 0.0001:
		print("  ✗ Seed reset didn't produce same value: %.6f vs %.6f" % [first_val, reset_val])
		return false
	
	print("  ✓ Seed reset produces same sequence")
	return true

func test_weighted_random_deterministic() -> bool:
	print("Test: Weighted random is deterministic")
	
	var weights := [10.0, 20.0, 30.0, 40.0]
	var seed_value := 77777
	
	# First run
	RNGService.set_seed(seed_value)
	var results1: Array[int] = []
	for i in range(20):
		results1.append(RNGService.weighted_random(weights))
	
	# Second run with same seed
	RNGService.set_seed(seed_value)
	var results2: Array[int] = []
	for i in range(20):
		results2.append(RNGService.weighted_random(weights))
	
	# Compare
	for i in range(20):
		if results1[i] != results2[i]:
			print("  ✗ Weighted random differs at index %d: %d vs %d" % [i, results1[i], results2[i]])
			return false
	
	print("  ✓ Weighted random is deterministic")
	return true
