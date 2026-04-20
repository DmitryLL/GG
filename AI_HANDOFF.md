# AI Handoff

Файл для координации двух AI-ассистентов в одном репозитории.

## Цель

Снизить конфликты между двумя параллельными агентами:
- `vovan` — фронт, UI, визуал
- `dima` — логика клиента, сервер, инфраструктура

## Роли

### Ветка `vovan`

Зона ответственности:
- `godot/assets/`
- `godot/scenes/visual/`
- `godot/data/`
- `godot/themes/`

Основная задача:
- визуал, анимации, UI, иконки, клиентские визуальные ассеты

### Ветка `dima`

Зона ответственности:
- `godot/scripts/`
- `godot/scenes/core/`
- `nakama-server/`
- `deploy/`
- `.github/`
- `scripts/`

Основная задача:
- логика клиента
- сервер
- контракты данных
- подключение визуала к игровой логике

## Правила взаимодействия

1. Каждый агент работает только в своей зоне.
2. Если задача упирается в чужую зону, агент не доделывает её молча, а оставляет handoff.
3. Перед каждым `commit/push` обязательно:
   - `git fetch origin`
   - проверить расхождение с `origin/vovan` или `origin/dima`
   - проверить расхождение с `origin/main`
4. Если `main` ушёл вперёд, сначала синхронизация с `main`, потом `commit/push`.
5. Один PR = одна понятная задача.
6. Коммиты и PR-описания — по-русски.

## Формат handoff

Когда одна сторона зависит от другой, запись должна быть короткой и конкретной:

```md
## Handoff
- Кто: vovan | dima
- Что сделано:
- Что нужно от второй стороны:
- Какие файлы затронуты:
- Контракт/ожидание:
- Что нельзя ломать:
```

## Текущий контракт по проекту

### Книги как оружие ✅

Сделано со стороны `vovan`:
- книги поддержаны как отдельные weapon-визуалы по `item_id`
- локальный игрок может видеть разные тома
- базовые ассеты книг лежат в:
  - `godot/assets/sprites/characters/books/apprentice_tome_open.png`
  - `godot/assets/sprites/characters/books/mystic_tome_open.png`
  - `godot/assets/sprites/characters/books/arcane_tome_open.png`

Сделано со стороны `dima` (закрыт запрос vovan):
- сервер шлёт в `OP_POSITIONS` поле `eqWeapon` с точным item id
  (и `wpn` — тип). Клиент использует `Player.set_weapon_item(id)`
  и тянет корректный спрайт для remote-игроков. (PR #73)

### Контракт имён weapon-overlay

Клиент (`Player._weapon_texture`) ищет индивидуальную текстуру
по следующим путям (первый найденный побеждает). Если ни одна не
найдена — используется общий `bow_hand.png` / `book_hand.png`.

Пусть `short` = часть `item_id` до суффикса (`apprentice_tome` → `apprentice`,
`wood_bow` → `wood`, `iron_sword` → `iron`).

| Оружие | Основной путь (актуальный) | Legacy (совместимость) |
|---|---|---|
| book / tome | `characters/books/<short>_tome_open.png` | `characters/book_<short>_hand.png` |
| bow         | `characters/bows/<short>_bow_drawn.png`  | `characters/bow_<short>_hand.png`  |
| sword       | `characters/swords/<short>_sword.png`    | — |

### Handoff открытые

**от `dima` → `vovan`** (фон экрана входа «Aetherlands»)
- Что сделано: игра переименована в «Aetherlands», в окне входа
  добавлен крупный титул «Aetherlands» + подзаголовок «земли эфира»
  + процедурные эфирные частицы (40 плывущих светлячков).
- Что нужно: заменить `godot/assets/sprites/ui/auth_bg.png` на
  тематическую картинку в духе названия — **странники идут по землям
  эфира**. Палитра: глубокий фиолетово-синий фон с холодным голубым
  свечением, силуэты 1-3 фигур-странников с посохами/капюшонами,
  светящиеся нити эфира в небе. 400×240 (старый размер) или любой
  разумный, движок растянет.
- Файлы: `godot/assets/sprites/ui/auth_bg.png` (замена на месте).
- Нельзя ломать: размер можно менять, координаты в `Auth.tscn`
  используют `expand_mode = 1, stretch_mode = 6` — подстроится.

**от `dima` → `vovan`** (луки)
- Что сделано: сервер теперь шлёт `eqWeapon`, клиент умеет
  подгружать индивидуальные оверлеи по контракту выше.
- Что нужно: доделать спрайты для луков (`bows/wood_bow_drawn.png`,
  `bows/iron_bow_drawn.png`). Золотой (`golden_bow_drawn.png`)
  уже сделан, спасибо ✅.
- Файлы: `godot/assets/sprites/characters/bows/*.png`.
- Контракт: 14×14..16×16 прозрачный PNG, nearest-filter; применяется
  как overlay в руке через те же позиции что текущий `bow_hand.png`.
- Нельзя ломать: существующие `book_hand.png` / `bow_hand.png` —
  это плейсхолдер-fallback и используется всеми, у кого ещё нет
  индивидуальной текстуры.

**от `vovan` → `dima`**
- Что сделано: по явной задаче пользователя в `player.gd` добавлена
  клиентская фазовая bow-анимация для `play_bow_shot()`:
  draw / release / recover, плюс тетива и preview-arrow.
- Что нужно: при переходе на полноценные `action_profile` перенести
  этот визуальный ритм в общий профиль `bow_attack`.
- Файлы: `godot/scripts/player.gd`, `AI_HANDOFF.md`
- Контракт: текущая bow-анимация меняет только visual overlay и не
  трогает механику урона или серверный спавн настоящей стрелы.
- Нельзя ломать: настоящий выстрел и урон остаются на серверной логике;
  это только клиентский визуальный слой.

**от `dima` → `vovan`** (иконки эффектов)
- Что сделано: сервер шлёт в OP_ME новые эффекты (`empowered`
  от мода Эскейпа, потенциально `haste/regen/shield` и т.п.).
  Клиент nameplate.gd ищет PNG по пути
  `res://assets/sprites/ui/effect_<type>.png`; если не найдена —
  рисует fallback-символ (⚔/»/+/▲) чтобы хоть что-то было видно.
- Что нужно: отдельные 16×16 иконки эффектов в
  `godot/assets/sprites/ui/`:
    - `effect_empowered.png` (Эскейп 1п)
    - `effect_sprint.png` (Эскейп 2п)
    - `effect_crit_buff.png` (Баф крита — базовый + party)
    - `effect_pierce.png` (Баф крита 2п)
    - `effect_slow.png` (дебафф, красный)
  при наличии: `effect_haste.png`, `effect_regen.png`,
  `effect_shield.png` — для положительных эффектов на мобах.
- Контракт: 16×16 прозрачный, nearest-filter, цвет зелёный (баффы).
- Нельзя ломать: существующие `effect_heal.png`, `effect_poison.png` —
  уже используются и работают.

### Оружие и анимации по типу оружия

Цель:
- общий `walk/idle` остаётся у базового тела персонажа
- атакующая анимация зависит от типа оружия
- внешний вид конкретного оружия зависит от `item_id`

Базовое разделение:
- `weapon_family`:
  - `bow`
  - `tome`
  - `sword`
- `weapon_visual`:
  - `wood_bow`
  - `iron_bow`
  - `golden_bow`
  - `apprentice_tome`
  - `mystic_tome`
  - `arcane_tome`

Правило:
- `weapon_family` определяет действие персонажа
- `weapon_visual` определяет внешний вид оружия

Что должно быть общим:
- `idle`
- `walk`
- базовые стойки тела

Что должно зависеть от `weapon_family`:
- `bow_attack`
- `tome_cast`
- `sword_slash`

Что должно зависеть от `weapon_visual`:
- форма оружия
- размер оружия
- положение в руке
- overlay-кадры для `idle/walk/attack`

Рекомендуемый контракт предмета:

```gdscript
"golden_bow": {
  "slot": "weapon",
  "weapon_family": "bow",
  "weapon_visual": "golden_bow",
  "action_profile": "bow_attack"
}
```

```gdscript
"mystic_tome": {
  "slot": "weapon",
  "weapon_family": "tome",
  "weapon_visual": "mystic_tome",
  "action_profile": "tome_cast"
}
```

Рекомендуемая структура ассетов:

```text
godot/assets/sprites/weapons/bows/wood_bow/
  idle.png
  walk.png
  attack.png

godot/assets/sprites/weapons/bows/iron_bow/
  idle.png
  walk.png
  attack.png

godot/assets/sprites/weapons/bows/golden_bow/
  idle.png
  walk.png
  attack.png

godot/assets/sprites/weapons/tomes/apprentice_tome/
  idle.png
  walk.png
  attack.png
```

Важно:
- не делать полный новый sprite sheet персонажа под каждый предмет
- делать общее тело + overlay оружия
- тогда одна и та же логика атаки работает для всех луков и всех книг

Что нужно от `dima`:
- в логике персонажа разделить:
  - `weapon_family`
  - `weapon_visual`
  - `action_profile`
- атакующее действие выбирать по `weapon_family`, а не по конкретному item id
- конкретную текстуру/атлас оружия выбирать по `weapon_visual`
- игровые события привязать к кадру action profile:
  - вылет стрелы
  - выпуск фаербола
  - момент удара мечом
- для локальных и remote игроков использовать один и тот же контракт `eq.weapon`

Что нельзя ломать:
- общий `walk` тела должен оставаться общим
- книга у мага должна оставаться в левой руке
- маг кастует правой рукой
- у лучника должен быть виден именно экипированный лук, а не абстрактный общий overlay

## Готовый промпт для Claude

Скопируй этот текст в Claude, если нужно подключить его к проекту по нашей схеме:

```text
Ты работаешь в репозитории GG вместе со вторым AI-ассистентом. Работай строго по схеме handoff.

Роли:
- ветка vovan: фронт, UI, визуал, ассеты, анимации, клиентский визуал
- ветка dima: godot/scripts, core-сцены, сервер, инфраструктура, контракты логики

Жёсткие правила:
1. Не выходи за пределы своей зоны ответственности.
2. Если задача требует изменения чужой зоны, не доделывай её молча — оставь короткий handoff.
3. Перед каждым commit/push обязательно:
   - git fetch origin
   - проверь расхождение своей ветки с origin/<своя ветка>
   - проверь расхождение своей ветки с origin/main
   - если main ушёл вперёд, сначала синхронизируйся с main
4. Не делай force push и reset --hard без явной команды.
5. Коммиты и сообщения — по-русски.
6. Один PR = одна задача.

Формат handoff:
- Кто:
- Что сделано:
- Что нужно от второй стороны:
- Какие файлы затронуты:
- Контракт/ожидание:
- Что нельзя ломать:

Текущий пример:
- со стороны vovan книги уже делаются как отдельные weapon-визуалы по item_id
- со стороны dima нужно передавать точный eq.weapon для remote players

Работай аккуратно, не смешивай визуал и сервер в одном изменении и всегда учитывай, что вторая нейронка тоже меняет проект параллельно.
```
