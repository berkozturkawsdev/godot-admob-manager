extends Control
## Live admin gate. The manager continues consent, loading, and retries behind it.

var next_scene: String = ""
var _report: RichTextLabel
var _message: Label
var _manager: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("141b29")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Admin · AdMob diagnostics"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	_report = RichTextLabel.new()
	_report.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_report.selection_enabled = true
	_report.bbcode_enabled = false
	_report.add_theme_font_size_override("normal_font_size", 16)
	column.add_child(_report)
	_message = Label.new()
	_message.text = "Live updates · Scroll to inspect logs. Continue when ready."
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)
	var copy := Button.new()
	copy.text = "Copy diagnostics"
	copy.custom_minimum_size.y = 48
	copy.pressed.connect(func() -> void: DisplayServer.clipboard_set(_report.text))
	column.add_child(copy)
	var proceed := Button.new()
	proceed.text = "Continue to game"
	proceed.custom_minimum_size.y = 52
	proceed.pressed.connect(_continue)
	column.add_child(proceed)
	_manager = get_node_or_null("/root/AdMobManager")
	# Poll also catches readiness changes which do not emit status_changed.
	var timer := Timer.new()
	timer.wait_time = 0.5
	timer.timeout.connect(_refresh)
	add_child(timer)
	timer.start()
	_refresh()
	proceed.grab_focus()


func _refresh() -> void:
	var report := "AdMobManager autoload is missing. No SDK diagnostics available."
	if is_instance_valid(_manager):
		report = _manager.diagnostics()
		report += "\n\nRECENT SESSION LOGS (latest 300 entries)\n"
		report += "\n".join(_manager.diagnostic_logs)
	if report != _report.text:
		_report.text = report


func _continue() -> void:
	if next_scene.is_empty():
		_message.text = "Next Scene is not configured on StartupScreen."
		return
	var error := get_tree().change_scene_to_file(next_scene)
	if error != OK:
		_message.text = "Could not open %s: %s" % [next_scene, error_string(error)]
