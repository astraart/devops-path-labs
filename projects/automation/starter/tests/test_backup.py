import re
import subprocess
import tarfile
import time

from conftest import run_script

NAME = re.compile(r"backup-\d{8}-\d{6}\.tar\.gz$")


def make_sources(tmp_path):
    src = tmp_path / "src"
    (src / "sub").mkdir(parents=True)
    (src / "a.txt").write_text("alpha\n")
    (src / "sub" / "b.txt").write_text("beta\n")
    return src


def test_creates_verified_archive(tmp_path):
    src = make_sources(tmp_path)
    dest = tmp_path / "backups"
    r = run_script("backup.sh", BACKUP_SOURCES=str(src), BACKUP_DIR=str(dest))
    assert r.returncode == 0, r.stderr
    archive = r.stdout.strip().splitlines()[-1]
    assert NAME.search(archive), archive
    with tarfile.open(archive) as t:
        names = t.getnames()
    assert any(n.endswith("src/a.txt") for n in names), names
    assert any(n.endswith("src/sub/b.txt") for n in names), names
    assert not any(n.startswith("/") for n in names), "пути в архиве должны быть без ведущего /"
    check = subprocess.run(["sha256sum", "-c", archive.rsplit("/", 1)[1] + ".sha256"], cwd=dest)
    assert check.returncode == 0


def test_archive_and_checksum_are_private(tmp_path):
    src = make_sources(tmp_path)
    dest = tmp_path / "backups"
    r = run_script("backup.sh", BACKUP_SOURCES=str(src), BACKUP_DIR=str(dest))
    assert r.returncode == 0, r.stderr
    for f in dest.iterdir():
        assert f.stat().st_mode & 0o077 == 0, f"{f.name} доступен группе или всем"


def test_missing_source_fails_without_leftovers(tmp_path):
    src = make_sources(tmp_path)
    dest = tmp_path / "backups"
    missing = tmp_path / "nope"
    r = run_script("backup.sh", BACKUP_SOURCES=f"{src} {missing}", BACKUP_DIR=str(dest))
    assert r.returncode != 0
    assert str(missing) in r.stderr
    assert not dest.exists() or not list(dest.glob("backup-*")), "остался недописанный архив"


def test_two_runs_make_two_archives(tmp_path):
    src = make_sources(tmp_path)
    dest = tmp_path / "backups"
    assert run_script("backup.sh", BACKUP_SOURCES=str(src), BACKUP_DIR=str(dest)).returncode == 0
    time.sleep(1.1)
    assert run_script("backup.sh", BACKUP_SOURCES=str(src), BACKUP_DIR=str(dest)).returncode == 0
    assert len(list(dest.glob("backup-*.tar.gz"))) == 2
    assert len(list(dest.glob("backup-*.tar.gz.sha256"))) == 2
