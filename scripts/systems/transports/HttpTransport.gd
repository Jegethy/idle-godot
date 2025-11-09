extends RefCounted
## HttpTransport: HTTP-based analytics batch upload with HMAC signing
## 
## Sends batched analytics events to a remote endpoint with cryptographic signing
## for integrity verification. Handles compression, retries, and backoff.

class_name HttpTransport

# HTTP client for making requests
var http_client: HTTPClient = null
var endpoint_url: String = ""
var api_key: String = ""
var api_secret: String = ""

func _init(url: String = "", key: String = "", secret: String = "") -> void:
	endpoint_url = url
	api_key = key
	api_secret = secret
	http_client = HTTPClient.new()

## Send a batch of events to the cloud endpoint
## Returns true if successful (2xx response), false on failure (4xx/5xx) or network error
func send_batch(envelope: Dictionary) -> bool:
	if endpoint_url.is_empty():
		push_warning("HttpTransport: No endpoint URL configured")
		return false
	
	# Add signature to envelope
	var signed_envelope := _sign_envelope(envelope)
	
	# Serialize to JSON
	var json_body := JSON.stringify(signed_envelope)
	var body_bytes := json_body.to_utf8_buffer()
	
	# Check if compression would be beneficial (>16KB)
	var use_compression := body_bytes.size() > 16384
	var final_body := body_bytes
	var content_encoding := ""
	
	if use_compression:
		# Note: Godot doesn't have built-in gzip compression in GDScript
		# For now, we'll skip compression but leave the structure for future implementation
		# In production, you might use a GDExtension or send uncompressed
		content_encoding = ""  # Would be "gzip" if compressed
	
	# Parse URL
	var url_parts := _parse_url(endpoint_url)
	if url_parts.is_empty():
		push_error("HttpTransport: Invalid endpoint URL: %s" % endpoint_url)
		return false
	
	# Make HTTP request
	var success := _make_http_request(url_parts, final_body, content_encoding)
	
	return success

## Sign the envelope with HMAC-SHA256
func _sign_envelope(envelope: Dictionary) -> Dictionary:
	# Create a copy without signature field
	var envelope_copy := envelope.duplicate(true)
	envelope_copy.erase("signature")
	
	# Create canonical JSON (sorted keys for consistency)
	var canonical_json := _canonical_json(envelope_copy)
	
	# Compute HMAC-SHA256
	var signature := _hmac_sha256(api_secret, canonical_json)
	
	# Add signature to envelope
	var signed_envelope := envelope.duplicate(true)
	signed_envelope["signature"] = signature
	
	return signed_envelope

## Create canonical JSON representation with sorted keys
func _canonical_json(data: Dictionary) -> String:
	# Sort keys alphabetically for deterministic output
	var sorted_keys := data.keys()
	sorted_keys.sort()
	
	var result := "{"
	var first := true
	
	for key in sorted_keys:
		if not first:
			result += ","
		first = false
		
		result += JSON.stringify(key) + ":"
		result += _value_to_canonical_json(data[key])
	
	result += "}"
	return result

## Convert a value to canonical JSON representation
func _value_to_canonical_json(value: Variant) -> String:
	if value is Dictionary:
		return _canonical_json(value)
	elif value is Array:
		var result := "["
		var first := true
		for item in value:
			if not first:
				result += ","
			first = false
			result += _value_to_canonical_json(item)
		result += "]"
		return result
	else:
		return JSON.stringify(value)

## Compute HMAC-SHA256 signature
func _hmac_sha256(key: String, message: String) -> String:
	var crypto := Crypto.new()
	var key_bytes := key.to_utf8_buffer()
	var message_bytes := message.to_utf8_buffer()
	
	# Use HMAC-SHA256
	var hmac := crypto.hmac_digest(HashingContext.HASH_SHA256, key_bytes, message_bytes)
	
	# Encode as base64
	return Marshalls.raw_to_base64(hmac)

## Parse URL into components
func _parse_url(url: String) -> Dictionary:
	# Simple URL parsing (scheme://host:port/path)
	var regex := RegEx.new()
	regex.compile("^(https?)://([^:/]+)(:(\\d+))?(/.*)?$")
	var result := regex.search(url)
	
	if not result:
		return {}
	
	var scheme := result.get_string(1)
	var host := result.get_string(2)
	var port_str := result.get_string(4)
	var path := result.get_string(5)
	
	var port := 443 if scheme == "https" else 80
	if not port_str.is_empty():
		port = int(port_str)
	
	if path.is_empty():
		path = "/"
	
	return {
		"scheme": scheme,
		"host": host,
		"port": port,
		"path": path,
		"use_tls": scheme == "https"
	}

## Make HTTP request (synchronous for simplicity)
func _make_http_request(url_parts: Dictionary, body: PackedByteArray, content_encoding: String) -> bool:
	var client := HTTPClient.new()
	
	# Connect to host
	var err := client.connect_to_host(url_parts["host"], url_parts["port"], TLSOptions.client() if url_parts["use_tls"] else null)
	if err != OK:
		push_error("HttpTransport: Failed to connect to %s:%d (error %d)" % [url_parts["host"], url_parts["port"], err])
		return false
	
	# Wait for connection
	var timeout_ms := UploadConstants.HTTP_TIMEOUT_SEC * 1000
	var elapsed_ms := 0
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		OS.delay_msec(10)
		elapsed_ms += 10
		if elapsed_ms >= timeout_ms:
			push_error("HttpTransport: Connection timeout")
			return false
		client.poll()
	
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		push_error("HttpTransport: Failed to connect (status: %d)" % client.get_status())
		return false
	
	# Build headers
	var headers := [
		"Content-Type: application/json",
		"User-Agent: idle-godot-analytics/1.0",
		"X-API-Key: %s" % api_key
	]
	
	if not content_encoding.is_empty():
		headers.append("Content-Encoding: %s" % content_encoding)
	
	# Send request
	err = client.request(HTTPClient.METHOD_POST, url_parts["path"], headers, body.get_string_from_utf8())
	if err != OK:
		push_error("HttpTransport: Failed to send request (error %d)" % err)
		return false
	
	# Wait for response
	elapsed_ms = 0
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		OS.delay_msec(10)
		elapsed_ms += 10
		if elapsed_ms >= timeout_ms:
			push_error("HttpTransport: Request timeout")
			return false
		client.poll()
	
	if client.get_status() != HTTPClient.STATUS_BODY and client.get_status() != HTTPClient.STATUS_CONNECTED:
		push_error("HttpTransport: Request failed (status: %d)" % client.get_status())
		return false
	
	# Check response code
	var response_code := client.get_response_code()
	
	# Read response body (optional, for debugging)
	if client.has_response():
		var response_body := client.read_response_body_chunk()
		# Optional: log response for debugging
		# print("HttpTransport: Response: %s" % response_body.get_string_from_utf8())
	
	# Success: 2xx response codes
	if response_code >= 200 and response_code < 300:
		return true
	
	# Retry on 429 (rate limit) or 5xx (server error)
	if response_code == 429 or response_code >= 500:
		push_warning("HttpTransport: Server error or rate limit (code %d)" % response_code)
		return false
	
	# Client error (4xx): don't retry
	push_error("HttpTransport: Client error (code %d)" % response_code)
	return false
