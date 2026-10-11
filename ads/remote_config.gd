
extends Node

signal config_loaded
signal config_failed(message: String)

const TIMEOUT_SECONDS: float = 10.0

var config: Dictionary = {}
var is_loaded: bool = false
var is_loading: bool = false
var error_message: String = ""
var current_url: String = ""

var _request: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_request = HTTPRequest.new()
	_request.timeout = TIMEOUT_SECONDS
	add_child(_request)

	_request.request_completed.connect(
		_on_request_completed
	)


# ============================================================
# LOAD CONFIGURATION
# ============================================================

func load_config(url: String) -> void:
	if is_loading:
		return

	if url.strip_edges().is_empty():
		_fail("Remote configuration URL is missing")
		return

	if not url.begins_with("https://"):
		_fail("Remote configuration must use HTTPS")
		return

	current_url = url
	is_loading = true
	is_loaded = false
	error_message = ""
	config.clear()

	var error := _request.request(current_url)

	if error != OK:
		_fail("No internet connection")


# ============================================================
# REQUEST COMPLETED
# ============================================================

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("No internet connection")
		return

	if response_code != 200:
		_fail("Configuration server unavailable")
		return

	var parsed: Variant = JSON.parse_string(
		body.get_string_from_utf8()
	)

	if not parsed is Dictionary:
		_fail("Invalid game configuration")
		return

	var data: Dictionary = parsed

	if not data.has("ads") or not data["ads"] is Dictionary:
		_fail("Missing ads configuration")
		return

	config = data
	is_loading = false
	is_loaded = true
	error_message = ""

	config_loaded.emit()


# ============================================================
# FAILURE
# ============================================================

func _fail(message: String) -> void:
	is_loading = false
	is_loaded = false
	error_message = message

	push_warning("[RemoteConfig] " + message)

	config_failed.emit(message)


# ============================================================
# GET SETTINGS
# ============================================================

func get_setting(
	section: String,
	key: String,
	default_value: Variant
) -> Variant:
	if not is_loaded:
		return default_value

	var settings: Variant = config.get(section, {})

	if not settings is Dictionary:
		return default_value

	return settings.get(key, default_value)


func get_ad_setting(
	key: String,
	default_value: Variant
) -> Variant:
	return get_setting(
		"ads",
		key,
		default_value
	)
