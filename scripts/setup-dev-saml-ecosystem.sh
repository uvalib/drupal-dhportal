#!/bin/bash

# SAML Development Ecosystem Setup
# Coordinates certificate generation between drupal-dhportal (SP) and drupal-netbadge (test IDP)
# 
# This script creates a complete local SAML testing environment by:
# 1. Generating IDP certificates for drupal-netbadge
# 2. Generating SP certificates for drupal-dhportal  
# 3. Cross-configuring trust relationships
#
# USAGE:
#   ./scripts/setup-dev-saml-ecosystem.sh [netbadge-project-path]
#
# EXAMPLE:
#   ./scripts/setup-dev-saml-ecosystem.sh ../drupal-netbadge

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] ℹ️  $1${NC}"; }
step() { echo -e "${PURPLE}[$(date +'%H:%M:%S')] 🔧 $1${NC}"; }
success() { echo -e "${CYAN}[$(date +'%H:%M:%S')] 🎉 $1${NC}"; }

# Configuration
NETBADGE_PATH="${1:-../drupal-netbadge}"
DHPORTAL_PATH="$(pwd)"
TEMP_DIR="/tmp/saml-dev-ecosystem"

banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              SAML Development Ecosystem Setup           ║"
    echo "║                                                          ║"
    echo "║  📋 SP (Service Provider): drupal-dhportal              ║"
    echo "║  🏢 IDP (Identity Provider): drupal-netbadge            ║"
    echo "║  🔗 Creates complete local SAML testing environment     ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_prerequisites() {
    step "Checking prerequisites..."
    
    # Check if netbadge project exists
    if [ ! -d "$NETBADGE_PATH" ]; then
        error "NetBadge project not found at: $NETBADGE_PATH"
        echo "Usage: $0 [netbadge-project-path]"
        exit 1
    fi
    
    # Check if we're in dhportal project
    if [ ! -f "composer.json" ] || [ ! -d "saml-config" ] || [ ! -f "README.md" ]; then
        error "This script must be run from the drupal-dhportal project root"
        error "Expected files: composer.json, saml-config/, README.md"
        exit 1
    fi
    
    # Check required tools
    for tool in openssl ddev; do
        if ! command -v $tool &> /dev/null; then
            error "$tool is required but not installed"
            exit 1
        fi
    done
    
    log "Prerequisites check passed"
    log "NetBadge project: $NETBADGE_PATH"
    log "DHPortal project: $DHPORTAL_PATH"
}

setup_temp_directories() {
    step "Setting up temporary directories..."
    
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"/{idp,sp}
    
    log "Created temporary workspace: $TEMP_DIR"
}

check_and_start_containers() {
    step "🚀 Checking and starting DDEV containers..."
    
    # Check NetBadge container status
    info "Checking NetBadge (IDP) container status..."
    cd "$NETBADGE_PATH"
    
    if ! ddev describe >/dev/null 2>&1; then
        warn "NetBadge container not running, starting it now..."
        ddev start
        if [ $? -eq 0 ]; then
            log "✅ NetBadge container started successfully"
        else
            error "Failed to start NetBadge container"
            exit 1
        fi
    else
        local netbadge_status=$(ddev status --format=json 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        if [ "$netbadge_status" = "running" ]; then
            log "✅ NetBadge container is already running"
        else
            warn "NetBadge container exists but not running, starting it..."
            ddev start
            if [ $? -eq 0 ]; then
                log "✅ NetBadge container started successfully"
            else
                error "Failed to start NetBadge container"
                exit 1
            fi
        fi
    fi
    
    # Check DHPortal container status
    info "Checking DHPortal (SP) container status..."
    cd "$DHPORTAL_PATH"
    
    if ! ddev describe >/dev/null 2>&1; then
        warn "DHPortal container not running, starting it now..."
        ddev start
        if [ $? -eq 0 ]; then
            log "✅ DHPortal container started successfully"
        else
            error "Failed to start DHPortal container"
            exit 1
        fi
    else
        local dhportal_status=$(ddev status --format=json 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        if [ "$dhportal_status" = "running" ]; then
            log "✅ DHPortal container is already running"
        else
            warn "DHPortal container exists but not running, starting it..."
            ddev start
            if [ $? -eq 0 ]; then
                log "✅ DHPortal container started successfully"
            else
                error "Failed to start DHPortal container"
                exit 1
            fi
        fi
    fi
    
    # Wait a moment for containers to fully initialize
    info "Waiting for containers to fully initialize..."
    sleep 3
    
    log "✅ Both DDEV containers are running and ready"
}

generate_idp_certificates() {
    step "🏢 Generating IDP certificates for drupal-netbadge..."
    
    # Generate IDP private key
    openssl genrsa -out "$TEMP_DIR/idp/server.key" 2048
    
    # Create IDP certificate configuration
    cat > "$TEMP_DIR/idp/cert.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = Virginia
L = Charlottesville
O = University of Virginia
OU = NetBadge Test IDP
CN = drupal-netbadge.ddev.site

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = drupal-netbadge.ddev.site
DNS.2 = localhost
DNS.3 = 127.0.0.1
EOF
    
    # Generate IDP self-signed certificate (30 days)
    openssl req -new -x509 -days 30 \
        -key "$TEMP_DIR/idp/server.key" \
        -out "$TEMP_DIR/idp/server.crt" \
        -config "$TEMP_DIR/idp/cert.conf" \
        -extensions v3_req
    
    # Convert private key to PEM format for SimpleSAMLphp
    cp "$TEMP_DIR/idp/server.key" "$TEMP_DIR/idp/server.pem"
    
    log "Generated IDP certificates:"
    log "  Private Key: $TEMP_DIR/idp/server.key"
    log "  Certificate: $TEMP_DIR/idp/server.crt"
    log "  PEM Format: $TEMP_DIR/idp/server.pem"
}

generate_sp_certificates() {
    step "📋 Generating SP certificates for drupal-dhportal..."
    
    # Generate SP private key
    openssl genrsa -out "$TEMP_DIR/sp/saml-sp-dev.key" 2048
    
    # Create SP certificate configuration
    cat > "$TEMP_DIR/sp/cert.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = Virginia
L = Charlottesville
O = University of Virginia
OU = Digital Humanities Portal - DEV
CN = drupal-dhportal.ddev.site

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = drupal-dhportal.ddev.site
DNS.2 = localhost
DNS.3 = 127.0.0.1
EOF
    
    # Generate SP self-signed certificate (30 days)
    openssl req -new -x509 -days 30 \
        -key "$TEMP_DIR/sp/saml-sp-dev.key" \
        -out "$TEMP_DIR/sp/saml-sp-dev.crt" \
        -config "$TEMP_DIR/sp/cert.conf" \
        -extensions v3_req
    
    log "Generated SP certificates:"
    log "  Private Key: $TEMP_DIR/sp/saml-sp-dev.key"
    log "  Certificate: $TEMP_DIR/sp/saml-sp-dev.crt"
}

install_idp_certificates() {
    step "🏢 Installing IDP certificates to drupal-netbadge..."
    
    # Create cert directory if it doesn't exist
    mkdir -p "$NETBADGE_PATH/saml-config/simplesamlphp/cert"
    
    # Install IDP certificates
    cp "$TEMP_DIR/idp/server.crt" "$NETBADGE_PATH/saml-config/simplesamlphp/cert/"
    cp "$TEMP_DIR/idp/server.pem" "$NETBADGE_PATH/saml-config/simplesamlphp/cert/"
    cp "$TEMP_DIR/idp/server.key" "$NETBADGE_PATH/saml-config/simplesamlphp/cert/"
    
    # Set proper permissions
    chmod 600 "$NETBADGE_PATH/saml-config/simplesamlphp/cert/server.key"
    chmod 600 "$NETBADGE_PATH/saml-config/simplesamlphp/cert/server.pem"
    chmod 644 "$NETBADGE_PATH/saml-config/simplesamlphp/cert/server.crt"
    
    log "Installed IDP certificates to: $NETBADGE_PATH/saml-config/simplesamlphp/cert/"
}

install_sp_certificates() {
    step "📋 Installing SP certificates to drupal-dhportal..."
    
    # Create dev cert directory
    mkdir -p "$DHPORTAL_PATH/saml-config/dev"
    
    # Install SP certificates
    cp "$TEMP_DIR/sp/saml-sp-dev.crt" "$DHPORTAL_PATH/saml-config/dev/"
    cp "$TEMP_DIR/sp/saml-sp-dev.key" "$DHPORTAL_PATH/saml-config/dev/"
    
    # Set proper permissions
    chmod 600 "$DHPORTAL_PATH/saml-config/dev/saml-sp-dev.key"
    chmod 644 "$DHPORTAL_PATH/saml-config/dev/saml-sp-dev.crt"
    
    log "Installed SP certificates to: $DHPORTAL_PATH/saml-config/dev/"
}

create_sp_metadata() {
    step "📋 Creating SP metadata for IDP configuration..."
    
    # Extract certificate content (without headers)
    SP_CERT_CONTENT=$(openssl x509 -in "$TEMP_DIR/sp/saml-sp-dev.crt" -noout -text | grep -A 100 "BEGIN CERTIFICATE" | grep -v "BEGIN CERTIFICATE" | grep -v "END CERTIFICATE" | tr -d ' \n')
    
    # Create SP metadata file for the IDP to consume
    cat > "$TEMP_DIR/sp-metadata.xml" << EOF
<?xml version="1.0"?>
<md:EntityDescriptor xmlns:md="urn:oasis:names:tc:SAML:2.0:metadata" 
                     entityID="https://drupal-dhportal.ddev.site/simplesaml/module.php/saml/sp/metadata.php/default-sp">
    <md:SPSSODescriptor protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
        <md:KeyDescriptor use="signing">
            <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
                <ds:X509Data>
                    <ds:X509Certificate>$SP_CERT_CONTENT</ds:X509Certificate>
                </ds:X509Data>
            </ds:KeyInfo>
        </md:KeyDescriptor>
        <md:KeyDescriptor use="encryption">
            <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
                <ds:X509Data>
                    <ds:X509Certificate>$SP_CERT_CONTENT</ds:X509Certificate>
                </ds:X509Data>
            </ds:KeyInfo>
        </md:KeyDescriptor>
        <md:AssertionConsumerService Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST" 
                                     Location="https://drupal-dhportal.ddev.site/simplesaml/module.php/saml/sp/saml2-acs.php/default-sp" 
                                     index="0" />
    </md:SPSSODescriptor>
</md:EntityDescriptor>
EOF
    
    log "Created SP metadata: $TEMP_DIR/sp-metadata.xml"
}

configure_idp_trust() {
    step "🔗 Configuring IDP to trust SP certificates..."
    
    # Create metadata directory for IDP
    mkdir -p "$NETBADGE_PATH/saml-config/simplesamlphp/metadata"
    
    # Create SP metadata entry for the IDP
    cat > "$NETBADGE_PATH/saml-config/simplesamlphp/metadata/saml20-sp-remote.php" << 'EOF'
<?php

/**
 * SAML 2.0 remote SP metadata for SimpleSAMLphp.
 * 
 * This file contains metadata for Service Providers (SP) that this 
 * Identity Provider (IDP) should trust.
 */

// DHPortal Development SP
$metadata['https://drupal-dhportal.ddev.site/simplesaml/module.php/saml/sp/metadata.php/default-sp'] = [
    'AssertionConsumerService' => 'https://drupal-dhportal.ddev.site/simplesaml/module.php/saml/sp/saml2-acs.php/default-sp',
    'SingleLogoutService' => 'https://drupal-dhportal.ddev.site/simplesaml/module.php/saml/sp/saml2-logout.php/default-sp',
    
    // Trust the SP certificate
    'keys' => [
        [
            'encryption' => false,
            'signing' => true,
            'type' => 'X509Certificate',
            'X509Certificate' => file_get_contents(__DIR__ . '/../cert/sp-dhportal-dev.crt'),
        ],
    ],
    
    // Attribute mapping
    'attributes' => [
        'uid',
        'cn', 
        'mail',
        'eduPersonPrincipalName',
        'eduPersonAffiliation',
    ],
    
    // Enable signature validation
    'sign.assertion' => true,
    'sign.response' => true,
    'validate.signature' => true,
];
EOF
    
    # Copy SP certificate for IDP validation
    cp "$TEMP_DIR/sp/saml-sp-dev.crt" "$NETBADGE_PATH/saml-config/simplesamlphp/cert/sp-dhportal-dev.crt"
    chmod 644 "$NETBADGE_PATH/saml-config/simplesamlphp/cert/sp-dhportal-dev.crt"
    
    log "Configured IDP to trust SP certificate"
}

create_configuration_summary() {
    step "📝 Creating configuration summary..."
    
    cat > "$TEMP_DIR/ecosystem-summary.md" << EOF
# SAML Development Ecosystem Configuration

## 🎉 Setup Complete!

Your local SAML development ecosystem has been configured with:

### 🏢 Identity Provider (drupal-netbadge)
- **URL**: https://drupal-netbadge.ddev.site:8443
- **Metadata**: https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/metadata.php
- **Certificate**: $NETBADGE_PATH/saml-config/simplesamlphp/cert/server.crt
- **Private Key**: $NETBADGE_PATH/saml-config/simplesamlphp/cert/server.pem
- **Status**: ✅ DDEV container is running and ready

### 📋 Service Provider (drupal-dhportal)  
- **URL**: https://drupal-dhportal.ddev.site
- **Metadata**: https://drupal-dhportal.ddev.site/simplesaml/module.php/saml/sp/metadata.php/default-sp
- **Certificate**: $DHPORTAL_PATH/saml-config/dev/saml-sp-dev.crt
- **Private Key**: $DHPORTAL_PATH/saml-config/dev/saml-sp-dev.key
- **Status**: ✅ DDEV container is running and ready

### 🔗 Trust Relationships
- ✅ IDP trusts SP certificate for authentication
- ✅ SP will trust IDP certificate for assertions
- ✅ Both certificates expire in 30 days (development only)
- ✅ Both DDEV containers are running and accessible

## 🚀 Ready for Testing!

### Test SAML Authentication Flow
1. **Visit**: https://drupal-dhportal.ddev.site/saml_login
2. **Redirected to**: NetBadge test IDP at https://drupal-netbadge.ddev.site:8443
3. **Login**: Use test credentials configured in NetBadge authsources
4. **Success**: Authenticated user redirected back to DHPortal

### 🔧 Configuration Updates (if needed)

If you need to update DHPortal SP configuration:
- **IDP Metadata URL**: https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/metadata.php
- **IDP Entity ID**: https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/metadata.php

### 🔍 Container Management

Both containers are already running, but if you need to manage them:

\`\`\`bash
# Check container status
cd $NETBADGE_PATH && ddev status
cd $DHPORTAL_PATH && ddev status

# Restart if needed
cd $NETBADGE_PATH && ddev restart
cd $DHPORTAL_PATH && ddev restart

# View logs if troubleshooting
cd $NETBADGE_PATH && ddev logs
cd $DHPORTAL_PATH && ddev logs
\`\`\`

## 🧹 Cleanup
When done developing, clean up certificates:
\`\`\`bash
cd $DHPORTAL_PATH
./scripts/setup-dev-saml-ecosystem.sh cleanup
\`\`\`

## 🔄 Certificate Renewal
These development certificates expire in 30 days. To regenerate:
\`\`\`bash
cd $DHPORTAL_PATH
./scripts/setup-dev-saml-ecosystem.sh [netbadge-path]
\`\`\`

---
🎉 **Your SAML development ecosystem is ready for testing!**
EOF
    
    log "Created configuration summary: $TEMP_DIR/ecosystem-summary.md"
}

cleanup_ecosystem() {
    step "🧹 Cleaning up SAML development ecosystem..."
    
    # Remove SP certificates from dhportal
    if [ -d "$DHPORTAL_PATH/saml-config/dev" ]; then
        rm -rf "$DHPORTAL_PATH/saml-config/dev"
        log "Removed SP certificates from dhportal"
    fi
    
    # Remove IDP certificates from netbadge
    if [ -d "$NETBADGE_PATH/saml-config/simplesamlphp/cert" ]; then
        find "$NETBADGE_PATH/saml-config/simplesamlphp/cert" -name "server.*" -delete
        find "$NETBADGE_PATH/saml-config/simplesamlphp/cert" -name "sp-dhportal-dev.crt" -delete
        log "Removed IDP certificates from netbadge"
    fi
    
    # Remove SP metadata from netbadge
    if [ -f "$NETBADGE_PATH/saml-config/simplesamlphp/metadata/saml20-sp-remote.php" ]; then
        rm "$NETBADGE_PATH/saml-config/simplesamlphp/metadata/saml20-sp-remote.php"
        log "Removed SP metadata from netbadge"
    fi
    
    # Remove temp directory
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
        log "Removed temporary files"
    fi
    
    success "🎉 SAML development ecosystem cleaned up!"
}

main() {
    banner
    
    if [ "$1" = "cleanup" ]; then
        cleanup_ecosystem
        exit 0
    fi
    
    check_prerequisites
    setup_temp_directories
    check_and_start_containers
    
    generate_idp_certificates
    generate_sp_certificates
    
    install_idp_certificates
    install_sp_certificates
    
    create_sp_metadata
    configure_idp_trust
    
    create_configuration_summary
    
    success "🎉 SAML Development Ecosystem Setup Complete!"
    echo
    warn "📋 Configuration Summary:"
    cat "$TEMP_DIR/ecosystem-summary.md"
    echo
    info "💾 Full summary saved to: $TEMP_DIR/ecosystem-summary.md"
    echo
    success "🚀 Both DDEV containers are running and ready for SAML testing!"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
