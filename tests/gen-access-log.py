"""Генератор учебного лога для практики real.linux-files-solo (запускать не нужно: лог уже в репозитории).

python3 tests/gen-access-log.py > labs/real.linux-files-solo/access.log
Формат — combined из nginx плюс $request_time последним полем. Ответы для check.sh считаются из самого лога.
"""
import random

rnd = random.Random(20261117)
top = [("203.0.113.45", 412), ("198.51.100.7", 377), ("192.0.2.150", 341), ("203.0.113.9", 298), ("198.51.100.23", 265), ("192.0.2.77", 233)]
others = [(f"10.20.{rnd.randint(0, 9)}.{rnd.randint(2, 250)}", rnd.randint(8, 150)) for _ in range(34)]
hits = [ip for ip, n in top + others for _ in range(n)]
rnd.shuffle(hits)
pages = ["/", "/api/orders", "/api/cart", "/static/app.js", "/static/style.css", "/login", "/favicon.ico"] + [f"/api/orders/{i}" for i in range(1001, 1013)]
missing = ["/wp-login.php"] * 9 + ["/.env"] * 6 + ["/admin"] * 4 + ["/phpmyadmin/"] * 3 + ["/static/old.js"] * 2
agents = ["Mozilla/5.0 (X11; Linux x86_64) Firefox/134.0", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/131.0", "curl/8.5.0", "python-requests/2.32.3", "Go-http-client/1.1"]
sec = 0
for ip in hits:
    sec += rnd.randint(1, 25)
    h, m, s = 8 + sec // 3600 % 14, sec // 60 % 60, sec % 60
    r = rnd.random()
    if r < 0.06:
        path, status = rnd.choice(missing), 404
    elif r < 0.09:
        path, status = rnd.choice(["/api/orders", "/api/cart"] + [f"/api/orders/{i}" for i in range(1001, 1004)]), rnd.choice([500, 502, 502, 503, 504])
    elif r < 0.15:
        path, status = rnd.choice(["/static/app.js", "/static/style.css", "/favicon.ico"]), 304
    else:
        path, status = rnd.choice(pages), 200
    method = "POST" if path == "/api/cart" and rnd.random() < 0.5 else "GET"
    size = 0 if status in (304,) else rnd.randint(120, 48000)
    t = rnd.uniform(1.05, 4.8) if (status == 504 or rnd.random() < 0.012) else rnd.uniform(0.001, 0.95)
    print(f'{ip} - - [17/Nov/2026:{h:02d}:{m:02d}:{s:02d} +0300] "{method} {path} HTTP/1.1" {status} {size} "-" "{rnd.choice(agents)}" {t:.3f}')
