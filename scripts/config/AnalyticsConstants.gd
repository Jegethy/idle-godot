extends RefCounted
## AnalyticsConstants: Default configuration for Analytics/Telemetry system
## 
## Provides default values used when analytics_settings.json is absent or incomplete.

class_name AnalyticsConstants

# Privacy & Consent
const DEFAULT_ENABLED: bool = false  # Opt-in only: OFF by default
const PROJECT_ID: String = "idle-incremental-godot"

# Sampling & Throttling
const DEFAULT_SESSION_SAMPLE_RATE: float = 1.0  # 100% sampling by default
const DEFAULT_EVENT_SAMPLE_OVERRIDES: Dictionary = {}  # Per-event-type overrides

# Throttle windows (seconds) - prevent event spam
const DEFAULT_THROTTLE: Dictionary = {
	"economy.rates_updated": 1.0,     # Max once per second
	"economy.resource_changed": 1.0,  # Max once per second
}

# Event Buffer & Storage
const RING_BUFFER_SIZE: int = 500  # In-memory events for UI
const FILE_ROTATION_DAILY: bool = true
const MAX_FILE_SIZE_MB: int = 10  # Rotate at 10MB if daily rotation disabled

# Performance
const MAX_EVENT_PROCESS_TIME_MS: float = 0.3  # Target max time per emit
const BATCH_FLUSH_SIZE: int = 100  # Flush to disk after N events

# Schema version
const SCHEMA_VERSION: int = 1

# Event Categories
enum EventCategory {
	ECONOMY,
	UPGRADE,
	PRESTIGE,
	COMBAT,
	INVENTORY,
	META,
	SESSION,
	SAVE
}

# Whitelisted string fields (non-numeric data allowed)
const WHITELISTED_STRING_FIELDS: Array[String] = [
	"id", "ids", "slot", "rarity", "event", "session_id", "version", "event_name"
]

# Data validation limits
const MAX_NUMERIC_VALUE: float = 1e15  # Clamp numbers to sane range
const MIN_NUMERIC_VALUE: float = -1e15

# File paths
const TELEMETRY_DIR: String = "user://telemetry/"
const SETTINGS_FILE: String = "user://data/analytics_settings.json"
const EVENT_FILE_PREFIX: String = "events-"
const EVENT_FILE_EXTENSION: String = ".ndjson"
