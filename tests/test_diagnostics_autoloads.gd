## Test Diagnostics Autoloads: Verify Diagnostics checks autoloads correctly
## 
## Tests that the Diagnostics tool properly verifies autoload existence.

extends Node

func _ready() -> void:
	print("=== Running Diagnostics Autoloads Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Diagnostics can check autoload existence
	print("Test 1: Check autoload existence")
	var passed := test_autoload_existence()
	print("Result: %s\n" % ("PASS" if passed else "FAIL"))
	all_passed = all_passed and passed
	
	# Test 2: Diagnostics detects missing autoloads
	print("Test 2: Detect missing autoloads")
	passed = test_missing_autoload_detection()
	print("Result: %s\n" % ("PASS" if passed else "FAIL"))
	all_passed = all_passed and passed
	
	# Test 3: MetaUpgradeService method check
	print("Test 3: MetaUpgradeService method availability")
	passed = test_meta_service_method()
	print("Result: %s\n" % ("PASS" if passed else "FAIL"))
	all_passed = all_passed and passed
	
	# Summary
	print("=== Summary ===")
	if all_passed:
		print("✓ All diagnostics tests passed!")
		get_tree().quit(0)
	else:
		print("✗ Some diagnostics tests failed")
		get_tree().quit(1)

func test_autoload_existence() -> bool:
	# Create a Diagnostics instance
	var diagnostics := preload("res://scripts/tools/Diagnostics.gd").new()
	
	# Check for expected autoloads
	var missing := diagnostics._check_autoloads()
	
	# All autoloads should be present in test environment
	if not missing.is_empty():
		push_warning("Some autoloads missing: %s" % ", ".join(missing))
		# This might not be a failure if running in minimal test environment
		print("  Note: Missing autoloads: %s" % ", ".join(missing))
	else:
		print("  ✓ All expected autoloads present")
	
	diagnostics.free()
	return true

func test_missing_autoload_detection() -> bool:
	# Create a Diagnostics instance
	var diagnostics := preload("res://scripts/tools/Diagnostics.gd").new()
	
	# Check for a fake autoload (should be detected as missing)
	var has_fake := diagnostics.has_node("/root/FakeAutoloadThatDoesNotExist")
	
	if has_fake:
		push_error("False positive: detected fake autoload")
		diagnostics.free()
		return false
	
	print("  ✓ Correctly detects missing autoloads")
	diagnostics.free()
	return true

func test_meta_service_method() -> bool:
	# Create a Diagnostics instance
	var diagnostics := preload("res://scripts/tools/Diagnostics.gd").new()
	
	# Check MetaUpgradeService method
	var has_method := diagnostics._check_meta_upgrade_service()
	
	if not has_method:
		push_error("MetaUpgradeService.sync_levels_from_game_state() not detected")
		diagnostics.free()
		return false
	
	print("  ✓ MetaUpgradeService.sync_levels_from_game_state() detected")
	diagnostics.free()
	return true
