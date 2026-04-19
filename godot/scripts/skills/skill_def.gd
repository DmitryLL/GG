# Базовый дескриптор скилла. ФУНДАМЕНТ системы: каждый скилл попадает ровно
# в один из трёх типов (Kind). Никаких четвёртых вариантов нет — если новый
# скилл не вписывается, значит не достаточно подумали: расширять SkillDef
# тоже нельзя без явного обновления game.gd._process_queued_skill.
#
# ═══════════════════ Три типа скиллов ═══════════════════
#
# INSTANT — срабатывает немедленно при нажатии клавиши/клика иконки.
#           Ни цель, ни позиция не нужны. Пример: skill_3 Эскейп.
#           payload: {"skill": N, "dx":..., "dy":...}  (направление взгляда)
#
# TARGET  — по одной цели (моб или игрок). Логика:
#   • если цель уже выбрана (attack_target/pvp_target) — скилл сразу
#     встаёт в очередь на применение к ней, targeting_mode НЕ включается;
#   • если цели нет — включается targeting_mode (курсор-крестик), первым
#     кликом по мобу/игроку цель фиксируется и ставится в очередь;
#   • в _process персонаж идёт к цели до радиуса атаки и кастует скилл;
#   • после скилла attack_target сохраняется → auto-атака продолжается.
#   payload: {"skill": N, "mobId": ...} или {"skill": N, "sid": ...}
#
# GROUND  — по точке на земле (AoE, направленный залп и т.п.). Логика:
#   • ВСЕГДА включается targeting_mode — нужно указать точку;
#   • в момент клика запоминается queued_ground_pos и queued_approach_pos
#     (ближайшая точка в радиусе каста к клику);
#   • если точка клика в радиусе — применяется немедленно;
#   • иначе персонаж идёт к approach-позиции и кастует как только
#     заходит в радиус.
#   payload: {"skill": N, "x":..., "y":...}
#
# ════════════════════════════════════════════════════════
class_name SkillDef
extends RefCounted

enum Kind { INSTANT = 0, TARGET = 1, GROUND = 2 }

# UI/мета
var id: String = ""        # стабильный символьный id, напр. "rdd_shot", "deza" — для hotbar-конфигов
var display_name: String = ""
var icon_path: String = ""
var cooldown: float = 5.0
var server_id: int = 0     # номер для сервера (1..5+), не совпадает со слотом в hotbar

# Требования
var requires_bow: bool = false

# Флаги типа. Включайте максимум один — иначе kind() ругается и откатывается
# к INSTANT. Для TARGET → targets_mob, для GROUND → targets_ground.
var targets_mob: bool = false
var targets_ground: bool = false

# Стиль стрелы для arrow.gd ("normal"/"crit"/"poison"/"ghost"/"")
var arrow_style: String = ""

# Вернуть тип скилла. game.gd диспетчеризует каст через match по этому значению.
func kind() -> int:
	if targets_mob and targets_ground:
		push_error("SkillDef %s: targets_mob и targets_ground взаимоисключаемы" % display_name)
		return Kind.INSTANT
	if targets_mob:
		return Kind.TARGET
	if targets_ground:
		return Kind.GROUND
	return Kind.INSTANT

# Срабатывает после успешной отправки скилла на сервер.
func on_send(game) -> void:
	if game.me and arrow_style != "":
		game.me.play_bow_shot()

# Обработка серверного OP_SKILL_FX. body — словарь с полями FX.
# Возвращает true если событие обработано, false — пробросить дальше.
func on_fx(_game, _body: Dictionary) -> bool:
	return false
