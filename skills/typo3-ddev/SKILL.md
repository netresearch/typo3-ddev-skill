---
name: typo3-ddev
description: "Use when setting up DDEV for TYPO3 extension development or testing across multiple TYPO3 versions (11.5/12.4/13.4/14.0)."
---

# TYPO3 DDEV Setup Skill

Automates DDEV environment for TYPO3 extension development with multi-version testing.

## Why DDEV

**Use DDEV when:**
- You need a quick, standardized TYPO3 development environment
- Testing extensions across multiple TYPO3/PHP versions
- Onboarding new team members (consistent setup)
- Working on multiple TYPO3 projects (DDEV isolates each)

**Use Docker Compose directly when:**
- Production-like environment testing (custom orchestration)
- Complex multi-service setups beyond DDEV's scope
- CI/CD pipelines with specific container requirements
- You need fine-grained control over container configuration

**Use plain Docker when:**
- Running single isolated commands (e.g., one-off scripts)
- Building/publishing custom images
- Minimal overhead needed for simple tasks

> **TL;DR**: DDEV = fast local development. Docker Compose = production-like or complex setups. Docker = single containers.

## When to Use

- Setting up DDEV for a TYPO3 extension project
- Testing extension across multiple TYPO3 versions
- Quick development environment spin-up

## Container Priority

**Always check for existing containers first:**

1. Check `.ddev/` exists → use `ddev exec`
2. Check `docker-compose.yml` exists → use `docker compose exec`
3. Only use system tools if no container environment

> **Critical**: Use the project's configured PHP version, not system PHP.

## Quick Start

```bash
scripts/validate-prerequisites.sh    # Check Docker, DDEV
ddev start
ddev install-all                     # All versions (11/12/13/14)
ddev install-v13                     # Single version
```

## Post-Setup Verification

After `ddev start` and installation, verify TYPO3 is fully functional:

```bash
# 1. Check DDEV status
ddev status                          # All services should be "running"

# 2. Verify backend is accessible
curl -sI https://v13.{sitename}.ddev.site/typo3/ | head -1
# Expected: HTTP/2 200 or HTTP/2 302 (redirect to login)

# 3. Verify extension is activated
ddev exec -d /var/www/html/v13 vendor/bin/typo3 extension:list --active | grep {extension_key}

# 4. Verify database is populated
ddev mysql -e "SHOW DATABASES;" | grep v13
ddev mysql v13 -e "SELECT COUNT(*) FROM be_users;"
# Expected: At least 1 backend user
```

**Quick health check (all-in-one):**
```bash
ddev describe                        # Shows URLs, ports, database info
ddev exec -d /var/www/html/v13 vendor/bin/typo3 backend:lock:status
# Expected: "Backend is not locked"
```

## Access URLs

| Environment | URL |
|-------------|-----|
| TYPO3 v13 | `https://v13.{sitename}.ddev.site/typo3/` |
| Docs | `https://docs.{sitename}.ddev.site/` |

**Credentials**: admin / Joh316!!

## Generated Files

Copy templates from `assets/templates/` to project's `.ddev/`:

```
.ddev/
├── config.yaml
├── docker-compose.web.yaml
├── apache/
│   ├── apache-site.conf     (main site - gitignored by ddev!)
│   ├── v12.conf             (committable - copy for TYPO3 v12)
│   ├── v13.conf             (committable - copy for TYPO3 v13)
│   └── docs.conf            (committable - for docs subdomain)
├── index.html.netresearch.template  (for netresearch/* packages)
├── index.html.typo3.template        (for all other packages)
└── commands/web/install-v{11,12,13,14}
```

**IMPORTANT:** `apache-site.conf` is gitignored by ddev's default `.gitignore`.
For multi-version setups, copy the separate `v{11,12,13,14}.conf` files which CAN be committed.

## Optional Commands

```bash
ddev generate-makefile    # Creates make up/test/lint/ci
ddev generate-index       # Overview dashboard
ddev docs                 # Render Documentation/*.rst
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Database exists | `ddev mysql -e "DROP DATABASE v13; CREATE DATABASE v13;"` |
| Extension not appearing | `ddev exec -d /var/www/html/v13 vendor/bin/typo3 cache:flush` |

## References

| Topic | File |
|-------|------|
| Prerequisites | `references/prerequisites-validation.md` |
| Quick start | `references/quickstart.md` |
| Advanced options | `references/advanced-options.md` |
| Landing page templates | `references/index-page-generation.md` |
| Windows fixes | `references/windows-fixes.md` |
| Troubleshooting | `references/troubleshooting.md` |
| PHP version management | `references/0003-php-version-management.md` |

---

> **Contributing:** https://github.com/netresearch/typo3-ddev-skill
