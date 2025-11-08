extends Node
## NumberFormatter: Utility for formatting numbers in short scale notation
## 
## Provides functions to format large numbers as K, M, B, T for better readability.

class_name NumberFormatter

## Format a number with short scale notation (K, M, B, T)
## Examples: 1234 -> "1.23K", 5_670_000 -> "5.67M", 3_450_000_000 -> "3.45B"
static func format_short(value: float, precision: int = 2) -> String:
	var abs_value := absf(value)
	var sign := "-" if value < 0 else ""
	
	# Handle values less than 1000
	if abs_value < 1000.0:
		if abs_value == floorf(abs_value):
			return sign + str(int(abs_value))
		else:
			return sign + ("%.2f" % abs_value)
	
	# Define thresholds and suffixes
	var thresholds := [
		{"value": 1_000_000_000_000.0, "suffix": "T"},  # Trillion
		{"value": 1_000_000_000.0, "suffix": "B"},      # Billion
		{"value": 1_000_000.0, "suffix": "M"},          # Million
		{"value": 1_000.0, "suffix": "K"}               # Thousand
	]
	
	for threshold in thresholds:
		if abs_value >= threshold["value"]:
			var scaled := abs_value / threshold["value"]
			var format_str := "%%.%df%%s" % precision
			return sign + (format_str % [scaled, threshold["suffix"]])
	
	# Fallback for very large numbers (> 1T) - use scientific notation
	if abs_value >= 1_000_000_000_000.0:
		return sign + ("%.2e" % abs_value)
	
	# Default case (shouldn't reach here, but just in case)
	return sign + str(int(abs_value))

## Format a number with full precision (no abbreviation)
static func format_full(value: float, decimals: int = 2) -> String:
	if value == floorf(value):
		return str(int(value))
	else:
		var format_str := "%%.%df" % decimals
		return format_str % value
