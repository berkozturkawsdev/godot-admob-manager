
class_name StartupScreen
extends Control


# ============================================================
# CONFIGURATION
# ============================================================

@export_group("Startup")
@export var game_title: String = "My Game"
@export_file("*.tscn") var next_scene: String = ""

@export_group("Remote Configuration")
@export var remote_config_url: String = ""

@export_group("Appearance")
@export var background_color: Color = Color("#100b2a")
@export var text_color: Color = Color("#ffffff")
@export var accent_color: Color = Color("#ffb379")


# ============================================================
# UI
# ============================================================

var _title_label: Label
var _status_label: Label
var _retry_button: Button

var _started: bool = false


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	_create_ui()

	RemoteConfig.config_loaded.connect(
		_on_config_loaded
	)

	RemoteConfig.config_failed.connect(
		_on_config_failed
	)

	_start_loading()


# ============================================================
# CREATE UI
# ============================================================

func _create_ui() -> void:
	var background := ColorRect.new()
	background.color = background_color
	add_child(background)

	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	add_child(center)

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	var content := VBoxContainer.new()
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override(
		"separation",
		24
	)
	center.add_child(content)

	_title_label = Label.new()
	_title_label.text = game_title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override(
		"font_color",
		text_color
	)
	_title_label.add_theme_font_size_override(
		"font_size",
		32
	)
	content.add_child(_title_label)

	_status_label = Label.new()
	_status_label.text = "Connecting..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(260, 0)
	_status_label.add_theme_color_override(
		"font_color",
		text_color
	)
	_status_label.add_theme_font_size_override(
		"font_size",
		17
	)
	content.add_child(_status_label)

	_retry_button = Button.new()
	_retry_button.text = "Retry"
	_retry_button.custom_minimum_size = Vector2(180, 52)

	_retry_button.add_theme_color_override(
		"font_color",
		background_color
	)

	var style := StyleBoxFlat.new()
	style.bg_color = accent_color
	style.set_corner_radius_all(12)

	_retry_button.add_theme_stylebox_override(
		"normal",
		style
	)

	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = accent_color.lightened(0.15)

	_retry_button.add_theme_stylebox_override(
		"hover",
		hover_style
	)

	content.add_child(_retry_button)

	_retry_button.hide()

	_retry_button.pressed.connect(
		_on_retry_pressed
	)


# ============================================================
# START
# ============================================================

func _start_loading() -> void:
	if RemoteConfig.is_loading:
		_set_status("Connecting...")
		return

	if (
		RemoteConfig.is_loaded
		and RemoteConfig.current_url == remote_config_url
	):
		_on_config_loaded()
		return

	_retry_button.hide()
	_set_status("Connecting...")

	RemoteConfig.load_config(remote_config_url)


# ============================================================
# CONFIG LOADED
# ============================================================

func _on_config_loaded() -> void:
	if _started:
		return

	_started = true

	_set_status("Starting game...")
	_retry_button.hide()

	if next_scene.is_empty():
		_on_config_failed("Next scene is not configured")
		return

	get_tree().change_scene_to_file.call_deferred(
		next_scene
	)


# ============================================================
# CONFIG FAILED
# ============================================================

func _on_config_failed(message: String) -> void:
	_started = false

	_set_status(message)
	_retry_button.show()


# ============================================================
# RETRY
# ============================================================

func _on_retry_pressed() -> void:
	_start_loading()


# ============================================================
# STATUS
# ============================================================

func _set_status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message
