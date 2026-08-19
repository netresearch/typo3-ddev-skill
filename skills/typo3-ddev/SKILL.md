---
name: typo3-ddev
description: "Use whenever a running TYPO3 instance is wanted, started or reached: ddev commands, backend URLs, DDEV setup, multi-version testing — and when DDEV cannot run, so the instance must be provisioned directly. Triggers on: I need an instance, install TYPO3 locally, ddev URLs, docker environment, CI or container without DDEV."
---

# TYPO3 DDEV Setup Skill

## CRITICAL: URL Scheme

**NEVER guess URLs. Read `name:` from `.ddev/config.yaml`, then apply the subdomain pattern:**

`https://v{VERSION}.{sitename}.ddev.site/typo3/` · Landing: `https://{sitename}.ddev.site/` · Docs: `https://docs.{sitename}.ddev.site/`

Each version gets a vhost (`/var/www/html/v{VERSION}`) via `additional_hostnames`. **Never infer URLs from directory listings.**

**Credentials**: admin / Joh316!!

## Container Priority

1. `.ddev/` exists → `ddev exec`
2. `docker-compose.yml` → `docker compose exec`
3. System tools only if no container. Use project's configured PHP.

**No DDEV available** (CI, container, agent harness — DDEV drives Docker): read `.ddev/config.yaml` and `.ddev/commands/`, then `scripts/provision-without-ddev.sh --extension . --serve`. The distribution ships no `.htaccess`, so `/typo3/` answers 200 while sub-routes 404 — `references/without-ddev.md`.

**In-container edits:** `docker cp` in, then `ddev exec` — not heredocs/`php -r`. See `references/container-file-editing.md`.

## Quick Start

```bash
ddev start && ddev install-all    # All versions (11/12/13/14)
ddev install-v14                  # v14.3 LTS (default / gold standard)
ddev install-v13                  # v13.4 LTS
```

## Database Selection

**MariaDB 10.11** (default) · SQLite · PostgreSQL 16 · MySQL 8.0. See `references/advanced-options.md`, `references/0002-mariadb-default-with-database-alternatives.md`.

## PHP Management

`php_version: "8.3"` in config.yaml. Upgrade via `.ddev/web-build/Dockerfile`. Settings: `.ddev/php/custom.ini`. See `references/0003-php-version-management.md`.

## TYPO3 Version Differences

| | v12 | v13 | v14.3 LTS |
|---|---|---|---|
| Setup | `install:setup --use-existing-database` | `setup` | `setup` |
| Activation | Auto | `extension:setup` | `extension:setup` |
| `composer.json` | optional | optional | **required** (#108310) |
| Theme | bootstrap-package | bootstrap-package | **Camino** (#108539) |
| Fluid | 2.x | 4.x | 5.x strict (#108148) |
| CKEditor | 41–42 | 41–42 | 47 |

See `references/typo3-12-cli-changes.md`.

## Post-Setup Verification

`ddev status`, `ddev describe`, `ddev exec -d /var/www/html/v13 vendor/bin/typo3 extension:list --active`. Check a consequence, not a status: `/typo3/login` must answer 200. See `references/post-setup-verification.md`.

## Optional Services & Commands

- **Valkey 8** (default) or Redis 7: `references/0001-valkey-default-with-redis-alternative.md`
- **Ofelia**: scheduler automation · `ddev generate-makefile` / `generate-index` / `docs` / `xdebug on`

## Extension Naming

Hyphens for composer (`nr-llm`), underscores for TYPO3 key (`nr_llm`). Source: composer.json `name`.

## Troubleshooting

| Issue | Solution |
|---|---|
| Port conflict | `router_http_port: "8080"` / `router_https_port: "8443"` |
| Database exists | `ddev mysql -e "DROP DATABASE v13; CREATE DATABASE v13;"` |
| Extension not found | `ddev exec -d /var/www/html/v13 vendor/bin/typo3 cache:flush` |
| Windows health check | `/phpstatus` endpoint with `php-fpm.sock` |
| PHP settings ignored | `.ddev/php/custom.ini` |
| Full cleanup | `ddev delete --omit-snapshot --yes`, remove volumes |

## References

| Topic | File in `references/` |
|---|---|
| Without DDEV | `without-ddev.md` |
| Prerequisites, quick start | `{prerequisites-validation,quickstart}.md` |
| Advanced, post-setup, branding | `{advanced-options,post-setup-verification,index-page-generation}.md` |
| ADRs · Windows | `{0001,0002,0003}-*.md` · `windows-{fixes,optimizations}.md` |
| Docs rendering, troubleshooting | `{documentation-rendering,troubleshooting}.md` |
