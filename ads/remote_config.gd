extends Node

signal config_loaded
signal config_failed(message: String)

const CONFIG_URL: String = "https://bozapps.com/config/spin-frenzy.json"
const TIMEOUT_SECONDS: float = 10.0

var config: Dictionary = {}
var is_loaded: bool = false
var is_loading: bool = false
var error_message: String = ""

var _request: HTTPRequest


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_config()


func load_config() -> void:
	if is_loading:
		return

	is_loading = true
	is_loaded = false
	error_message = ""

	if _request == null:
		_request = HTTPRequest.new()
		_request.timeout = TIMEOUT_SECONDS
		add_child(_request)
		_request.request_completed.connect(_on_request_completed)

	var error: Error = _request.request(CONFIG_URL)

	if error != OK:
		_fail("No internet connection")


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

	if not parsed.has("ads"):
		_fail("Missing game configuration")
		return

	config = parsed
	is_loading = false
	is_loaded = true
	error_message = ""

	config_loaded.emit()


func _fail(message: String) -> void:
	is_loading = false
	is_loaded = false
	error_message = message

	push_warning("[RemoteConfig] " + message)
	config_failed.emit(message)


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
	return get_setting("ads", key, default_value)