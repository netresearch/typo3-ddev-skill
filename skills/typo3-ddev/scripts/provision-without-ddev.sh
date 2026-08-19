#!/usr/bin/env bash
# Bring up a TYPO3 instance from a project's DDEV configuration, without DDEV.
#
# For environments that are already a container — CI, a devcontainer, an agent
# harness — where DDEV cannot run without being handed the host's Docker
# socket. The DDEV configuration is still the source of truth: this reads the
# project name, the PHP version and the hostnames from it, and carries out the
# same installation its .ddev/commands/ recipe describes.
#
# See references/without-ddev.md for the reasoning behind each step and for the
# traps that are not obvious: the missing .htaccess, the database host under a
# shared network namespace, and /etc/hosts being rewritten at container start.
#
# Usage:
#   provision-without-ddev.sh --extension /path/to/extension [options]
#
#   --extension PATH     extension to install as a path repository (required)
#   --instance PATH      where to build the instance          (default /instance)
#   --typo3 CONSTRAINT   TYPO3 version                        (default ^13.4)
#   --hostname HOST      host the instance is served under    (default from .ddev)
#   --serve              configure and start Apache as well
#   --admin-password PW  backend admin password               (default from env)
#
# Database settings come from the environment: DB_HOST, DB_NAME, DB_USER,
# DB_PASSWORD. DB_HOST defaults to 127.0.0.1 rather than a service name,
# because a shared network namespace is the common case in these environments
# and a wrong host fails late, during `typo3 setup`, as a driver exception.
set -euo pipefail

# The header comment is the help text, read from the file rather than repeated
# in a string: a fixed line range drifts the moment anything is inserted above,
# and this one already did — it began printing the shellcheck directive.
usage() {
    awk 'NR > 1 {
        if ($0 !~ /^#/) exit
        if ($0 ~ /shellcheck/) next
        sub(/^# ?/, "")
        print
    }' "$0"
}

EXTENSION=""
INSTANCE=/instance
TYPO3_CONSTRAINT="^13.4"
HOSTNAME_OVERRIDE=""
SERVE=0
ADMIN_PASSWORD="${TYPO3_ADMIN_PASSWORD:-}"

DB_HOST="${DB_HOST:-127.0.0.1}"
DB_NAME="${DB_NAME:-typo3}"
DB_USER="${DB_USER:-typo3}"
DB_PASSWORD="${DB_PASSWORD:-}"

while [ $# -gt 0 ]; do
    case "$1" in
        --extension)       EXTENSION="$2"; shift 2 ;;
        --instance)        INSTANCE="$2"; shift 2 ;;
        --typo3)           TYPO3_CONSTRAINT="$2"; shift 2 ;;
        --hostname)        HOSTNAME_OVERRIDE="$2"; shift 2 ;;
        --admin-password)  ADMIN_PASSWORD="$2"; shift 2 ;;
        --serve)           SERVE=1; shift ;;
        -h|--help)         usage; exit 0 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

[[ -n "$EXTENSION" ]] || { echo "--extension is required" >&2; exit 2; }
[[ -d "$EXTENSION" ]] || { echo "no such extension directory: $EXTENSION" >&2; exit 2; }
[[ -n "$DB_PASSWORD" ]] || { echo "DB_PASSWORD is not set" >&2; exit 2; }
[[ -n "$ADMIN_PASSWORD" ]] || { echo "--admin-password or TYPO3_ADMIN_PASSWORD required" >&2; exit 2; }

# --- what the project's own DDEV configuration says ---------------------------
CONFIG="$EXTENSION/.ddev/config.yaml"
PROJECT_NAME=""
if [[ -f "$CONFIG" ]]; then
    # Deliberately not a YAML parser: this needs two scalars and must not add a
    # dependency to an environment that may have neither yq nor python.
    PROJECT_NAME="$(sed -n 's/^name:[[:space:]]*//p' "$CONFIG" | head -1 | tr -d '"'"'"'')"
    echo "project (from .ddev/config.yaml): ${PROJECT_NAME:-unknown}"
    if [[ -d "$EXTENSION/.ddev/commands/web" ]]; then
        echo "the project ships install recipes; read them before deviating:"
        find "$EXTENSION/.ddev/commands/web" -maxdepth 1 -type f -printf '  .ddev/commands/web/%f\n'
    fi
fi

SITE_HOST="$HOSTNAME_OVERRIDE"
if [[ -z "$SITE_HOST" && -n "$PROJECT_NAME" ]]; then
    SITE_HOST="$PROJECT_NAME.ddev.site"
fi
SITE_HOST="${SITE_HOST:-localhost}"
# A locally provisioned instance has no certificate, so plain HTTP is the
# default. DDEV itself serves TLS through its router, and a deployment that
# terminates TLS sets SITE_SCHEME=https rather than editing this script.
SITE_SCHEME="${SITE_SCHEME:-http}"
SITE_IDENTIFIER="${PROJECT_NAME:-main}"

PACKAGE="$(sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$EXTENSION/composer.json" | head -1)"
[[ -n "$PACKAGE" ]] || { echo "no package name in $EXTENSION/composer.json" >&2; exit 1; }

# --- the instance -------------------------------------------------------------
echo "=== creating the project"
composer create-project "typo3/cms-base-distribution:$TYPO3_CONSTRAINT" "$INSTANCE" \
    --no-interaction --no-progress
cd "$INSTANCE"

echo "=== adding the extension as a path repository"
composer config repositories.extension path "$EXTENSION"
composer require "$PACKAGE:@dev" --no-interaction --no-progress

# --- the database connection, before setup ------------------------------------
echo "=== database connection"
mkdir -p config/system "config/sites/$SITE_IDENTIFIER"
cat > config/system/additional.php <<PHPCONF
<?php
\$GLOBALS['TYPO3_CONF_VARS']['DB']['Connections']['Default'] = [
    'charset' => 'utf8mb4',
    'driver' => 'mysqli',
    'host' => '${DB_HOST}',
    'port' => 3306,
    'dbname' => '${DB_NAME}',
    'user' => '${DB_USER}',
    'password' => '${DB_PASSWORD}',
];
\$GLOBALS['TYPO3_CONF_VARS']['SYS']['trustedHostsPattern'] = '.*';
PHPCONF

echo "=== waiting for the database"
for _ in $(seq 1 60); do
    # The PHP is deliberately unexpanded: it reads the connection settings from
    # the environment when it runs, not from the shell that writes it.
    # shellcheck disable=SC2016
    if php -r '
        $c = @mysqli_connect(getenv("DB_HOST") ?: "127.0.0.1", getenv("DB_USER"),
                             getenv("DB_PASSWORD"), getenv("DB_NAME"));
        exit($c ? 0 : 1);
    '; then break; fi
    sleep 2
done

echo "=== typo3 setup"
vendor/bin/typo3 setup \
    --driver=mysqli --host="$DB_HOST" --port=3306 --dbname="$DB_NAME" \
    --username="$DB_USER" --password="$DB_PASSWORD" \
    --admin-username=admin --admin-user-password="$ADMIN_PASSWORD" \
    --admin-email=admin@example.com \
    --project-name="${PROJECT_NAME:-TYPO3}" \
    --server-type=other --no-interaction --force

echo "=== extension setup"
vendor/bin/typo3 extension:setup

echo "=== site configuration"
cat > "config/sites/$SITE_IDENTIFIER/config.yaml" <<SITECONF
base: '$SITE_SCHEME://$SITE_HOST/'
rootPageId: 1
languages:
  -
    title: English
    enabled: true
    languageId: 0
    base: /
    locale: en_US.UTF-8
    navigationTitle: English
    flag: gb
SITECONF

# --- serving ------------------------------------------------------------------
if [[ "$SERVE" == "1" ]]; then
    echo "=== rewrite rules"
    # The composer distribution ships no .htaccess. Without it /typo3/ answers
    # 200 through DirectoryIndex while every sub-route 404s — a backend that
    # looks reachable and is not. Use the framework's own file; hand-written
    # rules route the backend into the frontend and hide the cause.
    cp vendor/typo3/cms-install/Resources/Private/FolderStructureTemplateFiles/root-htaccess \
        public/.htaccess

    echo "=== web server"
    cat > /etc/apache2/sites-available/000-default.conf <<VHOST
<VirtualHost *:80>
    ServerName $SITE_HOST
    ServerAlias localhost
    DocumentRoot $INSTANCE/public
    <Directory $INSTANCE/public>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
VHOST
    a2enmod rewrite > /dev/null
    chown -R www-data:www-data "$INSTANCE/var" "$INSTANCE/public" 2>/dev/null || true
    apache2ctl -k start

    # Verified by consequence: a 200 on /typo3/ can be reached by an instance
    # whose sub-routes all fail, so the login route is what gets checked.
    for _ in $(seq 1 30); do
        if curl -fsS -o /dev/null "$SITE_SCHEME://127.0.0.1/typo3/login"; then
            echo "backend answers at $SITE_SCHEME://$SITE_HOST/typo3/"
            break
        fi
        sleep 1
    done
fi

vendor/bin/typo3 cache:flush || true
echo "=== instance ready at $INSTANCE (host: $SITE_HOST)"
