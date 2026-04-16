# GG Test Client

Инструменты для тестирования сервера без браузера.

## state.js — снимок состояния матча

Дёргает RPC `debug_state` через `matchSignal` — возвращает текущее состояние:
позиции игроков и мобов, HP, кулдауны скиллов, дебаффы, активные зоны.

```bash
node state.js              # краткий дамп всего
node state.js player       # JSON всех игроков (inventory, equipment, skillCd)
node state.js mob          # JSON всех мобов
node state.js mob slime    # все слаймы
node state.js mob 5        # моб по индексу
node state.js zone         # активные AoE-зоны (Ливень и т.п.)
```

Краткий вывод:
```
tick 512 ts 1776330968434
players 2, mobs 23, zones 1
  P ыфвф pos=(1022,761) hp=144/300 lv11 cd[1:0ms 2:11874ms 3:0ms]
  M m17 goblin pos=(1554,778) hp=60/60 alive
  Z arrow_rain (1037,961) r=80 ends_in=3374ms
```

## bot.js — отправка действий за тестового игрока

Авторизуется как тестовый user, входит в матч, шлёт одно действие, читает OP_ME.

```bash
node bot.js name=t1                          # просто зайти и выйти
node bot.js name=t1 move=970,720              # двинуться к точке
node bot.js name=t1 attack=m12                # атаковать моба m12
node bot.js name=t1 skill=1 mob=m12           # Меткий выстрел в m12
node bot.js name=t1 skill=2 x=900 y=700       # Ливень в точке
node bot.js name=t1 skill=3 dx=1 dy=0         # Отскок вправо
node bot.js name=t1 skill=4 mob=m12           # Яд в m12
node bot.js name=t1 skill=5 x=1100 y=720      # Залп в направлении
node bot.js name=t1 equip=0                   # надеть предмет из слота 0 инвентаря
```

## Типичный сценарий теста

```bash
# 1. Посмотреть состояние, найти id моба
node state.js | grep goblin

# 2. Запомнить hp моба ДО
node state.js mob 5 | grep hp

# 3. Атаковать
node bot.js name=tester1 skill=1 mob=m12

# 4. Через сек проверить hp ПОСЛЕ
sleep 1 && node state.js mob 5 | grep hp
```

## Конфиг

Хост можно поменять через env: `NK_HOST=other.example.com node state.js`
