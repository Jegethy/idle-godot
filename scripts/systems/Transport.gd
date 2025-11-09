extends RefCounted
## Transport: Interface for analytics event transport
## 
## Provides pluggable backend for sending analytics events.
## Default implementation is no-op (local storage only).

class_name Transport

## Send a batch of events
## Returns true if successful, false otherwise
func send_batch(events: Array) -> bool:
	push_error("Transport.send_batch() not implemented")
	return false

## Validate transport configuration
## Returns true if transport is properly configured
func is_configured() -> bool:
	return false

## Get transport name for logging
func get_transport_name() -> String:
	return "BaseTransport"
