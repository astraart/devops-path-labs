"""Общие помощники тестов. Тесты не трогают настоящие /etc и /var: все пути — во временных каталогах."""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BIN = ROOT / "bin"
sys.path.insert(0, str(BIN))


def run_script(name: str, **env: str) -> subprocess.CompletedProcess:
    """Запустить bin/NAME через bash с дополнительными переменными окружения."""
    full_env = {**os.environ, "LC_ALL": "C.UTF-8", **env}
    return subprocess.run(
        ["bash", str(BIN / name)], env=full_env, capture_output=True, text=True, timeout=60
    )
