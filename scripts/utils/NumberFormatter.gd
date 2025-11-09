extends Node
## NumberFormatter: Utility for formatting numbers in short scale notation
## 
## Provides functions to format large numbers as K, M, B, T for better readability.

class_name NumberFormatter

const EPS: float = 1e-9

## Format a number with short scale notation (K, M, B, T)
## Examples: 1234 -> "1.23K", 5_670_000 -> "5.67M", 3_450_000_000 -> "3.45B"
static func format_short(value: float, precision: int = 2) -> String:
	var abs_value := absf(value)
	var sign_str := "-" if value < 0 else ""
	
	# Handle values less than 1000
	if abs_value < 1000.0:
		if abs_value == floorf(abs_value):
			return sign_str + str(int(abs_value))
		else:
			return sign_str + ("%.2f" % abs_value)
	
	# Define thresholds and suffixes
	var thresholds := [
		{"value": 1_000_000_000_000.0, "suffix": "T"},  # Trillion
		{"value": 1_000_000_000.0, "suffix": "B"},      # Billion
		{"value": 1_000_000.0, "suffix": "M"},          # Million
		{"value": 1_000.0, "suffix": "K"}               # Thousand
	]
	
	for threshold in thresholds:
		if abs_value >= threshold["value"]:
			var scaled: float = abs_value / float(threshold.get("value", 1.0))
			var format_str := "%%.%df%%s" % precision
			return sign_str + (format_str % [scaled, threshold.get("suffix", "")])
	
	# Fallback for very large numbers (> 1T) - use scientific notation
	if abs_value >= 1_000_000_000_000.0:
		return sign_str + ("%.2e" % abs_value)
	
	# Default case (shouldn't reach here, but just in case)
	return sign_str + str(int(abs_value))

## Format a number with full precision (no abbreviation)
static func format_full(value: float, decimals: int = 2) -> String:
	if value == floorf(value):
		return str(int(value))
	else:
		var format_str := "%%.%df" % decimals
		return format_str % value

## Format a number with scientific notation above a threshold
static func format_scientific_above(value: float, threshold: float = 1e12, precision: int = 2) -> String:
	if absf(value) >= threshold:
		var format_str := "%%.%de" % precision
		return format_str % value
	else:
		return format_short(value, precision)

## Format a value as a percentage (e.g., 0.15 -> "15%")
static func format_percentage(value: float, decimals: int = 0) -> String:
	var percent := value * 100.0
	if decimals == 0 and percent == floorf(percent):
		return "%d%%" % int(percent)
	else:
		var format_str := "%%.%df%%%%" % decimals
		return format_str % percent

## Format a delta between two values as a percentage change
## Returns: "+X.Y%" or "-X.Y%" or "±0%"
static func format_delta(old_value: float, new_value: float, decimals: int = 1) -> String:
	var baseline: float = abs(old_value)
	if baseline < EPS:
		# If baseline is ~0, use |new| as a fallback to avoid INF. If still ~0, delta is 0.
		baseline = abs(new_value)
		if baseline < EPS:
			return "±0%"
	
	var delta: float = new_value - old_value
	var delta_percent: float = (delta / baseline) * 100.0
	var sign_str: String = "+" if delta_percent >= 0.0 else ""
	
	if abs(delta_percent) < 0.01:
		return "±0%"
	
	var format_str := "%s%%.%df%%%%" % [sign_str, decimals]
	return format_str % delta_percent

## Format an effect for display in UI
## Returns formatted string like "+5.0 Attack" or "+10% Idle Rate"
static func format_effect_line(effect: Dictionary) -> String:
	var effect_type: String = String(effect.get("type", ""))
	var value: float = float(effect.get("value", 0.0))
	
	match effect_type:
		Constants.EffectType.COMBAT_ATTACK_ADD:
			return "+%.0f Attack" % value
		Constants.EffectType.COMBAT_DEFENSE_ADD:
			return "+%.0f Defense" % value
		Constants.EffectType.COMBAT_ATTACK_MULT:
			return "+%s Attack" % format_percentage(value)
		Constants.EffectType.COMBAT_DEFENSE_MULT:
			return "+%s Defense" % format_percentage(value)
		Constants.EffectType.COMBAT_CRIT_CHANCE_ADD:
			return "+%s Crit Chance" % format_percentage(value)
		Constants.EffectType.COMBAT_CRIT_MULTIPLIER_ADD:
			return "+%s Crit Damage" % format_percentage(value)
		Constants.EffectType.COMBAT_SPEED_ADD:
			return "+%s Combat Speed" % format_percentage(value)
		Constants.EffectType.IDLE_RATE_ADD:
			var resource: String = String(effect.get("resource", "gold"))
			return "+%.1f %s/sec" % [value, resource.capitalize()]
		Constants.EffectType.IDLE_RATE_MULTIPLIER:
			return "+%s Idle Rate" % format_percentage(value)
		Constants.EffectType.ESSENCE_MULTIPLIER:
			return "+%s Essence Gain" % format_percentage(value)
		_:
			return "Unknown Effect"
