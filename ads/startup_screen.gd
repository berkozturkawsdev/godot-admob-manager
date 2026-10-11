class_name StartupScreen
extends Control


# ============================================================
# CONFIGURATION
# ============================================================

@export_group("Startup")
@export_file("*.tscn") var next_scene: String = ""
@export var game_title: String = "My Game"

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

	if RemoteConfig.is_loaded:
		_on_config_loaded()

	elif RemoteConfig.is_loading:
		_set_status("Connecting...")

	elif not RemoteConfig.error_message.is_empty():
		_on_config_failed(RemoteConfig.error_message)

	else:
		_on_retry_pressed()


# ============================================================
# CREATE UI
# ============================================================

func _create_ui() -> void:
	# Background
	var background := ColorRect.new()
	background.name = "Background"
	background.color = background_color
	background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Center content
	var center := CenterContainer.new()
	center.name = "CenterContainer"
	add_child(center)
	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	# Vertical layout
	var content := VBoxContainer.new()
	content.name = "Content"
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override(
		"separation",
		24
	)
	center.add_child(content)

	# Game title
	_title_label = Label.new()
	_title_label.name = "TitleLabel"
	_title_label.text = game_title
	_title_label.horizontal_alignment = \
		HORIZONTAL_ALIGNMENT_CENTER

	_title_label.add_theme_color_override(
		"font_color",
		text_color
	)

	_title_label.add_theme_font_size_override(
		"font_size",
		32
	)

	content.add_child(_title_label)

	# Status
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = "Connecting..."
	_status_label.horizontal_alignment = \
		HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = \
		TextServer.AUTOWRAP_WORD_SMART

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

	# Retry button
	_retry_button = Button.new()
	_retry_button.name = "RetryButton"
	_retry_button.text = "Retry"
	_retry_button.custom_minimum_size = Vector2(180, 52)

	_retry_button.add_theme_color_override(
		"font_color",
		background_color
	)

	_retry_button.add_theme_color_override(
		"font_hover_color",
		background_color
	)

	_retry_button.add_theme_color_override(
		"font_pressed_color",
		background_color
	)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = accent_color
	normal_style.set_corner_radius_all(12)

	var hover_style := normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = accent_color.lightened(0.15)

	var pressed_style := normal_style.duplicate() as StyleBoxFlat
	pressed_style.bg_color = accent_color.darkened(0.15)

	_retry_button.add_theme_stylebox_override(
		"normal",
		normal_style
	)

	_retry_button.add_theme_stylebox_override(
		"hover",
		hover_style
	)

	_retry_button.add_theme_stylebox_override(
		"pressed",
		pressed_style
	)

	content.add_child(_retry_button)

	_retry_button.hide()

	_retry_button.pressed.connect(
		_on_retry_pressed
	)


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
		_started = false
		_on_config_failed(
			"Next scene is not configured"
		)
		return

	var error := ResourceLoader.load_threaded_request(
		next_scene
	)

	if error != OK:
		_started = false
		_on_config_failed(
			"Could not load game scene"
		)
		return

	_wait_for_game_scene()


# ============================================================
# WAIT FOR SCENE
# ============================================================

func _wait_for_game_scene() -> void:
	while is_inside_tree():
		var status := ResourceLoader.load_threaded_get_status(
			next_scene
		)

		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene := ResourceLoader.load_threaded_get(
				next_scene
			) as PackedScene

			if scene == null:
				_started = false
				_on_config_failed(
					"Invalid game scene"
				)
				return

			get_tree().change_scene_to_packed(scene)
			return

		if status == ResourceLoader.THREAD_LOAD_FAILED \
		or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_started = false
			_on_config_failed(
				"Failed to load game"
			)
			return

		await get_tree().process_frame


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
	if RemoteConfig.is_loading:
		return

	_retry_button.hide()
	_set_status("Connecting...")

	RemoteConfig.load_config()


# ============================================================
# STATUS
# ============================================================

func _set_status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message