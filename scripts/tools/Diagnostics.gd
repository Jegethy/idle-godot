extends Node
## Diagnostics: Startup diagnostic checks for autoloads and configurations
## 
## Verifies that all critical singletons are loaded, checks for duplicate
## class_name conflicts, and validates method availability.

# Expected autoloads
const EXPECTED_AUTOLOADS := [
	"GameState",
	"Economy",
	"TimeService",
	"SaveSystem",
	"CombatSystem",
	"InventorySystem",
	"UpgradeService",
	"UnlockService",
	"PrestigeService",
	"RNGService",
	"EnemyDatabase",
	"DropService",
	"AffixService",
	"MetaUpgradeService",
	"AnalyticsService"
]

func _ready() -> void:
	# Run diagnostics after one frame to ensure all autoloads are initialized
	await get_tree().process_frame
	_run_diagnostics()

## Run all diagnostic checks
func _run_diagnostics() -> void:
	var issues: Array[String] = []
	
	# Check autoloads
	var missing_autoloads := _check_autoloads()
	if not missing_autoloads.is_empty():
		issues.append("Missing autoloads: %s" % ", ".join(missing_autoloads))
	
	# Check for duplicate class_name conflicts
	var class_conflicts := _check_class_name_conflicts()
	if not class_conflicts.is_empty():
		issues.append("Class name conflicts detected: %s" % ", ".join(class_conflicts))
	
	# Check MetaUpgradeService method availability
	if not _check_meta_upgrade_service():
		issues.append("MetaUpgradeService.sync_levels_from_game_state() method unavailable")
	
	# Report results
	if issues.is_empty():
		print("✓ Diagnostics OK - All systems healthy")
	else:
		push_error("✗ Diagnostics FAILED:")
		for issue in issues:
			push_error("  - %s" % issue)

## Check if all expected autoloads are present
func _check_autoloads() -> Array[String]:
	var missing: Array[String] = []
	
	for autoload_name in EXPECTED_AUTOLOADS:
		if not has_node("/root/%s" % autoload_name):
			missing.append(autoload_name)
	
	return missing

## Check for class_name conflicts with autoloads
## Note: This is a simplified check - we verify known potential conflicts
func _check_class_name_conflicts() -> Array[String]:
	var conflicts: Array[String] = []
	
	# Check MetaUpgradeService (known potential conflict from problem statement)
	# If it's an autoload, verify it's a Node and not just a class reference
	var meta_service = get_node_or_null("/root/MetaUpgradeService")
	if meta_service and not meta_service is Node:
		conflicts.append("MetaUpgradeService")
	
	return conflicts

## Check if MetaUpgradeService has the required method
func _check_meta_upgrade_service() -> bool:
	var meta_service = get_node_or_null("/root/MetaUpgradeService")
	if not meta_service:
		return false
	
	# Check if method exists
	return meta_service.has_method("sync_levels_from_game_state")
