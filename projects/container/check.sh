#!/usr/bin/env bash
# Проверка проекта 2 «Сервис в контейнере с пайплайном» (project.container). Только читает:
# репозиторий ученика (Dockerfile, CI, README, git), образ и контейнер (docker image inspect,
# docker inspect) и ответы сервиса на localhost:8080.
# Запуск: ./projects/container/check.sh ЧИСЛО [ПУТЬ_К_РЕПОЗИТОРИЮ]   (по умолчанию ~/notes-api)
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init project.container "$@"

REPO="${2:-$H/notes-api}"
IMAGE=notes-api:local
CONTAINER=notes-api
echo "Репозиторий: $REPO"
echo

git_ok() {
    local n dirty
    n="$(as_user git -C "$REPO" rev-list --count HEAD)" || return 1
    dirty="$(as_user git --no-optional-locks -C "$REPO" status --porcelain)" || return 1
    [[ "$n" -ge 5 && -z "$dirty" ]]
}

readme_ok() {
    local f="$REPO/README.md" sections
    [[ -f "$f" ]] || return 1
    sections="$(grep -c '^## ' "$f")" || return 1
    # значок пайплайна: GitHub Actions (…/badge.svg) или GitLab (…/badges/…/pipeline.svg)
    [[ "$sections" -ge 4 ]] && grep -qE 'badge\.svg|/badges/[^)]*pipeline\.svg' "$f" && ! grep -q 'TODO' "$f"
}

# Две стадии и больше; каждый внешний образ с тегом или дайджестом и не latest; последняя стадия не от root.
# Разбор без исполнения: Dockerfile только читается.
dockerfile_ok() {
    [[ -f "$REPO/Dockerfile" ]] || return 1
    python3 -I - "$REPO/Dockerfile" <<'PY'
import re, sys
froms, stages, user = 0, set(), None
for line in open(sys.argv[1], encoding="utf-8"):
    m = re.match(r"\s*FROM\s+(?:--platform=\S+\s+)?(\S+)(?:\s+AS\s+(\S+))?", line, re.I)
    if m:
        ref, alias = m.group(1), m.group(2)
        froms += 1
        user = None
        if ref.lower() not in stages:
            last = ref.split("/")[-1]
            pinned = "@sha256:" in ref or (":" in last and not last.endswith(":latest"))
            if not pinned:
                sys.exit(1)
        if alias:
            stages.add(alias.lower())
        continue
    m = re.match(r"\s*USER\s+(\S+)", line, re.I)
    if m:
        user = m.group(1)
sys.exit(0 if froms >= 2 and user is not None and user.split(":")[0] not in ("root", "0") else 1)
PY
}

dockerignore_ok() { [[ -f "$REPO/.dockerignore" ]] && grep -qE '^/?\.git/?$' "$REPO/.dockerignore"; }

# Файлы пайплайна: GitHub Actions или GitLab CI.
ci_files() {
    local f
    for f in "$REPO"/.github/workflows/*.yml "$REPO"/.github/workflows/*.yaml "$REPO/.gitlab-ci.yml"; do
        [[ -f "$f" ]] && printf '%s\n' "$f"
    done
    return 0
}
ci_text() {
    local -a files=()
    mapfile -t files < <(ci_files)
    [[ ${#files[@]} -gt 0 ]] || return 1
    cat -- "${files[@]}"
}

ci_ok() {
    local ci
    ci="$(ci_text)" || return 1
    grep -q 'go test' <<<"$ci" && grep -qE 'docker/build-push-action|docker push|buildah push|kaniko' <<<"$ci"
}

ci_sha_tag_ok() {
    local ci
    ci="$(ci_text)" || return 1
    grep -qE 'type=sha|github\.sha|CI_COMMIT_SHA|CI_COMMIT_SHORT_SHA' <<<"$ci"
}

# Сторонние действия GitHub закреплены по полному хешу; для GitLab CI проверка не нужна.
pinned_ok() {
    local ci uses
    ci="$(ci_text)" || return 1
    uses="$(grep -E '^[[:space:]-]*uses:[[:space:]]' <<<"$ci" | grep -vE 'uses:[[:space:]]*\./' || true)"
    [[ -z "$uses" ]] && return 0
    ! grep -vqE '@[0-9a-f]{40}([[:space:]]|$)' <<<"$uses"
}

secrets_ok() {
    local log
    log="$(as_user git -C "$REPO" log -p --all)" || return 1
    ! grep -qiE 'BEGIN [A-Z ]*PRIVATE KEY|(password|passwd|token|secret)[[:space:]]*[:=][[:space:]]*[^[:space:]$]{6,}|gh[pousr]_[A-Za-z0-9]{30,}|glpat-[A-Za-z0-9_-]{20,}' <<<"$log"
}

# docker без sudo, если ученик в группе docker; иначе через sudo без пароля, иначе «?».
dk() {
    if docker info >/dev/null 2>&1; then
        docker "$@"
    else
        as_root docker "$@"
    fi
}

image_user_ok() {
    local user
    command -v docker >/dev/null || return 1
    user="$(dk image inspect -f '{{.Config.User}}' "$IMAGE")" || return $?
    [[ -n "$user" && "${user%%:*}" != root && "${user%%:*}" != 0 ]]
}

image_size_ok() {
    local size
    command -v docker >/dev/null || return 1
    size="$(dk image inspect -f '{{.Size}}' "$IMAGE")" || return $?
    [[ "$size" -lt 50000000 ]]
}

healthy_ok() {
    local st
    command -v docker >/dev/null || return 1
    st="$(dk inspect -f '{{.State.Status}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' "$CONTAINER")" || return $?
    [[ "$st" == "running healthy" ]]
}

healthz_ok() { curl -fsS --max-time 3 http://127.0.0.1:8080/healthz >/dev/null; }

version_ok() {
    local v
    v="$(curl -fsS --max-time 3 http://127.0.0.1:8080/version)" || return 1
    grep -q '"version"' <<<"$v" && ! grep -q '"version":"dev"' <<<"$v"
}

volume_ok() {
    local mounts
    command -v docker >/dev/null || return 1
    mounts="$(dk inspect -f '{{range .Mounts}}{{.Type}}:{{.Destination}} {{end}}' "$CONTAINER")" || return $?
    grep -q 'volume:/data ' <<<"$mounts"
}

check 0 "репозиторий git: не меньше 5 коммитов, всё закоммичено" git_ok
check 1 "README: значок пайплайна, от 4 разделов, не осталось TODO" readme_ok
check 2 "Dockerfile: две стадии, версии образов закреплены, запуск не от root" dockerfile_ok
check 3 ".dockerignore исключает .git" dockerignore_ok
check 4 "пайплайн запускает go test и публикует образ" ci_ok
check 5 "образ в пайплайне помечается хешем коммита" ci_sha_tag_ok
check 6 "действия GitHub закреплены по полному хешу (для GitLab не нужно)" pinned_ok
check 7 "в истории git нет ключей, токенов и паролей" secrets_ok
check 8 "образ notes-api:local запускается не от root" image_user_ok
check 9 "образ меньше 50 МБ" image_size_ok
check 10 "контейнер notes-api работает, healthcheck — healthy" healthy_ok
check 11 "сервис отвечает на localhost:8080/healthz" healthz_ok
check 12 "/version показывает версию из сборки, а не dev" version_ok
check 13 "заметки в именованном томе /data" volume_ok

manual "пайплайн зелёный на main, образ в реестре с тегом-хешем коммита"
manual "в pull request образ собирается, но не публикуется"
manual "сканер уязвимостей в пайплайне: CRITICAL делает его красным"
manual "тег v1.0.0 публикует образ с версией 1.0.0"
manual "README объясняет запуск, настройки и выпуск релиза"
lab_finish
