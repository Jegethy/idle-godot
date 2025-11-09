## Test Payback Estimate: Verify payback time calculations
## 
## Tests projection simulator payback time estimates.

extends SceneTree

func _init() -> void:
	print("=== Running Payback Estimate Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Payback for idle multiplier upgrade
	all_passed = test_idle_multiplier_payback() and all_passed
	
	# Test 2: Payback for idle additive upgrade
	all_passed = test_idle_additive_payback() and all_passed
	
	# Test 3: Non-idle upgrades return INF
	all_passed = test_non_idle_returns_inf() and all_passed
	
	# Test 4: Zero delta rate returns INF
	all_passed = test_zero_delta_returns_inf() and all_passed
	
	print("\n=== Test Results ===")
	if all_passed:
		print("✓ All payback estimate tests passed!")
	else:
		print("✗ Some payback estimate tests failed")
	
	quit(0 if all_passed else 1)

func test_idle_multiplier_payback() -> bool:
	print("Test: Payback calculation for idle multiplier upgrade")
	
	# Create idle_core upgrade at level 0
	var upgrade := MetaUpgradeService.get_upgrade("idle_core")
	if not upgrade:
		print("  ✗ idle_core upgrade not found")
		return false
	
	# Reset to level 0
	upgrade.current_level = 0
	
	# Simulate current idle rate of 100/sec
	var current_rate := 100.0
	
	# Next level effect: 0.02 multiplier
	# Delta rate = 100 * 0.02 = 2.0/sec
	# Cost at level 0 = 10
	# Payback = 10 / 2.0 = 5 seconds
	
	var payback_info := MetaProjection.calculate_payback_for_upgrade(upgrade, current_rate)
	
	if not payback_info.get("is_finite", false):
		print("  ✗ Payback should be finite for idle multiplier")
		return false
	
	var payback := payback_info.get("payback_seconds", INF)
	var expected := 10.0 / 2.0
	
	if not is_equal_approx(payback, expected):
		print("  ✗ Expected payback %.2f seconds, got %.2f" % [expected, payback])
		return false
	
	print("  ✓ Idle multiplier payback: %.2f seconds" % payback)
	return true

func test_idle_additive_payback() -> bool:
	print("\nTest: Payback calculation for idle additive upgrade")
	
	# Get idle_boost upgrade (idle_rate_add: 0.5 per level)
	var upgrade := MetaUpgradeService.get_upgrade("idle_boost")
	if not upgrade:
		print("  ✗ idle_boost upgrade not found")
		return false
	
	# Reset to level 0
	upgrade.current_level = 0
	
	# For additive, current_rate doesn't matter for delta calculation
	var current_rate := 100.0
	
	# Next level effect: 0.5 additive
	# Delta rate = 0.5/sec
	# Cost at level 0 = 15
	# Payback = 15 / 0.5 = 30 seconds
	
	var payback_info := MetaProjection.calculate_payback_for_upgrade(upgrade, current_rate)
	
	if not payback_info.get("is_finite", false):
		print("  ✗ Payback should be finite for idle additive")
		return false
	
	var payback := payback_info.get("payback_seconds", INF)
	var expected := 15.0 / 0.5
	
	if not is_equal_approx(payback, expected):
		print("  ✗ Expected payback %.2f seconds, got %.2f" % [expected, payback])
		return false
	
	print("  ✓ Idle additive payback: %.2f seconds" % payback)
	return true

func test_non_idle_returns_inf() -> bool:
	print("\nTest: Non-idle upgrades return INF payback")
	
	# Get combat_edge upgrade (combat effect)
	var upgrade := MetaUpgradeService.get_upgrade("combat_edge")
	if not upgrade:
		print("  ✗ combat_edge upgrade not found")
		return false
	
	# Reset to level 0
	upgrade.current_level = 0
	
	var current_rate := 100.0
	
	var payback_info := MetaProjection.calculate_payback_for_upgrade(upgrade, current_rate)
	
	if payback_info.get("is_finite", false):
		print("  ✗ Non-idle upgrade should have infinite payback")
		return false
	
	var payback := payback_info.get("payback_seconds", 0.0)
	if payback != INF:
		print("  ✗ Expected INF payback for non-idle upgrade, got %.2f" % payback)
		return false
	
	print("  ✓ Non-idle upgrade returns INF payback")
	return true

func test_zero_delta_returns_inf() -> bool:
	print("\nTest: Zero delta rate returns INF")
	
	# Test estimate_payback directly with zero delta
	var cost := 100.0
	var current_rate := 100.0
	var delta_rate := 0.0
	
	var payback := MetaProjection.estimate_payback(cost, current_rate, delta_rate)
	
	if payback != INF:
		print("  ✗ Expected INF payback for zero delta, got %.2f" % payback)
		return false
	
	# Also test negative delta
	delta_rate = -1.0
	payback = MetaProjection.estimate_payback(cost, current_rate, delta_rate)
	
	if payback != INF:
		print("  ✗ Expected INF payback for negative delta, got %.2f" % payback)
		return false
	
	print("  ✓ Zero/negative delta returns INF")
	return true
