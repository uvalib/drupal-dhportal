#!/bin/bash

# SAML Integration Setup Script (Container Version)
# This script handles all SAML configuration after database import
# Designed to run INSIDE the container, not through DDEV
# Supports both server (/opt/drupal) and container (/var/www/html) environments
# Run with: ./scripts/setup-saml-integration-container.sh

set -e

echo "🔧 SAML Integration Setup Starting (Container Mode)..."

# Define logging functions
info() {
    echo "   ℹ️  $1"
}

warn() {
    echo "   ⚠️  $1"
}

log() {
    echo "   📝 $1"
}

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

# Configure UVA NetBadge attribute mapping per ITS specifications
echo "   🔗 Configuring UVA NetBadge attribute mapping..."
$DRUSH config:set simplesamlphp_auth.settings user_name uid -y
$DRUSH config:set simplesamlphp_auth.settings mail_attr mail -y
$DRUSH config:set simplesamlphp_auth.settings unique_id uid -y

# Configure role mapping based on eduPersonAffiliation
$DRUSH config:set simplesamlphp_auth.settings role.population '1' -y
$DRUSH config:set simplesamlphp_auth.settings role.eval_every_time 1 -y

echo "   ✅ Configured Drupal SAML settings for UVA NetBadge"

echo "3. 🔐 Setting up SAML certificates..."
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
        echo "   ⚠️ Certificate management script not found, using fallback method"
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

echo "4. 🔒 Fixing SimpleSAMLphp permissions..."
if [ -d "$VENDOR_ROOT/simplesamlphp/simplesamlphp/public" ]; then
    chmod -R 755 "$VENDOR_ROOT/simplesamlphp/simplesamlphp/public"
    echo "   ✅ SimpleSAMLphp permissions fixed"
else
    echo "   ⚠️  SimpleSAMLphp public directory not found at expected location"
fi

echo "5. 🔗 Ensuring SimpleSAMLphp symlink exists..."
SIMPLESAML_LINK="$WEB_ROOT/simplesaml"
SIMPLESAML_TARGET="../vendor/simplesamlphp/simplesamlphp/public"

if [ ! -L "$SIMPLESAML_LINK" ]; then
    echo "   Creating SimpleSAMLphp symlink..."
    ln -sf "$SIMPLESAML_TARGET" "$SIMPLESAML_LINK"
    echo "   ✅ SimpleSAMLphp symlink created"
else
    echo "   ✅ SimpleSAMLphp symlink already exists"
fi

echo "6. 📄 Checking .htaccess for SimpleSAMLphp rules..."
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

echo "7. 🧪 Checking and generating SimpleSAMLphp configuration..."

# Check if configuration files exist, generate if missing
CONFIG_NEEDS_GENERATION=false

if [ ! -f "$SIMPLESAML_ROOT/config/config.php" ]; then
    CONFIG_NEEDS_GENERATION=true
    echo "   ⚠️  config.php missing"
fi

if [ ! -f "$SIMPLESAML_ROOT/config/authsources.php" ]; then
    CONFIG_NEEDS_GENERATION=true
    echo "   ⚠️  authsources.php missing"
fi

if [ ! -f "$SIMPLESAML_ROOT/metadata/saml20-idp-remote.php" ]; then
    CONFIG_NEEDS_GENERATION=true
    echo "   ⚠️  saml20-idp-remote.php missing"
fi

# Generate configuration files if any are missing
if [ "$CONFIG_NEEDS_GENERATION" = true ]; then
    # Determine domain and environment for config generation
    if [ "$DRUPAL_ROOT" = "/opt/drupal" ]; then
        DOMAIN="${SAML_DOMAIN:-${HOSTNAME:-$(hostname)}}"
        ENVIRONMENT="server"
    else
        DOMAIN="${SAML_DOMAIN:-https://drupal-dhportal.ddev.site}"
        ENVIRONMENT="container"
    fi
    
    generate_simplesaml_config "$DOMAIN" "$ENVIRONMENT"
fi

# Recheck configuration status
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

# Check certificate status
CERT_STATUS="❌"
if [ -f "$SIMPLESAML_ROOT/cert/server.crt" ] && [ -f "$SIMPLESAML_ROOT/cert/server.key" ]; then
    CERT_STATUS="✅"
fi
echo "   - server certificates: $CERT_STATUS"

echo "8. 🔐 Checking IdP certificate in metadata..."
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
echo "3. View SP metadata at: $PROJECT_URL/simplesaml/module.php/saml/sp/metadata.php/default-sp"
echo ""
echo "🎓 UVA NetBadge Integration:"
echo "   - SP Entity ID: \$(grep 'entityID' $SIMPLESAML_ROOT/config/authsources.php | head -1 | sed \"s/.*=> '//\" | sed \"s/',//\" || echo 'Check authsources.php')"
echo "   - For production: Register SP with UVA ITS using the form at:"
echo "     https://virginia.service-now.com/esc?id=emp_taxonomy_topic&topic_id=123cf54e9359261081bcf5c56aba108d"
echo ""
echo "🧪 Test Users (from drupal-netbadge in development):"
echo "   - Student: username=student, password=studentpass"
echo "   - Staff: username=staff, password=staffpass"
echo "   - Faculty: username=faculty, password=facultypass"
echo ""
echo "⚠️  Production Requirements:"
echo "   - Must register SP Entity ID with UVA ITS"
echo "   - Must include logout advisory as required by UVA policy"
echo "   - SP metadata must be accessible for ITS to download"
echo ""
echo "💡 Container Environment Notes:"
echo "   - This script runs inside the Drupal container (detected: $DRUPAL_ROOT)"
echo "   - Uses direct drush commands instead of 'ddev drush'"
echo "   - Paths are adapted for container filesystem structure"
echo "   - Replace hardcoded URLs with environment-appropriate values"

# Function to generate SimpleSAMLphp configuration files
generate_simplesaml_config() {
    local domain="$1"
    local environment="$2"
    
    log "📝 Generating SimpleSAMLphp configuration files..."
    
    # Ensure config and metadata directories exist
    mkdir -p "$SIMPLESAML_ROOT/config"
    mkdir -p "$SIMPLESAML_ROOT/metadata"
    
    # Generate config.php
    generate_config_php "$domain" "$environment"
    
    # Generate authsources.php
    generate_authsources_php "$domain" "$environment"
    
    # Generate IdP metadata
    generate_idp_metadata "$domain" "$environment"
}

# Generate main SimpleSAMLphp configuration
generate_config_php() {
    local domain="$1"
    local environment="$2"
    
    info "Creating config.php for environment: $environment"
    
    # Environment-specific settings
    local secret_salt=""
    local admin_password=""
    local cookie_domain=""
    local cookie_secure="false"
    local tech_email=""
    local db_config=""
    
    case "$environment" in
        "server"|"production")
            secret_salt="\${SAML_SECRET_SALT:-\$(openssl rand -hex 32)}"
            admin_password="\${SAML_ADMIN_PASSWORD:-\$(openssl rand -hex 16)}"
            cookie_domain=""
            cookie_secure="true"
            tech_email="\${TECH_CONTACT_EMAIL:-admin@\$(echo $domain | sed 's/https\\?:\\/\\///')}"
            db_config="'store.sql.dsn' => 'mysql:host=\\\${DB_HOST:-localhost};dbname=\\\${DB_NAME:-drupal}',
    'store.sql.username' => '\\\${DB_USER:-drupal}',
    'store.sql.password' => '\\\${DB_PASSWORD:-drupal}',"
            ;;
        "container")
            secret_salt="dhportal-container-salt-\$(date +%s)"
            admin_password="admin123"
            cookie_domain=""
            cookie_secure="false"
            tech_email="dev@localhost"
            db_config="'store.sql.dsn' => 'mysql:host=db;dbname=db',
    'store.sql.username' => 'db',
    'store.sql.password' => 'db',"
            ;;
        *)
            secret_salt="dhportal-dev-salt-\$(date +%s)"
            admin_password="admin123"
            cookie_domain=".ddev.site"
            cookie_secure="false"
            tech_email="dev@localhost"
            db_config="'store.sql.dsn' => 'mysql:host=db;dbname=db',
    'store.sql.username' => 'db',
    'store.sql.password' => 'db',"
            ;;
    esac
    
    cat > "$SIMPLESAML_ROOT/config/config.php" << EOF
<?php
/**
 * SimpleSAMLphp configuration for drupal-dhportal (Service Provider)
 * Generated automatically by setup-saml-integration-container.sh
 * Environment: $environment
 * Generated: \$(date)
 */

\\$config = [
    // Basic configuration
    'baseurlpath' => '/simplesaml/',
    'certdir' => 'cert/',
    'loggingdir' => 'log/',
    'datadir' => 'data/',
    'tempdir' => '/tmp/simplesamlphp',

    // Security settings
    'secretsalt' => '$secret_salt',
    'auth.adminpassword' => '$admin_password',
    'admin.protectindexpage' => false,
    'admin.protectmetadata' => false,

    // Technical contact
    'technicalcontact_name' => 'DH Portal Administrator',
    'technicalcontact_email' => '$tech_email',

    // Session configuration
    'session.cookie.name' => 'SimpleSAMLSessionID',
    'session.cookie.lifetime' => 0,
    'session.cookie.path' => '/',
    'session.cookie.domain' => '$cookie_domain',
    'session.cookie.secure' => $cookie_secure,

    // Language settings
    'language.available' => ['en'],
    'language.rtl' => [],
    'language.default' => 'en',

    // Module configuration
    'module.enable' => [
        'core' => true,
        'admin' => true,
        'saml' => true,
    ],

    // Store configuration
    'store.type' => 'sql',
    $db_config

    // Logging
    'logging.level' => SimpleSAML\\Logger::INFO,
    'logging.handler' => 'file',

    // Error handling
    'errors.reporting' => true,
    'errors.show_errors' => false,
];
EOF

    info "✅ Generated config.php"
}

# Generate authsources configuration
generate_authsources_php() {
    local domain="$1"
    local environment="$2"
    
    info "Creating authsources.php for domain: $domain"
    
    # Determine SP entity ID based on environment - must match virtual host name per UVA requirements
    local sp_entity_id=""
    local idp_entity_id=""
    
    case "$environment" in
        "server"|"production")
            # Production uses official UVA NetBadge IdP
            sp_entity_id="$domain/shibboleth"
            idp_entity_id="urn:mace:incommon:virginia.edu"
            ;;
        *)
            # Development uses local drupal-netbadge container
            sp_entity_id="https://drupal-dhportal.ddev.site/shibboleth"
            idp_entity_id="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/metadata.php"
            ;;
    esac
    
    cat > "$SIMPLESAML_ROOT/config/authsources.php" << EOF
<?php
/**
 * Authentication sources configuration for drupal-dhportal
 * Generated automatically by setup-saml-integration-container.sh
 * Configured for UVA NetBadge integration per ITS specifications
 * Environment: $environment
 * Generated: \$(date)
 */

\\$config = [
    // Default SP configuration - connects to UVA NetBadge IdP
    'default-sp' => [
        'saml:SP',
        
        // Entity ID must match virtual host name per UVA requirements
        'entityID' => '$sp_entity_id',
        
        // Point to UVA NetBadge IdP
        'idp' => '$idp_entity_id',
        'discoURL' => null,
        
        // Enable signature validation for security
        'validate.response' => true,
        'validate.assertion' => true,
        'signature.algorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256',
        
        // Certificate configuration
        'privatekey' => 'server.key',
        'certificate' => 'server.crt',
        
        // UVA NetBadge attribute mapping per ITS documentation
        // uid = NetBadge computing ID, eduPersonPrincipalName = uid@virginia.edu
        'attributes' => [
            'uid',                          // Required: NetBadge computing ID
            'eduPersonPrincipalName',       // Required: uid@virginia.edu 
            'eduPersonAffiliation',         // Default release: user affiliation
            'eduPersonScopedAffiliation',   // Default release: scoped affiliation
            'displayName',                  // Optional: display name
            'cn',                          // Optional: common name
            'mail',                        // Optional: email address
        ],
        
        // NameID format - use persistent for consistent user identification
        'NameIDFormat' => 'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent',
        
        // Assertion Consumer Service - where SAML responses are posted
        'AssertionConsumerService' => [
            [
                'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST',
                'Location' => '$sp_entity_id/../simplesaml/module.php/saml/sp/saml2-acs.php/default-sp',
                'index' => 0,
            ],
        ],
        
        // Single Logout Service - for proper logout handling
        'SingleLogoutService' => [
            [
                'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
                'Location' => '$sp_entity_id/../simplesaml/module.php/saml/sp/saml2-logout.php/default-sp',
            ],
        ],
        
        // Additional security settings
        'saml20.sign.response' => false,
        'saml20.sign.assertion' => true,
    ],
];
EOF

    info "✅ Generated authsources.php"
}

# Generate IdP metadata configuration
generate_idp_metadata() {
    local domain="$1"
    local environment="$2"
    
    info "Creating IdP metadata configuration..."
    
    # Configure IdP endpoints per UVA NetBadge specifications
    local idp_entity_id=""
    local idp_sso_url=""
    local idp_slo_url=""
    local idp_metadata_url=""
    local idp_description=""
    
    case "$environment" in
        "server"|"production")
            # Official UVA NetBadge production endpoints
            idp_entity_id="urn:mace:incommon:virginia.edu"
            idp_sso_url="https://shibidp.its.virginia.edu/idp/profile/SAML2/Redirect/SSO"
            idp_slo_url="https://shibidp.its.virginia.edu/idp/profile/SAML2/Redirect/SLO"
            idp_metadata_url="https://shibidp.its.virginia.edu/idp/shibboleth/uva-idp-metadata.xml"
            idp_description="Official UVA NetBadge Identity Provider"
            ;;
        *)
            # Development uses local drupal-netbadge container
            idp_entity_id="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/metadata.php"
            idp_sso_url="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/SSOService.php"
            idp_slo_url="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/SingleLogoutService.php"
            idp_metadata_url="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/metadata.php"
            idp_description="Development NetBadge Identity Provider (drupal-netbadge container)"
            ;;
    esac
    
    cat > "$SIMPLESAML_ROOT/metadata/saml20-idp-remote.php" << EOF
<?php
/**
 * SAML 2.0 remote IdP metadata for drupal-dhportal
 * Generated automatically by setup-saml-integration-container.sh
 * Configured for UVA NetBadge integration per ITS specifications
 * Environment: $environment
 * Generated: \$(date)
 */

// UVA NetBadge Identity Provider Configuration
\\$metadata['$idp_entity_id'] = [
    'entityid' => '$idp_entity_id',
    'name' => [
        'en' => 'UVA NetBadge Authentication',
    ],
    'description' => [
        'en' => '$idp_description',
    ],
    
    // Single Sign-On Service endpoint
    'SingleSignOnService' => [
        [
            'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
            'Location' => '$idp_sso_url',
        ],
    ],
    
    // Single Logout Service endpoint
    'SingleLogoutService' => [
        [
            'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
            'Location' => '$idp_slo_url',
        ],
    ],
    
    // NameID formats supported
    'NameIDFormats' => [
        'urn:oasis:names:tc:SAML:2.0:nameid-format:persistent',
        'urn:oasis:names:tc:SAML:2.0:nameid-format:transient',
    ],
    
    // Certificate configuration - will be populated automatically if available
    'keys' => [
        [
            'encryption' => false,
            'signing' => true,
            'type' => 'X509Certificate',
            'X509Certificate' => '// CERTIFICATE_PLACEHOLDER
            // This will be automatically populated from: $idp_metadata_url
            // For production: Contact ITS to register this SP and obtain certificate
            // For development: Certificate from drupal-netbadge container',
        ],
    ],
    
    // UVA NetBadge attributes - as specified in ITS documentation
    'attributes' => [
        'uid',                          // NetBadge computing ID (required)
        'eduPersonPrincipalName',       // uid@virginia.edu (required)
        'eduPersonAffiliation',         // User affiliation (default release)
        'eduPersonScopedAffiliation',   // Scoped affiliation (default release)
        'displayName',                  // Display name
        'cn',                          // Common name
        'mail',                        // Email address
    ],
    
    // Attribute name format
    'attributes.NameFormat' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified',
];

// For development environment, also configure local drupal-netbadge
EOF

    info "✅ Generated IdP metadata template"
    
    # Note: Certificate will be populated by the certificate management functions
    info "💡 IdP certificate will be populated automatically when certificate management functions are available"
}
