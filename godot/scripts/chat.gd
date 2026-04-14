# Чат — лог + поле ввода в левом нижнем углу. Enter открывает/отправляет,
# Esc закрывает.
class_name ChatPanel
extends CanvasLayer

signal send_requested(text: String)

const LOG_KEEP := 8

var log_box: VBoxContainer
var input: LineEdit

func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := VBoxContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 8
	panel.offset_top = -180
	panel.offset_right = 320
	panel.offset_bottom = -8
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_constant_override("separation", 2)
	root.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, 140)
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(scroll)
	log_box = VBoxContainer.new()
	log_box.add_theme_constant_override("separation", 2)
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(log_box)

	input = LineEdit.new()
	input.placeholder_text = "Enter — написать"
	input.max_length = 140
	input.modulate = Color(1, 1, 1, 0.55)
	panel.add_child(input)
	input.text_submitted.connect(_on_submit)
	input.focus_entered.connect(func(): input.modulate = Color(1, 1, 1, 1.0))
	input.focus_exited.connect(func(): input.modulate = Color(1, 1, 1, 0.55))

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var keycode: int = event.keycode
	if keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		if input.has_focus():
			return  # text_submitted will fire
		input.grab_focus()
		get_viewport().set_input_as_handled()
	elif keycode == KEY_ESCAPE:
		if input.has_focus():
			input.release_focus()
			input.text = ""
			get_viewport().set_input_as_handled()

func _on_submit(text: String) -> void:
	var trimmed := text.strip_edges()
	input.text = ""
	input.release_focus()
	if trimmed.is_empty():
		return
	send_requested.emit(trimmed)

func append_line(name: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var panel_bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	panel_bg.add_theme_stylebox_override("panel", sb)
	row.add_child(panel_bg)

	var h := HBoxContainer.new()
	panel_bg.add_child(h)
	var who := Label.new()
	who.text = name + ":"
	who.add_theme_color_override("font_color", Color(0.6, 0.76, 0.95, 1.0))
	h.add_child(who)
	var body := Label.new()
	body.text = " " + text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = 220
	body.add_theme_color_override("font_color", Color(0.93, 0.93, 0.93, 1.0))
	h.add_child(body)

	log_box.add_child(row)
	while log_box.get_child_count() > LOG_KEEP:
		log_box.get_child(0).queue_free()
