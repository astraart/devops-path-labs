# shop-api

Учебный сервис итогового проекта DevOps Path: Flask-приложение с двумя адресами.

| Адрес | Ответ |
|---|---|
| `GET /` | `{"service": "shop-api", "version": "<APP_VERSION>", "hostname": "<имя хоста>"}` |
| `GET /health` | `{"status": "ok"}` — для проб и мониторинга |

Запуск локально:

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt pytest
.venv/bin/pytest -q
.venv/bin/gunicorn --bind 127.0.0.1:8000 app:app
```

В контейнере:

```bash
docker build -t shop-api:1.0.0 .
docker run --rm -p 8000:8000 shop-api:1.0.0
```

Код и версии зависимостей совпадают с заданиями модуля «Итоговый проект» в приложении.
