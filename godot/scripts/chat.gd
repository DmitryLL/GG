# Чат. Компактный лог снизу-слева (последние 6 сообщений) + большое окно
# истории по кнопке «↗». В окне истории — полная прокручиваемая лента.
class_name ChatPanel
extends CanvasLayer

signal send_requested(text: String, channel: String)

const COMPACT_KEEP := 7     # сколько сообщений показываем в компактном логе
const HISTORY_MAX := 200    # сколько хранится в локальной истории для модала

# Каналы: global — всем в матче; faction — только своей фракции;
# party — только группе. Сервер фильтрует получателей по ch.
const CHANNELS := ["global", "faction", "party"]
const CHANNEL_LABEL := {
	"global":  { "short": "Гл",  "full": "Общий",   "color": Color(0.97, 0.97, 0.97) },
	"faction": { "short": "Фр",  "full": "Фракция", "color": Color(0.60, 0.85, 1.0) },
	"party":   { "short": "Гр",  "full": "Группа",  "color": Color(0.70, 0.95, 0.60) },
}
var current_channel: String = "global"

var history: Array = []  # [{name, text, channel}]

# Compact (bottom-left)
var compact_panel: Control
var compact_log: VBoxContainer
var input: LineEdit
var channel_btn: Button

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

	# === Compact panel — полностью прозрачный, без фона и без скролла ===
	compact_panel = Control.new()
	compact_panel.anchor_left = 0.0
	compact_panel.anchor_top = 1.0
	compact_panel.anchor_right = 0.0
	compact_panel.anchor_bottom = 1.0
	compact_panel.offset_left = 8
	compact_panel.offset_top = -200
	compact_panel.offset_right = 360
	compact_panel.offset_bottom = -8
	compact_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(compact_panel)

	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 4)
	cv.anchor_right = 1.0
	cv.anchor_bottom = 1.0
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compact_panel.add_child(cv)

	# Лог сообщений — просто VBox. Новые снизу, старые уезжают (удаляются).
	compact_log = VBoxContainer.new()
	compact_log.add_theme_constant_override("separation", 2)
	compact_log.alignment = BoxContainer.ALIGNMENT_END
	compact_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compact_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	compact_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(compact_log)

	# Нижняя строка: селектор канала + поле ввода + кнопка «История».
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 4)
	cv.add_child(bottom_row)

	channel_btn = Button.new()
	channel_btn.custom_minimum_size = Vector2(48, 24)
	channel_btn.focus_mode = Control.FOCUS_NONE
	channel_btn.add_theme_font_size_override("font_size", 11)
	channel_btn.tooltip_text = "Клик: сменить канал (Общий / Фракция / Группа)"
	channel_btn.pressed.connect(_cycle_channel)
	bottom_row.add_child(channel_btn)
	_refresh_channel_btn()

	input = LineEdit.new()
	input.placeholder_text = "Enter — написать"
	input.max_length = 140
	input.modulate = Color(1, 1, 1, 0.85)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(input)
	input.text_submitted.connect(_on_submit)
	input.focus_entered.connect(func(): input.modulate = Color(1, 1, 1, 1.0))
	input.focus_exited.connect(func(): input.modulate = Color(1, 1, 1, 0.85))

	var expand_btn := Button.new()
	expand_btn.text = "История"
	expand_btn.tooltip_text = "Показать всю историю чата"
	expand_btn.custom_minimum_size = Vector2(72, 24)
	expand_btn.add_theme_font_size_override("font_size", 11)
	expand_btn.pressed.connect(open_history)
	bottom_row.add_child(expand_btn)

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
	send_requested.emit(trimmed, current_channel)

func _cycle_channel() -> void:
	var idx := CHANNELS.find(current_channel)
	idx = (idx + 1) % CHANNELS.size()
	current_channel = CHANNELS[idx]
	_refresh_channel_btn()

func _refresh_channel_btn() -> void:
	if channel_btn == null:
		return
	var meta: Dictionary = CHANNEL_LABEL.get(current_channel, CHANNEL_LABEL["global"])
	channel_btn.text = String(meta.get("short", "Гл"))
	channel_btn.add_theme_color_override("font_color", meta.get("color", Color.WHITE))

func append_line(name: String, text: String, channel: String = "global") -> void:
	history.append({ "name": name, "text": text, "channel": channel })
	while history.size() > HISTORY_MAX:
		history.pop_front()

	# Compact view: новые снизу, старше 7-го удаляется.
	compact_log.add_child(_make_message_row(name, text, channel, false))
	while compact_log.get_child_count() > COMPACT_KEEP:
		compact_log.get_child(0).queue_free()

	# History view (если открыт)
	if history_overlay.visible:
		history_log.add_child(_make_message_row(name, text, channel, true))
		await get_tree().process_frame
		_scroll_history_to_bottom()

func _make_message_row(name: String, text: String, channel: String, full: bool) -> Control:
	# Чат прозрачный — текст с чёрной обводкой чтобы читался на любом фоне.
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)

	var meta: Dictionary = CHANNEL_LABEL.get(channel, CHANNEL_LABEL["global"])
	var col_chan: Color = meta.get("color", Color.WHITE)
	var tag := Label.new()
	tag.text = "[%s]" % String(meta.get("short", "Гл"))
	tag.add_theme_color_override("font_color", col_chan)
	tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	tag.add_theme_constant_override("outline_size", 3)
	h.add_child(tag)

	var who := Label.new()
	who.text = name + ":"
	who.add_theme_color_override("font_color", Color(0.55, 0.78, 0.98, 1.0))
	who.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	who.add_theme_constant_override("outline_size", 3)
	h.add_child(who)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size.x = (520 if full else 280)
	# Тинтим тело под канал — чтобы в истории «гр» был зеленоватым, «фр» синим.
	var body_col: Color = Color(0.97, 0.97, 0.97)
	if channel != "global":
		body_col = col_chan.lerp(Color.WHITE, 0.4)
	body.add_theme_color_override("font_color", body_col)
	body.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	body.add_theme_constant_override("outline_size", 3)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(body)
	return h

func open_history() -> void:
	for c in history_log.get_children():
		c.queue_free()
	for entry in history:
		history_log.add_child(_make_message_row(String(entry["name"]), String(entry["text"]), String(entry.get("channel", "global")), true))
	history_overlay.visible = true
	await get_tree().process_frame
	_scroll_history_to_bottom()

func close_history() -> void:
	history_overlay.visible = false

func _scroll_history_to_bottom() -> void:
	var sb := history_scroll.get_v_scroll_bar()
	if sb:
		history_scroll.scroll_vertical = int(sb.max_value)
