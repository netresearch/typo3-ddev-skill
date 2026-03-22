# Architecture — TYPO3 DDEV Skill

## Purpose

This skill automates DDEV environment setup for TYPO3 extension development. It generates a complete multi-version TYPO3 testing environment from extension metadata, allowing developers to test their extension across TYPO3 11.5, 12.4, and 13.4 LTS simultaneously.

## Skill Structure

```
skills/typo3-ddev/
├── SKILL.md              # Entry point — workflow and decision logic
├── checkpoints.yaml      # Evaluation checkpoints for skill quality
├── assets/templates/     # File templates copied into target projects
├── references/           # Deep-dive docs and ADRs
└── scripts/              # Validation helpers
```

### SKILL.md

The main skill file containing the step-by-step workflow: detect extension metadata, validate prerequisites, generate DDEV configuration files, and guide the user through starting the environment.

### Templates (assets/templates/)

The core of the skill. Contains all DDEV configuration files that get copied and customized for the target extension:

- **config.yaml** — DDEV project configuration (PHP version, database, router)
- **docker-compose.web.yaml** — web container with multi-docroot setup
- **commands/** — custom DDEV commands for TYPO3 installation per version
- **apache/** — virtual host config for multi-version routing (v11/v12/v13 subdomains)
- **web-build/** — Dockerfile for PHP extension installation
- **\*.optional** — opt-in services (Valkey, Redis, Ofelia scheduler)

### References

Architecture Decision Records (ADRs) and reference docs:
- ADR-0001: Valkey as default over Redis
- ADR-0002: MariaDB tiered database selection
- ADR-0003: PHP version management
- Troubleshooting, prerequisites, quickstart guides

## Multi-Version Architecture

The generated environment uses a unique layout:

```
/var/www/
├── <extension-key>/     # Extension source (mounted from host)
├── html/
│   ├── v11/             # TYPO3 11.5 installation
│   ├── v12/             # TYPO3 12.4 installation
│   └── v13/             # TYPO3 13.4 installation
└── index.html           # Branded landing page
```

Each TYPO3 installation includes the extension via a Composer path repository, so changes to extension source are immediately available in all versions without rebuilding.

## Key Design Decisions

- **Multi-version in one DDEV project** — avoids running three separate DDEV instances
- **Subdomain routing** — `v11.ext.ddev.site`, `v12.ext.ddev.site`, etc. via Apache vhosts
- **Tiered database** — SQLite for simple extensions (faster startup), MariaDB for complex ones
- **Template-based generation** — files are copied and variable-substituted, not dynamically generated at runtime
- **Branded landing pages** — Netresearch and generic TYPO3 templates with auto-detected metadata
