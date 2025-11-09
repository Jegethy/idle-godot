extends RefCounted
## UUID: Simple unique ID generator for item instances
## 
## Provides incremental IDs for tracking individual item instances in inventory.

class_name UUID

static var _next_id: int = 1

## Generate a new unique ID
static func generate() -> String:
	var id := _next_id
	_next_id += 1
	return "item_%d" % id

## Reset the counter (useful for tests)
static func reset() -> void:
	_next_id = 1
