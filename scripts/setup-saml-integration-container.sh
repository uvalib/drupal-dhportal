#!/bin/bash

# SAML Integration Setup Script (Container Version)
# This script handles all SAMLecho "4. 🔒 Fixiecho "5. 🔗 Ensuring Simecho "6. 📄 Checking .htaccess for SimpleSAMecho "   Configuration files:"
echo "   - config.php: $CONFIG_STATUS"
echo "   - authsources.php: $AUTHSOURCES_STATUS"
echo "   - saml20-idp-remote.php: $METADATA_STATUS"

# Check certificate status
CERT_STATUS="❌"
if [ -f "$SIMPLESAML_ROOT/cert/server.crt" ] && [ -f "$SIMPLESAML_ROOT/cert/server.key" ]; then
    CERT_STATUS="✅"
fi
echo "   - server certificates: $CERT_STATUS"

echo "8. 🔐 Checking IdP certificate in metadata..."ules..."
HTACCESS_FILE="$WEB_ROOT/.htaccess"
if [ -f "$HTACCESS_FILE" ]; then
    if ! grep -q "simplesaml" "$HTACCESS_FILE"; then
        echo "   ⚠️  SimpleSAMLphp rewrite rules missing from .htaccess"
        echo "   Please ensure the following rule is present before the main Drupal routing:"
        echo "   RewriteCond %{REQUEST_URI} !^/simplesaml"
    else
        echo "   ✅ SimpleSAMLphp rewrite rules found in .htaccess"
    fi
else
    echo "   ⚠️  .htaccess file not found at $HTACCESS_FILE"
fi

echo "7. 🧪 Checking SimpleSAMLphp configuration..."ink exists..."
SIMPLESAML_LINK="$WEB_ROOT/simplesaml"
SIMPLESAML_TARGET="../vendor/simplesamlphp/simplesamlphp/public"

if [ ! -L "$SIMPLESAML_LINK" ]; then
    echo "   Creating SimpleSAMLphp symlink..."
    ln -sf "$SIMPLESAML_TARGET" "$SIMPLESAML_LINK"
    echo "   ✅ SimpleSAMLphp symlink created"
else
    echo "   ✅ SimpleSAMLphp symlink already exists"
fi

echo "6. 📄 Checking .htaccess for SimpleSAMLphp rules..."php permissions..."
if [ -d "$VENDOR_ROOT/simplesamlphp/simplesamlphp/public" ]; then
    chmod -R 755 "$VENDOR_ROOT/simplesamlphp/simplesamlphp/public"
    echo "   ✅ SimpleSAMLphp permissions fixed"
else
    echo "   ⚠️  SimpleSAMLphp public directory not found at expected location"
fi

echo "5. 🔗 Ensuring SimpleSAMLphp symlink exists..."configuration after database import
# Designed to run INSIDE the container, not through DDEV
# Supports both server (/opt/drupal) and container (/var/www/html) environments
# Run with: ./scripts/setup-saml-integration-container.sh

set -e

echo "🔧 SAML Integration Setup Starting (Container Mode)..."

# Detect Drupal root directory (server vs container environments)
DRUPAL_ROOT=""
if [ -f "/opt/drupal/web/index.php" ]; then
    DRUPAL_ROOT="/opt/drupal"
    echo "   🖥️  Detected server environment: /opt/drupal"
elif [ -f "/var/www/html/web/index.php" ]; then
    DRUPAL_ROOT="/var/www/html"
    echo "   🐳 Detected container environment: /var/www/html"
else
    echo "❌ Not in a recognized Drupal environment. Expected to find web/index.php in /opt/drupal or /var/www/html"
    exit 1
fi

WEB_ROOT="$DRUPAL_ROOT/web"
VENDOR_ROOT="$DRUPAL_ROOT/vendor"
SIMPLESAML_ROOT="$DRUPAL_ROOT/simplesamlphp"

# Check if Drush is available
if ! command -v drush &> /dev/null; then
    # Try vendor/bin/drush
    if [ -f "$VENDOR_ROOT/bin/drush" ]; then
        DRUSH="$VENDOR_ROOT/bin/drush"
        echo "   📦 Using vendor drush: $VENDOR_ROOT/bin/drush"
    else
        echo "❌ Drush not found. Cannot configure Drupal."
        exit 1
    fi
else
    DRUSH="drush"
    echo "   🔧 Using system drush"
fi

# Set the working directory to Drupal root
cd "$DRUPAL_ROOT"

echo "1. 📦 Enabling SAML modules..."
$DRUSH en simplesamlphp_auth externalauth -y

echo "2. ⚙️ Configuring SimpleSAMLphp auth module..."
$DRUSH config:set simplesamlphp_auth.settings authsource default-sp -y
$DRUSH config:set simplesamlphp_auth.settings activate 1 -y

echo "3. � Setting up SAML certificates..."
# Check if certificates exist, generate if needed
if [ ! -f "$SIMPLESAML_ROOT/cert/server.crt" ] || [ ! -f "$SIMPLESAML_ROOT/cert/server.key" ]; then
    echo "   📜 SAML certificates not found, generating..."
    
    # Source the certificate management script
    if [ -f "$DRUPAL_ROOT/scripts/manage-saml-certificates.sh" ]; then
        source "$DRUPAL_ROOT/scripts/manage-saml-certificates.sh"
        
        # Determine certificate mode based on environment
        if [ "$DRUPAL_ROOT" = "/opt/drupal" ]; then
            # Production environment
            echo "   🏭 Production environment detected, setting up production certificates"
            setup_certificates "prod" "${SAML_DOMAIN:-${HOSTNAME:-localhost}}" "server"
        else
            # Development/container environment
            echo "   🧪 Development environment detected, generating self-signed certificates"
            setup_certificates "dev" "${SAML_DOMAIN:-localhost}" "server"
        fi
    else
        # Fallback: simple self-signed certificate generation
        warn "Certificate management script not found, using fallback method"
        CERT_DIR="$SIMPLESAML_ROOT/cert"
        mkdir -p "$CERT_DIR"
        
        # Generate simple self-signed certificate
        openssl req -x509 -newkey rsa:2048 -keyout "$CERT_DIR/server.key" -out "$CERT_DIR/server.crt" -days 365 -nodes -subj "/C=US/ST=Virginia/L=Charlottesville/O=University of Virginia/CN=${SAML_DOMAIN:-localhost}"
        
        # Create PEM file
        cat "$CERT_DIR/server.key" "$CERT_DIR/server.crt" > "$CERT_DIR/server.pem"
        
        # Set permissions
        chmod 600 "$CERT_DIR/server.key" "$CERT_DIR/server.pem"
        chmod 644 "$CERT_DIR/server.crt"
        
        echo "   ✅ Generated fallback self-signed certificate"
    fi
else
    echo "   ✅ SAML certificates already exist"
fi

echo "4. �🔒 Fixing SimpleSAMLphp permissions..."
if [ -d "$VENDOR_ROOT/simplesamlphp/simplesamlphp/public" ]; then
    chmod -R 755 "$VENDOR_ROOT/simplesamlphp/simplesamlphp/public"
    echo "   ✅ SimpleSAMLphp permissions fixed"
else
    echo "   ⚠️  SimpleSAMLphp public directory not found at expected location"
fi

echo "4. 🔗 Ensuring SimpleSAMLphp symlink exists..."
SIMPLESAML_LINK="$WEB_ROOT/simplesaml"
SIMPLESAML_TARGET="../vendor/simplesamlphp/simplesamlphp/public"

if [ ! -L "$SIMPLESAML_LINK" ]; then
    echo "   Creating SimpleSAMLphp symlink..."
    ln -sf "$SIMPLESAML_TARGET" "$SIMPLESAML_LINK"
    echo "   ✅ SimpleSAMLphp symlink created"
else
    echo "   ✅ SimpleSAMLphp symlink already exists"
fi

echo "5. 📄 Checking .htaccess for SimpleSAMLphp rules..."
HTACCESS_FILE="$WEB_ROOT/.htaccess"
if [ -f "$HTACCESS_FILE" ]; then
    if ! grep -q "simplesaml" "$HTACCESS_FILE"; then
        echo "   ⚠️  SimpleSAMLphp rewrite rules missing from .htaccess"
        echo "   Please ensure the following rule is present before the main Drupal routing:"
        echo "   RewriteCond %{REQUEST_URI} !^/simplesaml"
    else
        echo "   ✅ SimpleSAMLphp rewrite rules found in .htaccess"
    fi
else
    echo "   ⚠️  .htaccess file not found at $HTACCESS_FILE"
fi

echo "6. 🧪 Checking SimpleSAMLphp configuration..."
CONFIG_STATUS="❌"
if [ -f "$SIMPLESAML_ROOT/config/config.php" ]; then
    CONFIG_STATUS="✅"
fi

AUTHSOURCES_STATUS="❌"
if [ -f "$SIMPLESAML_ROOT/config/authsources.php" ]; then
    AUTHSOURCES_STATUS="✅"
fi

METADATA_STATUS="❌"
if [ -f "$SIMPLESAML_ROOT/metadata/saml20-idp-remote.php" ]; then
    METADATA_STATUS="✅"
fi

echo "   Configuration files:"
echo "   - config.php: $CONFIG_STATUS"
echo "   - authsources.php: $AUTHSOURCES_STATUS"
echo "   - saml20-idp-remote.php: $METADATA_STATUS"

echo "7. 🔐 Checking IdP certificate in metadata..."
METADATA_FILE="$SIMPLESAML_ROOT/metadata/saml20-idp-remote.php"
if [ -f "$METADATA_FILE" ]; then
    if grep -q 'X509Certificate.*MII' "$METADATA_FILE"; then
        echo "   ✅ IdP certificate found in metadata"
    else
        echo "   ⚠️  IdP certificate missing or invalid in metadata"
        echo "   💡 You may need to update the certificate from drupal-netbadge"
    fi
else
    echo "   ⚠️  Metadata file not found: $METADATA_FILE"
fi

echo "9. 🌐 Testing SimpleSAMLphp access..."
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
    PROJECT_URL=$($DRUSH config:get system.site.url 2>/dev/null | grep -o 'https\?://[^[:space:]]*' || echo "")
    
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
echo "   - Run this script inside the Drupal container (detected: $DRUPAL_ROOT)"
echo "   - Ensure the database is accessible and imported"
echo "   - Make sure SimpleSAMLphp configuration files are mounted/copied"
