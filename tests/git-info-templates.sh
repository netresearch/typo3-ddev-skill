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
# The subject closes and reopens a CSS comment and holds a sed back-reference.
SUBJECT='First */ body{display:none} /* fix \1 commit'
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
check "the file has its three keys and nothing else" \
    "$(printf '%s\n' services: '  web:' '    build:' '      args:' '        GIT_BRANCH: V' '        GIT_COMMIT: V' '        GIT_PR: V')" \
    "$(sed -E 's/^(        GIT_[A-Z]+): ".*"$/\1: V/' "$REPO/.ddev/docker-compose.git-info.yaml")"

echo "generate-index"
cp "$TEMPLATES/index.html.typo3.template" "$HTML/.ddev/"
cat >"$HTML/composer.json" <<'JSON'
{"name": "vendor/my-ext", "description": "Uses <b>bold</b> & {{GIT_BRANCH}}\nmore", "extra": {"typo3": {"extension-key": "my_ext"}}}
JSON
(cd "$REPO" && GENERATE_INDEX_ROOT="$HTML" bash "$TEMPLATES/commands/web/generate-index") >"$WORK/out" 2>&1
check "the command succeeds" 0 "$?"
check "the branch is shown as text" 1 \
    "$(grep -cF '<span class="git-branch">x&#39;$(touch$&#123;IFS}PWNED)|e&lt;b&gt;&amp;&quot;y;z</span>' "$HTML/index.html")"
check "no placeholder is left" 0 "$(grep -c '{{GIT_BRANCH}}' "$HTML/index.html")"
SUBJECT_HTML=${SUBJECT//\{/"&#123;"}
check "the commit subject appears only as page text, not in the stylesheet" \
    '<span class="git-commit-msg">'"$SUBJECT_HTML"'</span>' \
    "$(grep -F "fix \\1 commit" "$HTML/index.html" | sed 's/^ *//')"

check "the composer.json description is shown as text, on one line, with no placeholder filled" 1 \
    "$(grep -cF '<p class="header-description">Uses &lt;b&gt;bold&lt;/b&gt; &amp; &#123;&#123;GIT_BRANCH}} more</p>' "$HTML/index.html")"

# A branch without a double quote: with one, the old hook's command did not
# even parse, so it could not show that a command in the name runs.
echo "config.yaml post-start hook, branch without a double quote"
BRANCH2='y'"'"'$(touch${IFS}PWNED)'"'"''
git -C "$REPO" checkout -q -b "$BRANCH2"
(cd "$REPO" && bash "$WORK/post-start.sh") >"$WORK/out" 2>&1
check "the hook succeeds" 0 "$?"
check "the branch name reaches .git-info.json as written" "$BRANCH2" \
    "$(jq -r .branch "$HTML/.git-info.json" 2>/dev/null)"

check "nothing named in a branch ran" "absent" \
    "$(find "$WORK" -name PWNED | grep -q . && echo present || echo absent)"

echo
if [ "$fail" -eq 0 ]; then
    echo "All git-info template tests passed"
else
    echo "Some git-info template tests FAILED"
fi
exit "$fail"
