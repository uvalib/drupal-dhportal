#!/bin/bash

# SAML Certificate Generation Script
# 
# USAGE:
#   ./generate-saml-certificates.sh [dev|staging|production|cleanup|cleanup-dev]
#
# DEVELOPMENT: Generates disposable self-signed certificates locally
# STAGING/PRODUCTION: Generates CSRs for CA-signed certificates (one-time setup)
# 
# DEV certificates are temporary and NEVER committed to git
# STAGING/PROD certificates are static and committed to git for consistent deployments

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️  $1${NC}"; }
error() { echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%H:%M:%S')] ℹ️  $1${NC}"; }

# Generate disposable development certificates  
generate_dev_certificates() {
    local domain="$1"
    
    info "🏠 Generating DISPOSABLE development certificates"
    warn "These certificates are temporary and will NOT be committed to git"
    
    # Create local temp directory
    local temp_dir="/tmp/drupal-dhportal-saml-dev"
    mkdir -p "$temp_dir"
    
    # Generate temporary private key
    openssl genrsa -out "$temp_dir/saml-sp-dev.key" 2048
    
    # Create certificate configuration
    cat > "$temp_dir/cert.conf" << EOF
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
CN = ${domain}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${domain}
DNS.2 = localhost
DNS.3 = 127.0.0.1
EOF
    
    # Generate self-signed certificate for development
    openssl req -new -x509 -days 30 \
        -key "$temp_dir/saml-sp-dev.key" \
        -out "$temp_dir/saml-sp-dev.crt" \
        -config "$temp_dir/cert.conf" \
        -extensions v3_req
    
    # Copy to SAML config directory for SimpleSAMLphp
    mkdir -p "saml-config/dev"
    cp "$temp_dir/saml-sp-dev.crt" "saml-config/dev/"
    cp "$temp_dir/saml-sp-dev.key" "saml-config/dev/"
    
    log "Generated development certificates:"
    log "  Certificate: saml-config/dev/saml-sp-dev.crt (30-day expiry)"
    log "  Private Key: saml-config/dev/saml-sp-dev.key (local only)"
    log "  Temp files: $temp_dir/"
    echo
    warn "🚮 IMPORTANT: These are DISPOSABLE certificates for development only!"
    warn "   Run './scripts/generate-saml-certificates.sh cleanup-dev' when done"
    echo
}

# Generate key and CSR for environment
generate_key_and_csr() {
    local env="$1"
    local domain="$2"
    
    info "Generating certificates for $env environment"
    
    # Create output directory
    mkdir -p "saml-config/temp/$env"
    
    # Handle development environment differently
    if [ "$env" = "dev" ]; then
        generate_dev_certificates "$domain"
        return
    fi
    
    # Check if we're in a server environment with existing infrastructure keys
    local use_infrastructure_key=false
    local infra_key_path=""
    
    if [ -n "$TERRAFORM_INFRA_DIR" ] && [ -d "$TERRAFORM_INFRA_DIR" ]; then
        case "$env" in
            "staging")
                infra_key_path="$TERRAFORM_INFRA_DIR/dh.library.virginia.edu/staging/keys/dh-drupal-staging.pem"
                ;;
            "production")
                infra_key_path="$TERRAFORM_INFRA_DIR/dh.library.virginia.edu/production/keys/dh-drupal-production.pem"
                ;;
        esac
        
        if [ -f "$infra_key_path" ]; then
            use_infrastructure_key=true
            log "Using existing infrastructure private key: $infra_key_path"
        fi
    fi
    
    # Generate or use existing private key
    if [ "$use_infrastructure_key" = true ]; then
        # Use existing infrastructure key
        cp "$infra_key_path" "saml-config/temp/$env/saml-sp-${env}.key"
    else
        # Generate new private key
        log "Generating new private key for $env environment"
        openssl genrsa -out "saml-config/temp/$env/saml-sp-${env}.key" 2048
    fi
    
    # Create certificate configuration
    cat > "saml-config/temp/$env/cert.conf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = Virginia
L = Charlottesville
O = University of Virginia
OU = Digital Humanities Portal
CN = ${domain}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${domain}
DNS.2 = *.${domain}
EOF
    
    # Generate CSR
    openssl req -new \
        -key "saml-config/temp/$env/saml-sp-${env}.key" \
        -out "saml-config/temp/$env/saml-sp-${env}.csr" \
        -config "saml-config/temp/$env/cert.conf"
    
    # Generate self-signed certificate for testing
    openssl x509 -req -days 365 \
        -in "saml-config/temp/$env/saml-sp-${env}.csr" \
        -signkey "saml-config/temp/$env/saml-sp-${env}.key" \
        -out "saml-config/temp/$env/saml-sp-${env}-selfsigned.crt" \
        -extensions v3_req \
        -extfile "saml-config/temp/$env/cert.conf"
    
    log "Generated files for $env environment:"
    if [ "$use_infrastructure_key" = true ]; then
        log "  Using Infrastructure Key: $infra_key_path"
    else
        log "  Private Key: saml-config/temp/$env/saml-sp-${env}.key"
    fi
    log "  CSR: saml-config/temp/$env/saml-sp-${env}.csr"
    log "  Self-signed Cert: saml-config/temp/$env/saml-sp-${env}-selfsigned.crt"
    echo
}

# Main function
main() {
    local env="$1"
    
    case "$env" in
        "dev")
            info "🏠 Generating DEVELOPMENT certificates..."
            generate_key_and_csr "dev" "localhost"
            ;;
        "staging")
            info "🔐 Generating STAGING certificates and CSRs..."
            generate_key_and_csr "staging" "dh-staging.library.virginia.edu"
            show_staging_production_instructions
            ;;
        "production")
            info "🔐 Generating PRODUCTION certificates and CSRs..."
            generate_key_and_csr "production" "dh.library.virginia.edu"
            show_staging_production_instructions
            ;;
        "")
            info "🔐 Generating certificates for ALL environments..."
            echo
            
            # Generate for staging environment
            generate_key_and_csr "staging" "dh-staging.library.virginia.edu"
            
            # Generate for production environment  
            generate_key_and_csr "production" "dh.library.virginia.edu"
            
            show_staging_production_instructions
            ;;
        *)
            error "Unknown environment: $env"
            echo "Usage: $0 [dev|staging|production|cleanup|cleanup-dev]"
            exit 1
            ;;
    esac
}

show_staging_production_instructions() {
    echo "=================================================="
    warn "IMPORTANT - Static Certificate Strategy:"
    echo "These certificates will be used consistently across ALL deployments."
    echo "Send the signed certificates to NetBadge admin for IDP configuration."
    echo
    warn "SECURITY NOTICE:"
    echo "Private keys have been generated in saml-config/temp/"
    echo "If running on a server, REMOVE private keys after generating CSRs!"
    echo "Private keys should only be stored encrypted in terraform-infrastructure."
    echo
    warn "Next Steps:"
    echo "1. Submit CSRs to UVA Certificate Authority:"
    echo "   - saml-config/temp/staging/saml-sp-staging.csr"
    echo "   - saml-config/temp/production/saml-sp-production.csr"
    echo
    echo "2. Once you receive signed certificates from CA:"
    echo "   - Copy staging cert to: saml-config/certificates/staging/saml-sp.crt"
    echo "   - Copy production cert to: saml-config/certificates/production/saml-sp.crt"
    echo "   - Commit certificates to git repository"
    echo
    echo "3. Send certificate data to NetBadge admin:"
    echo "   - Staging certificate for test IDP setup"
    echo "   - Production certificate for production IDP setup"
    echo
    echo "4. Private keys management:"
    echo "   - If using existing infrastructure keys: Use those (recommended)"
    echo "   - If using generated keys: Encrypt with ccrypt and store in terraform repo"
    echo "   - NEVER store unencrypted private keys in git repository"
    echo "   - DELETE private keys from servers after CSR generation"
    echo
    warn "Recommended Workflow:"
    echo "- Generate locally on secure workstation (preferred)"
    echo "- OR generate on staging and immediately remove private keys"
    echo "- Commit certificates from local machine"
    echo
    warn "Certificate Renewal:"
    echo "Only regenerate certificates when approaching expiration AND"
    echo "coordinate with NetBadge admin for IDP reconfiguration."
    echo "=================================================="
    
    log "🎉 Certificate generation completed!"
}

# Cleanup function for server environments
cleanup_private_keys() {
    warn "🧹 Cleaning up private keys from server..."
    
    if [ -f "saml-config/temp/staging/saml-sp-staging.key" ]; then
        rm -f saml-config/temp/staging/saml-sp-staging.key
        log "Removed staging private key"
    fi
    
    if [ -f "saml-config/temp/production/saml-sp-production.key" ]; then
        rm -f saml-config/temp/production/saml-sp-production.key
        log "Removed production private key"
    fi
    
    log "✅ Private keys cleaned up"
}

# Cleanup function for development certificates
cleanup_dev_certificates() {
    warn "🧹 Cleaning up development certificates..."
    
    # Remove local development certificates
    if [ -d "saml-config/dev" ]; then
        rm -rf "saml-config/dev"
        log "Removed development certificates from saml-config/dev/"
    fi
    
    # Remove temporary files
    local temp_dir="/tmp/drupal-dhportal-saml-dev"
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
        log "Removed temporary development files from $temp_dir"
    fi
    
    log "✅ Development certificates cleaned up"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Parse command line arguments
    COMMAND=""
    OUTPUT_DIR=""
    FORCE_FLAG=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dev)
                COMMAND="dev"
                shift
                ;;
            --output-dir)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            --force)
                FORCE_FLAG="--force"
                shift
                ;;
            dev|staging|production|cleanup|cleanup-dev)
                COMMAND="$1"
                shift
                ;;
            *)
                if [ -z "$COMMAND" ]; then
                    COMMAND="$1"
                fi
                shift
                ;;
        esac
    done
    
    case "$COMMAND" in
        "cleanup")
            cleanup_private_keys
            ;;
        "cleanup-dev")
            cleanup_dev_certificates
            ;;
        "dev"|"staging"|"production")
            # If output directory is specified (for testing), use it
            if [ -n "$OUTPUT_DIR" ]; then
                # For testing, generate simple SP certificates to output directory
                if [ "$COMMAND" = "dev" ]; then
                    mkdir -p "$OUTPUT_DIR"
                    openssl req -x509 -newkey rsa:2048 -keyout "$OUTPUT_DIR/sp.key" -out "$OUTPUT_DIR/sp.crt" -days 365 -nodes -subj "/CN=test-sp/O=Test/C=US" 2>/dev/null
                    log "Test certificates generated in $OUTPUT_DIR"
                    exit 0
                fi
            fi
            
            main "$COMMAND"
            
            # Offer cleanup option if running on server (for staging/production)
            if [ "$COMMAND" != "dev" ] && ([ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ]); then
                echo
                warn "🚨 Server environment detected!"
                echo "Run './scripts/generate-saml-certificates.sh cleanup' to remove private keys"
            fi
            ;;
        "")
            main ""
            
            # Offer cleanup option if running on server
            if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ]; then
                echo
                warn "🚨 Server environment detected!"
                echo "Run './scripts/generate-saml-certificates.sh cleanup' to remove private keys"
            fi
            ;;
        *)
            error "Unknown command: $COMMAND"
            echo "Usage: $0 [dev|staging|production|cleanup|cleanup-dev] [--dev --output-dir DIR --force]"
            echo
            echo "Commands:"
            echo "  dev          Generate disposable development certificates"
            echo "  staging      Generate staging certificates and CSRs"
            echo "  production   Generate production certificates and CSRs"
            echo "  cleanup      Remove staging/production private keys from server"
            echo "  cleanup-dev  Remove all development certificates"
            echo "  (no args)    Generate both staging and production"
            echo
            echo "Options:"
            echo "  --dev        Same as 'dev' command"
            echo "  --output-dir DIR  Generate certificates in specified directory (testing only)"
            echo "  --force      Force overwrite existing files"
            exit 1
            ;;
    esac
fi
