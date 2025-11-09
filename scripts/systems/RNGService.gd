extends Node
## RNGService: Deterministic random number generation for combat
## 
## Provides seeded RNG for reproducible combat simulations.
## Uses Godot's RandomNumberGenerator with explicit seed control.

class_name RNGServiceClass

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var current_seed: int = 0

func _ready() -> void:
	# Initialize with a default seed based on system time
	var default_seed := Time.get_ticks_msec()
	set_seed(default_seed)
	print("RNGService initialized with seed: %d" % current_seed)

## Set the seed for deterministic random generation
func set_seed(seed: int) -> void:
	current_seed = seed
	rng.seed = seed

## Get current seed value
func get_seed() -> int:
	return current_seed

## Generate a random float between 0.0 and 1.0
func randf() -> float:
	return rng.randf()

## Generate a random integer in range [min_val, max_val]
func rand_range(min_val: int, max_val: int) -> int:
	return rng.randi_range(min_val, max_val)

## Generate a random float in range [min_val, max_val]
func randf_range(min_val: float, max_val: float) -> float:
	return rng.randf_range(min_val, max_val)

## Check if a random event with probability p occurs
func chance(p: float) -> bool:
	return rng.randf() < p

## Generate a random integer with weighted probabilities
## weights: Array of floats representing relative weights
## Returns: Index of selected item
func weighted_random(weights: Array) -> int:
	var total_weight := 0.0
	for w in weights:
		total_weight += float(w)
	
	if total_weight <= 0.0:
		return 0
	
	var rand_val := rng.randf() * total_weight
	var cumulative := 0.0
	
	for i in range(weights.size()):
		cumulative += float(weights[i])
		if rand_val < cumulative:
			return i
	
	return weights.size() - 1
