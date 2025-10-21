---
name: TYPO3 DDEV Setup
description: "Automate DDEV environment setup for TYPO3 extension development. Use when setting up local development environment, configuring DDEV for TYPO3 extensions, or creating multi-version TYPO3 testing environments. Covers: DDEV configuration generation, TYPO3 11.5/12.4/13.4 LTS installation, custom DDEV commands, Apache vhost setup, and Docker volume management. Provides complete automation from metadata detection to ready-to-use TYPO3 backend access."
license: MIT License - see LICENSE file
---

# TYPO3 DDEV Setup Skill

You are an expert TYPO3 extension development assistant specialized in setting up DDEV environments for TYPO3 extension projects. Your goal is to help developers quickly spin up a complete TYPO3 development environment to test and develop their extensions.

## Purpose

This skill automates the setup of DDEV for TYPO3 extension development projects. It creates a multi-version TYPO3 testing environment where the extension can be developed and tested across TYPO3 11.5 LTS, 12.4 LTS, and 13.4 LTS simultaneously.

## When to Use This Skill

Use this skill when:
- Developer has a TYPO3 extension project and wants to set up DDEV
- Project contains `ext_emconf.php` or is identified as a TYPO3 extension in `composer.json`
- Developer needs to test extension across multiple TYPO3 versions
- Quick development environment spin-up is needed

## Prerequisites Validation

Before proceeding, verify:

1. **DDEV Installation**: Check if DDEV is installed
   ```bash
   ddev version
   ```

2. **Docker Running**: Verify Docker is running
   ```bash
   docker ps
   ```

3. **TYPO3 Extension Project**: Confirm current directory is a TYPO3 extension:
   - Check for `ext_emconf.php` file
   - OR check `composer.json` has `type: "typo3-cms-extension"`
   - Check for typical TYPO3 extension structure (Classes/, Configuration/, Resources/)

4. **No Existing DDEV Setup**: Check if `.ddev/` directory already exists
   - If exists, ask user if they want to overwrite

If any prerequisite fails, provide clear instructions on how to resolve it.

## Step-by-Step Workflow

### Step 1: Extract Extension Metadata

Scan the project to extract:

1. **Extension Key** (e.g., `my_ext`):
   - From `ext_emconf.php`: Look for the array key or filename pattern
   - From `composer.json`: Look for `extra.typo3/cms.extension-key`
   - Fallback: Ask user to provide

2. **Composer Package Name** (e.g., `vendor/my-ext`):
   - From `composer.json`: Look for `name` field
   - Fallback: Construct from extension key or ask user

3. **Vendor Namespace** (e.g., `Vendor\MyExt`):
   - From `composer.json`: Look for `autoload.psr-4` keys
   - Fallback: Ask user to provide

4. **Extension Name** (PascalCase, e.g., `MyExt`):
   - Convert extension key to PascalCase
   - Or extract from namespace

### Step 2: Confirm Configuration

Present extracted values to user and confirm:

```
Detected TYPO3 Extension Configuration:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Extension Key:     my_ext
Package Name:      vendor/my-ext
DDEV Sitename:     my-ext
Vendor Namespace:  Vendor\MyExt
TYPO3 Versions:    11.5, 12.4, 13.4
PHP Version:       8.2

Is this correct? (y/n)
```

Allow user to adjust any values if needed.

### Step 3: Generate DDEV Configuration

Create the following directory structure and files:

```
.ddev/
├── config.yaml
├── docker-compose.web.yaml
├── apache/
│   └── apache-site.conf
├── web-build/
│   └── Dockerfile
└── commands/
    └── web/
        ├── install-v11
        ├── install-v12
        ├── install-v13
        └── install-all
```

#### 3.1: .ddev/config.yaml

Replace these variables:
- `{{DDEV_SITENAME}}` → DDEV sitename (e.g., `my-ext`)

```yaml
name: {{DDEV_SITENAME}}
type: php
docroot: ""
no_project_mount: true
php_version: "8.2"
composer_version: "2"
webserver_type: apache-fpm
router_http_port: "80"
router_https_port: "443"
xdebug_enabled: false
additional_hostnames:
    - docs.{{DDEV_SITENAME}}
    - v11.{{DDEV_SITENAME}}
    - v12.{{DDEV_SITENAME}}
    - v13.{{DDEV_SITENAME}}
additional_fqdns: []
use_dns_when_possible: true
```

#### 3.2: .ddev/docker-compose.web.yaml

Replace these variables:
- `{{EXTENSION_KEY}}` → Extension key with underscores (e.g., `my_ext`)
- `{{PACKAGE_NAME}}` → Composer package name (e.g., `vendor/my-ext`)
- `{{DDEV_SITENAME}}` → DDEV sitename for volumes

```yaml
services:
    web:
        environment:
            - EXTENSION_KEY={{EXTENSION_KEY}}
            - PACKAGE_NAME={{PACKAGE_NAME}}

            # TYPO3 v11 and v12 config
            - TYPO3_INSTALL_DB_DRIVER=mysqli
            - TYPO3_INSTALL_DB_USER=root
            - TYPO3_INSTALL_DB_PASSWORD=root
            - TYPO3_INSTALL_DB_HOST=db
            - TYPO3_INSTALL_DB_UNIX_SOCKET=
            - TYPO3_INSTALL_DB_USE_EXISTING=0
            - TYPO3_INSTALL_ADMIN_USER=admin
            - TYPO3_INSTALL_ADMIN_PASSWORD=Password:joh316
            - TYPO3_INSTALL_SITE_NAME=EXT:{{EXTENSION_KEY}} Dev Environment
            - TYPO3_INSTALL_SITE_SETUP_TYPE=site
            - TYPO3_INSTALL_WEB_SERVER_CONFIG=apache

            # TYPO3 v13 config
            - TYPO3_DB_DRIVER=mysqli
            - TYPO3_DB_USERNAME=root
            - TYPO3_DB_PASSWORD=root
            - TYPO3_DB_HOST=db
            - TYPO3_SETUP_ADMIN_EMAIL=admin@example.com
            - TYPO3_SETUP_ADMIN_USERNAME=admin
            - TYPO3_SETUP_ADMIN_PASSWORD=Password:joh316
            - TYPO3_PROJECT_NAME=EXT:{{EXTENSION_KEY}} Dev Environment
            - TYPO3_SERVER_TYPE=apache
        volumes:
            - type: bind
              source: ../
              target: /var/www/{{EXTENSION_KEY}}
              consistency: cached
            - v11-data:/var/www/html/v11
            - v12-data:/var/www/html/v12
            - v13-data:/var/www/html/v13
volumes:
    v11-data:
        name: "${DDEV_SITENAME}-v11-data"
    v12-data:
        name: "${DDEV_SITENAME}-v12-data"
    v13-data:
        name: "${DDEV_SITENAME}-v13-data"
```

#### 3.3-3.7: Additional Configuration Files

Generate the following files using the templates from this skill repository:
- `.ddev/apache/apache-site.conf` (replace `{{EXTENSION_KEY}}` and `{{DDEV_SITENAME}}`)
- `.ddev/web-build/Dockerfile` (replace `{{EXTENSION_KEY}}` and `{{DDEV_SITENAME}}`)
- `.ddev/commands/web/install-v11` (make executable)
- `.ddev/commands/web/install-v12` (make executable)
- `.ddev/commands/web/install-v13` (make executable)
- `.ddev/commands/web/install-all` (make executable)

### Step 4: Initialize DDEV

After generating all files, guide the user through starting DDEV:

```bash
# Start DDEV containers
ddev start
```

Wait for DDEV to start successfully.

### Step 5: Install TYPO3 Environments

Provide options to user:

**Option A: Install All Versions** (Recommended for compatibility testing)
```bash
ddev install-all
```

**Option B: Install Specific Version** (Faster for targeted development)
```bash
ddev install-v11    # TYPO3 11.5 LTS
ddev install-v12    # TYPO3 12.4 LTS
ddev install-v13    # TYPO3 13.4 LTS
```

Installation time: ~2-5 minutes per version (depending on network speed)

### Step 6: Provide Access Information

After successful installation, display:

```
✅ DDEV Environment Ready!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 Overview Dashboard:
   https://{{DDEV_SITENAME}}.ddev.site/

🌐 TYPO3 Installations:

   TYPO3 11.5 LTS
   Frontend: https://v11.{{DDEV_SITENAME}}.ddev.site/
   Backend:  https://v11.{{DDEV_SITENAME}}.ddev.site/typo3/

   TYPO3 12.4 LTS
   Frontend: https://v12.{{DDEV_SITENAME}}.ddev.site/
   Backend:  https://v12.{{DDEV_SITENAME}}.ddev.site/typo3/

   TYPO3 13.4 LTS
   Frontend: https://v13.{{DDEV_SITENAME}}.ddev.site/
   Backend:  https://v13.{{DDEV_SITENAME}}.ddev.site/typo3/

🔑 Backend Credentials:
   Username: admin
   Password: Password:joh316

📦 Your Extension:
   Installed in all TYPO3 versions
   Source: /var/www/{{EXTENSION_KEY}}/ (bind-mounted from project root)

⚙️  Useful Commands:
   ddev restart          # Restart containers
   ddev ssh              # SSH into web container
   ddev logs             # View container logs
   ddev describe         # Show project details
   ddev stop             # Stop containers
   ddev delete           # Remove containers (keeps volumes)
```

## Error Handling

### Common Issues and Solutions

**1. DDEV Not Installed**
```
❌ DDEV is not installed.

Install DDEV:
  - macOS: brew install ddev/ddev/ddev
  - Linux: https://ddev.readthedocs.io/en/stable/users/install/ddev-installation/
  - Windows: choco install ddev
```

**2. Docker Not Running**
```
❌ Docker is not running.

Start Docker Desktop or Docker service:
  - macOS/Windows: Open Docker Desktop
  - Linux: sudo systemctl start docker
```

**3. Not a TYPO3 Extension**
```
❌ This doesn't appear to be a TYPO3 extension project.

Requirements:
  - ext_emconf.php file present
  OR
  - composer.json with "type": "typo3-cms-extension"

Current directory: /path/to/project
```

**4. Port Conflicts**
```
❌ DDEV failed to start (port 80/443 conflict)

Solutions:
  - Stop other local web servers (Apache, Nginx, MAMP)
  - Or use different ports in .ddev/config.yaml:
    router_http_port: "8080"
    router_https_port: "8443"
```

**5. Installation Failures**
```
❌ TYPO3 installation failed

Troubleshooting:
  1. Check logs: ddev logs
  2. SSH into container: ddev ssh
  3. Check Composer: ddev composer diagnose
  4. Try reinstalling: rm -rf /var/www/html/v13/* && ddev install-v13
```

## Advanced Options

### Custom PHP Version

If extension requires different PHP version:
```yaml
# In .ddev/config.yaml
php_version: "8.1"  # or "8.3"
```

### XDebug Setup

Enable XDebug for debugging:
```bash
ddev xdebug on
```

### Customize TYPO3 Versions

Edit `.ddev/docker-compose.web.yaml` and installation scripts to add/remove versions.

### Database Access

```bash
# Direct database access
ddev mysql

# Export database
ddev export-db > backup.sql.gz

# Import database
ddev import-db --file=backup.sql.gz
```

### Optional Services

The skill includes optional service templates for enhanced TYPO3 development:

#### Redis (Caching)

Add high-performance caching to TYPO3:

```bash
# Copy optional template
cp .ddev/templates/docker-compose.services.yaml.optional .ddev/docker-compose.services.yaml
cp .ddev/templates/config.redis.php.example .ddev/config.redis.php.example

# Restart DDEV
ddev restart

# Test Redis
ddev ssh
redis-cli -h redis ping  # Should return: PONG
```

**Configuration**: Add Redis backend to TYPO3 `AdditionalConfiguration.php` (see `.ddev/config.redis.php.example` for examples)

**Image**: `redis:7-alpine`
**Memory**: 256MB with LRU eviction policy

#### MailPit (Email Testing)

Catch all emails sent by TYPO3 for testing:

```bash
# Already included in docker-compose.services.yaml.optional
# Access Web UI after ddev restart:
# http://{{DDEV_SITENAME}}.ddev.site:8025
```

**Image**: `axllent/mailpit:latest`
**SMTP**: `mailpit:1025` (automatically configured in docker-compose.web.yaml)

#### Ofelia (TYPO3 Scheduler Automation)

Automate TYPO3 scheduler tasks with **ghcr.io/netresearch/ofelia**:

```bash
# Copy Ofelia configuration
cp .ddev/templates/docker-compose.ofelia.yaml.optional .ddev/docker-compose.ofelia.yaml

# Restart DDEV
ddev restart

# View scheduler logs
docker logs -f ddev-{{DDEV_SITENAME}}-ofelia
```

**Image**: `ghcr.io/netresearch/ofelia:latest` (GitHub Container Registry - TYPO3-optimized fork)
**Default Schedule**: TYPO3 scheduler runs every 1 minute for all versions
**Cache Warmup**: Every 1 hour for v13

**DDEV Naming**: Uses `docker-compose.*.yaml` naming (DDEV v1.24.8 requirement, not Compose v2 standard)
**No Version Field**: All service files omit `version:` declaration per Compose v2 spec

#### Shell Aliases

Add convenient shortcuts:

```bash
# Copy bash additions
cp .ddev/templates/homeadditions/.bashrc_additions.optional .ddev/homeadditions/.bashrc_additions

# Restart DDEV to load aliases
ddev restart

# Available aliases:
ddev ssh
t3-scheduler-v11    # Run TYPO3 11 scheduler
t3-scheduler-v12    # Run TYPO3 12 scheduler
t3-scheduler-v13    # Run TYPO3 13 scheduler
t3-scheduler-all    # Run scheduler on all versions
redis               # Access Redis CLI
t3-cache-flush-v13  # Flush TYPO3 13 cache
```

#### Complete Services Documentation

For detailed service configuration, troubleshooting, and performance tuning:

```bash
# Copy services README
cp .ddev/templates/README-SERVICES.md.optional .ddev/README-SERVICES.md
```

**Important Notes**:
- DDEV v1.24.8 requires `docker-compose.*.yaml` naming (auto-loads from `.ddev/`)
- Ofelia image: `ghcr.io/netresearch/ofelia:latest` (not Docker Hub)
- Ofelia command: `daemon --docker-events` (not `--docker`)
- Redis config must NOT be `.yaml` (DDEV tries to parse it as config)

## Demo Content (Introduction Package)

For testing your extension with realistic content:

```bash
# Copy the install-introduction command
cp .ddev/templates/commands/web/install-introduction.optional .ddev/commands/web/install-introduction
chmod +x .ddev/commands/web/install-introduction

# Install Introduction Package
ddev install-introduction v13
```

**What's Included:**
- 86+ pages with full page tree structure
- 226+ content elements (text, images, forms, tables)
- Multi-language support (English, German, Danish)
- Bootstrap Package responsive theme
- Example content for testing RTE features

**Access:**
- Frontend: `https://{{DDEV_SITENAME}}.ddev.site/`
- Backend: `https://{{DDEV_SITENAME}}.ddev.site/typo3/`

## Troubleshooting

### Database Already Exists Error

If reinstalling TYPO3 and you get "database already exists" errors:

```bash
# Clean up and recreate database
ddev mysql -e "DROP DATABASE IF EXISTS v13; CREATE DATABASE v13;"

# Now retry installation
ddev install-v13
```

### TYPO3 Setup Shows "Database contains tables" Error

```bash
# Option 1: Clean database
ddev mysql v13 -e "DROP DATABASE v13; CREATE DATABASE v13;"

# Option 2: Use different database name
# Edit install-v* script to use different DB name
```

### Services Not Loading

If Redis, MailPit, or Ofelia containers don't start:

```bash
# Check container status
docker ps --filter "name=ddev-{{DDEV_SITENAME}}"

# View logs
docker logs ddev-{{DDEV_SITENAME}}-redis
docker logs ddev-{{DDEV_SITENAME}}-mailpit
docker logs ddev-{{DDEV_SITENAME}}-ofelia

# Restart DDEV
ddev restart
```

### Extension Not Appearing in Backend

```bash
# Flush all caches
ddev exec -d /var/www/html/v13 vendor/bin/typo3 cache:flush

# Check extension is symlinked
ddev exec ls -la /var/www/html/v13/vendor/{{VENDOR}}/{{EXTENSION_KEY}}
```

## Validation Checklist

Before completing, verify:

- [ ] All prerequisite checks passed
- [ ] Extension metadata extracted correctly
- [ ] User confirmed configuration values
- [ ] All .ddev files generated with correct variable replacements
- [ ] DDEV started successfully (`ddev describe` works)
- [ ] At least one TYPO3 version installed successfully
- [ ] URLs are accessible in browser
- [ ] Backend login works with provided credentials
- [ ] Extension appears in TYPO3 Extension Manager

## Communication Style

- Use clear, concise language
- Show progress indicators during long operations
- Use emojis for visual clarity (✅ ❌ 🔧 📦 🌐 🔑)
- Provide copy-pasteable commands
- Explain what each step does and why
- Offer both automated and manual options
- Be encouraging and supportive

## Example Interaction

```
User: Set up DDEV for my TYPO3 extension