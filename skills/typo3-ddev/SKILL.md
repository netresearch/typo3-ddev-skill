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

After setup, verify with `ddev status` (all running), then check backend URL and extension activation. See `references/post-setup-verification.md` for full verification commands and generated file structure.

## Access URLs

| Environment | URL |
|-------------|-----|
| TYPO3 v13 | `https://v13.{sitename}.ddev.site/typo3/` |
| Docs | `https://docs.{sitename}.ddev.site/` |

**Credentials**: admin / Joh316!!

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
| Post-setup verification | `references/post-setup-verification.md` |
| Prerequisites | `references/prerequisites-validation.md` |
| Quick start | `references/quickstart.md` |
| Advanced options | `references/advanced-options.md` |
| Landing page templates | `references/index-page-generation.md` |
| Windows fixes | `references/windows-fixes.md` |
| Troubleshooting | `references/troubleshooting.md` |
| PHP version management | `references/0003-php-version-management.md` |

---

> **Contributing:** https://github.com/netresearch/typo3-ddev-skill
