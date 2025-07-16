#!/bin/bash

# Enhanced SAML Certificate Management Script
# Integrates with existing encrypted key infrastructure
# Uses environment-specific certificates stored in git repo

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"; }

# Detect environment and set paths
detect_environment() {
    DRUPAL_ROOT=""
    if [ -f "/opt/drupal/web/index.php" ]; then
        DRUPAL_ROOT="/opt/drupal"
        ENVIRONMENT="server"
        # Look for decrypted key from deployment pipeline
        TERRAFORM_INFRA_DIR="${TERRAFORM_INFRA_DIR:-/opt/drupal/terraform-infrastructure}"
        info "Detected server environment: /opt/drupal"
    elif [ -f "/var/www/html/web/index.php" ]; then
        DRUPAL_ROOT="/var/www/html"
        ENVIRONMENT="container"
        info "Detected container environment: /var/www/html"
    else
        # Not in container, assume we're in project directory
        if [ -f "web/index.php" ]; then
            DRUPAL_ROOT="$(pwd)"
            ENVIRONMENT="ddev"
            info "Detected DDEV/local environment: $(pwd)"
        else
            error "Not in a recognized Drupal environment"
            exit 1
        fi
    fi

    CERT_DIR="$DRUPAL_ROOT/simplesamlphp/cert"
    CONFIG_DIR="$DRUPAL_ROOT/simplesamlphp/config"
    
    # Set paths for certificate storage in repo
    if [ "$ENVIRONMENT" = "server" ]; then
        # In production, use the git repo from container
        REPO_CERT_DIR="/opt/drupal/util/drupal-dhportal/saml-config/certificates"
        REPO_KEY_DIR="/opt/drupal/util/drupal-dhportal/saml-config/keys"
    else
        # In development, use local repo
        REPO_CERT_DIR="$DRUPAL_ROOT/saml-config/certificates"
        REPO_KEY_DIR="$DRUPAL_ROOT/saml-config/keys"
    fi
}

# Create necessary directories
setup_directories() {
    mkdir -p "$CERT_DIR"
    mkdir -p "$REPO_CERT_DIR/staging"
    mkdir -p "$REPO_CERT_DIR/production"
    mkdir -p "$REPO_KEY_DIR/staging"
    mkdir -p "$REPO_KEY_DIR/production"
}

# Generate CSR for certificate signing
generate_csr() {
    local env_name="$1"
    local domain="$2"
    local key_file="$3"
    local csr_file="$4"
    
    log "Generating CSR for $env_name environment"
    
    # Create certificate configuration
    cat > "/tmp/saml-cert-${env_name}.conf" << EOF
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
    openssl req -new -key "$key_file" -out "$csr_file" -config "/tmp/saml-cert-${env_name}.conf"
    
    log "CSR generated: $csr_file"
}

# Setup certificate for specific environment
setup_environment_certificate() {
    local env_name="$1"  # staging or production
    local domain="$2"
    local cert_name="${3:-server}"
    
    log "Setting up SAML certificate for $env_name environment"
    
    # Determine key source based on environment
    local encrypted_key_path=""
    local decrypted_key_path=""
    
    if [ "$ENVIRONMENT" = "server" ] && [ -n "$TERRAFORM_INFRA_DIR" ]; then
        # In server environment, use existing decrypted infrastructure keys
        case "$env_name" in
            "staging")
                decrypted_key_path="$TERRAFORM_INFRA_DIR/dh.library.virginia.edu/staging/keys/dh-drupal-staging.pem"
                ;;
            "production")
                decrypted_key_path="$TERRAFORM_INFRA_DIR/dh.library.virginia.edu/production/keys/dh-drupal-production.pem"
                ;;
        esac
        
        if [ ! -f "$decrypted_key_path" ]; then
            error "Infrastructure key not found: $decrypted_key_path"
            error "Make sure the deployment pipeline has decrypted the infrastructure keys"
            return 1
        fi
        
        log "Using existing infrastructure private key: $decrypted_key_path"
    else
        # In development, use local encrypted keys (if available)
        encrypted_key_path="$REPO_KEY_DIR/$env_name/saml-sp-${env_name}.pem.cpt"
        if [ -f "$encrypted_key_path" ]; then
            warn "Encrypted key found but cannot decrypt in $ENVIRONMENT environment"
            return 1
        else
            warn "No encrypted key found, generating self-signed certificate"
            generate_self_signed_certificate "$domain" "$cert_name"
            return 0
        fi
    fi
    
    # Copy the decrypted private key
    cp "$decrypted_key_path" "$CERT_DIR/${cert_name}.key"
    chmod 600 "$CERT_DIR/${cert_name}.key"
    
    # Check if we have a stored certificate for this environment
    local stored_cert_path="$REPO_CERT_DIR/$env_name/saml-sp.crt"
    
    if [ -f "$stored_cert_path" ]; then
        log "Using stored certificate for $env_name environment"
        cp "$stored_cert_path" "$CERT_DIR/${cert_name}.crt"
        chmod 644 "$CERT_DIR/${cert_name}.crt"
        
        # Check if chain certificate exists
        local chain_cert_path="$REPO_CERT_DIR/$env_name/saml-sp-chain.crt"
        if [ -f "$chain_cert_path" ]; then
            log "Found certificate chain, creating full chain certificate"
            cat "$stored_cert_path" "$chain_cert_path" > "$CERT_DIR/${cert_name}.crt"
        fi
    else
        warn "No stored certificate found for $env_name environment"
        warn "Generate a CSR and get it signed by your CA, then store the certificate in:"
        warn "  $stored_cert_path"
        
        # Generate CSR for manual signing
        local csr_path="/tmp/saml-sp-${env_name}.csr"
        generate_csr "$env_name" "$domain" "$CERT_DIR/${cert_name}.key" "$csr_path"
        
        warn "CSR generated at: $csr_path"
        warn "Send this CSR to your Certificate Authority for signing"
        return 1
    fi
    
    # Create PEM file (private key + certificate)
    cat "$CERT_DIR/${cert_name}.key" "$CERT_DIR/${cert_name}.crt" > "$CERT_DIR/${cert_name}.pem"
    chmod 600 "$CERT_DIR/${cert_name}.pem"
    
    log "✅ Certificate setup complete for $env_name environment"
    show_certificate_info "$CERT_DIR/${cert_name}.crt"
}

# Generate self-signed certificate for development
generate_self_signed_certificate() {
    local domain="$1"
    local cert_name="$2"
    
    log "Generating self-signed certificate for development"
    
    # Generate private key
    openssl genrsa -out "$CERT_DIR/${cert_name}.key" 2048
    
    # Generate self-signed certificate
    openssl req -new -x509 -key "$CERT_DIR/${cert_name}.key" -out "$CERT_DIR/${cert_name}.crt" -days 365 \
        -subj "/C=US/ST=Virginia/L=Charlottesville/O=University of Virginia/OU=Digital Humanities Portal/CN=${domain}"
    
    # Create PEM file
    cat "$CERT_DIR/${cert_name}.key" "$CERT_DIR/${cert_name}.crt" > "$CERT_DIR/${cert_name}.pem"
    
    # Set permissions
    chmod 600 "$CERT_DIR/${cert_name}.key" "$CERT_DIR/${cert_name}.pem"
    chmod 644 "$CERT_DIR/${cert_name}.crt"
    
    log "✅ Self-signed certificate generated"
}

# Display certificate information
show_certificate_info() {
    local cert_file="$1"
    
    if [ -f "$cert_file" ]; then
        log "Certificate information for: $cert_file"
        openssl x509 -in "$cert_file" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After)"
        echo
    fi
}

# Main function
main() {
    local mode="$1"
    local env_name="$2"
    local domain="$3"
    local cert_name="${4:-server}"
    
    log "🔐 Enhanced SAML Certificate Management Starting..."
    
    detect_environment
    setup_directories
    
    case "$mode" in
        "staging"|"production")
            # Set default domain based on environment
            if [ -z "$domain" ]; then
                case "$mode" in
                    "staging")
                        domain="dh-staging.library.virginia.edu"
                        ;;
                    "production")
                        domain="dh.library.virginia.edu"
                        ;;
                esac
            fi
            
            setup_environment_certificate "$mode" "$domain" "$cert_name"
            ;;
            
        "dev"|"development")
            domain="${domain:-drupal-dhportal.ddev.site}"
            generate_self_signed_certificate "$domain" "$cert_name"
            ;;
            
        "info")
            if [ -f "$CERT_DIR/${cert_name}.crt" ]; then
                show_certificate_info "$CERT_DIR/${cert_name}.crt"
            else
                error "Certificate not found: $CERT_DIR/${cert_name}.crt"
            fi
            ;;
            
        *)
            error "Invalid mode: $mode"
            echo "Usage: $0 {staging|production|dev|info} [domain] [cert_name]"
            echo "Examples:"
            echo "  $0 staging dh-staging.library.virginia.edu"
            echo "  $0 production dh.library.virginia.edu"
            echo "  $0 dev drupal-dhportal.ddev.site"
            echo "  $0 info"
            exit 1
            ;;
    esac
    
    log "🎉 Certificate management completed!"
}

# Run if executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
