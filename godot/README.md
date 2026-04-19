# GG — Godot 4 клиент

Фаза 1 миграции с Phaser+Colyseus на Godot 4 + Nakama.

## Что есть сейчас

- Проект Godot 4.3 с настроенным окном 800×608, stretch mode `canvas_items`.
- Вендорный Nakama SDK в `addons/com.heroiclabs.nakama/`.
- Autoload `Session` держит `NakamaClient`, `NakamaSocket`, `NakamaSession`.
- Сцены: `scenes/core/Main` (роутер), `scenes/core/Auth` (email+password), `scenes/core/Game` (заглушка с подключением к socket).
- Структура: `scenes/core/` — логические сцены (Дима), `scenes/visual/` — визуальные префабы (Вова). См. `scenes/visual/README.md`.
- Connection: `https://nk.193-238-134-75.sslip.io`, server key `defaultkey`.

## Как запустить

1. Установить Godot 4.3+ (https://godotengine.org/).
2. Открыть проект: Godot → Import → выбрать `godot/project.godot`.
3. В `Project → Project Settings → Plugins` включить **Nakama** (должен уже быть активен).
4. F5 для запуска.

## Что должно работать

- Главная открывает форму входа/регистрации.
- Регистрация создаёт пользователя в Nakama (виден в админке https://admin.193-238-134-75.sslip.io/ в разделе Accounts).
- После логина открывается заглушка Game с «Real-time OK».
- Кнопка «Выйти» возвращает на форму входа.

## Следующая фаза

Phase 2 — портировать мир: TileMap с процедурной генерацией (seed 1337, 60×45 тайлов), коллизии, камера, персонаж с WASD и click-to-move, отправка позиции через Nakama match.
