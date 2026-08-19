# Provisioning the instance without DDEV

DDEV drives Docker. Where the agent is *already inside* a container — CI, a
benchmark harness, a devcontainer, a remote sandbox — DDEV cannot run without
handing that container the host's Docker socket, which is root-equivalent
control of the host and is not an acceptable price for a local instance.

The project's DDEV configuration is still the right source: it states the PHP
version, the database, the hostnames and, in `.ddev/commands/`, the exact
install recipe the maintainers use. Read it and carry it out directly.

`scripts/provision-without-ddev.sh` does this. What follows is what it does and
why each step is there, so the steps can be adapted rather than copied blindly.

## Read the configuration first, invent nothing

```bash
name=$(yq '.name' .ddev/config.yaml)                    # hostname stem
php=$(yq '.php_version' .ddev/config.yaml)              # image tag
hosts=$(yq '.additional_hostnames[]' .ddev/config.yaml) # v13.<name>, docs.<name>, …
ls .ddev/commands/web/                                  # install-v13, install-v14, …
```

The install command is the authority on the TYPO3 version, the packages and the
path repository. Read it before writing your own; it usually needs only DDEV's
paths replaced.

## The instance

```bash
composer create-project "typo3/cms-base-distribution:^13.4" /instance
cd /instance
composer config repositories.ext path /path/to/extension
composer require "<vendor>/<package>:@dev"
```

## The database connection

TYPO3 reads `config/system/additional.php` before setup, so write it first:

```php
$GLOBALS['TYPO3_CONF_VARS']['DB']['Connections']['Default'] = [
    'charset' => 'utf8mb4', 'driver' => 'mysqli',
    'host' => getenv('DB_HOST'), 'port' => 3306,
    'dbname' => getenv('DB_NAME'), 'user' => getenv('DB_USER'),
    'password' => getenv('DB_PASSWORD'),
];
```

**The host is not always a service name.** Under an egress proxy or any
`network_mode: service:` arrangement the containers share one network
namespace, so the database is on `127.0.0.1` and the Compose service name
resolves nowhere (`getaddrinfo for db failed`). Check how the containers are
networked before assuming.

## Setup, extension, site

```bash
vendor/bin/typo3 setup --driver=mysqli --host="$DB_HOST" --port=3306 \
    --dbname="$DB_NAME" --username="$DB_USER" --password="$DB_PASSWORD" \
    --admin-username=admin --admin-user-password='<password>' \
    --admin-email=admin@example.com --project-name='<name>' \
    --server-type=other --no-interaction --force
vendor/bin/typo3 extension:setup
```

Then a site configuration under `config/sites/<identifier>/config.yaml`, whose
`base` must match the hostname you will serve under.

## Serving it — the step that is usually forgotten

An installed instance is not a reachable one, and a case that involves a
backend module or the frontend needs HTTP. Apache with `DocumentRoot` on
`public/`, `AllowOverride All`, and:

```bash
cp vendor/typo3/cms-install/Resources/Private/FolderStructureTemplateFiles/root-htaccess \
   public/.htaccess
```

**The composer distribution ships no `.htaccess`.** Without it `/typo3/`
resolves through `DirectoryIndex` and answers 200, while every sub-route —
`/typo3/login` included — returns 404. The backend looks reachable and is not.
Hand-written rewrite rules are a poor substitute: getting them slightly wrong
routes backend requests into the *frontend*, which answers 404 in its own voice
and hides the cause. Use the file the framework ships.

## Hostnames

Set them where they survive: Docker rewrites `/etc/hosts` at container start,
so an entry baked into an image is silently discarded. Use Compose
`extra_hosts:` (or `--add-host`), pointing the DDEV hostname at `127.0.0.1`.

## Verify by consequence, not by status

`typo3 --version` and a 200 on `/typo3/` both pass against an instance whose
backend does not work. Check the things that can only succeed if it does:

```bash
curl -so /dev/null -w '%{http_code}\n' "$SCHEME://<host>/typo3/login"   # 200
curl -so /dev/null -w '%{http_code}\n' "$SCHEME://<host>/typo3/main"    # 302 unauthenticated
# form login with the __RequestToken from the login page           # 303
# /typo3/main with that session cookie                             # 200
vendor/bin/typo3 site:list                                          # lists the site
```

## Offering a familiar surface

Agents and instructions written for DDEV reach for `ddev exec`, `ddev mysql`,
`ddev describe`. A small wrapper mapping those onto the instance keeps that
knowledge usable. Make it honest: `describe` should state that it is a
compatible surface rather than DDEV, and unsupported subcommands should exit
non-zero instead of quietly doing nothing — a silent no-op gets attributed to
the agent.
