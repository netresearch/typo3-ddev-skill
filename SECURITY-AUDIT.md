# Security Audit Notes

## Known Scanner Findings (Accepted Risk)

### Snyk W007 — HIGH: Hardcoded credential "Joh316!!"

**Status:** Accepted risk. Standard TYPO3 community default.

The password `Joh316!!` is the well-known default admin password used across the TYPO3 community for local development environments. It appears in DDEV setup instructions for initial TYPO3 installation. This is:
- Only used in local DDEV environments (not production)
- The standard documented in official TYPO3 tutorials
- Expected to be changed by the developer after initial setup

### Snyk W012 — MEDIUM: Unverifiable Docker image

**Status:** Accepted risk. The `ghcr.io/typo3-documentation/render-guides:latest` image is the official TYPO3 documentation rendering container maintained by the TYPO3 Documentation Team.
