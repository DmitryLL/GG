# Общие UI-хелперы для магических окон (персонаж, сумка, лут).
# Использует сгенерированные пиксель-арт ассеты: panel_frame.png, slot.png, banner.png.
class_name UI
extends RefCounted

const TEX_PANEL  := preload("res://assets/sprites/ui/panel_frame.png")
const TEX_SLOT   := preload("res://assets/sprites/ui/slot.png")

# Бронзово-деревянная палитра — тёплое дерево, бронза, рубин.
const BG_DEEP        := Color(0.055, 0.040, 0.025, 1.0)  # почти чёрный тёплый
const BG_PANEL       := Color(0.110, 0.080, 0.050, 1.0)  # тёмное дерево
const BG_INNER       := Color(0.175, 0.130, 0.082, 0.92) # пергаментный коричневый
const BG_SLOT        := Color(0.085, 0.060, 0.035, 1.0)  # тёмная кожа
const BG_SLOT_HOVER  := Color(0.150, 0.105, 0.055, 1.0)
const BORDER_DIM     := Color(0.435, 0.320, 0.180, 1.0)  # старая бронза
const BORDER_MID     := Color(0.735, 0.555, 0.290, 1.0)  # полированная бронза
const MAGIC_ACCENT   := Color(0.975, 0.830, 0.470, 1.0)  # золотая эмаль
const MAGIC_GLOW     := Color(1.000, 0.910, 0.600, 1.0)  # горячее золото
const GOLD           := Color(0.990, 0.820, 0.340, 1.0)  # для монет
const GOLD_SOFT      := Color(0.840, 0.670, 0.280, 1.0)
const TEXT_MAIN      := Color(0.975, 0.920, 0.810, 1.0)  # кремовый
const TEXT_DIM       := Color(0.790, 0.695, 0.555, 1.0)  # приглушённый бежевый
const TEXT_MUTED     := Color(0.570, 0.490, 0.385, 1.0)
const HP_RED         := Color(0.890, 0.290, 0.280, 1.0)
const HP_BG          := Color(0.180, 0.070, 0.050, 1.0)
const XP_ORANGE      := Color(0.975, 0.670, 0.285, 1.0)  # янтарно-оранжевый
const XP_BG          := Color(0.180, 0.100, 0.040, 1.0)

# Основная панель — nine-slice по ассету panel_frame.png (256×256, бронзовые углы ~60).
static func panel_style(radius: int = 10, border_w: int = 2) -> StyleBox:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_PANEL
	sb.texture_margin_left = 62
	sb.texture_margin_right = 62
	sb.texture_margin_top = 62
	sb.texture_margin_bottom = 62
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
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

# Ячейка инвентаря — nine-slice по slot.png (64×64, бронзовые углы ~16).
# Редкость передаётся лёгким тинтом; hover — чуть ярче.
static func slot_style(rarity: int, hover: bool, radius: int = 6) -> StyleBox:
	var sb := StyleBoxTexture.new()
	sb.texture = TEX_SLOT
	sb.texture_margin_left = 16
	sb.texture_margin_right = 16
	sb.texture_margin_top = 16
	sb.texture_margin_bottom = 16
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	var tint := Color(1, 1, 1, 1)
	if rarity >= 0:
		var base: Color = Items.rarity_color(rarity)
		tint = Color(1, 1, 1).lerp(base, 0.35)
	if hover:
		tint = Color(min(tint.r * 1.22, 1.0), min(tint.g * 1.22, 1.0), min(tint.b * 1.22, 1.0), 1.0)
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
