# Чат. Компактный лог снизу-слева (последние 6 сообщений) + большое окно
# истории по кнопке «↗». В окне истории — полная прокручиваемая лента.
class_name ChatPanel
extends CanvasLayer

signal send_requested(text: String)

const COMPACT_KEEP := 6
const HISTORY_MAX := 200

var history: Array = []  # [{name, text}]

# Compact (bottom-left)
var compact_panel: PanelContainer
var compact_log: VBoxContainer
var input: LineEdit

# History modal
var history_overlay: ColorRect
var history_card: PanelContainer
var history_log: VBoxContainer
var history_scroll: ScrollContainer

func _ready() -> void:
	var root := Control.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# === Compact panel ===
	compact_panel = PanelContainer.new()
	compact_panel.anchor_left = 0.0
	compact_panel.anchor_top = 1.0
	compact_panel.anchor_right = 0.0
	compact_panel.anchor_bottom = 1.0
	compact_panel.offset_left = 8
	compact_panel.offset_top = -190
	compact_panel.offset_right = 340
	compact_panel.offset_bottom = -8
	compact_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var cp_sb := StyleBoxFlat.new()
	cp_sb.bg_color = Color(0.06, 0.05, 0.04, 0.75)
	cp_sb.border_color = Color(0.40, 0.32, 0.20, 1.0)
	cp_sb.set_border_width_all(1)
	cp_sb.set_corner_radius_all(4)
	cp_sb.set_content_margin_all(6)
	compact_panel.add_theme_stylebox_override("panel", cp_sb)
	root.add_child(compact_panel)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	compact_panel.add_child(cv)

	var top_row := HBoxContainer.new()
	cv.add_child(top_row)
	var chat_label := Label.new()
	chat_label.text = "Чат"
	chat_label.add_theme_font_size_override("font_size", 11)
	chat_label.add_theme_color_override("font_color", Color(0.55, 0.50, 0.40, 1))
	chat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(chat_label)
	var expand_btn := Button.new()
	expand_btn.text = "↗"
	expand_btn.tooltip_text = "Показать всю историю"
	expand_btn.custom_minimum_size = Vector2(24, 18)
	expand_btn.add_theme_font_size_override("font_size", 11)
	expand_btn.pressed.connect(open_history)
	top_row.add_child(expand_btn)

	compact_log = VBoxContainer.new()
	compact_log.add_theme_constant_override("separation", 2)
	compact_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_child(compact_log)

	input = LineEdit.new()
	input.placeholder_text = "Enter — написать"
	input.max_length = 140
	input.modulate = Color(1, 1, 1, 0.7)
	cv.add_child(input)
	input.text_submitted.connect(_on_submit)
	input.focus_entered.connect(func(): input.modulate = Color(1, 1, 1, 1.0))
	input.focus_exited.connect(func(): input.modulate = Color(1, 1, 1, 0.7))

	# === History modal ===
	history_overlay = ColorRect.new()
	history_overlay.color = Color(0, 0, 0, 0.85)
	history_overlay.anchor_right = 1.0
	history_overlay.anchor_bottom = 1.0
	history_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(history_overlay)
	history_overlay.visible = false

	history_card = PanelContainer.new()
	history_card.anchor_left = 0.5
	history_card.anchor_top = 0.5
	history_card.anchor_right = 0.5
	history_card.anchor_bottom = 0.5
	history_card.offset_left = -300
	history_card.offset_top = -240
	history_card.offset_right = 300
	history_card.offset_bottom = 240
	var hc_sb := StyleBoxFlat.new()
	hc_sb.bg_color = Color(0.10, 0.09, 0.08, 1.0)
	hc_sb.border_color = Color(0.65, 0.50, 0.20, 1.0)
	hc_sb.set_border_width_all(2)
	hc_sb.set_corner_radius_all(8)
	hc_sb.set_content_margin_all(16)
	history_card.add_theme_stylebox_override("panel", hc_sb)
	history_overlay.add_child(history_card)

	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	hv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	history_card.add_child(hv)

	var ht := HBoxContainer.new()
	hv.add_child(ht)
	var ht_title := Label.new()
	ht_title.text = "История чата"
	ht_title.add_theme_font_size_override("font_size", 20)
	ht_title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 1))
	ht_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ht.add_child(ht_title)
	var ht_close := Button.new()
	ht_close.text = "×"
	ht_close.custom_minimum_size = Vector2(36, 32)
	ht_close.add_theme_font_size_override("font_size", 18)
	ht_close.pressed.connect(close_history)
	ht.add_child(ht_close)

	hv.add_child(HSeparator.new())

	history_scroll = ScrollContainer.new()
	history_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	history_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	history_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hv.add_child(history_scroll)
	history_log = VBoxContainer.new()
	history_log.add_theme_constant_override("separation", 4)
	history_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	history_scroll.add_child(history_log)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var keycode: int = event.keycode
	if keycode == KEY_ENTER or keycode == KEY_KP_ENTER:
		if input.has_focus():
			return
		input.grab_focus()
		get_viewport().set_input_as_handled()
	elif keycode == KEY_ESCAPE:
		if input.has_focus():
			input.release_focus()
			input.text = ""
			get_viewport().set_input_as_handled()
		elif history_overlay.visible:
			close_history()
			get_viewport().set_input_as_handled()

func _on_submit(text: String) -> void:
	var trimmed := text.strip_edges()
	input.text = ""
	input.release_focus()
	if trimmed.is_empty():
		return
	send_requested.emit(trimmed)

func append_line(name: String, text: String) -> void:
	history.append({ "name": name, "text": text })
	while history.size() > HISTORY_MAX:
		history.pop_front()

	# Compact view
	compact_log.add_child(_make_message_row(name, text, false))
	while compact_log.get_child_count() > COMPACT_KEEP:
		compact_log.get_child(0).queue_free()

	# History view (если открыт)
	if history_overlay.visible:
		history_log.add_child(_make_message_row(name, text, true))
		await get_tree().process_frame
		_scroll_history_to_bottom()

func _make_message_row(name: String, text: String, full: bool) -> Control:
	var panel_bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.0 if full else 0.55)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(4)
	panel_bg.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	panel_bg.add_child(h)
	var who := Label.new()
	who.text = name + ":"
	who.add_theme_color_override("font_color", Color(0.6, 0.76, 0.95, 1.0))
	h.add_child(who)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = (520 if full else 220)
	body.add_theme_color_override("font_color", Color(0.93, 0.93, 0.93, 1.0))
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(body)
	return panel_bg

func open_history() -> void:
	for c in history_log.get_children():
		c.queue_free()
	for entry in history:
		history_log.add_child(_make_message_row(String(entry["name"]), String(entry["text"]), true))
	history_overlay.visible = true
	await get_tree().process_frame
	_scroll_history_to_bottom()

func close_history() -> void:
	history_overlay.visible = false

func _scroll_history_to_bottom() -> void:
	var sb := history_scroll.get_v_scroll_bar()
	if sb:
		history_scroll.scroll_vertical = int(sb.max_value)
