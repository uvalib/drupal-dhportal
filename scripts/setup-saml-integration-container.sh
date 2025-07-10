#!/bin/bash

# SAML Integration Setup Script (In-Container Version)
# This script handles all SAML-related configuration after database import
# Run inside the container with: ./scripts/setup-saml-integration-container.sh

set -e

echo "🔧 SAML Integration Setup Starting (Container Mode)..."

# Check if we're in a container environment (look for typical container indicators)
if [ ! -f "/var/www/html/web/index.php" ]; then
    echo "❌ Not in a Drupal container environment. This script must be run inside the Drupal container."
    exit 1
fi

# Check if Drush is available
if ! command -v drush &> /dev/null; then
    echo "❌ Drush not found. This script requires Drush to be available in the container."
    exit 1
fi

# Set the working directory to Drupal root
cd /var/www/html

echo "1. 📦 Enabling SAML modules..."
drush en simplesamlphp_auth externalauth -y

echo "2. ⚙️ Configuring SimpleSAMLphp auth module..."
drush config:set simplesamlphp_auth.settings authsource default-sp -y
drush config:set simplesamlphp_auth.settings activate 1 -y

echo "3. 🔒 Fixing SimpleSAMLphp permissions..."
chmod -R 755 /var/www/html/vendor/simplesamlphp/simplesamlphp/public

echo "4. 🔗 Ensuring SimpleSAMLphp symlink exists..."
if [ ! -L "/var/www/html/web/simplesaml" ]; then
    echo "   Creating SimpleSAMLphp symlink..."
    ln -sf ../vendor/simplesamlphp/simplesamlphp/public /var/www/html/web/simplesaml
else
    echo "   ✅ SimpleSAMLphp symlink already exists"
fi

echo "5. 📄 Checking .htaccess for SimpleSAMLphp rules..."
if ! grep -q "simplesaml" /var/www/html/web/.htaccess; then
    echo "   ⚠️  SimpleSAMLphp rewrite rules missing from .htaccess"
    echo "   Please ensure the following rule is present before the main Drupal routing:"
    echo "   RewriteCond %{REQUEST_URI} !^/simplesaml"
else
    echo "   ✅ SimpleSAMLphp rewrite rules found in .htaccess"
fi

echo "6. 🧪 Checking SimpleSAMLphp configuration..."
CONFIG_STATUS="❌"
if [ -f "/var/www/html/simplesamlphp/config/config.php" ]; then
    CONFIG_STATUS="✅"
fi

AUTHSOURCES_STATUS="❌"
if [ -f "/var/www/html/simplesamlphp/config/authsources.php" ]; then
    AUTHSOURCES_STATUS="✅"
fi

METADATA_STATUS="❌"
if [ -f "/var/www/html/simplesamlphp/metadata/saml20-idp-remote.php" ]; then
    METADATA_STATUS="✅"
fi

echo "   Configuration files:"
echo "   - config.php: $CONFIG_STATUS"
echo "   - authsources.php: $AUTHSOURCES_STATUS"
echo "   - saml20-idp-remote.php: $METADATA_STATUS"

echo "7. 🔐 Checking IdP certificate in metadata..."
if grep -q 'X509Certificate.*MII' /var/www/html/simplesamlphp/metadata/saml20-idp-remote.php 2>/dev/null; then
    echo "   ✅ IdP certificate found in metadata"
else
    echo "   ⚠️  IdP certificate missing or invalid in metadata"
    echo "   💡 You may need to update the certificate from drupal-netbadge"
fi

echo "8. 🌐 Testing SimpleSAMLphp access..."
RESPONSE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost/simplesaml/ 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "302" ] || [ "$RESPONSE" = "303" ]; then
    echo "   ✅ SimpleSAMLphp is accessible (HTTP $RESPONSE)"
else
    echo "   ⚠️  SimpleSAMLphp returned HTTP $RESPONSE"
fi

echo ""
echo "🎉 SAML Integration Setup Complete!"
echo ""

# Determine project URL based on environment
PROJECT_URL=""

# Check for common environment variables that might contain the base URL
if [ -n "$DRUPAL_BASE_URL" ]; then
    PROJECT_URL="$DRUPAL_BASE_URL"
elif [ -n "$BASE_URL" ]; then
    PROJECT_URL="$BASE_URL"
elif [ -n "$VIRTUAL_HOST" ]; then
    PROJECT_URL="https://$VIRTUAL_HOST"
else
    # Try to get the URL from Drupal configuration
    PROJECT_URL=$(drush config:get system.site.url 2>/dev/null | grep -o 'https\?://[^[:space:]]*' || echo "")
    
    # Fallback to localhost if nothing else works
    if [ -z "$PROJECT_URL" ]; then
        PROJECT_URL="http://localhost"
    fi
fi

echo "📋 Next Steps:"
echo "1. Test SAML authentication at: $PROJECT_URL/test-saml-integration.php"
echo "2. Access SimpleSAMLphp admin at: $PROJECT_URL/simplesaml/"
echo "3. Ensure drupal-netbadge IdP is running for testing"
echo ""
echo "🧪 Test Users (from drupal-netbadge):"
echo "   - Student: username=student, password=studentpass"
echo "   - Staff: username=staff, password=staffpass"
echo "   - Faculty: username=faculty, password=facultypass"
echo ""
echo "💡 Container Environment Tips:"
echo "   - Run this script inside the Drupal container"
echo "   - Ensure the database is accessible and imported"
echo "   - Make sure SimpleSAMLphp configuration files are mounted/copied"
