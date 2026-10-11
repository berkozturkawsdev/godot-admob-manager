@tool
class_name StartupScreen
extends Control
## Reusable startup branding. Empty overrides use the project's name and icon.

@export_group("Startup")
## Leave empty to use application/config/name.
@export var game_title: String = ""
@export_file("*.tscn") var next_scene: String = ""

@export_group("Branding")
## Full game logo (ideally transparent). Falls back to the project icon.
@export var game_logo: Texture2D
## Disable for a logo that already contains the game's name.
@export var show_game_title: bool = true
@export var title_font: Font

@export_group("Remote Configuration")
@export var remote_config_url: String = ""

@export_group("Appearance")
@export var background_color: Color = Color("#ffc568")
@export var text_color: Color = Color("#fffaf0")
@export var accent_color: Color = Color("#00dbef")
@export var outline_color: Color = Color("#54234f")

var _content: VBoxContainer
var _logo: TextureRect
var _title_label: Label
var _status_label: Label
var _retry_button: Button
var _bar: ColorRect
var _bar_material: ShaderMaterial
var _progress_tween: Tween
var _remote_config: Node
var _started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_create_ui()
	resized.connect(_update_layout)
	_update_layout()
	if Engine.is_editor_hint():
		_set_progress(0.32)
		return
	_remote_config = get_node_or_null("/root/RemoteConfig")
	if _remote_config == null:
		_on_config_failed("Add the RemoteConfig autoload to start the game.")
		return
	_remote_config.config_loaded.connect(_on_config_loaded)
	_remote_config.config_failed.connect(_on_config_failed)
	_start_loading()


func _resolve_logo() -> Texture2D:
	if game_logo != null:
		return game_logo
	var icon_path := str(ProjectSettings.get_setting("application/config/icon", ""))
	if icon_path.begins_with("res://") and ResourceLoader.exists(icon_path):
		return load(icon_path) as Texture2D
	return null


func _create_ui() -> void:
	var background := ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := Shader.new()
	backdrop.code = """
shader_type canvas_item;
uniform vec4 sand : source_color;
void fragment() {
	vec2 uv = UV;
	float glow = 1.0 - smoothstep(0.0, 0.8, distance(uv, vec2(0.5, 0.43)));
	float wave = uv.y * 15.0 + sin(uv.x * 4.5 + uv.y * 8.0) * 0.22;
	float grain = fract(sin(dot(uv, vec2(127.1, 311.7))) * 43758.5453);
	float lines = 1.0 - smoothstep(0.015, 0.045, abs(fract(wave) - 0.5));
	vec3 col = sand.rgb * (0.94 + glow * 0.08 - lines * 0.035 + grain * 0.012);
	COLOR = vec4(col, 1.0);
}
"""
	var background_material := ShaderMaterial.new()
	background_material.shader = backdrop
	background_material.set_shader_parameter("sand", background_color)
	background.material = background_material

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content = VBoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_theme_constant_override("separation", 20)
	center.add_child(_content)

	_logo = TextureRect.new()
	_logo.texture = _resolve_logo()
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.visible = _logo.texture != null
	_content.add_child(_logo)

	_title_label = Label.new()
	_title_label.text = game_title.strip_edges()
	if _title_label.text.is_empty():
		_title_label.text = str(ProjectSettings.get_setting("application/config/name", ""))
	if _title_label.text.is_empty():
		_title_label.text = "My Game"
	_title_label.visible = show_game_title or _logo.texture == null
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title_label.add_theme_color_override("font_color", text_color)
	_title_label.add_theme_color_override("font_outline_color", outline_color)
	_title_label.add_theme_constant_override("outline_size", 12)
	_title_label.add_theme_color_override("font_shadow_color", outline_color.darkened(0.3))
	_title_label.add_theme_constant_override("shadow_offset_y", 6)
	if title_font != null:
		_title_label.add_theme_font_override("font", title_font)
	_content.add_child(_title_label)

	_bar = ColorRect.new()
	_bar.custom_minimum_size.y = 40
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar_shader := Shader.new()
	bar_shader.code = """
shader_type canvas_item;
uniform float progress = 0.0;
uniform float aspect = 10.0;
uniform vec4 accent : source_color;
uniform vec4 track : source_color;
uniform vec4 rim : source_color;
void fragment() {
	vec2 p = vec2((UV.x - 0.5) * aspect, UV.y - 0.5);
	float d = length(vec2(max(abs(p.x) - (aspect * 0.5 - 0.5), 0.0), p.y));
	float aa = fwidth(d);
	float outer = 1.0 - smoothstep(0.49 - aa, 0.49, d);
	float inner = 1.0 - smoothstep(0.40 - aa, 0.40, d);
	vec3 fill = mix(accent.rgb * 0.68, accent.rgb, 1.0 - UV.y);
	fill += vec3(0.19) * (1.0 - smoothstep(0.13, 0.48, UV.y));
	vec3 base = track.rgb * (0.85 + 0.2 * (1.0 - UV.y));
	vec3 col = mix(base, fill, step(UV.x, progress));
	col += vec3(0.12) * (1.0 - smoothstep(0.08, 0.14, abs(UV.y - 0.23)));
	COLOR = vec4(mix(rim.rgb, col, inner), outer);
}
"""
	_bar_material = ShaderMaterial.new()
	_bar_material.shader = bar_shader
	_bar_material.set_shader_parameter("accent", accent_color)
	_bar_material.set_shader_parameter("track", outline_color)
	_bar_material.set_shader_parameter("rim", text_color)
	_bar.material = _bar_material
	_content.add_child(_bar)
	_bar.resized.connect(func() -> void:
		_bar_material.set_shader_parameter("aspect", _bar.size.x / maxf(_bar.size.y, 1.0)))

	_status_label = Label.new()
	_status_label.text = "Loading..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_color_override("font_color", outline_color)
	_status_label.add_theme_font_size_override("font_size", 17)
	_content.add_child(_status_label)

	# Reserve retry space so failure never moves the logo or bar.
	var retry_slot := CenterContainer.new()
	retry_slot.custom_minimum_size.y = 52
	_content.add_child(retry_slot)
	_retry_button = Button.new()
	_retry_button.text = "Try again"
	_retry_button.custom_minimum_size = Vector2(180, 52)
	_retry_button.add_theme_color_override("font_color", outline_color)
	_retry_button.add_theme_color_override("font_hover_color", outline_color)
	_retry_button.add_theme_color_override("font_pressed_color", outline_color)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = accent_color.lightened(0.2) if state == "hover" else accent_color
		if state == "pressed":
			style.bg_color = accent_color.darkened(0.12)
		style.border_color = outline_color if state == "focus" else text_color
		style.set_border_width_all(3)
		style.set_corner_radius_all(22)
		_retry_button.add_theme_stylebox_override(state, style)
	retry_slot.add_child(_retry_button)
	_retry_button.hide()
	_retry_button.pressed.connect(_start_loading)


func _update_layout() -> void:
	if not is_instance_valid(_content):
		return
	var content_width := clampf(size.x * 0.72, 180.0, 480.0)
	content_width = minf(content_width, maxf(size.x - 40.0, 1.0))
	_content.custom_minimum_size.x = content_width
	_logo.custom_minimum_size.y = minf(content_width * 0.65, size.y * 0.28)
	_title_label.add_theme_font_size_override("font_size", int(clampf(content_width * 0.12, 24.0, 58.0)))
	_content.add_theme_constant_override("separation", int(clampf(size.y * 0.018, 8.0, 22.0)))
	_bar.custom_minimum_size.y = clampf(content_width * 0.105, 26.0, 44.0)


func _set_progress(value: float) -> void:
	_bar_material.set_shader_parameter("progress", value)


func _stop_progress() -> void:
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()


func _start_loading() -> void:
	if _remote_config == null or _started:
		return
	_retry_button.hide()
	_set_status("Connecting...")
	_stop_progress()
	_set_progress(0.06)
	# Activity estimate, not download percentage. Never completes before success.
	_progress_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_progress_tween.tween_method(_set_progress, 0.06, 0.88, 10.0)
	if _remote_config.is_loading:
		return
	if _remote_config.is_loaded and _remote_config.current_url == remote_config_url:
		_on_config_loaded()
		return
	_remote_config.load_config(remote_config_url)


func _on_config_loaded() -> void:
	if _started:
		return
	# Another caller may have been loading a different configuration.
	if _remote_config.current_url != remote_config_url:
		_start_loading()
		return
	if next_scene.is_empty():
		_on_config_failed("Next scene is not configured")
		return
	_started = true
	_set_status("Starting game...")
	_retry_button.hide()
	_stop_progress()
	var current: float = _bar_material.get_shader_parameter("progress")
	_progress_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_progress_tween.tween_method(_set_progress, current, 1.0, 0.25)
	_progress_tween.tween_callback(_open_game)


func _open_game() -> void:
	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		_on_config_failed("Could not open the game scene. Check Next Scene.")


func _on_config_failed(message: String) -> void:
	_started = false
	_stop_progress()
	_set_status(message)
	_retry_button.visible = _remote_config != null
	if _retry_button.visible:
		_retry_button.grab_focus()


func _set_status(message: String) -> void:
	if is_instance_valid(_status_label):
		_status_label.text = message
