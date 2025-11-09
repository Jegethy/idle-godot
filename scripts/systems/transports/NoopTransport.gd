extends Transport
## NoopTransport: Default no-op transport implementation
## 
## Does nothing - analytics data stays local only.
## This is the privacy-preserving default.

class_name NoopTransport

## Send a batch of events (no-op)
func send_batch(events: Array) -> bool:
	# Do nothing - local storage only
	return true

## Always returns false - no remote configuration
func is_configured() -> bool:
	return false

## Get transport name
func get_transport_name() -> String:
	return "NoopTransport"
