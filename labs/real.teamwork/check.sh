#!/usr/bin/env bash
# Проверка практики «Репозиторий, с которым удобно работать команде» (real.teamwork). Только читает файлы репозитория.
# Запуск: ./labs/real.teamwork/check.sh ЧИСЛО [ПУТЬ_К_РЕПОЗИТОРИЮ]
set -euo pipefail
# shellcheck source=../../lib/common.sh
source "$(dirname "$0")/../../lib/common.sh"
lab_init real.teamwork "$@"

REPO="${2:-$H/team-lab}"
readme() { local n; n="$(grep -c '^## ' "$REPO/README.md")"; [[ "$n" -ge 4 ]]; }
runbook() { grep -qiE '^## (эскалация|escalation)' "$REPO"/docs/runbook/*.md; }
adr() {
    local f s
    f="$(find "$REPO/docs/adr" -maxdepth 1 -name '0001-*.md' | head -n 1)"
    [[ -n "$f" ]] || return 1
    for s in Status Context Decision Consequences; do grep -q "^## $s" "$f" || return 1; done
}
templates() {
    local n
    n="$(find "$REPO/.github/ISSUE_TEMPLATE" -maxdepth 1 -name '*.md' | wc -l)"
    [[ "$n" -ge 1 && -f "$REPO/.github/pull_request_template.md" ]]
}
commits() {
    local subjects n
    subjects="$(as_user git -C "$REPO" log --format=%s)"
    n="$(wc -l <<<"$subjects")"
    [[ "$n" -ge 3 ]] || return 1
    ! grep -qE '^(Added|Fixed|Updated|Changed|Removed|Deleted|Created)\b' <<<"$subjects"
}

check 0 "README: 4 раздела или больше" readme
check 1 "в runbook есть раздел эскалации" runbook
check 2 "ADR 0001 с разделами Status, Context, Decision, Consequences" adr
check 3 "шаблоны issue и pull request" templates
check 4 "3 коммита или больше, без Added/Fixed/Updated в начале" commits
manual "pull request с «Closes #1» влит, issue закрылся сам"
lab_finish
