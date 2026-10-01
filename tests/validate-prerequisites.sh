#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
#
# tests/validate-prerequisites.sh — behavioural tests for
# skills/typo3-ddev/scripts/validate-prerequisites.sh.
#
# docker and ddev are stubs whose answers are set per case through
# environment variables; PATH holds only the stubs and the few tools the
# script calls (cut, grep, head), so an installed Docker or DDEV cannot leak
# into a result. Requires bash, cut, grep and head.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SCRIPT="$ROOT/skills/typo3-ddev/scripts/validate-prerequisites.sh"
BASH_BIN="$(command -v bash)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

BIN="$WORK/bin"
mkdir -p "$BIN"
for tool in cut grep head; do
    ln -s "$(command -v "$tool")" "$BIN/$tool"
done

# docker: STUB_DOCKER_INFO=ok|fail, STUB_DOCKER_VERSION (empty = not
# installed), STUB_COMPOSE_VERSION (empty = no compose plugin).
# The stubs name bash by its absolute path: PATH holds no env to resolve it.
{
    printf '#!%s\n' "$BASH_BIN"
    cat <<'STUB'
case "$1" in
    info) [ "${STUB_DOCKER_INFO:-ok}" = ok ] ;;
    version) [ -n "${STUB_DOCKER_VERSION:-}" ] && echo "$STUB_DOCKER_VERSION" ;;
    compose) [ -n "${STUB_COMPOSE_VERSION:-}" ] && echo "$STUB_COMPOSE_VERSION" ;;
    *) exit 1 ;;
esac
STUB
} >"$BIN/docker"
printf '#!%s\necho "ddev version v1.24.3"\n' "$BASH_BIN" >"$BIN/ddev-stub"
chmod +x "$BIN/docker" "$BIN/ddev-stub"

fail=0
count=0
OUT=""
RC=0

report() { # report <description> <ok 0|1> [detail]
    count=$((count + 1))
    if [ "$2" -eq 0 ]; then
        echo "  ok   $1"
    else
        echo "  FAIL $1${3:+ ($3)}"
        printf '%s\n' "$OUT" | sed 's/^/         /'
        fail=1
    fi
}

expect_exit() { # expect_exit <description> <expected exit>
    local ok=0
    [ "$RC" -eq "$2" ] || ok=1
    report "$1" "$ok" "expected exit $2, got $RC"
}

expect_line() { # expect_line <description> <fixed string>
    local ok=0
    grep -qF -- "$2" <<<"$OUT" || ok=1
    report "$1" "$ok" "missing line: $2"
}

# project <name> <kind> — an empty directory, one with ext_emconf.php, or one
# whose composer.json declares a TYPO3 extension.
project() {
    local dir="$WORK/$1"
    mkdir -p "$dir"
    case "$2" in
        emconf) printf '<?php\n' >"$dir/ext_emconf.php" ;;
        composer) printf '{ "type": "typo3-cms-extension" }\n' >"$dir/composer.json" ;;
    esac
    printf '%s\n' "$dir"
}

# run <dir> <with ddev: yes|no> [VAR=value...] — runs the script in <dir>.
run() {
    local dir="$1" ddev="$2"
    shift 2
    rm -f "$BIN/ddev"
    if [ "$ddev" = yes ]; then
        ln -s "$BIN/ddev-stub" "$BIN/ddev"
    fi
    OUT=$(cd "$dir" && env -i PATH="$BIN" STUB_DOCKER_VERSION=27.3.1 STUB_COMPOSE_VERSION=2.29.7 "$@" \
        "$BASH_BIN" "$SCRIPT" 2>&1)
    RC=$?
}

ext="$(project ext emconf)"
plain="$(project plain none)"

echo "all prerequisites present"

run "$ext" yes
expect_exit "a complete environment exits 0" 0
expect_line "the Docker version is reported" "27.3.1 (>= 20.10)"
expect_line "the Compose version is reported" "2.29.7 (>= 2.0)"
expect_line "the DDEV version is reported" "v1.24.3"
expect_line "ext_emconf.php is detected" "Detected"
expect_line "success is reported" "All prerequisites validated successfully!"

run "$(project composer-ext composer)" yes
expect_line "a composer.json of type typo3-cms-extension is detected" "Detected"

run "$plain" yes
expect_exit "a directory without an extension still exits 0" 0
expect_line "a missing extension is only a warning" "Not detected (optional check)"

echo "Docker version boundary"

run "$ext" yes STUB_DOCKER_VERSION=20.10.0
expect_exit "Docker 20.10 is accepted" 0
run "$ext" yes STUB_DOCKER_VERSION=21.0.0
expect_exit "Docker 21.0 is accepted" 0
run "$ext" yes STUB_DOCKER_VERSION=20.9.5
expect_exit "Docker 20.9 is rejected" 1
expect_line "Docker 20.9 names the minimum" "20.9.5 (need >= 20.10)"
run "$ext" yes STUB_DOCKER_VERSION=19.12.0
expect_exit "Docker 19.12 is rejected" 1

echo "missing prerequisites"

run "$ext" yes STUB_DOCKER_INFO=fail
expect_exit "a stopped Docker daemon exits 1" 1
expect_line "a stopped Docker daemon is reported" "Docker daemon is not running"

run "$ext" yes STUB_DOCKER_VERSION=
expect_exit "a missing Docker CLI exits 1" 1
expect_line "a missing Docker CLI is reported" "Not installed"

run "$ext" yes STUB_COMPOSE_VERSION=1.29.2
expect_exit "Compose v1 exits 1" 1
expect_line "Compose v1 names the minimum" "1.29.2 (need >= 2.0)"

run "$ext" yes STUB_COMPOSE_VERSION=
expect_exit "a missing Compose plugin exits 1" 1
expect_line "a missing Compose plugin is reported" "Install Docker Compose v2"

run "$ext" no
expect_exit "a missing DDEV exits 1" 1
expect_line "a missing DDEV comes with install instructions" "Install DDEV:"
expect_line "failure is reported" "Prerequisites validation failed"

echo
if [ "$fail" -ne 0 ]; then
    echo "validate-prerequisites: FAILED ($count checks)"
    exit 1
fi
echo "validate-prerequisites: all $count checks passed"
