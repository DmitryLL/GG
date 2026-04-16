# Базовый дескриптор скилла. Каждый конкретный скилл — отдельный
# .gd файл, расширяет SkillDef и переопределяет нужные методы.
class_name SkillDef
extends RefCounted

# UI/мета
var display_name: String = ""
var icon_path: String = ""
var cooldown: float = 5.0
var server_id: int = 0     # номер для сервера (1..5)

# Тип таргетинга (взаимоисключающие)
var targets_mob: bool = false
var targets_ground: bool = false

# Стиль стрелы для arrow.gd ("normal"/"crit"/"poison"/"ghost"/"")
var arrow_style: String = ""

# Срабатывает после успешной отправки скилла на сервер.
# game — узел Game для доступа к me/world/etc.
func on_send(game) -> void:
	# По умолчанию: проиграть анимацию выстрела если есть лук.
	if game.me and arrow_style != "":
		game.me.play_bow_shot()

# Обработка серверного OP_SKILL_FX. body — словарь с полями FX.
# Возвращает true если событие обработано, false — пробросить дальше.
func on_fx(_game, _body: Dictionary) -> bool:
	return false
