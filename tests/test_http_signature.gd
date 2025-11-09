## Test HTTP Signature: Verify HMAC-SHA256 signing for envelopes
## 
## Tests that the HttpTransport produces deterministic HMAC signatures.

extends SceneTree

func _init() -> void:
	print("=== Running HTTP Signature Tests ===\n")
	
	var all_passed := true
	
	# Test 1: Deterministic signature for known envelope
	print("Test 1: Deterministic HMAC-SHA256 signature")
	var passed := test_deterministic_signature()
	print("Result: %s\n" % ("PASS" if passed else "FAIL"))
	all_passed = all_passed and passed
	
	# Test 2: Different secrets produce different signatures
	print("Test 2: Different secrets produce different signatures")
	passed = test_different_secrets()
	print("Result: %s\n" % ("PASS" if passed else "FAIL"))
	all_passed = all_passed and passed
	
	# Test 3: Envelope modification changes signature
	print("Test 3: Envelope modification changes signature")
	passed = test_envelope_modification()
	print("Result: %s\n" % ("PASS" if passed else "FAIL"))
	all_passed = all_passed and passed
	
	# Summary
	print("=== Summary ===")
	if all_passed:
		print("✓ All HTTP signature tests passed!")
		quit(0)
	else:
		print("✗ Some HTTP signature tests failed")
		quit(1)

func test_deterministic_signature() -> bool:
	var transport := HttpTransport.new("https://example.com/api", "test-key", "test-secret")
	
	# Create a known envelope
	var envelope := {
		"project_id": "test-project",
		"session_id": "test-session",
		"sent_at": 1234567890,
		"ver": 1,
		"events": [
			{"event": "test.event", "data": {"value": 42}}
		]
	}
	
	# Sign it twice
	var signed1 := transport._sign_envelope(envelope)
	var signed2 := transport._sign_envelope(envelope)
	
	# Signatures should be identical
	if signed1["signature"] != signed2["signature"]:
		push_error("Signatures are not deterministic")
		return false
	
	# Signature should be base64 encoded (length divisible by 4, uses valid chars)
	var sig: String = signed1["signature"]
	if sig.is_empty():
		push_error("Signature is empty")
		return false
	
	# Base64 uses A-Z, a-z, 0-9, +, /, and = for padding
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9+/]+=*$")
	if not regex.search(sig):
		push_error("Signature is not valid base64")
		return false
	
	print("  Signature: %s" % sig)
	return true

func test_different_secrets() -> bool:
	var envelope := {
		"project_id": "test-project",
		"session_id": "test-session",
		"sent_at": 1234567890,
		"ver": 1,
		"events": []
	}
	
	var transport1 := HttpTransport.new("https://example.com", "key", "secret1")
	var transport2 := HttpTransport.new("https://example.com", "key", "secret2")
	
	var signed1 := transport1._sign_envelope(envelope)
	var signed2 := transport2._sign_envelope(envelope)
	
	if signed1["signature"] == signed2["signature"]:
		push_error("Different secrets produced same signature")
		return false
	
	print("  Secret1 signature: %s" % signed1["signature"])
	print("  Secret2 signature: %s" % signed2["signature"])
	return true

func test_envelope_modification() -> bool:
	var transport := HttpTransport.new("https://example.com", "key", "secret")
	
	var envelope1 := {
		"project_id": "test-project",
		"session_id": "test-session",
		"sent_at": 1234567890,
		"ver": 1,
		"events": []
	}
	
	var envelope2 := envelope1.duplicate(true)
	envelope2["sent_at"] = 9876543210  # Change timestamp
	
	var signed1 := transport._sign_envelope(envelope1)
	var signed2 := transport._sign_envelope(envelope2)
	
	if signed1["signature"] == signed2["signature"]:
		push_error("Modified envelope produced same signature")
		return false
	
	print("  Original signature: %s" % signed1["signature"])
	print("  Modified signature: %s" % signed2["signature"])
	return true
