# GG

2D top-down MMORPG на **Godot 4** + **Nakama** (серверная логика на TypeScript).

Сервер — `nakama-server/` (single bundled `index.js`, server-authoritative).
Клиент — `godot/` (web export в первую очередь, потом мобилки).

## Разделение работы

| Кто       | Область                                                                 |
|-----------|-------------------------------------------------------------------------|
| **dima**  | Функционал, логика игры, серверная часть, UI, редактор карт, протокол   |
| **vovan** | Графика, спрайты, анимации, звук, ассеты, визуальные эффекты            |

Чтобы меньше конфликтов — каждый держится в своей зоне. Если нужно трогать чужое (например, vovan хочет добавить новую анимацию = маленькая правка в `player.gd`) — **написать в чат до push**.

## Ветки

- `main` — прод. **Прямой push запрещён** (branch protection + обязательный CI).
- `dima` — рабочая ветка dima.
- `vovan` — рабочая ветка vovan.

Каждый пушит **только в свою** ветку. В main попадают изменения через **Pull Request** с зелёным CI.

## CI-чеки (обязательные для merge в main)

1. **TypeScript (server)** — `nakama-server` должен собираться без ошибок.
2. **Godot (parse client)** — все `.gd` скрипты в `godot/` должны парситься без Parse Error.

Оба чека запускаются автоматически на каждый PR.

## Workflow — одиночная работа

```bash
# 1. Синхронизироваться с main перед началом работы
git checkout dima                # или vovan
git fetch origin
git merge origin/main
git push

# 2. Работать, коммитить, пушить в свою ветку
git add <files>
git commit -m "описание изменений по-русски"
git push

# 3. Когда готово — залить в main через PR
gh pr create --base main --head dima --fill
gh pr checks                     # дождаться обоих зелёных
gh pr merge --squash --delete-branch

# 4. Пересоздать свою ветку из свежего main
git checkout main && git pull
git checkout -b dima && git push -u origin dima
```

## Workflow — одновременная работа (dima + vovan)

1. **Перед началом дня** — каждый делает `git merge origin/main` в свою ветку.
2. **Договориться устно/в чате** кто какие файлы трогает.
3. Каждый пилит в своей ветке, пушит в `origin/dima` / `origin/vovan`.
4. Кто первый готов — открывает PR, дожидается CI, mergит.
5. Второй — подтягивает main и разруливает конфликты (см. ниже).

## Решение конфликтов

Если при попытке PR GitHub показывает «This branch is out-of-date» или «conflicts with base branch»:

### Нет конфликтов (только устарела)

В UI PR есть кнопка **"Update branch"** → GitHub сам смержит main в твою ветку. Потом локально:

```bash
git pull
```

### Есть конфликты

```bash
git checkout vovan               # или dima
git fetch origin
git merge origin/main
```

Git покажет файлы с маркерами:

```
<<<<<<< HEAD                 (твой код)
var SPEED = 150
=======                      (что залили в main)
var SPEED = 105
>>>>>>> origin/main
```

Открыть файл, удалить маркеры, оставить правильный вариант (или объединить). Потом:

```bash
git add <файл>
git commit                        # merge commit — дефолтное сообщение норм
git push
```

PR обновится автоматически, CI перезапустится. Если зелёное — merge.

## Что НЕ делать

- ❌ **Не пушить в main напрямую** — запрещено branch protection.
- ❌ **Не пушить в чужую ветку** (dima ↔ vovan) — это чужая песочница.
- ❌ **Не использовать `git push --force`** в main или чужих ветках.
- ❌ **Не mergить PR с красным CI** — сломает всем.
- ❌ **Не коммитить файлы секретов** (`.env`, токены, приватные ключи).

## Структура проекта

```
/gg/
├── godot/           # клиент (Godot 4)
│   ├── scripts/     # GDScript — логика, UI, сущности
│   ├── assets/      # спрайты, звуки, карты (.tmj)
│   └── scenes/      # .tscn
├── nakama-server/   # серверная логика
│   └── src/
│       ├── main.ts       # основной модуль (match handler, RPC)
│       ├── data.gen.ts   # генерится из YAML — НЕ редактировать руками
│       └── skills/       # определения скиллов
├── data/            # YAML-источники для data.gen.ts + генераторы карт (Python)
├── deploy/          # скрипты деплоя и конфиги
└── scripts/         # тестовые клиенты, утилиты
```

## Локальная разработка

### Клиент (Godot)

Открыть `godot/project.godot` в Godot 4.4+. Запустить сцену `Main.tscn`.

### Сервер

Изменения в `nakama-server/src/` → компилируется в `nakama-server/build/index.js` при деплое.

Проверить что TS собирается:

```bash
cd nakama-server
npx tsc --noEmit
```

### Деплой

Только dima (у админа доступ к продакшен-серверу).

## Полезные ссылки

- Прод-сервер: `nk.193-238-134-75.sslip.io`
- Nakama console: `admin.193-238-134-75.sslip.io`
- GitHub: https://github.com/DmitryLL/GG
