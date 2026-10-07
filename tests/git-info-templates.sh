#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
#
# tests/git-info-templates.sh — the templates that put the current git branch
# into the web container, a Compose file and the landing page take the branch
# name as text.
#
# Each case runs in a throw-away repository whose branch name holds quotes,
# a command substitution, sed and HTML metacharacters. A `ddev` stub runs the
# `ddev exec` command with a local bash, with /var/www/html pointed at the
# test directory. Requires bash, git, jq and sed.

# The $(...) and ${...} in the expected strings are data: they must stay literal.
# shellcheck disable=SC2016
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES="$(cd "$HERE/.." && pwd)/skills/typo3-ddev/assets/templates"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

fail=0
check() { # check <name> <expected> <actual>
    if [ "$2" = "$3" ]; then
        echo "  ok   $1"
    else
        echo "  FAIL $1: expected '$2', got '$3'"
        fail=1
    fi
}

# A valid branch name (git check-ref-format) that is also shell, sed and HTML.
BRANCH='x'"'"'$(touch${IFS}PWNED)|e<b>&"y;z'
REPO="$WORK/repo"
git init -q -b main "$REPO"
# The subject closes and reopens a CSS comment.
SUBJECT='First */ body{display:none} /* commit'
git -C "$REPO" -c user.email=t@example.org -c user.name=t -c commit.gpgsign=false commit -q --allow-empty -m "$SUBJECT"
git -C "$REPO" checkout -q -b "$BRANCH"

mkdir -p "$WORK/bin" "$WORK/html/.ddev"
cat >"$WORK/bin/ddev" <<'STUB'
#!/usr/bin/env bash
# `ddev exec <command>`: run the command as the web container would, with
# /var/www/html standing for $HTML.
[ "$1" = "exec" ] || exit 0
shift
cmd="$*"
exec bash -c "${cmd//\/var\/www\/html/$HTML}"
STUB
printf '#!/usr/bin/env bash\nexit 1\n' >"$WORK/bin/gh"
chmod +x "$WORK/bin/ddev" "$WORK/bin/gh"
export HTML="$WORK/html"
export PATH="$WORK/bin:$PATH"

echo "config.yaml post-start hook"
# The exec-host block, de-indented.
sed -n '/- exec-host: |/,$p' "$TEMPLATES/config.yaml" | sed '1d; s/^        //' >"$WORK/post-start.sh"
(cd "$REPO" && bash "$WORK/post-start.sh") >"$WORK/out" 2>&1
check "the hook succeeds" 0 "$?"
check "the branch name reaches .git-info.json as written" "$BRANCH" \
    "$(jq -r .branch "$HTML/.git-info.json" 2>/dev/null)"
check "the PR falls back to unknown" "unknown" "$(jq -r .pr "$HTML/.git-info.json" 2>/dev/null)"

echo "pre-start-git-info"
mkdir -p "$REPO/.ddev"
(cd "$REPO" && bash "$TEMPLATES/commands/host/pre-start-git-info") >"$WORK/out" 2>&1
check "the command succeeds" 0 "$?"
check "the branch is one double-quoted YAML scalar, \$ doubled for Compose" \
    '        GIT_BRANCH: "x'"'"'$$(touch$${IFS}PWNED)|e<b>&\"y;z"' \
    "$(grep 'GIT_BRANCH:' "$REPO/.ddev/docker-compose.git-info.yaml")"
check "the file has its three keys and nothing else" 3 \
    "$(grep -c '^        GIT_[A-Z]*: "' "$REPO/.ddev/docker-compose.git-info.yaml")"

echo "generate-index"
cp "$TEMPLATES/index.html.typo3.template" "$HTML/.ddev/"
(cd "$REPO" && GENERATE_INDEX_ROOT="$HTML" bash "$TEMPLATES/commands/web/generate-index") >"$WORK/out" 2>&1
check "the command succeeds" 0 "$?"
check "the branch is shown as text" 1 \
    "$(grep -cF '<span class="git-branch">x&#39;$(touch${IFS}PWNED)|e&lt;b&gt;&amp;&quot;y;z</span>' "$HTML/index.html")"
check "no placeholder is left" 0 "$(grep -c '{{GIT_BRANCH}}' "$HTML/index.html")"
check "the commit subject appears only as page text, not in the stylesheet" \
    '<span class="git-commit-msg">'"$SUBJECT"'</span>' \
    "$(grep -F "$SUBJECT" "$HTML/index.html" | sed 's/^ *//')"

check "nothing named in the branch ran" "absent" \
    "$(find "$WORK" -name PWNED | grep -q . && echo present || echo absent)"

echo
if [ "$fail" -eq 0 ]; then
    echo "All git-info template tests passed"
else
    echo "Some git-info template tests FAILED"
fi
exit "$fail"
