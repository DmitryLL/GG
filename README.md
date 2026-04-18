# GG

Локальный прототип top-down MMORPG на `Godot 4` и `Nakama`.

## Что в репозитории

- `godot/` — клиент игры
- `nakama-server/` — runtime-модули сервера на TypeScript
- `data/` — игровые данные: предметы, мобы, дроп, NPC, баланс
- `deploy/` — локальный docker-compose для Nakama/Postgres
- `site/` — статическая веб-страница проекта

## Локальный запуск

### 1. Сервер

```bash
cd /home/bvd/codex/GG
docker compose -f deploy/docker-compose.yml -f deploy/docker-compose.local.yml up -d
curl http://127.0.0.1:7350/healthcheck
```

Ожидаемый ответ:

```json
{}
```

### 2. Веб-страница проекта

```bash
cd /home/bvd/codex/GG/site
python3 -m http.server 8090
```

Открыть:

```text
http://localhost:8090
```

### 3. Godot demo

```bash
cd /home/bvd/codex/GG
./run-godot-demo.sh
```

## Полезные страницы

- главная витрина: [site/index.html](/home/bvd/codex/GG/site/index.html)
- статус локального запуска: [site/status.html](/home/bvd/codex/GG/site/status.html)

## Git flow

- рабочая ветка: `vovan`
- в `main` напрямую не пушим
- изменения идут через PR
