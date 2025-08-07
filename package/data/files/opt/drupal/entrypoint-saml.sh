#!/bin/bash

# SimpleSAMLphp Production Entrypoint
# This script sets up SAML certificates and starts the web server

set -e

echo "=== ENTRYPOINT START: $(date) ==="
echo "=== ENTRYPOINT ARGS: $@ ==="
echo "=== PWD: $(pwd) ==="
echo "=== USER: $(whoami) ==="

echo "🔐 Setting up SAML certificates for production..."

# Configure PHP based on environment
PHP_MODE="${PHP_MODE:-development}"
if [[ "${PHP_MODE}" == "production" ]]; then
    echo "📝 Switching to production PHP configuration"
    cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini
else
    echo "📝 Using development PHP configuration (display_errors=On)"
    cp /usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini
fi

# Run certificate setup with production mode
/opt/drupal/scripts/manage-saml-certificates.sh prod

echo "✅ SAML certificate setup completed"

echo "🔍 Runtime SimpleSAMLphp debugging:"
echo "Web directory contents:"
ls -la /opt/drupal/web/ | grep -E "(simplesaml|total)"
echo "Symlink details:"
file /opt/drupal/web/simplesaml || echo "Symlink does not exist"
ls -la /opt/drupal/web/simplesaml/ 2>/dev/null | head -5 || echo "Cannot list symlink contents"
echo "Target directory:"
ls -la /opt/drupal/vendor/simplesamlphp/simplesamlphp/public/ 2>/dev/null | head -5 || echo "Target directory not accessible"
echo "Index.php check:"
ls -la /opt/drupal/web/simplesaml/index.php || echo "index.php not accessible via symlink"
echo "Apache user can access:"
su www-data -s /bin/bash -c "ls -la /opt/drupal/web/simplesaml/index.php" || echo "www-data cannot access index.php"
echo "Full path resolution test:"
realpath /opt/drupal/web/simplesaml/index.php || echo "Cannot resolve real path"
echo "Directory permissions on symlink path:"
ls -ld /opt/drupal/web/simplesaml
ls -ld /opt/drupal/vendor/simplesamlphp/simplesamlphp/public
echo "Testing Apache access as www-data user:"
su www-data -s /bin/bash -c "cat /opt/drupal/web/simplesaml/index.php | head -1" || echo "www-data cannot read index.php content"
echo "Apache configuration check:"
grep -A 5 -B 2 "DocumentRoot\|Directory.*drupal\|Alias.*simplesaml" /etc/apache2/sites-enabled/000-default.conf
echo "SimpleSAMLphp Apache alias verification:"
apache2ctl -S 2>/dev/null | grep -i simplesaml || echo "No SimpleSAMLphp alias found in Apache config"
echo "Testing Apache configuration syntax:"
apache2ctl configtest || echo "Apache configuration has syntax errors"
echo "Apache log configuration (should be symlinks to stdout/stderr):"
ls -la /var/log/apache2/
echo "Apache directory permissions test:"
echo "- /opt/drupal/web permissions:"
ls -ld /opt/drupal/web
echo "- /opt/drupal/web/simplesaml permissions:"
ls -ld /opt/drupal/web/simplesaml
echo "- /opt/drupal/web/simplesaml/admin permissions:"
ls -ld /opt/drupal/web/simplesaml/admin 2>/dev/null || echo "admin directory not found"
echo "- Contents of simplesaml/admin directory:"
ls -la /opt/drupal/web/simplesaml/admin/ 2>/dev/null || echo "Cannot list admin directory contents"
echo "- Apache user access test to admin directory:"
su www-data -s /bin/bash -c "ls -la /opt/drupal/web/simplesaml/admin/" 2>/dev/null || echo "www-data cannot access admin directory"
echo "Apache error logging test (this should appear in container logs):"
echo "[ENTRYPOINT-DEBUG] Testing Apache error log - this message should appear in container stderr" >&2
echo "Apache error log configuration verification:"
echo "- Current ErrorLog directive:"
grep -i "ErrorLog" /etc/apache2/sites-enabled/000-default.conf || echo "No ErrorLog directive in vhost"
grep -i "ErrorLog" /etc/apache2/apache2.conf || echo "No ErrorLog directive in main config"
echo "- Current LogLevel:"
grep -i "LogLevel" /etc/apache2/apache2.conf /etc/apache2/sites-enabled/000-default.conf || echo "No LogLevel directives found"
echo "- Testing manual Apache error generation:"
logger -p local0.err "MANUAL TEST: Apache error logging test from entrypoint"
echo "- Apache log files status:"
ls -la /var/log/apache2/
echo "- Testing direct write to error log:"
echo "[$(date)] ENTRYPOINT-TEST: Manual error log entry" >> /var/log/apache2/error.log 2>&1 || echo "Cannot write to error.log"
echo "SimpleSAMLphp environment configuration check:"
echo "- PHP_MODE: ${PHP_MODE}"
echo "- SIMPLESAMLPHP_ADMIN_PASSWORD: ${SIMPLESAMLPHP_ADMIN_PASSWORD:0:20}... (truncated)"
echo "- SIMPLESAMLPHP_SECRET_SALT: ${SIMPLESAMLPHP_SECRET_SALT:0:10}... (truncated)"
echo "- Config file permissions:"
ls -la /opt/drupal/simplesamlphp/config/config.php
echo "- SimpleSAMLphp library version and admin access:"
if [[ -f "/opt/drupal/vendor/simplesamlphp/simplesamlphp/composer.json" ]]; then
    grep '"version"' /opt/drupal/vendor/simplesamlphp/simplesamlphp/composer.json || echo "Version not found in composer.json"
fi
echo "- SimpleSAMLphp configuration verification:"
echo "  Config file exists: $(test -f /opt/drupal/simplesamlphp/config/config.php && echo 'YES' || echo 'NO')"
echo "  Environment variables available for config:"
echo "    PHP_MODE: ${PHP_MODE:-'not set'}"
echo "    SIMPLESAMLPHP_ADMIN_PASSWORD: ${SIMPLESAMLPHP_ADMIN_PASSWORD:+set}"
echo "    SIMPLESAMLPHP_SECRET_SALT: ${SIMPLESAMLPHP_SECRET_SALT:+set}"
echo "📋 Testing container logging channels:"
echo "[STDOUT-TEST] This message should appear in container stdout logs"
echo "[STDERR-TEST] This message should appear in container stderr logs" >&2
echo "[PHP-ERROR-TEST] Testing PHP error logging..." 
php -r "error_log('[PHP-ERROR-LOG-TEST] PHP error_log to stderr test', 0);"
echo "✅ Logging tests complete - check container logs for [*-TEST] markers"
echo "SimpleSAMLphp debugging complete - errors will appear in container logs (stdout/stderr)"

echo "PHP error logging test:"
php -r "error_log('[ENTRYPOINT-DEBUG] Testing PHP error log - this should appear in container stderr');"
echo "PHP configuration check:"
echo "PHP_MODE environment variable: ${PHP_MODE:-development}"
php -r "echo 'PHP error_log: ' . ini_get('error_log') . PHP_EOL; echo 'PHP log_errors: ' . (ini_get('log_errors') ? 'On' : 'Off') . PHP_EOL; echo 'PHP display_errors: ' . (ini_get('display_errors') ? 'On' : 'Off') . PHP_EOL;"

# Continue with the original entrypoint
exec "$@"
