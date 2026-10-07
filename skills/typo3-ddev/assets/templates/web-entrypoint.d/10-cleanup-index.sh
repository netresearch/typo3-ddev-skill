# shellcheck shell=bash
# DDEV's web container sources every .ddev/web-entrypoint.d/*.sh at start;
# it is not executed, so it carries no shebang and no executable bit.
# Remove stale Debian default index.html if it exists
# This ensures index.php is served instead
# The index.html can persist in Docker volumes across rebuilds
if [ -f /var/www/html/index.html ]; then
    # Check if it's the Debian default page
    if grep -q "Apache2 Debian Default Page" /var/www/html/index.html 2>/dev/null; then
        rm -f /var/www/html/index.html
        echo "Removed stale Debian default index.html"
    fi
fi
