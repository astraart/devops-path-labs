from conftest import run_script


def make_backups(d, n):
    d.mkdir(parents=True, exist_ok=True)
    names = [f"backup-202611{day:02d}-023000.tar.gz" for day in range(1, n + 1)]
    for name in names:
        (d / name).write_bytes(b"x")
        (d / (name + ".sha256")).write_text(f"0  {name}\n")
    return names


def test_keeps_newest(tmp_path):
    d = tmp_path / "backups"
    names = make_backups(d, 10)
    (d / "notes.txt").write_text("не бэкап\n")
    r = run_script("rotate.sh", BACKUP_DIR=str(d), KEEP="3")
    assert r.returncode == 0, r.stderr
    left = sorted(p.name for p in d.glob("backup-*.tar.gz"))
    assert left == names[-3:]
    assert sorted(p.name for p in d.glob("*.sha256")) == [n + ".sha256" for n in names[-3:]]
    assert (d / "notes.txt").exists(), "чужие файлы трогать нельзя"


def test_fewer_than_keep_is_noop(tmp_path):
    d = tmp_path / "backups"
    names = make_backups(d, 2)
    r = run_script("rotate.sh", BACKUP_DIR=str(d), KEEP="7")
    assert r.returncode == 0, r.stderr
    assert sorted(p.name for p in d.glob("backup-*.tar.gz")) == names


def test_bad_keep_deletes_nothing(tmp_path):
    d = tmp_path / "backups"
    make_backups(d, 5)
    for keep in ["0", "-1", "abc", "3x", "007x"]:
        r = run_script("rotate.sh", BACKUP_DIR=str(d), KEEP=keep)
        assert r.returncode == 2, f"KEEP={keep!r}: код {r.returncode}"
        assert len(list(d.glob("backup-*.tar.gz"))) == 5


def test_directory_with_spaces(tmp_path):
    d = tmp_path / "мои бэкапы"
    names = make_backups(d, 4)
    r = run_script("rotate.sh", BACKUP_DIR=str(d), KEEP="1")
    assert r.returncode == 0, r.stderr
    assert [p.name for p in d.glob("backup-*.tar.gz")] == names[-1:]
