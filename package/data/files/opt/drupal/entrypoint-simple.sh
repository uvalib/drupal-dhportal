#!/bin/bash

# Simplified SimpleSAMLphp Production Entrypoint
# Focuses on essential setup without complex debugging

set -e

echo "=== SimpleSAML Setup: $(date) ==="

# Get environment configuration
DEPLOYMENT_ENVIRONMENT="${DEPLOYMENT_ENVIRONMENT:-development}"
PHP_MODE="${PHP_MODE:-development}"

echo "📝 Configuring for environment: ${DEPLOYMENT_ENVIRONMENT}"

# Configure PHP based on environment
echo "🐘 Setting up PHP for ${PHP_MODE} mode"
cp "/usr/local/etc/php/php.ini-${PHP_MODE}" /usr/local/etc/php/php.ini

# Configure Apache based on environment
echo "🌐 Configuring Apache for ${DEPLOYMENT_ENVIRONMENT}"
if [[ "${DEPLOYMENT_ENVIRONMENT}" == "production" ]]; then
    a2enconf dhportal-production
    a2disconf dhportal-development 2>/dev/null || true
    a2disconf dhportal 2>/dev/null || true
elif [[ "${DEPLOYMENT_ENVIRONMENT}" == "development" ]]; then
    a2enconf dhportal-development
    a2disconf dhportal-production 2>/dev/null || true
    a2disconf dhportal 2>/dev/null || true
else
    # Staging or other environments use the default configuration
    a2enconf dhportal
    a2disconf dhportal-development 2>/dev/null || true
    a2disconf dhportal-production 2>/dev/null || true
fi

# Run SimpleSAML configuration
echo "� Running SimpleSAML configuration..."
/opt/drupal/scripts/configure-simplesaml.sh

echo "✅ Configuration summary:"
echo "  - Environment: ${DEPLOYMENT_ENVIRONMENT}"
echo "  - PHP Mode: ${PHP_MODE}"
echo "  - Apache config test: $(apache2ctl configtest 2>&1 | head -1)"

echo "🚀 Starting Apache..."
exec "$@"
