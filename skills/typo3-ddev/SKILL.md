---
name: typo3-ddev
description: "Use when providing DDEV URLs, accessing TYPO3 backend in browser, performing ANY ddev command (start, stop, restart, describe, exec, config), setting up DDEV for TYPO3 extension development, testing across TYPO3 versions (11.5/12.4/13.4/14.0), or reviewing changes in DDEV. Triggers on: ddev URLs, backend URLs, local development, docker environment, PHP version management, multi-version testing."
---

# TYPO3 DDEV Setup Skill

## CRITICAL: URL Scheme

**NEVER guess URLs. Read `name:` from `.ddev/config.yaml`, then apply subdomain pattern:**

`https://v{VERSION}.{sitename}.ddev.site/typo3/` — e.g., `https://v13.my-ext.ddev.site/typo3/`

Landing page: `https://{sitename}.ddev.site/` · Docs: `https://docs.{sitename}.ddev.site/`

Each version has its own Apache vhost (`/var/www/html/v{11,12,13,14}`), routed via `additional_hostnames` in config.yaml. **Never infer URLs from directory listings.**

**Credentials**: admin / Joh316!!

## Container Priority

1. `.ddev/` exists → `ddev exec`
2. `docker-compose.yml` → `docker compose exec`
3. System tools only if no container. Always use project's configured PHP.

## Quick Start

```bash
ddev start && ddev install-all    # All versions (11/12/13/14)
ddev install-v13                  # Single version
```

## Database Selection

**MariaDB 10.11** (default) · SQLite (simple, no SQL) · PostgreSQL 16 (GIS) · MySQL 8.0 (Oracle parity). See `references/advanced-options.md`.

## PHP Management

`php_version: "8.3"` in config.yaml. Upgrade via `.ddev/web-build/Dockerfile` (`apt-get dist-upgrade`). Custom settings: `.ddev/php/custom.ini`. See `references/0003-php-version-management.md`.

## TYPO3 Version Differences

| | TYPO3 12 | TYPO3 13+ |
|---|---|---|
| Setup | `install:setup --use-existing-database` | `setup` |
| Extension activation | Automatic (Composer) | `extension:setup` |

See `references/typo3-12-cli-changes.md`.

## Post-Setup Verification

`ddev status`, `ddev describe`, `ddev exec -d /var/www/html/v13 vendor/bin/typo3 extension:list --active`. See `references/post-setup-verification.md`.

## Optional Services & Commands

- **Valkey 8** (default) or Redis 7: `references/0001-valkey-default-with-redis-alternative.md`
- **Ofelia** scheduler: TYPO3 scheduler automation
- `ddev generate-makefile` / `ddev generate-index` / `ddev docs`
- `ddev xdebug on` / Cache: `ddev exec -d /var/www/html/v13 vendor/bin/typo3 cache:flush`

## Extension Naming

Hyphens for composer (`nr-llm`), underscores for TYPO3 key (`nr_llm`). Source: composer.json `name`.

## Troubleshooting

| Issue | Solution |
|---|---|
| Port conflict | `router_http_port: "8080"` / `router_https_port: "8443"` |
| Database exists | `ddev mysql -e "DROP DATABASE v13; CREATE DATABASE v13;"` |
| Extension not found | `ddev exec -d /var/www/html/v13 vendor/bin/typo3 cache:flush` |
| Windows health check | Add `/phpstatus` endpoint with `php-fpm.sock` |
| PCOV/pecl fails | `apt-get install php${PHP_VERSION}-pcov` |
| PHP settings ignored | Place in `.ddev/php/custom.ini` |
| Full cleanup | `ddev delete --omit-snapshot --yes` then remove Docker volumes |

## References

| Topic | File |
|---|---|
| Prerequisites | `references/prerequisites-validation.md` |
| Quick start | `references/quickstart.md` |
| Advanced options | `references/advanced-options.md` |
| Post-setup | `references/post-setup-verification.md` |
| Branding/landing page | `references/index-page-generation.md` |
| Windows | `references/windows-fixes.md`, `references/windows-optimizations.md` |
| Docs rendering | `references/documentation-rendering.md` |
| PHP versions | `references/0003-php-version-management.md` |
| Troubleshooting | `references/troubleshooting.md` |
