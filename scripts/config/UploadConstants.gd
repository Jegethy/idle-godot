extends Object
## UploadConstants: Configuration constants for analytics cloud upload
## 
## Defines default values for upload batching, backoff, disk management, and HTTP transport.

class_name UploadConstants

# Upload intervals
const DEFAULT_UPLOAD_INTERVAL_SEC: int = 60  # Upload every 60 seconds

# Batch size limits
const DEFAULT_MAX_BATCH_EVENTS: int = 5000  # Maximum events per batch
const DEFAULT_MAX_BATCH_BYTES: int = 1048576  # 1 MB maximum batch size

# Disk management
const DEFAULT_DISK_CAP_BYTES: int = 52428800  # 50 MB disk cap for telemetry data

# Exponential backoff configuration
const BACKOFF_BASE_SEC: float = 1.0  # Base backoff time
const BACKOFF_FACTOR: float = 2.0  # Exponential growth factor
const BACKOFF_MAX_SEC: float = 300.0  # Maximum backoff (5 minutes)
const BACKOFF_JITTER_RATIO: float = 0.2  # ±20% jitter

# HTTP configuration
const HTTP_TIMEOUT_SEC: int = 30  # HTTP request timeout
const HTTP_MAX_REDIRECTS: int = 3  # Maximum HTTP redirects to follow

# Envelope version
const ENVELOPE_VERSION: int = 1  # Current envelope schema version

# File suffixes
const DONE_FILE_SUFFIX: String = ".done"  # Suffix for completed upload files
const CURSOR_FILE_SUFFIX: String = ".cursor"  # Suffix for cursor tracking files
const ORPHAN_FILE_SUFFIX: String = ".orphan"  # Suffix for orphaned event files
