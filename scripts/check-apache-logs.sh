#!/bin/bash

# Apache Log Checker Script for Container Environment
# Helps debug Apache issues in containerized environments where logs go to stdout/stderr

echo "=== Apache Log Configuration ==="
echo "Apache logs in container are symlinked to stdout/stderr:"
ls -la /var/log/apache2/

echo ""
echo "=== Important Note ==="
echo "In this containerized environment, Apache logs go to:"
echo "- Error logs: /dev/stderr (container stderr)"
echo "- Access logs: /dev/stdout (container stdout)"
echo ""
echo "To view logs, use one of these methods:"
echo "1. Docker logs: docker logs <container_name>"
echo "2. DDEV logs: ddev logs"
echo "3. AWS CloudWatch (if configured)"
echo "4. Kubernetes logs: kubectl logs <pod_name>"

echo ""
echo "=== Test Error Log Output ==="
echo "[LOG-CHECKER] This error message should appear in container stderr" >&2
echo "[LOG-CHECKER] This info message should appear in container stdout"

echo ""
echo "=== PHP Configuration ==="
echo "PHP error logging settings:"
php -r "echo 'error_log: ' . ini_get('error_log') . PHP_EOL;"
php -r "echo 'log_errors: ' . (ini_get('log_errors') ? 'On' : 'Off') . PHP_EOL;"
php -r "echo 'display_errors: ' . (ini_get('display_errors') ? 'On' : 'Off') . PHP_EOL;"
echo "PHP error test:"
php -r "error_log('[LOG-CHECKER] PHP error test - should appear in container stderr');"

echo ""
echo "=== Apache Configuration Status ==="
echo "Apache modules:"
apache2ctl -M | grep -E "(headers|rewrite)"
echo ""
echo "DocumentRoot and Directory config:"
grep -A 5 -B 2 "DocumentRoot\|Directory.*drupal" /etc/apache2/sites-enabled/000-default.conf

echo ""
echo "=== SimpleSAMLphp Status ==="
echo "Symlink status:"
ls -la /opt/drupal/web/simplesaml
echo "Target accessibility:"
ls -la /opt/drupal/vendor/simplesamlphp/simplesamlphp/public/index.php 2>/dev/null || echo "Target not accessible"
