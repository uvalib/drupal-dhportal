#!/bin/bash

# SAML Integration Setup Script (Universal Version)
# This script handles all SAML configuration after database import
# Automatically detects and supports multiple environments:
# - DDEV development environment (uses 'ddev' commands)
# - Direct container execution (uses direct commands)
# - Server/production environments (uses direct commands)
# Run with: ./scripts/saml-setup/setup-saml-integration-container.sh [--test-only]

set -e

# Parse command line arguments
TEST_ONLY=false
if [ "$1" = "--test-only" ] || [ "$1" = "-t" ]; then
    TEST_ONLY=true
    echo "🧪 Running in test-only mode - will only generate test configurations"
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "SAML Integration Setup Script (Universal Version)"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --test-only, -t    Generate test configurations only (no system changes)"
    echo "  --help, -h         Show this help message"
    echo ""
    echo "MODES:"
    echo "  Normal mode:       Sets up SAML integration in the current environment"
    echo "  Test-only mode:    Generates test configurations in test-output/ directory"
    echo ""
    echo "ENVIRONMENTS:"
    echo "  - DDEV development environment (auto-detected)"
    echo "  - Direct container execution (auto-detected)" 
    echo "  - Server/production environments (auto-detected)"
    echo ""
    echo "REQUIREMENTS:"
    echo "  - Auto-checks and guides installation of required dependencies:"
    echo "    * envsubst (from gettext package) - for template processing"
    echo "    * drush - for Drupal configuration (when not using DDEV)"
    echo "  - Templates must be present in scripts/saml-setup/templates/ directory"
    exit 0
fi

echo "🔧 SAML Integration Setup Starting (Universal Mode)..."

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

# Detect execution environment
EXECUTION_MODE=""
USE_DDEV=false

# Check if we're in a DDEV environment and it's available
if command -v ddev &> /dev/null && ddev describe &> /dev/null 2>&1; then
    EXECUTION_MODE="ddev"
    USE_DDEV=true
    echo "   🏠 Detected DDEV development environment"
elif [ -f "/opt/drupal/web/index.php" ]; then
    EXECUTION_MODE="server"
    echo "   🖥️  Detected server environment: /opt/drupal"
elif [ -f "/var/www/html/web/index.php" ]; then
    EXECUTION_MODE="container"
    echo "   🐳 Detected container environment: /var/www/html"
else
    # In test-only mode, we can work without a full environment
    if [ "$TEST_ONLY" = true ]; then
        EXECUTION_MODE="test"
        echo "   🧪 Test-only mode: Using current directory"
    else
        echo "❌ No recognized environment found."
        echo "   Expected: DDEV project, /opt/drupal, or /var/www/html"
        echo "   💡 Use --test-only flag to generate test configurations"
        exit 1
    fi
fi

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    local install_commands=()
    
    # Check for envsubst (required for template processing)
    if ! command -v envsubst &> /dev/null; then
        missing_deps+=("envsubst")
        case "$(uname -s)" in
            Linux*)
                if command -v apt-get &> /dev/null; then
                    install_commands+=("sudo apt-get update && sudo apt-get install -y gettext-base")
                elif command -v yum &> /dev/null; then
                    install_commands+=("sudo yum install -y gettext")
                elif command -v dnf &> /dev/null; then
                    install_commands+=("sudo dnf install -y gettext")
                elif command -v apk &> /dev/null; then
                    install_commands+=("sudo apk add gettext")
                else
                    install_commands+=("Install gettext package using your system's package manager")
                fi
                ;;
            Darwin*)
                if command -v brew &> /dev/null; then
                    install_commands+=("brew install gettext")
                else
                    install_commands+=("Install Homebrew, then run: brew install gettext")
                fi
                ;;
            *)
                install_commands+=("Install gettext package (provides envsubst)")
                ;;
        esac
    fi
    
    # Check for drush (only if not in DDEV mode and not test-only)
    if [ "$USE_DDEV" = false ] && [ "$TEST_ONLY" != true ]; then
        if ! command -v drush &> /dev/null && [ ! -f "$VENDOR_ROOT/bin/drush" ]; then
            missing_deps+=("drush")
            install_commands+=("Install Drush: composer global require drush/drush OR use vendor/bin/drush")
        fi
    fi
    
    # Report missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        echo "❌ Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "🔧 Installation instructions:"
        for i in "${!missing_deps[@]}"; do
            echo "   ${missing_deps[$i]}: ${install_commands[$i]}"
        done
        echo ""
        echo "💡 After installing dependencies, re-run this script."
        return 1
    fi
    
    return 0
}

# Environment-aware command execution
exec_cmd() {
    local cmd="$1"
    if [ "$USE_DDEV" = true ]; then
        if [[ "$cmd" == drush* ]]; then
            ddev $cmd
        else
            ddev exec "$cmd"
        fi
    else
        if [[ "$cmd" == drush* ]] && command -v $cmd &> /dev/null; then
            $cmd
        elif [[ "$cmd" == drush* ]]; then
            # Try vendor/bin/drush if system drush not available
            if [ -f "$VENDOR_ROOT/bin/drush" ]; then
                $VENDOR_ROOT/bin/$cmd
            else
                echo "❌ Drush not found. Cannot configure Drupal."
                exit 1
            fi
        else
            eval $cmd
        fi
    fi
}

# Environment-aware file check
file_exists() {
    local file_path="$1"
    if [ "$USE_DDEV" = true ]; then
        ddev exec "[ -f $file_path ]" 2>/dev/null
    else
        [ -f "$file_path" ]
    fi
}

# Environment-aware directory check  
dir_exists() {
    local dir_path="$1"
    if [ "$USE_DDEV" = true ]; then
        ddev exec "[ -d $dir_path ]" 2>/dev/null
    else
        [ -d "$dir_path" ]
    fi
}

# Template configuration variables
setup_template_vars() {
    local domain="$1"
    local environment="$2"
    local output_dir="${3:-$SIMPLESAML_ROOT}"
    
    # Set generation date
    export GENERATION_DATE="$(date)"
    export ENVIRONMENT="$environment"
    
    # Configure environment-specific variables
    case "$environment" in
        "server"|"production")
            export SECRET_SALT="\${SAML_SECRET_SALT:-\$(openssl rand -hex 32)}"
            export ADMIN_PASSWORD="\${SAML_ADMIN_PASSWORD:-\$(openssl rand -hex 16)}"
            export COOKIE_DOMAIN=""
            export COOKIE_SECURE="true"
            export TECH_EMAIL="\${TECH_CONTACT_EMAIL:-admin@$(echo $domain | sed 's/https\?:\/\///')}"
            export DB_CONFIG="'store.sql.dsn' => 'mysql:host=\\\${DB_HOST:-localhost};dbname=\\\${DB_NAME:-drupal}',
    'store.sql.username' => '\\\${DB_USER:-drupal}',
    'store.sql.password' => '\\\${DB_PASSWORD:-drupal}',"
            
            # Production SP and IdP configuration
            export SP_ENTITY_ID="$domain/shibboleth"
            export IDP_ENTITY_ID="urn:mace:incommon:virginia.edu"
            export IDP_SSO_URL="https://shibidp.its.virginia.edu/idp/profile/SAML2/Redirect/SSO"
            export IDP_SLO_URL="https://shibidp.its.virginia.edu/idp/profile/SAML2/Redirect/SLO"
            export IDP_METADATA_URL="https://shibidp.its.virginia.edu/idp/shibboleth/uva-idp-metadata.xml"
            export IDP_DESCRIPTION="Official UVA NetBadge Identity Provider"
            export IDP_CERTIFICATE="// CERTIFICATE_PLACEHOLDER
            // This will be automatically populated from: $IDP_METADATA_URL
            // For production: Contact ITS to register this SP and obtain certificate"
            ;;
        "container")
            export SECRET_SALT="dhportal-container-salt-$(date +%s)"
            export ADMIN_PASSWORD="admin123"
            export COOKIE_DOMAIN=""
            export COOKIE_SECURE="false"
            export TECH_EMAIL="dev@localhost"
            export DB_CONFIG="'store.sql.dsn' => 'mysql:host=db;dbname=db',
    'store.sql.username' => 'db',
    'store.sql.password' => 'db',"
            
            # Development SP and IdP configuration
            export SP_ENTITY_ID="https://drupal-dhportal.ddev.site/shibboleth"
            export IDP_ENTITY_ID="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/metadata.php"
            export IDP_SSO_URL="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/SSOService.php"
            export IDP_SLO_URL="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/SingleLogoutService.php"
            export IDP_METADATA_URL="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/metadata.php"
            export IDP_DESCRIPTION="Development NetBadge Identity Provider (drupal-netbadge container)"
            export IDP_CERTIFICATE="// CERTIFICATE_PLACEHOLDER
            // For development: Certificate from drupal-netbadge container"
            ;;
        *)
            export SECRET_SALT="dhportal-dev-salt-$(date +%s)"
            export ADMIN_PASSWORD="admin123"
            export COOKIE_DOMAIN=".ddev.site"
            export COOKIE_SECURE="false"
            export TECH_EMAIL="dev@localhost"
            export DB_CONFIG="'store.sql.dsn' => 'mysql:host=db;dbname=db',
    'store.sql.username' => 'db',
    'store.sql.password' => 'db',"
            
            # Default development configuration
            export SP_ENTITY_ID="https://drupal-dhportal.ddev.site/shibboleth"
            export IDP_ENTITY_ID="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/metadata.php"
            export IDP_SSO_URL="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/SSOService.php"
            export IDP_SLO_URL="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/SingleLogoutService.php"
            export IDP_METADATA_URL="https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/metadata.php"
            export IDP_DESCRIPTION="Development NetBadge Identity Provider (drupal-netbadge container)"
            export IDP_CERTIFICATE="// CERTIFICATE_PLACEHOLDER
            // For development: Certificate from drupal-netbadge container"
            ;;
    esac
}

# Generate configuration files from templates
generate_from_template() {
    local template_file="$1"
    local output_file="$2"
    local template_dir="${DRUPAL_ROOT}/scripts/saml-setup/templates"
    
    if [ ! -f "$template_dir/$template_file" ]; then
        warn "Template file not found: $template_dir/$template_file"
        return 1
    fi
    
    # Ensure output directory exists
    mkdir -p "$(dirname "$output_file")"
    
    # Use envsubst to process the template
    envsubst < "$template_dir/$template_file" > "$output_file"
    
    if [ $? -eq 0 ]; then
        info "✅ Generated $output_file from template"
        return 0
    else
        warn "❌ Failed to generate $output_file from template"
        return 1
    fi
}

# Function to generate SimpleSAMLphp configuration files
generate_simplesaml_config() {
    local domain="$1"
    local environment="$2"
    local output_dir="${3:-$SIMPLESAML_ROOT}"
    
    log "📝 Generating SimpleSAMLphp configuration files from templates..."
    
    # Setup template variables
    setup_template_vars "$domain" "$environment" "$output_dir"
    
    # Ensure config and metadata directories exist
    mkdir -p "$output_dir/config"
    mkdir -p "$output_dir/metadata"
    
    # Generate configuration files from templates
    generate_from_template "config.php.template" "$output_dir/config/config.php"
    generate_from_template "authsources.php.template" "$output_dir/config/authsources.php"
    generate_from_template "saml20-idp-remote.php.template" "$output_dir/metadata/saml20-idp-remote.php"
    
    log "✅ SimpleSAMLphp configuration files generated successfully"
}

# Test generation function - generates configs in test-output directory
generate_test_configs() {
    local test_environments=("dev" "container" "production")
    local test_domains=("https://drupal-dhportal.ddev.site" "https://drupal-dhportal.ddev.site" "https://dhportal.example.com")
    local base_test_dir="${DRUPAL_ROOT}/test-output"
    
    log "🧪 Generating test configuration files..."
    
    # Clean and create test output directory
    rm -rf "$base_test_dir"
    mkdir -p "$base_test_dir"
    
    for i in "${!test_environments[@]}"; do
        local env="${test_environments[$i]}"
        local domain="${test_domains[$i]}"
        local test_dir="$base_test_dir/$env"
        
        info "Generating test configs for environment: $env"
        
        # Generate configs for this environment
        generate_simplesaml_config "$domain" "$env" "$test_dir"
        
        # Create a summary file for this environment
        cat > "$test_dir/README.md" << EOF
# Test Configuration: $env

Generated: $(date)
Domain: $domain
Environment: $env

## Files Generated:
- \`config/config.php\` - Main SimpleSAMLphp configuration
- \`config/authsources.php\` - Authentication sources (SP configuration)
- \`metadata/saml20-idp-remote.php\` - IdP metadata configuration

## Environment Variables Used:
- ENVIRONMENT: $env
- SP_ENTITY_ID: $(echo "$domain/shibboleth" | envsubst)
- IDP_ENTITY_ID: $([ "$env" = "production" ] && echo "urn:mace:incommon:virginia.edu" || echo "https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/metadata.php")

## Usage:
These files can be reviewed and copied to the appropriate SimpleSAMLphp directories:
\`\`\`bash
cp config/* \$SIMPLESAML_ROOT/config/
cp metadata/* \$SIMPLESAML_ROOT/metadata/
\`\`\`
EOF
    done
    
    # Create overall test summary
    cat > "$base_test_dir/README.md" << EOF
# SAML Configuration Test Generation

Generated: $(date)

This directory contains test configurations for all supported environments:

$(for env in "${test_environments[@]}"; do echo "- **$env/**: Configuration for $env environment"; done)

## Template System:
The configuration files are generated from templates in \`scripts/saml-setup/templates/\`:
- \`config.php.template\` - Main SimpleSAMLphp configuration template
- \`authsources.php.template\` - Authentication sources template  
- \`saml20-idp-remote.php.template\` - IdP metadata template

## Environment Variables:
Templates use envsubst for variable substitution. Key variables include:
- \`ENVIRONMENT\` - Target environment (dev/container/production)
- \`SP_ENTITY_ID\` - Service Provider entity ID
- \`IDP_ENTITY_ID\` - Identity Provider entity ID
- \`SECRET_SALT\` - SimpleSAMLphp secret salt
- \`ADMIN_PASSWORD\` - Admin interface password

## Validation:
Each environment directory contains a README.md with specific configuration details.
Review generated files before deploying to ensure they match your requirements.
EOF
    
    log "✅ Test configurations generated in: $base_test_dir"
    info "📋 Review the generated files in $base_test_dir before deployment"
}

# Detect Drupal root directory based on execution environment
DRUPAL_ROOT=""
WEB_ROOT=""
VENDOR_ROOT=""
SIMPLESAML_ROOT=""

case "$EXECUTION_MODE" in
    "ddev")
        DRUPAL_ROOT="/var/www/html"
        WEB_ROOT="$DRUPAL_ROOT/web"
        VENDOR_ROOT="$DRUPAL_ROOT/vendor"
        SIMPLESAML_ROOT="$DRUPAL_ROOT/simplesamlphp"
        ;;
    "server")
        DRUPAL_ROOT="/opt/drupal"
        WEB_ROOT="$DRUPAL_ROOT/web"
        VENDOR_ROOT="$DRUPAL_ROOT/vendor"
        SIMPLESAML_ROOT="$DRUPAL_ROOT/simplesamlphp"
        ;;
    "container")
        DRUPAL_ROOT="/var/www/html"
        WEB_ROOT="$DRUPAL_ROOT/web"
        VENDOR_ROOT="$DRUPAL_ROOT/vendor"
        SIMPLESAML_ROOT="$DRUPAL_ROOT/simplesamlphp"
        ;;
    "test")
        DRUPAL_ROOT="$(pwd)"
        WEB_ROOT="$DRUPAL_ROOT/web"
        VENDOR_ROOT="$DRUPAL_ROOT/vendor"
        SIMPLESAML_ROOT="$DRUPAL_ROOT/simplesamlphp"
        ;;
esac

# Check dependencies before proceeding
info "Checking required dependencies..."
if ! check_dependencies; then
    exit 1
fi
info "✅ All dependencies are available"

# If running in test-only mode, generate test configs and exit
if [ "$TEST_ONLY" = true ]; then
    echo ""
    echo "🧪 Generating test configurations..."
    generate_test_configs
    echo ""
    echo "✅ Test configuration generation complete!"
    echo "📋 Review the generated files in $DRUPAL_ROOT/test-output/ before deployment"
    echo "💡 To run the full setup, use: $0 (without --test-only flag)"
    exit 0
fi

# Set the working directory to Drupal root (only if not using DDEV)
if [ "$USE_DDEV" = false ]; then
    cd "$DRUPAL_ROOT"
fi

echo "1. 📦 Enabling SAML modules..."
exec_cmd "drush en simplesamlphp_auth externalauth -y"

echo "2. ⚙️ Configuring SimpleSAMLphp auth module..."
exec_cmd "drush config:set simplesamlphp_auth.settings authsource default-sp -y"
exec_cmd "drush config:set simplesamlphp_auth.settings activate 1 -y"

# Configure UVA NetBadge attribute mapping per ITS specifications
echo "   🔗 Configuring UVA NetBadge attribute mapping..."
exec_cmd "drush config:set simplesamlphp_auth.settings user_name uid -y"
exec_cmd "drush config:set simplesamlphp_auth.settings mail_attr mail -y"
exec_cmd "drush config:set simplesamlphp_auth.settings unique_id uid -y"

# Configure role mapping based on eduPersonAffiliation
exec_cmd "drush config:set simplesamlphp_auth.settings role.population '1' -y"
exec_cmd "drush config:set simplesamlphp_auth.settings role.eval_every_time 1 -y"

echo "   ✅ Configured Drupal SAML settings for UVA NetBadge"

echo "3. 🔐 Setting up SAML certificates..."
# Check if certificates exist, generate if needed
if [ ! -f "$SIMPLESAML_ROOT/cert/server.crt" ] || [ ! -f "$SIMPLESAML_ROOT/cert/server.key" ]; then
    echo "   📜 SAML certificates not found, generating..."
    
    # Source the certificate management script
    if [ -f "$DRUPAL_ROOT/scripts/saml-setup/manage-saml-certificates.sh" ]; then
        source "$DRUPAL_ROOT/scripts/saml-setup/manage-saml-certificates.sh"
        
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
echo ""
echo "🔧 Template System:"
echo "   - Configuration files generated from templates in scripts/saml-setup/templates/"
echo "   - Uses envsubst for variable substitution"
echo "   - Run with --test-only flag to generate test configurations"
echo "   - Templates support multiple environments (dev/container/production)"
