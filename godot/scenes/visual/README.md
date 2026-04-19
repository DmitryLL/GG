# scenes/visual — визуальные префабы

Здесь лежат сцены, отвечающие **только за визуал** — спрайты, анимации, эффекты. Владелец: **@protiik** (Вова). Скрипты логики в эти сцены не добавляем.

Папка пока пустая по задумке — рефакторинг существующих сущностей (`player.gd`, `mob.gd`, `arrow.gd`) из «визуал в коде» в «визуал-префабы» сделаем, когда будет первый готовый префаб от Вовы. До этого код продолжает создавать `Sprite2D.new()` как сейчас.

## Планируемые префабы

| Файл | Что внутри | Кто инстанцирует |
|---|---|---|
| `PlayerVisual.tscn`        | `AnimatedSprite2D` + `AnimationPlayer` игрока (walk/attack/hurt/…) | `player.gd` |
| `MobGoblinVisual.tscn`     | `AnimatedSprite2D` гоблина                                         | `mob.gd`    |
| `MobSlimeVisual.tscn`      | `AnimatedSprite2D` слайма                                          | `mob.gd`    |
| `MobDummyVisual.tscn`      | `Sprite2D` чучела (анимации не нужны)                              | `mob.gd`    |
| `ArrowVisual.tscn`         | `Sprite2D` стрелы + `AnimationPlayer` на impact                    | `arrow.gd`  |
| `effects/Fire.tscn`        | Эффект поджога                                                     | `game.gd`   |
| `effects/Poison.tscn`      | Эффект отравления                                                  | `game.gd`   |

## Контракт для префабов персонажей/мобов

Корневой узел префаба — `Node2D` с именем `Visual`. Внутри — `AnimatedSprite2D` (или `AnimationPlayer`).

Обязательные анимации (имена из `assets/README.md`):
- персонаж: `idle`, `walk`, `attack`, `cast_1..5`, `hurt`, `death`
- моб: `idle`, `walk`, `attack`, `hurt`, `death`
- стрела: `fly` (loop), `impact` (oneshot)

Скрипты Димы обращаются только через:
```gdscript
visual.play("walk")           # AnimatedSprite2D
visual.stop()
visual.flip_h = facing < 0
```

Если в префабе будут дополнительные ноды (тень, партиклы) — ок, логика их не знает и не трогает.

## Как прислать новый префаб

1. Создаёшь в `scenes/visual/MobWolfVisual.tscn` (только визуал, без скриптов).
2. Проверяешь, что имена анимаций соответствуют контракту.
3. ПР → @DmitryLL подключит к логической сцене.
