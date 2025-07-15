#!/bin/bash

# SAML Integration Setup Script
# This script handles all SAML-related configuration after database import
# Run with: ./scripts/setup-saml-integration.sh

set -e

echo "🔧 SAML Integration Setup Starting..."

# Check if we're in a DDEV environment
if ! command -v ddev &> /dev/null; then
    echo "❌ DDEV not found. This script must be run from a DDEV project directory."
    exit 1
fi

# Check if DDEV project is running
if ! ddev describe &> /dev/null; then
    echo "❌ DDEV project not running. Please run 'ddev start' first."
    exit 1
fi

echo "1. 📦 Enabling SAML modules..."
ddev drush en simplesamlphp_auth externalauth -y

echo "2. ⚙️ Configuring SimpleSAMLphp auth module..."
ddev drush config:set simplesamlphp_auth.settings authsource default-sp -y
ddev drush config:set simplesamlphp_auth.settings activate 1 -y

echo "3. 🔒 Fixing SimpleSAMLphp permissions..."
ddev exec "chmod -R 755 /var/www/html/vendor/simplesamlphp/simplesamlphp/public"

echo "4. 🔗 Ensuring SimpleSAMLphp symlink exists..."
if ! ddev exec "[ -L /var/www/html/web/simplesaml ]"; then
    echo "   Creating SimpleSAMLphp symlink..."
    ddev exec "ln -sf ../vendor/simplesamlphp/simplesamlphp/public /var/www/html/web/simplesaml"
else
    echo "   ✅ SimpleSAMLphp symlink already exists"
fi

echo "5. 📄 Checking .htaccess for SimpleSAMLphp rules..."
if ! grep -q "simplesaml" web/.htaccess; then
    echo "   ⚠️  SimpleSAMLphp rewrite rules missing from .htaccess"
    echo "   Please ensure the following rule is present before the main Drupal routing:"
    echo "   RewriteCond %{REQUEST_URI} !^/simplesaml"
else
    echo "   ✅ SimpleSAMLphp rewrite rules found in .htaccess"
fi

echo "6. 🧪 Checking SimpleSAMLphp configuration..."
CONFIG_STATUS="❌"
if ddev exec "[ -f /var/www/html/simplesamlphp/config/config.php ]"; then
    CONFIG_STATUS="✅"
fi

AUTHSOURCES_STATUS="❌"
if ddev exec "[ -f /var/www/html/simplesamlphp/config/authsources.php ]"; then
    AUTHSOURCES_STATUS="✅"
fi

METADATA_STATUS="❌"
if ddev exec "[ -f /var/www/html/simplesamlphp/metadata/saml20-idp-remote.php ]"; then
    METADATA_STATUS="✅"
fi

echo "   Configuration files:"
echo "   - config.php: $CONFIG_STATUS"
echo "   - authsources.php: $AUTHSOURCES_STATUS"
echo "   - saml20-idp-remote.php: $METADATA_STATUS"

echo "7. 🔐 Checking IdP certificate in metadata..."
if ddev exec "grep -q 'X509Certificate.*MII' /var/www/html/simplesamlphp/metadata/saml20-idp-remote.php"; then
    echo "   ✅ IdP certificate found in metadata"
else
    echo "   ⚠️  IdP certificate missing or invalid in metadata"
    echo "   💡 You may need to update the certificate from drupal-netbadge"
fi

echo "8. 🌐 Testing SimpleSAMLphp access..."
RESPONSE=$(ddev exec "curl -s -o /dev/null -w '%{http_code}' http://localhost/simplesaml/" 2>/dev/null || echo "000")
if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "302" ] || [ "$RESPONSE" = "303" ]; then
    echo "   ✅ SimpleSAMLphp is accessible (HTTP $RESPONSE)"
else
    echo "   ⚠️  SimpleSAMLphp returned HTTP $RESPONSE"
fi

echo ""
echo "🎉 SAML Integration Setup Complete!"
echo ""

# Get the project URL from DDEV
PROJECT_URL=$(ddev describe -j 2>/dev/null | grep -o '"primary_url":"[^"]*"' | cut -d'"' -f4)
if [ -z "$PROJECT_URL" ]; then
    # Fallback if JSON parsing fails - extract from regular output
    PROJECT_URL=$(ddev describe | grep -o 'https://[^,]*\.ddev\.site:[0-9]*' | head -1)
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
