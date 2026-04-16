# Общие UI-хелперы для магических окон (персонаж, сумка, лут).
# Использует сгенерированные пиксель-арт ассеты: panel_frame.png, slot.png, banner.png.
class_name UI
extends RefCounted

const TEX_PANEL  := preload("res://assets/sprites/ui/panel_frame.png")
const TEX_SLOT   := preload("res://assets/sprites/ui/slot.png")

# Магическая палитра — тёмно-фиолетовая рамка, тёплые бежевые акценты текста.
const BG_DEEP        := Color(0.040, 0.032, 0.055, 1.0)
const BG_PANEL       := Color(0.095, 0.078, 0.120, 1.0)
const BG_INNER       := Color(0.165, 0.130, 0.095, 0.92)  # тёплый пергаментный коричневый
const BG_SLOT        := Color(0.070, 0.055, 0.095, 1.0)
const BG_SLOT_HOVER  := Color(0.125, 0.098, 0.155, 1.0)
const BORDER_DIM     := Color(0.460, 0.380, 0.260, 1.0)   # тёплый коричневый border
const BORDER_MID     := Color(0.720, 0.610, 0.430, 1.0)   # светлый бежевый
const MAGIC_ACCENT   := Color(0.945, 0.855, 0.640, 1.0)  # светло-бежевый (пергамент)
const MAGIC_GLOW     := Color(0.995, 0.920, 0.745, 1.0)  # тёплый кремовый
const GOLD           := Color(0.970, 0.820, 0.380, 1.0)  # для монет золота
const GOLD_SOFT      := Color(0.820, 0.690, 0.340, 1.0)
const TEXT_MAIN      := Color(0.965, 0.925, 0.830, 1.0)  # кремовый основной текст
const TEXT_DIM       := Color(0.780, 0.715, 0.600, 1.0)  # приглушённый бежевый
const TEXT_MUTED     := Color(0.580, 0.520, 0.440, 1.0)  # коричневато-серый
const HP_RED         := Color(0.88, 0.34, 0.38, 1.0)
const HP_BG          := Color(0.16, 0.07, 0.10, 1.0)
const XP_ORANGE      := Color(0.955, 0.720, 0.360, 1.0)  # тёплый янтарный
const XP_BG          := Color(0.18, 0.12, 0.06, 1.0)

# Основная панель — nine-slice по ассету panel_frame.png (256×256, декоративные углы ~50).
static func panel_style(radius: int = 10, border_w: int = 2) -> StyleBox:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_PANEL
	sb.texture_margin_left = 54
	sb.texture_margin_right = 54
	sb.texture_margin_top = 54
	sb.texture_margin_bottom = 54
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 28
	sb.content_margin_bottom = 28
	return sb

# Внутренний блок (статы/списки) — полупрозрачный тёмно-фиолетовый, чтобы не спорить с рамкой.
static func inner_style(radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_INNER
	sb.border_color = BORDER_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	return sb

# Ячейка инвентаря — nine-slice по slot.png (64×64, декоративные углы ~14).
# Редкость передаётся тинтом через modulate_color; hover — чуть ярче.
static func slot_style(rarity: int, hover: bool, radius: int = 6) -> StyleBox:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_SLOT
	sb.texture_margin_left = 14
	sb.texture_margin_right = 14
	sb.texture_margin_top = 14
	sb.texture_margin_bottom = 14
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	var tint := Color(1, 1, 1, 1)
	if rarity >= 0:
		var base: Color = Items.rarity_color(rarity)
		tint = Color(1, 1, 1).lerp(base, 0.55)
	if hover:
		tint = Color(tint.r * 1.22, tint.g * 1.22, tint.b * 1.22, 1.0)
	sb.modulate_color = tint
	return sb

# Тонкий «рунный» разделитель.
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
	l.add_theme_color_override("font_color", MAGIC_ACCENT)
	return l

# Стиль кнопки «призыв к действию» — тёплый бежевый акцент.
static func button_primary() -> Array:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.18, 0.14, 0.28, 1.0)
	n.border_color = BORDER_MID
	n.set_border_width_all(1)
	n.set_corner_radius_all(6)
	n.set_content_margin_all(8)
	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.26, 0.22, 0.40, 1.0)
	h.border_color = MAGIC_ACCENT
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
	b.add_theme_color_override("font_hover_color", MAGIC_ACCENT)
	b.add_theme_font_size_override("font_size", 13)

# Крестик-закрытие.
static func apply_close_button(b: Button) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.10, 0.08, 0.16, 1.0)
	n.border_color = BORDER_DIM
	n.set_border_width_all(1)
	n.set_corner_radius_all(6)
	var h := StyleBoxFlat.new()
	h.bg_color = Color(0.30, 0.10, 0.18, 1.0)
	h.border_color = Color(0.85, 0.42, 0.55, 1.0)
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

# Полоска прогресса (HP/XP).
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

# Круглая «монета» — золотая, для счёта золота.
static func coin(size: int = 14) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(size, size)
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
