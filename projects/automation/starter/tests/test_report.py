import json
import os
import time

import report

HOUR = 3600


def make_backup(d, name, size, age_hours, now):
    d.mkdir(parents=True, exist_ok=True)
    f = d / name
    f.write_bytes(b"x" * size)
    os.utime(f, (now - age_hours * HOUR, now - age_hours * HOUR))


def healthy():
    return {"checked_at": "2026-11-12T07:00:00+00:00", "ok": True, "results": [{"name": "disk /", "ok": True, "detail": "занято 40%"}]}


def test_summary(tmp_path):
    now = time.time()
    make_backup(tmp_path, "backup-20261110-023000.tar.gz", 100, 50, now)
    make_backup(tmp_path, "backup-20261111-023000.tar.gz", 200, 26.5, now)
    make_backup(tmp_path, "backup-20261112-023000.tar.gz", 300, 2, now)
    (tmp_path / "notes.txt").write_text("не бэкап")
    s = report.backups_summary(str(tmp_path), now)
    assert s.count == 3 and s.total_bytes == 600
    assert s.newest == "backup-20261112-023000.tar.gz"
    assert 1.9 < s.newest_age_hours < 2.1


def test_summary_without_directory(tmp_path):
    s = report.backups_summary(str(tmp_path / "нет"), time.time())
    assert s.count == 0 and s.newest is None


def test_load_health(tmp_path):
    assert report.load_health(str(tmp_path)) is None
    (tmp_path / "health.json").write_text("{битый")
    assert report.load_health(str(tmp_path)) is None
    (tmp_path / "health.json").write_text(json.dumps(healthy()))
    assert report.load_health(str(tmp_path))["ok"] is True


def test_no_problems_when_fresh():
    s = report.BackupSummary(3, "backup-20261112-023000.tar.gz", 2.0, 600)
    assert report.problems(s, healthy(), 5) == []


def test_problems_listed():
    stale = report.BackupSummary(1, "backup-20261110-023000.tar.gz", 30.0, 100)
    health = healthy()
    health["ok"] = False
    health["results"].append({"name": "http://localhost/", "ok": False, "detail": "HTTP 502"})
    issues = report.problems(stale, health, 5)
    assert len(issues) == 2
    assert any("http://localhost/" in i for i in issues)
    assert report.problems(report.BackupSummary(0, None, None, 0), None, None)


def test_render_status_line():
    s = report.BackupSummary(3, "backup-20261112-023000.tar.gz", 2.0, 600)
    now = time.time()
    assert "Статус: OK" in report.render(s, healthy(), [], 40, now)
    text = report.render(s, healthy(), ["нет свежего бэкапа"], 40, now)
    assert "Статус: ВНИМАНИЕ" in text and "нет свежего бэкапа" in text


def test_main_writes_dated_report(tmp_path, capsys):
    now = time.time()
    make_backup(tmp_path / "b", "backup-20261112-023000.tar.gz", 10, 1, now)
    (tmp_path / "s").mkdir()
    (tmp_path / "s" / "health.json").write_text(json.dumps(healthy()))
    env = {"BACKUP_DIR": str(tmp_path / "b"), "STATE_DIR": str(tmp_path / "s"), "REPORT_DIR": str(tmp_path / "r")}
    assert report.main(env) == 0
    path = capsys.readouterr().out.strip()
    assert os.path.basename(path).startswith("report-") and path.endswith(".md")
    assert "Статус: OK" in open(path, encoding="utf-8").read()
