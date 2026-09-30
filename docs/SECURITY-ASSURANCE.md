<!-- SPDX-License-Identifier: CC-BY-SA-4.0 -->
<!-- SPDX-FileCopyrightText: Netresearch DTT GmbH -->

# Security assurance case — typo3-ddev-skill

This document states what a user can expect from this repository in terms of security, and argues why that expectation holds. Every claim names the file that implements it. Reporting a vulnerability: see the [security policy](https://github.com/netresearch/.github/blob/main/SECURITY.md). Components: [ARCHITECTURE.md](ARCHITECTURE.md).

## What the repository ships

| Part | Files | Runs where |
| --- | --- | --- |
| Skill instructions for an AI agent | `skills/typo3-ddev/SKILL.md`, `skills/typo3-ddev/references/*.md` | Read by the agent as instructions; not executed. The agent copies templates into the user's project and runs DDEV and TYPO3 commands with the user's permissions. |
| DDEV templates | `skills/typo3-ddev/assets/templates/` | Copied into the user's `.ddev/` directory. DDEV then runs the configuration, the hooks and the custom commands on the user's machine and in the project's containers. |
| Prerequisite check | `skills/typo3-ddev/scripts/validate-prerequisites.sh` | On the user's machine. |
| Provisioner without DDEV | `skills/typo3-ddev/scripts/provision-without-ddev.sh` | Inside a container that already exists (CI, devcontainer, agent harness), usually as root, because it writes the Apache configuration. |
| Checkpoints | `skills/typo3-ddev/checkpoints.yaml` | Only when an assessment tool runs them in a user's project. |
| Repository checks | `Build/Scripts/check-plugin-version.sh`, `Build/hooks/pre-push`, `scripts/verify-harness.sh`, `tests/*.sh` | In this repository's CI and on contributors' machines. |

The environment this skill builds is for local development and testing. It is not a production setup: it uses well-known default credentials and relaxed TYPO3 settings on purpose (see [What a user cannot expect](#what-a-user-cannot-expect)). The repository ships no server component and no container image of its own, stores nothing and handles no accounts.

## Security requirements

1. The scripts act only on what the user names: `validate-prerequisites.sh` only reads, and `provision-without-ddev.sh` writes below `--instance` and, with `--serve`, to the Apache virtual host file before it enables `mod_rewrite` and starts Apache.
2. The database settings the provisioner writes into `config/system/additional.php` cannot change the structure of that file.
3. A provisioning run that did not produce a working backend does not report success.
4. Every download the scripts and templates start goes through Composer to Packagist or through Docker to the image registry the template names; neither the scripts nor the templates weaken the transport security of either client.
5. Nothing committed to this repository contains a secret.
6. A release carries the version that `.claude-plugin/plugin.json` states, comes from a signed tag, and its archives can be verified against the build that produced them.

## Actors and trust boundaries

- **Skill user and agent.** The agent reads `SKILL.md` and the references and acts in the user's project with the user's permissions. What it writes or runs is decided by the agent and the user, not by this repository. `SKILL.md` declares no `allowed-tools`.
- **The user's project.** The templates and the provisioner read the project's own files: `composer.json`, `ext_emconf.php`, `.ddev/config.yaml`, `.ddev/commands/`, and its git metadata. These are trusted as the user's own configuration. The extension is installed as a Composer path repository and runs inside TYPO3 like any extension.
- **DDEV and Docker.** DDEV starts the containers, runs the hooks in `config.yaml` and the custom commands, and terminates TLS in its router with its own certificates. The Apache templates (`assets/templates/apache/*.conf`) serve port 80 and port 443 with the certificate DDEV places at `/etc/ssl/certs/master.crt`; this repository creates no certificate and handles no private key.
- **Package registries.** Packagist (through Composer, which downloads the archives from the URLs Packagist lists), Docker Hub and GHCR (through Docker) supply TYPO3, the extension's dependencies and the service images. Their content is trusted as published; see [Downloads](#downloads-and-how-they-are-verified).
- **The container running the provisioner.** `provision-without-ddev.sh` trusts its arguments and the environment variables `DB_HOST`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`, `TYPO3_ADMIN_PASSWORD`, `SITE_SCHEME` and `APACHE_SITE_CONF`: they come from the operator of that container.
- **Contributors.** Changes reach `main` through pull requests checked by the workflows in `.github/workflows/`. `.envrc` (used by direnv) sets `core.hooksPath` to `Build/hooks`, so a contributor who allows it runs the repository's `pre-push` hook.
- **CI.** Workflows run on GitHub-hosted runners with `permissions: {}` at the top level and grant each job only the scopes its called reusable workflow needs (`.github/workflows/*.yml`). The two `pull_request_target` workflows (`auto-merge-deps.yml`, `labeler.yml`) only call reusables that merge or label and do not check out pull request code; `auto-merge-deps.yml` passes two named secrets instead of `secrets: inherit`.

## Downloads and how they are verified

| What | Started by | Source and transport | Verification |
| --- | --- | --- | --- |
| TYPO3 base distribution and the extension's Composer dependencies | `provision-without-ddev.sh` (`composer create-project`, `composer require`) | Packagist, through Composer; the script sets no repository besides the local path repository and does not disable Composer's HTTPS enforcement (`secure-http`) | Composer's own checks. The versions are resolved at run time within `--typo3` (default `^13.4`); no lock file is supplied. |
| TYPO3 per version, Introduction Package, Styleguide, Extension Manager | `assets/templates/commands/install-v11` … `install-v14`, `install-introduction.optional`, `configure-extension.optional` | Packagist, through Composer inside the DDEV web container | As above; constraints such as `t3/cms:^13`, resolved at run time. |
| Web container | DDEV (`config.yaml`, `web-build/Dockerfile`, which builds on DDEV's `BASE_IMAGE`) | DDEV's own image | DDEV's choice of image and tag. |
| Optional services | `docker-compose.services.yaml.optional`, `docker-compose.services-redis.yaml.optional` | `valkey/valkey:8-alpine`, `redis:7-alpine`, `axllent/mailpit:latest`, `ghcr.io/netresearch/ofelia:latest` | Tags only, no digests: the image behind a tag can change between two starts. |
| Documentation renderer | `assets/templates/commands/host/docs` | `ghcr.io/typo3-documentation/render-guides:latest` | Tag only, no digest. [SECURITY-AUDIT.md](../SECURITY-AUDIT.md) records this as an accepted scanner finding. |
| DDEV itself | Not downloaded. `validate-prerequisites.sh` prints the install commands (Homebrew, the DDEV install script from `raw.githubusercontent.com` piped to `bash`, Chocolatey) when DDEV is missing | — | The script executes none of them; the user decides. |

## Network protocols

- `provision-without-ddev.sh` serves the instance over plain HTTP: the virtual host it writes listens on port 80, and `SITE_SCHEME` defaults to `http` because the instance has no certificate. A deployment that terminates TLS in front of it sets `SITE_SCHEME=https`, which becomes the scheme of the site's `base`. The login probe goes to `127.0.0.1` and does not leave the container.
- The provisioner connects to the database with `mysqli` and no TLS; `DB_HOST` defaults to `127.0.0.1`.
- The DDEV templates serve every site on both HTTP and HTTPS through DDEV's router (`config.yaml`: `router_http_port`, `router_https_port`); the frontend and backend URLs the templates and the skill print use HTTPS.
- No script or template turns off certificate verification: none passes `--insecure`/`-k` to `curl` or `secure-http: false` / `disable-tls` to Composer. One troubleshooting hint in `references/troubleshooting.md` shows `curl -sk` for fetching an asset from the local DDEV site, which skips certificate verification for that single request.

## Threats and countermeasures

| Threat | Countermeasure | Evidence |
| --- | --- | --- |
| A database setting or password breaks out of the PHP string it is written into (CWE-94) | `php_string` escapes `\` and `'` in `DB_HOST`, `DB_NAME`, `DB_USER` and `DB_PASSWORD` before they are written to `config/system/additional.php` | `provision-without-ddev.sh`; `tests/provision-without-ddev.sh` (parses the file with `php -l` and reads back a password containing a quote and a backslash) |
| A provisioned backend that does not work is reported as ready | The provisioner checks `/typo3/login` rather than `/typo3/`, and exits 1 with the URL when it does not answer after 30 attempts | `provision-without-ddev.sh`; `tests/provision-without-ddev.sh` |
| The rewrite rules route the backend into the frontend and hide failures | The provisioner copies the `.htaccess` TYPO3 ships instead of writing rules by hand | `provision-without-ddev.sh`; `references/without-ddev.md` |
| Missing or wrong input starts a half-configured installation | The provisioner stops with exit 2 before installing anything when `--extension`, `DB_PASSWORD` or the admin password is missing or an argument is unknown, and with exit 1 when `composer.json` has no package name | `provision-without-ddev.sh`; `tests/provision-without-ddev.sh` |
| A path or value is interpreted by the shell (CWE-78) | The scripts quote the arguments and paths they pass to other commands; `validate-prerequisites.sh` only compares version numbers it reads from `docker` and `ddev` | `provision-without-ddev.sh`, `validate-prerequisites.sh`; ShellCheck at severity style reports nothing for either |
| The prerequisite check changes the user's machine | `validate-prerequisites.sh` only runs `docker info`, `docker version`, `docker compose version` and `ddev version` and reads `ext_emconf.php` and `composer.json` | `validate-prerequisites.sh`; `tests/validate-prerequisites.sh` |
| A checkpoint modifies the assessed project | Every checkpoint is a file-existence or content check, or a command built from `grep`, `sed -n`, `jq`, `perl` and `find` that only reads and exits with a status | `checkpoints.yaml` |
| A release is tagged with a version that disagrees with `plugin.json` | The pre-push hook runs `check-plugin-version.sh`, which fails when a semver tag at `HEAD` differs from `.claude-plugin/plugin.json` | `Build/hooks/pre-push`, `Build/Scripts/check-plugin-version.sh`; `tests/check-plugin-version.sh` |
| A released archive is tampered with, or released from an unsigned tag | The release workflow refuses lightweight and unsigned tags, and publishes a Cosign-signed `SHA256SUMS.txt` and build-provenance attestations for the archives | `.github/workflows/release.yml` (calls the skill-repo-skill release reusable) |
| A secret is committed | Betterleaks scans every push to `main` and every pull request to `main`; its check is required on `main` | `.github/workflows/security.yml` |
| A vulnerable or malicious dependency is added | Dependency review fails on vulnerabilities of severity high or above in a pull request; Composer Audit checks the Composer dependencies against known advisories; Renovate proposes updates, including pre-commit hook revisions | `.github/workflows/security.yml`, `renovate.json` |
| Insecure code or workflow patterns | Opengrep fails on findings of severity WARNING or above; zizmor analyses the workflows; ShellCheck runs on every `*.sh` file in Skill Validation | `.github/workflows/security.yml`, `.github/workflows/lint.yml` |

Which of these checks must pass before a pull request can merge is set in the branch protection of `main`, not in this repository. On 2026-09-30 it required CodeQL (`Analyze (actions)`), Skill Validation, Composer Audit, Opengrep, Eval Validation, Secret Scanning (Betterleaks) and DCO, as well as signed commits; dependency review, zizmor, Harness Verification, Template Drift and Skill Tests ran on pull requests without being required.

## Secure design principles applied

- **Least privilege:** the prerequisite check and the checkpoints only read. The provisioner writes only below `--instance` and, with `--serve`, to the Apache configuration. Workflows start from `permissions: {}` and grant each job the scopes it needs.
- **Economy of mechanism:** the provisioner reads the two values it needs from `.ddev/config.yaml` with `sed` instead of requiring a YAML parser, and uses the `.htaccess` TYPO3 ships instead of its own rewrite rules.
- **Fail-safe defaults:** the provisioner has no default database password or admin password; it stops when they are not given.
- **Complete mediation of input:** the database settings written into PHP are escaped for the literal they end up in. The hostname and the instance path are written into the site configuration and the virtual host unchanged; they are the operator's input.

## What a user cannot expect

- The environment is not hardened and must not be reachable from untrusted networks. The templates set the backend user `admin` with the password `Joh316!!` and the database user `root` with the password `root` (`docker-compose.web.yaml`, `commands/host/setup`); [SECURITY-AUDIT.md](../SECURITY-AUDIT.md) explains why this TYPO3 community default is kept. The install commands set `trustedHostsPattern` to `.*`, disable `security.backend.enforceReferrer`, set `devIPmask` to `*` and turn on `displayErrors` and debug output (`commands/install-v11` … `install-v14`). The provisioner also sets `trustedHostsPattern` to `.*`.
- The provisioner passes the admin and database passwords to `typo3 setup` as command-line arguments, where other processes in the same container can read them.
- Downloads are not pinned: Composer resolves the newest versions within the constraints at run time, and the service images are referenced by tag. A compromised release in one of those registries reaches the environment the next time it is built.
- The opt-in Ofelia scheduler service mounts the Docker socket (`docker-compose.services.yaml.optional`, `docker-compose.services-redis.yaml.optional`). `:ro` on that mount does not restrict the Docker API, so that container can control the host's Docker daemon. Use it only on machines where that is acceptable.
- The skill gives guidance; it does not enforce it. The agent acts with the user's permissions; review what it proposes and runs.
- `validate-prerequisites.sh` checks the presence and versions of Docker, Docker Compose and DDEV; it does not check their configuration or security.
- Security fixes follow the supported-versions rules of the organisation's security policy; older releases may not receive them.
