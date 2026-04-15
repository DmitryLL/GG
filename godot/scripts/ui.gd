# Общие UI-хелперы для «фэнтези»-окон (персонаж, сумка, лут).
# Без автозагрузки — использовать как `UI.panel_style(...)` через preload.
class_name UI
extends RefCounted

# Палитра — тёмно-тёплая, золотые акценты.
const BG_DEEP        := Color(0.055, 0.043, 0.031, 1.0)
const BG_PANEL       := Color(0.090, 0.075, 0.059, 1.0)
const BG_INNER       := Color(0.130, 0.106, 0.082, 1.0)
const BG_SLOT        := Color(0.055, 0.047, 0.035, 1.0)
const BG_SLOT_HOVER  := Color(0.110, 0.090, 0.060, 1.0)
const BORDER_DIM     := Color(0.260, 0.200, 0.135, 1.0)
const BORDER_MID     := Color(0.420, 0.325, 0.180, 1.0)
const GOLD           := Color(0.910, 0.757, 0.420, 1.0)
const GOLD_SOFT      := Color(0.780, 0.650, 0.360, 1.0)
const TEXT_MAIN      := Color(0.937, 0.902, 0.820, 1.0)
const TEXT_DIM       := Color(0.600, 0.545, 0.460, 1.0)
const TEXT_MUTED     := Color(0.470, 0.420, 0.350, 1.0)
const HP_RED         := Color(0.82, 0.28, 0.28, 1.0)
const HP_BG          := Color(0.20, 0.08, 0.08, 1.0)
const XP_ORANGE      := Color(0.99, 0.72, 0.28, 1.0)
const XP_BG          := Color(0.20, 0.14, 0.06, 1.0)

# Основная панель с мягкой рамкой и тенью.
static func panel_style(radius: int = 10, border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_PANEL
	sb.border_color = BORDER_MID
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 4)
	sb.set_content_margin_all(14)
	return sb

# Внутренний блок (статы/списки) — чуть светлее, без тени.
static func inner_style(radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_INNER
	sb.border_color = BORDER_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb

# Ячейка инвентаря — двойная рамка (внешняя по редкости, внутренняя dim).
static func slot_style(rarity: int, hover: bool, radius: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_SLOT_HOVER if hover else BG_SLOT
	if rarity >= 0:
		var base: Color = Items.rarity_color(rarity)
		sb.border_color = base if hover else Color(base.r * 0.75, base.g * 0.75, base.b * 0.75, 1.0)
		sb.set_border_width_all(2)
	else:
		sb.border_color = BORDER_MID if hover else BORDER_DIM
		sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	return sb

# Тонкая «золотая» линия-разделитель.
static func divider() -> Control:
	var c := ColorRect.new()
	c.color = BORDER_MID
	c.custom_minimum_size = Vector2(0, 1)
	return c

# Заголовок секции.
static func section_title(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", GOLD)
	return l

# Стиль кнопки «призыв к действию» (золотой).
static func button_primary() -> Array:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.24, 0.17, 0.08, 1.0)
	n.border_color = GOLD_SOFT
	n.set_border_width_all(1)
	n.set_corner_radius_all(6)
	n.set_content_margin_all(8)
	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.34, 0.23, 0.10, 1.0)
	h.border_color = GOLD
	h.set_border_width_all(1)
	h.set_corner_radius_all(6)
	h.set_content_margin_all(8)
	return [n, h]

static func apply_primary_button(b: Button) -> void:
	var s: Array = button_primary()
	b.add_theme_stylebox_override("normal", s[0])
	b.add_theme_stylebox_override("hover", s[1])
	b.add_theme_stylebox_override("pressed", s[1])
	b.add_theme_stylebox_override("focus", s[1])
	b.add_theme_color_override("font_color", TEXT_MAIN)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_font_size_override("font_size", 13)

# Крестик-закрытие.
static func apply_close_button(b: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.12, 0.09, 0.07, 1.0)
	n.border_color = BORDER_DIM
	n.set_border_width_all(1)
	n.set_corner_radius_all(6)
	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.30, 0.10, 0.08, 1.0)
	h.border_color = Color(0.75, 0.32, 0.24, 1.0)
	h.set_border_width_all(1)
	h.set_corner_radius_all(6)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_color_override("font_color", TEXT_DIM)
	b.add_theme_color_override("font_hover_color", TEXT_MAIN)
	b.add_theme_font_size_override("font_size", 16)
	b.text = "×"
	b.custom_minimum_size = Vector2(30, 28)

# Полоска прогресса (HP/XP) — фон + заливка, рисуется как два ColorRect.
# Возвращает контейнер; чтобы обновить — вызвать set_meta("fill", ratio).
static func progress_bar(bg_col: Color, fill_col: Color, height: int = 10) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(0, height)
	wrap.clip_contents = true

	var bg := ColorRect.new()
	bg.color = bg_col
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	wrap.add_child(bg)

	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.color = fill_col
	fill.anchor_right = 0.0
	fill.anchor_bottom = 1.0
	wrap.add_child(fill)
	return wrap

static func progress_set(wrap: Control, ratio: float) -> void:
	var fill: ColorRect = wrap.get_node_or_null("Fill")
	if fill == null:
		return
	fill.anchor_right = clamp(ratio, 0.0, 1.0)

# Круглая «монета» — простой ColorRect-кружок цвета золота.
static func coin(size: int = 14) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(size, size)
	var base := ColorRect.new()
	base.color = Color(0.92, 0.68, 0.18, 1.0)
	base.anchor_right = 1.0
	base.anchor_bottom = 1.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.68, 0.18, 1.0)
	# ColorRect не принимает стайлбокс — используем Panel.
	wrap.remove_child(base)
	base.queue_free()
	var panel := Panel.new()
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.95, 0.72, 0.20, 1.0)
	st.border_color = Color(1.00, 0.90, 0.45, 1.0)
	st.set_border_width_all(1)
	st.set_corner_radius_all(size)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 3
	panel.add_theme_stylebox_override("panel", st)
	wrap.add_child(panel)
	return wrap
