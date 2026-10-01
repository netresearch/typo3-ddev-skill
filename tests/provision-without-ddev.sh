#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: Netresearch DTT GmbH
#
# tests/provision-without-ddev.sh — behavioural tests for
# skills/typo3-ddev/scripts/provision-without-ddev.sh.
#
# composer, php, curl, apache2ctl, a2enmod and sleep are replaced by stubs on
# PATH that log their arguments, so no package is downloaded, no database is
# contacted and no web server is started. The composer stub builds the few
# files of an instance the script touches (vendor/bin/typo3, the root-htaccess
# template). Requires bash and coreutils; the additional.php checks also need
# php and are skipped without it.

# The stub bodies are single-quoted on purpose: they expand $CALLS and $* when
# the stub runs, not when it is written.
# shellcheck disable=SC2016

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
SCRIPT="$ROOT/skills/typo3-ddev/scripts/provision-without-ddev.sh"

# The real php, looked up before the stub directory shadows it.
REAL_PHP="$(command -v php || true)"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

STUBS="$WORK/stubs"
CALLS="$WORK/calls.log"
mkdir -p "$STUBS"

stub() { # stub <name> <body>
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$STUBS/$1"
    chmod +x "$STUBS/$1"
}

stub composer 'echo "composer $*" >>"$CALLS"
if [ "$1" = create-project ]; then
    dir="$3"
    mkdir -p "$dir/vendor/bin" "$dir/public" "$dir/var" \
        "$dir/vendor/typo3/cms-install/Resources/Private/FolderStructureTemplateFiles"
    printf "# root-htaccess\n" \
        >"$dir/vendor/typo3/cms-install/Resources/Private/FolderStructureTemplateFiles/root-htaccess"
    printf "#!/usr/bin/env bash\necho \"typo3 \$*\" >>\"\$CALLS\"\n" >"$dir/vendor/bin/typo3"
    chmod +x "$dir/vendor/bin/typo3"
fi'
stub php 'echo "php-stub" >>"$CALLS"'
stub curl 'echo "curl $*" >>"$CALLS"
[ "${CURL_MODE:-ok}" = ok ]'
stub apache2ctl 'echo "apache2ctl $*" >>"$CALLS"'
stub a2enmod 'echo "a2enmod $*" >>"$CALLS"'
stub sleep ':'

export CALLS

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

status() { # status <command...> — prints 0 when the command succeeds, else 1
    if "$@"; then echo 0; else echo 1; fi
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

expect_no_line() { # expect_no_line <description> <fixed string>
    local ok=0
    if grep -qF -- "$2" <<<"$OUT"; then ok=1; fi
    report "$1" "$ok" "unexpected line: $2"
}

expect_file_line() { # expect_file_line <description> <file> <fixed string>
    local ok=0
    grep -qF -- "$3" "$2" 2>/dev/null || ok=1
    report "$1" "$ok" "$2 lacks: $3"
}

# extension <name> [ddev project name] — a fixture extension directory.
extension() {
    local dir="$WORK/$1"
    mkdir -p "$dir"
    printf '{\n    "name": "vendor/%s",\n    "type": "typo3-cms-extension"\n}\n' "$1" >"$dir/composer.json"
    if [ -n "${2:-}" ]; then
        mkdir -p "$dir/.ddev/commands/web"
        printf 'name: "%s"\ntype: php\n' "$2" >"$dir/.ddev/config.yaml"
        printf '#!/bin/bash\n' >"$dir/.ddev/commands/web/install-v13"
    fi
    printf '%s\n' "$dir"
}

# run [args...] — runs the script with the stubs first on PATH. Environment
# assignments are made by the caller with `env`.
run() {
    : >"$CALLS"
    OUT=$(PATH="$STUBS:$PATH" "$@" 2>&1)
    RC=$?
}

echo "argument handling"

run bash "$SCRIPT" --help
expect_exit "--help exits 0" 0
first="$(head -n1 <<<"$OUT")"
report "--help starts with the description" "$(status [ "$first" = "Bring up a TYPO3 instance from a project's DDEV configuration, without DDEV." ])" "first line: $first"
expect_no_line "--help does not print the licence notice" "SPDX"
expect_no_line "--help does not print shellcheck directives" "shellcheck"
expect_line "--help lists --extension" "--extension PATH"

run bash "$SCRIPT" --bogus
expect_exit "an unknown argument exits 2" 2
expect_line "an unknown argument is named" "unknown argument: --bogus"

run env DB_PASSWORD=x TYPO3_ADMIN_PASSWORD=y bash "$SCRIPT"
expect_exit "a missing --extension exits 2" 2
expect_line "a missing --extension is named" "--extension is required"

run env DB_PASSWORD=x TYPO3_ADMIN_PASSWORD=y bash "$SCRIPT" --extension "$WORK/nowhere"
expect_exit "a missing extension directory exits 2" 2
expect_line "a missing extension directory is named" "no such extension directory: $WORK/nowhere"

ext="$(extension plain)"
run env -u DB_PASSWORD TYPO3_ADMIN_PASSWORD=y bash "$SCRIPT" --extension "$ext"
expect_exit "an unset DB_PASSWORD exits 2" 2
expect_line "an unset DB_PASSWORD is named" "DB_PASSWORD is not set"

run env -u TYPO3_ADMIN_PASSWORD DB_PASSWORD=x bash "$SCRIPT" --extension "$ext"
expect_exit "a missing admin password exits 2" 2
expect_line "a missing admin password is named" "--admin-password or TYPO3_ADMIN_PASSWORD required"

nameless="$WORK/nameless"
mkdir -p "$nameless"
printf '{ "type": "typo3-cms-extension" }\n' >"$nameless/composer.json"
run env DB_PASSWORD=x TYPO3_ADMIN_PASSWORD=y bash "$SCRIPT" --extension "$nameless" --instance "$WORK/i-nameless"
expect_exit "a composer.json without a name exits 1" 1
expect_line "a composer.json without a name is named" "no package name in $nameless/composer.json"
report "nothing is installed without a package name" "$(status [ ! -s "$CALLS" ])" "calls were made"

echo "instance from the DDEV configuration"

ext="$(extension my-ext my-project)"
inst="$WORK/i-ddev"
password="it's a \\ secret"
run env DB_PASSWORD="$password" DB_HOST=db DB_NAME=typo3db DB_USER=typo3user \
    bash "$SCRIPT" --extension "$ext" --instance "$inst" --admin-password 'adm1n!'
expect_exit "a run without --serve exits 0" 0
expect_line "the project name is read from .ddev/config.yaml" "project (from .ddev/config.yaml): my-project"
expect_line "the project's install recipes are listed" ".ddev/commands/web/install-v13"
expect_file_line "the base distribution is created at the default constraint" "$CALLS" "composer create-project typo3/cms-base-distribution:^13.4 $inst"
expect_file_line "the extension is added as a path repository" "$CALLS" "composer config repositories.extension path $ext"
expect_file_line "the extension package is required" "$CALLS" "composer require vendor/my-ext:@dev"
expect_file_line "typo3 setup receives the admin password" "$CALLS" "--admin-user-password=adm1n!"
expect_file_line "typo3 setup receives the database host" "$CALLS" "--host=db"
expect_file_line "the extension is set up" "$CALLS" "typo3 extension:setup"
site="$inst/config/sites/my-project/config.yaml"
expect_file_line "the site is named after the DDEV project" "$site" "base: 'http://my-project.ddev.site/'"
expect_file_line "trustedHostsPattern is written" "$inst/config/system/additional.php" "trustedHostsPattern'] = '.*'"
report "no web server is touched without --serve" "$(! grep -qE '^(apache2ctl|a2enmod|curl) ' "$CALLS"; echo $?)" "a web server call was made"
expect_line "the run ends with the instance path" "=== instance ready at $inst (host: my-project.ddev.site)"

if [ -n "$REAL_PHP" ]; then
    lint="$("$REAL_PHP" -l "$inst/config/system/additional.php" 2>&1)"
    report "additional.php parses with a quote and a backslash in the password" "$(grep -q 'No syntax errors' <<<"$lint"; echo $?)" "$lint"
    # shellcheck disable=SC2016  # PHP code, expanded by php, not by the shell
    read_back="$("$REAL_PHP" -r '
        $GLOBALS["TYPO3_CONF_VARS"] = [];
        include $argv[1];
        $c = $GLOBALS["TYPO3_CONF_VARS"]["DB"]["Connections"]["Default"];
        echo $c["host"], "|", $c["dbname"], "|", $c["user"], "|", $c["password"];
    ' "$inst/config/system/additional.php" 2>&1)"
    expected="db|typo3db|typo3user|$password"
    report "additional.php holds the database settings unchanged" "$(status [ "$read_back" = "$expected" ])" "read back: $read_back"
else
    echo "  skip additional.php checks: php is not installed"
fi

echo "hostname and scheme"

ext="$(extension other-ext)"
inst="$WORK/i-host"
run env DB_PASSWORD=x TYPO3_ADMIN_PASSWORD=y SITE_SCHEME=https \
    bash "$SCRIPT" --extension "$ext" --instance "$inst" --hostname example.test --typo3 '^14.3'
expect_exit "a run with --hostname exits 0" 0
expect_file_line "--typo3 sets the constraint" "$CALLS" "composer create-project typo3/cms-base-distribution:^14.3 $inst"
expect_file_line "--hostname and SITE_SCHEME form the site base" "$inst/config/sites/main/config.yaml" "base: 'https://example.test/'"

inst="$WORK/i-local"
run env DB_PASSWORD=x TYPO3_ADMIN_PASSWORD=y bash "$SCRIPT" --extension "$ext" --instance "$inst"
expect_exit "a run without DDEV configuration exits 0" 0
expect_file_line "without DDEV configuration the site is localhost under 'main'" "$inst/config/sites/main/config.yaml" "base: 'http://localhost/'"

echo "serving"

ext="$(extension served-ext served)"
inst="$WORK/i-serve"
vhost="$WORK/000-default.conf"
run env DB_PASSWORD=x TYPO3_ADMIN_PASSWORD=y APACHE_SITE_CONF="$vhost" \
    bash "$SCRIPT" --extension "$ext" --instance "$inst" --serve
expect_exit "--serve with an answering backend exits 0" 0
expect_file_line "the framework's .htaccess is copied" "$inst/public/.htaccess" "# root-htaccess"
expect_file_line "the virtual host names the site" "$vhost" "ServerName served.ddev.site"
expect_file_line "the virtual host serves public/" "$vhost" "DocumentRoot $inst/public"
expect_file_line "mod_rewrite is enabled" "$CALLS" "a2enmod rewrite"
expect_file_line "Apache is started" "$CALLS" "apache2ctl -k start"
expect_file_line "the login route is probed on loopback with a time limit" "$CALLS" "curl --connect-timeout 2 --max-time 5 -fsS -o /dev/null http://127.0.0.1/typo3/login"
expect_line "the answering backend is reported" "backend answers at http://served.ddev.site/typo3/"

inst="$WORK/i-serve-down"
run env DB_PASSWORD=x TYPO3_ADMIN_PASSWORD=y APACHE_SITE_CONF="$vhost" CURL_MODE=fail \
    bash "$SCRIPT" --extension "$ext" --instance "$inst" --serve
expect_exit "--serve with a backend that never answers exits 1" 1
expect_line "the unanswered login route is named" "the backend login route did not answer at http://127.0.0.1/typo3/login"
expect_no_line "an unanswered backend is not reported ready" "=== instance ready"
probes="$(grep -c '^curl ' "$CALLS")"
report "the login route is probed 30 times before giving up" "$(status [ "$probes" -eq 30 ])" "probed $probes times"

inst="$WORK/i-serve-https"
run env DB_PASSWORD=x TYPO3_ADMIN_PASSWORD=y APACHE_SITE_CONF="$vhost" SITE_SCHEME=https \
    bash "$SCRIPT" --extension "$ext" --instance "$inst" --serve
expect_exit "--serve behind a TLS-terminating proxy exits 0" 0
expect_file_line "SITE_SCHEME=https still probes port 80 over HTTP" "$CALLS" "curl --connect-timeout 2 --max-time 5 -fsS -o /dev/null http://127.0.0.1/typo3/login"
expect_line "the public https URL is reported" "backend answers at https://served.ddev.site/typo3/"

echo
if [ "$fail" -ne 0 ]; then
    echo "provision-without-ddev: FAILED ($count checks)"
    exit 1
fi
echo "provision-without-ddev: all $count checks passed"
