# AGENTS.md — TYPO3 DDEV Skill

## Repo Structure

```
├── skills/typo3-ddev/
│   ├── SKILL.md                         # Main skill definition
│   ├── checkpoints.yaml                 # Skill evaluation checkpoints
│   ├── assets/templates/                # DDEV config templates
│   │   ├── config.yaml                  # DDEV project config
│   │   ├── docker-compose.web.yaml      # Web container config
│   │   ├── commands/                    # Custom DDEV commands (install-v11/v12/v13)
│   │   ├── apache/                      # Apache site config
│   │   ├── web-build/                   # Dockerfile for PHP extensions
│   │   └── *.optional                   # Optional service configs (Valkey, Redis, Ofelia)
│   ├── references/                      # Reference documentation
│   │   ├── troubleshooting.md
│   │   ├── prerequisites-validation.md
│   │   ├── quickstart.md
│   │   ├── 0001-valkey-default-with-redis-alternative.md   # ADR
│   │   ├── 0002-mariadb-default-with-database-alternatives.md  # ADR
│   │   └── ...                          # More references
│   └── scripts/
│       └── validate-prerequisites.sh
├── .github/workflows/                   # CI workflows
├── Build/                               # Build tooling
├── evals/                               # Skill evaluations
├── docs/                                # Architecture and plans
│   ├── ARCHITECTURE.md
│   └── exec-plans/
└── composer.json                        # Package definition
```

## Commands

No Makefile or npm scripts. Key scripts and DDEV commands:

- `bash skills/typo3-ddev/scripts/validate-prerequisites.sh` — check DDEV, Docker, extension structure
- `ddev install-v11` / `ddev install-v12` / `ddev install-v13` — install specific TYPO3 version
- `ddev install-all` — install all TYPO3 versions
- `ddev install-introduction v13` — install Introduction Package with demo content
- `ddev generate-index` — regenerate the branded landing page

## Rules

1. **Multi-version isolation** — each TYPO3 version gets its own directory (`/var/www/html/v11`, `v12`, `v13`)
2. **Extension mounted separately** — extension source at `/var/www/{{EXTENSION_KEY}}`, installed via Composer path repository
3. **Tiered database selection** — SQLite for simple extensions (dev only), MariaDB 10.11 for complex ones
4. **Valkey over Redis** — Valkey 8 is the default caching service (open source, BSD-3)
5. **apt-get not pecl** — DDEV does not include pecl; use `apt-get install php${PHP_VERSION}-<ext>`
6. **PHP settings in `.ddev/php/custom.ini`** — not in `/usr/local/etc/php/conf.d/`
7. **Template variables auto-detected** — from `composer.json` and `ext_emconf.php`

## References

- [SKILL.md](skills/typo3-ddev/SKILL.md) — full skill definition
- [Quickstart](skills/typo3-ddev/references/quickstart.md)
- [Troubleshooting](skills/typo3-ddev/references/troubleshooting.md)
- [Prerequisites](skills/typo3-ddev/references/prerequisites-validation.md)
- [ADR: Valkey Default](skills/typo3-ddev/references/0001-valkey-default-with-redis-alternative.md)
- [ADR: MariaDB Default](skills/typo3-ddev/references/0002-mariadb-default-with-database-alternatives.md)
- [Architecture](docs/ARCHITECTURE.md)
