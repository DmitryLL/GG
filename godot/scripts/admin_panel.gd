# Внутриигровая админ-панель: открывается F12 если ник в ADMIN_USERNAMES.
# Кнопки: heal, give gold, give bow, killall mobs, respawn mobs, teleport.
class_name AdminPanel
extends CanvasLayer

const ADMIN_USERNAMES = ["dmitryll", "admin"]

var panel: PanelContainer
var content: VBoxContainer
var log_label: Label
var visible_now := false

func _ready() -> void:
	layer = 20  # выше всех окон
	panel = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.offset_left = -260
	panel.offset_top = 90
	panel.offset_right = -10
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.visible = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.06, 0.06, 0.92)
	sb.border_color = Color(0.85, 0.25, 0.25, 1)
	sb.border_width_left = 2; sb.border_width_top = 2
	sb.border_width_right = 2; sb.border_width_bottom = 2
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	var title := Label.new()
	title.text = "АДМИНКА (F12)"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1, 0.7, 0.7))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)

	_add_button("Полное лечение", "heal_self")
	_add_button("Лечить всех", "heal_all")
	_add_button("+1000 золота", "give_gold")
	_add_button("Выдать Золотой лук", "give_golden_bow")
	_add_button("Уровень +5", "level_up")
	_add_button("Убить всех мобов", "killall_mobs")
	_add_button("Респавн мобов", "respawn_mobs")
	_add_button("Телепорт сюда: курсор", "teleport_cursor")

	log_label = Label.new()
	log_label.text = ""
	log_label.add_theme_font_size_override("font_size", 11)
	log_label.add_theme_color_override("font_color", Color(0.7, 1, 0.7))
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.custom_minimum_size = Vector2(240, 0)
	content.add_child(log_label)

func _add_button(text: String, action: String) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 28)
	b.pressed.connect(_on_action.bind(action))
	content.add_child(b)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		if not is_admin():
			return
		visible_now = not visible_now
		panel.visible = visible_now

func is_admin() -> bool:
	var name: String = String(Session.auth.username if Session.auth else "").to_lower()
	return ADMIN_USERNAMES.has(name)

# Сигнал в game.gd — оно знает позицию курсора и текущий ник
signal action_requested(action: String)

func _on_action(action: String) -> void:
	action_requested.emit(action)

func log_result(text: String) -> void:
	log_label.text = text
