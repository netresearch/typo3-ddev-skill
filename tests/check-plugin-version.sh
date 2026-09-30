#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
#
# tests/check-plugin-version.sh — behavioural tests for
# Build/Scripts/check-plugin-version.sh and the Build/hooks/pre-push hook
# that runs it.
#
# Each case builds a throwaway git repository with a .claude-plugin/plugin.json,
# tags HEAD and runs the script inside it. The user's git configuration is not
# read, so signing or hook settings cannot interfere. Requires bash, git and
# python3.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SCRIPT="$ROOT/Build/Scripts/check-plugin-version.sh"
HOOK="$ROOT/Build/hooks/pre-push"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

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

# repo <name> <plugin.json content> [tag...] — creates a repository with one
# commit, tags it and prints its path.
repo() {
    local dir="$WORK/$1" content="$2" tag
    shift 2
    mkdir -p "$dir/.claude-plugin"
    printf '%s\n' "$content" >"$dir/.claude-plugin/plugin.json"
    git -C "$dir" init -q
    git -C "$dir" add .claude-plugin/plugin.json
    git -C "$dir" -c user.name=test -c user.email=test@example.invalid commit -q -m init
    for tag in "$@"; do
        git -C "$dir" tag "$tag"
    done
    printf '%s\n' "$dir"
}

# run <dir> <command> — runs the command inside <dir>.
run() {
    OUT=$(cd "$1" && bash "$2" 2>&1)
    RC=$?
}

echo "check-plugin-version.sh"

dir=$(repo untagged '{"version": "1.2.3"}')
run "$dir" "$SCRIPT"
expect_exit "no tag at HEAD exits 0" 0

dir=$(repo prefixed '{"version": "1.2.3"}' v1.2.3)
run "$dir" "$SCRIPT"
expect_exit "a matching v-prefixed tag exits 0" 0

dir=$(repo bare '{"version": "1.2.3"}' 1.2.3)
run "$dir" "$SCRIPT"
expect_exit "a matching tag without prefix exits 0" 0

dir=$(repo nonsemver '{"version": "1.2.3"}' latest v1.2)
run "$dir" "$SCRIPT"
expect_exit "tags that are not semver are ignored" 0

dir=$(repo mismatch '{"version": "1.2.3"}' v1.2.4)
run "$dir" "$SCRIPT"
expect_exit "a tag that differs from plugin.json exits 1" 1
expect_line "the mismatch names the version" "plugin.json version (1.2.3) does not match any semver tag at HEAD"
expect_line "the mismatch lists the tag" "1.2.4"

dir=$(repo several '{"version": "1.2.3"}' v1.2.4 v1.2.3)
run "$dir" "$SCRIPT"
expect_exit "one matching tag among several is enough" 0

dir=$(repo broken '{"version": ' v1.2.3)
run "$dir" "$SCRIPT"
expect_exit "an unreadable plugin.json fails a tagged push" 1

echo "pre-push hook"

dir=$(repo hook-ok '{"version": "2.0.0"}' v2.0.0)
run "$dir" "$HOOK"
expect_exit "the hook passes a matching tag" 0

dir=$(repo hook-bad '{"version": "2.0.0"}' v2.0.1)
run "$dir" "$HOOK"
expect_exit "the hook fails a mismatching tag" 1
expect_line "the hook passes the script's message on" "does not match any semver tag at HEAD"

echo
if [ "$fail" -ne 0 ]; then
    echo "check-plugin-version: FAILED ($count checks)"
    exit 1
fi
echo "check-plugin-version: all $count checks passed"
