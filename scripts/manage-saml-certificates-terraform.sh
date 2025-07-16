#!/bin/bash

# Enhanced SAML Certificate Management with Terraform Infrastructure Integration
# 
# This script integrates with your existing terraform-infrastructure encryption/decryption
# and AWS secrets management to securely manage SAML private keys while storing public 
# certificates in git.
#
# USAGE:
#   ./manage-saml-certificates-terraform.sh [command] [environment] [domain]
#
# COMMANDS:
#   generate-keys     Generate new encrypted private keys and self-signed certificates
#   bootstrap-secrets Bootstrap AWS secrets for key encryption passphrases  
#   deploy           Deploy certificates using terraform-decrypted keys
#   encrypt-existing Encrypt existing private keys for terraform storage
#   info            Show certificate information
#
# ENVIRONMENTS: dev, staging, production

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
TERRAFORM_REPO_PATH="${TERRAFORM_REPO_PATH:-../terraform-infrastructure}"
SAML_CERT_DIR="$PROJECT_ROOT/saml-config/certificates"
SAML_KEY_DIR="$PROJECT_ROOT/saml-config/keys"

# Environment-specific configuration
get_key_paths() {
    local env="$1"
    case "$env" in
        "staging")
            TERRAFORM_KEY_PATH="dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem"
            CERT_PATH="$SAML_CERT_DIR/staging/saml-sp.crt"
            DEFAULT_DOMAIN="dh-staging.library.virginia.edu"
            SECRET_NAME="dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem"
            ;;
        "production")
            TERRAFORM_KEY_PATH="dh.library.virginia.edu/production/keys/dh-drupal-production-saml.pem"
            CERT_PATH="$SAML_CERT_DIR/production/saml-sp.crt"
            DEFAULT_DOMAIN="dh.library.virginia.edu"
            SECRET_NAME="dh.library.virginia.edu/production/keys/dh-drupal-production-saml.pem"
            ;;
        "dev")
            # Development uses local keys, not terraform
            TERRAFORM_KEY_PATH=""
            CERT_PATH="$SAML_CERT_DIR/dev/saml-sp.crt"
            DEFAULT_DOMAIN="drupal-dhportal.ddev.site"
            SECRET_NAME=""
            ;;
        *)
            error "Unknown environment: $env"
            exit 1
            ;;
    esac
}

# Bootstrap AWS secrets for SAML key encryption passphrases
bootstrap_secrets() {
    local env="$1"
    
    if [ "$env" = "dev" ]; then
        error "Development environment doesn't use AWS secrets"
        return 1
    fi
    
    get_key_paths "$env"
    
    info "Bootstrapping AWS secrets for $env environment"
    
    # IDEMPOTENCY CHECK: Verify secret doesn't already exist
    info "Checking if AWS secret already exists: $SECRET_NAME"
    if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" >/dev/null 2>&1; then
        warn "⚠️  AWS secret already exists: $SECRET_NAME"
        info "Verifying secret accessibility..."
        
        if SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" --query 'SecretString' --output text 2>/dev/null); then
            SECRET_LENGTH=${#SECRET_VALUE}
            log "✅ Existing secret is accessible (length: $SECRET_LENGTH characters)"
            
            if [ "$SECRET_LENGTH" -eq 32 ]; then
                log "✅ Existing secret format appears correct (32-character passphrase)"
            else
                warn "⚠️  Existing secret format may be incorrect (expected 32 characters)"
            fi
            
            echo
            warn "IDEMPOTENCY: AWS secret bootstrap complete (using existing secret)"
            echo "Secret name: $SECRET_NAME"
            echo "Status: Already exists and accessible"
            echo
            echo "Next steps:"
            echo "1. Generate SAML keys: $0 generate-keys $env"
            echo "2. The key generation will use the existing secret for encryption"
            return 0
        else
            error "❌ Existing secret is not accessible"
            error "This may indicate a permissions issue or corrupted secret"
            return 1
        fi
    fi
    
    # Check if terraform infrastructure is available
    if [ ! -d "$TERRAFORM_REPO_PATH" ]; then
        error "Terraform infrastructure not found at: $TERRAFORM_REPO_PATH"
        error "Please clone the terraform-infrastructure repository or set TERRAFORM_REPO_PATH"
        return 1
    fi
    
    # Check if add-secret script exists
    local add_secret_script="$TERRAFORM_REPO_PATH/scripts/add-secret.ksh"
    if [ ! -f "$add_secret_script" ]; then
        error "AWS secrets script not found: $add_secret_script"
        return 1
    fi
    
    info "Creating NEW AWS secret for SAML key encryption passphrase..."
    log "Secret name: $SECRET_NAME"
    
    # Create the secret using terraform infrastructure script
    cd "$TERRAFORM_REPO_PATH"
    if ./scripts/add-secret.ksh "$SECRET_NAME" "SAML private key encryption passphrase for $env environment"; then
        log "✅ AWS secret created successfully: $SECRET_NAME"
        
        echo
        warn "IMPORTANT: Remember this secret for key encryption!"
        echo "The secret '$SECRET_NAME' has been created in AWS Secrets Manager."
        echo "This passphrase will be used to encrypt the SAML private key."
        echo
        echo "Next steps:"
        echo "1. Note the secret name: $SECRET_NAME"
        echo "2. Generate SAML keys: $0 generate-keys $env"
        echo "3. The key generation will use this secret for encryption"
        
    else
        error "Failed to create AWS secret: $SECRET_NAME"
        return 1
    fi
}

# Generate new private key and encrypted version for terraform storage
generate_keys_for_terraform() {
    local env="$1"
    local domain="${2:-}"
    local force_regenerate="${3:-false}"
    
    get_key_paths "$env"
    
    if [ "$env" = "dev" ]; then
        error "Development environment doesn't use terraform encryption"
        return 1
    fi
    
    domain="${domain:-$DEFAULT_DOMAIN}"
    
    info "Generating SAML private key and certificate for $env environment"
    
    # IDEMPOTENCY CHECKS: Verify what already exists
    local encrypted_key_file="$TERRAFORM_REPO_PATH/${TERRAFORM_KEY_PATH}.cpt"
    local certificate_file="$CERT_PATH"
    
    info "Performing idempotency checks..."
    
    # Check if encrypted key already exists
    if [ -f "$encrypted_key_file" ]; then
        warn "⚠️  Encrypted SAML key already exists: ${TERRAFORM_KEY_PATH}.cpt"
        
        # Verify the encrypted key is valid by trying to get its info
        local key_size=$(stat -f%z "$encrypted_key_file" 2>/dev/null || stat -c%s "$encrypted_key_file")
        info "Existing encrypted key size: $key_size bytes"
        
        if [ "$key_size" -gt 1000 ]; then
            log "✅ Existing encrypted key appears valid (reasonable size)"
        else
            warn "⚠️  Existing encrypted key appears small (may be corrupted)"
        fi
    fi
    
    # Check if certificate already exists
    if [ -f "$certificate_file" ]; then
        warn "⚠️  SAML certificate already exists: $certificate_file"
        
        # Verify the certificate is valid
        if openssl x509 -in "$certificate_file" -noout -subject >/dev/null 2>&1; then
            log "✅ Existing certificate is valid"
            info "Certificate details:"
            openssl x509 -in "$certificate_file" -noout -subject -dates | sed 's/^/   /'
        else
            warn "⚠️  Existing certificate appears corrupted"
        fi
    fi
    
    # Check if AWS secret exists
    info "Checking AWS secret accessibility: $SECRET_NAME"
    if ! aws secretsmanager get-secret-value --secret-id "$SECRET_NAME" >/dev/null 2>&1; then
        error "❌ AWS secret not accessible: $SECRET_NAME"
        error "Run first: $0 bootstrap-secrets $env"
        return 1
    fi
    log "✅ AWS secret is accessible"
    
    # IDEMPOTENCY DECISION: Both key and certificate exist
    if [ -f "$encrypted_key_file" ] && [ -f "$certificate_file" ] && [ "$force_regenerate" != "true" ]; then
        echo
        warn "IDEMPOTENCY: SAML key and certificate already exist for $env"
        echo "Encrypted key: ${TERRAFORM_KEY_PATH}.cpt"
        echo "Certificate:   $certificate_file"
        echo
        info "To regenerate (DESTRUCTIVE), run with --force:"
        echo "$0 generate-keys $env $domain --force"
        echo
        warn "⚠️  WARNING: Regeneration will invalidate existing NetBadge registrations"
        echo "Only regenerate if you coordinate with NetBadge admin to update SP metadata"
        echo
        log "✅ Key generation complete (using existing assets)"
        return 0
    fi
    
    # Check for partial state
    if [ -f "$encrypted_key_file" ] || [ -f "$certificate_file" ]; then
        if [ "$force_regenerate" != "true" ]; then
            warn "⚠️  PARTIAL STATE DETECTED:"
            [ -f "$encrypted_key_file" ] && echo "   ✓ Encrypted key exists: ${TERRAFORM_KEY_PATH}.cpt"
            [ ! -f "$encrypted_key_file" ] && echo "   ✗ Encrypted key missing"
            [ -f "$certificate_file" ] && echo "   ✓ Certificate exists: $certificate_file"
            [ ! -f "$certificate_file" ] && echo "   ✗ Certificate missing"
            echo
            warn "Partial state detected. Use --force to complete/regenerate:"
            echo "$0 generate-keys $env $domain --force"
            return 1
        else
            warn "⚠️  FORCE MODE: Regenerating existing keys/certificates"
        fi
    fi
    
    # Proceed with generation
    info "Proceeding with SAML key and certificate generation..."
    
    # Create temporary directory for key generation
    local temp_dir=$(mktemp -d)
    local temp_key="$temp_dir/saml-sp.key"
    local temp_cert="$temp_dir/saml-sp.crt"
    
    # Generate private key
    info "Generating 2048-bit RSA private key..."
    openssl genrsa -out "$temp_key" 2048
    
    # Generate self-signed certificate (SAML2 doesn't require CA-signed certificates)
    info "Generating self-signed certificate (10-year validity)..."
    openssl req -new -x509 -key "$temp_key" -out "$temp_cert" -days 3650 \
        -subj "/CN=$domain/O=University of Virginia Library/OU=Digital Humanities/L=Charlottesville/ST=Virginia/C=US"
    
    # Check if terraform infrastructure is available
    if [ ! -d "$TERRAFORM_REPO_PATH" ]; then
        error "Terraform infrastructure not found at: $TERRAFORM_REPO_PATH"
        error "Please clone the terraform-infrastructure repository or set TERRAFORM_REPO_PATH"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Check if encrypt script exists
    local encrypt_script="$TERRAFORM_REPO_PATH/scripts/crypt-key.ksh"
    if [ ! -f "$encrypt_script" ]; then
        error "Encryption script not found: $encrypt_script"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Create target directory in terraform repo
    local terraform_key_dir=$(dirname "$TERRAFORM_REPO_PATH/$TERRAFORM_KEY_PATH")
    mkdir -p "$terraform_key_dir"
    
    # Copy key to terraform location
    cp "$temp_key" "$TERRAFORM_REPO_PATH/$TERRAFORM_KEY_PATH"
    
    # Encrypt the key using terraform infrastructure script
    log "Encrypting private key using terraform infrastructure..."
    cd "$TERRAFORM_REPO_PATH"
    if ./scripts/crypt-key.ksh "$TERRAFORM_KEY_PATH" "$SECRET_NAME"; then
        log "✅ Private key encrypted successfully"
    else
        error "❌ Private key encryption failed"
        rm -rf "$temp_dir"
        rm -f "$TERRAFORM_REPO_PATH/$TERRAFORM_KEY_PATH"
        return 1
    fi
    
    # Remove unencrypted key
    rm -f "$TERRAFORM_REPO_PATH/$TERRAFORM_KEY_PATH"
    
    # Copy self-signed certificate to git repository
    mkdir -p "$(dirname "$CERT_PATH")"
    cp "$temp_cert" "$CERT_PATH"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Verify final state
    if [ -f "$encrypted_key_file" ] && [ -f "$certificate_file" ]; then
        log "✅ Key generation complete:"
        log "   Encrypted key: $TERRAFORM_REPO_PATH/${TERRAFORM_KEY_PATH}.cpt"
        log "   Certificate:   $CERT_PATH"
        
        # Verify certificate details
        info "Generated certificate details:"
        openssl x509 -in "$certificate_file" -noout -subject -dates | sed 's/^/   /'
        
        echo
        warn "NEXT STEPS:"
        echo "1. Commit encrypted key to terraform-infrastructure repository"
        echo "2. Commit self-signed certificate to git: $CERT_PATH"
        echo "3. Register SP metadata (including certificate) with NetBadge admin"
        echo "4. Deploy using: $0 deploy $env"
        echo
        warn "⚠️  IMPORTANT: If regenerating, coordinate with NetBadge admin"
        echo "The new certificate must be registered before SAML authentication will work"
    else
        error "❌ Key generation verification failed"
        return 1
    fi
}

# Deploy certificates using terraform-decrypted keys (during deployment)
deploy_certificates() {
    local env="$1"
    local domain="${2:-}"
    
    get_key_paths "$env"
    domain="${domain:-$DEFAULT_DOMAIN}"
    
    if [ "$env" = "dev" ]; then
        generate_dev_certificates "$domain"
        return
    fi
    
    info "Deploying SAML certificates for $env environment"
    
    # IDEMPOTENCY CHECK: Verify deployment prerequisites
    local decrypted_key="$TERRAFORM_REPO_PATH/$TERRAFORM_KEY_PATH"
    local simplesaml_cert_dir="$PROJECT_ROOT/simplesamlphp/cert"
    local deployed_cert="$simplesaml_cert_dir/server.crt"
    local deployed_key="$simplesaml_cert_dir/server.key"
    
    # Check if already deployed and valid
    if [ -f "$deployed_cert" ] && [ -f "$deployed_key" ]; then
        info "SAML certificates already deployed, validating..."
        
        # Verify deployed certificates are valid and matching
        if openssl x509 -in "$deployed_cert" -noout >/dev/null 2>&1 && \
           openssl rsa -in "$deployed_key" -check -noout >/dev/null 2>&1; then
            
            # Check if they match
            local deployed_cert_pubkey=$(openssl x509 -in "$deployed_cert" -pubkey -noout 2>/dev/null)
            local deployed_key_pubkey=$(openssl rsa -in "$deployed_key" -pubout 2>/dev/null)
            
            if [ "$deployed_cert_pubkey" = "$deployed_key_pubkey" ]; then
                log "✅ SAML certificates already deployed and valid"
                info "Certificate details:"
                openssl x509 -in "$deployed_cert" -noout -subject -dates | sed 's/^/   /'
                
                log "✅ SAML certificate deployment complete (idempotent)"
                return 0
            else
                warn "⚠️  Deployed certificate and key do not match - redeploying"
            fi
        else
            warn "⚠️  Deployed certificates are invalid - redeploying"
        fi
    fi
    
    # Verify deployment prerequisites exist
    if [ ! -f "$decrypted_key" ]; then
        error "Decrypted private key not found: $decrypted_key"
        error "Ensure terraform infrastructure has decrypted the key during deployment"
        return 1
    fi
    
    if [ ! -f "$CERT_PATH" ]; then
        error "Public certificate not found: $CERT_PATH"
        error "Ensure signed certificate is stored in git repository"
        return 1
    fi
    
    # Validate source certificate and key before deployment
    info "Validating source certificate and key before deployment..."
    if ! openssl x509 -in "$CERT_PATH" -noout >/dev/null 2>&1; then
        error "Source certificate is invalid: $CERT_PATH"
        return 1
    fi
    
    if ! openssl rsa -in "$decrypted_key" -check -noout >/dev/null 2>&1; then
        error "Source private key is invalid: $decrypted_key"
        return 1
    fi
    
    # Verify source certificate and key match
    local source_cert_pubkey=$(openssl x509 -in "$CERT_PATH" -pubkey -noout 2>/dev/null)
    local source_key_pubkey=$(openssl rsa -in "$decrypted_key" -pubout 2>/dev/null)
    
    if [ "$source_cert_pubkey" != "$source_key_pubkey" ]; then
        error "Source certificate and private key do not match"
        error "This indicates a serious configuration error"
        return 1
    fi
    
    log "✅ Source certificate and private key validated"
    
    # Create SimpleSAMLphp certificate directory
    mkdir -p "$simplesaml_cert_dir"
    
    # Deploy certificate and key for SimpleSAMLphp
    info "Deploying certificates to SimpleSAMLphp directory..."
    cp "$CERT_PATH" "$simplesaml_cert_dir/server.crt"
    cp "$decrypted_key" "$simplesaml_cert_dir/server.key"
    
    # Set proper permissions
    chmod 644 "$simplesaml_cert_dir/server.crt"
    chmod 600 "$simplesaml_cert_dir/server.key"
    
    log "✅ SAML certificates deployed for $env"
    log "   Certificate: $simplesaml_cert_dir/server.crt"
    log "   Private key: $simplesaml_cert_dir/server.key"
    
    # Validate certificate
    validate_certificate "$simplesaml_cert_dir/server.crt" "$simplesaml_cert_dir/server.key"
}

# Encrypt existing private key for terraform storage
encrypt_existing_key() {
    local env="$1"
    local existing_key="$2"
    
    if [ ! -f "$existing_key" ]; then
        error "Private key file not found: $existing_key"
        return 1
    fi
    
    get_key_paths "$env"
    
    if [ "$env" = "dev" ]; then
        error "Development environment doesn't use terraform encryption"
        return 1
    fi
    
    # Check if terraform infrastructure is available
    if [ ! -d "$TERRAFORM_REPO_PATH" ]; then
        error "Terraform infrastructure not found at: $TERRAFORM_REPO_PATH"
        return 1
    fi
    
    local encrypt_script="$TERRAFORM_REPO_PATH/scripts/crypt-key.ksh"
    if [ ! -f "$encrypt_script" ]; then
        error "Encryption script not found: $encrypt_script"
        return 1
    fi
    
    # Create target directory in terraform repo
    local terraform_key_dir=$(dirname "$TERRAFORM_REPO_PATH/$TERRAFORM_KEY_PATH")
    mkdir -p "$terraform_key_dir"
    
    # Copy key to terraform location
    cp "$existing_key" "$TERRAFORM_REPO_PATH/$TERRAFORM_KEY_PATH"
    
    # Encrypt the key
    log "Encrypting existing private key..."
    cd "$TERRAFORM_REPO_PATH"
    ./scripts/crypt-key.ksh "$TERRAFORM_KEY_PATH" "$SECRET_NAME"
    
    # Remove unencrypted key
    rm -f "$TERRAFORM_REPO_PATH/$TERRAFORM_KEY_PATH"
    
    log "✅ Existing key encrypted and stored:"
    log "   Encrypted key: $TERRAFORM_REPO_PATH/${TERRAFORM_KEY_PATH}.cpt"
    
    warn "Remember to commit encrypted key to terraform-infrastructure repository"
}

# Generate development certificates (local only)
generate_dev_certificates() {
    local domain="${1:-drupal-dhportal.ddev.site}"
    
    info "Generating development SAML certificates for $domain"
    
    local cert_dir="$PROJECT_ROOT/saml-config/dev"
    local simplesaml_cert_dir="$PROJECT_ROOT/simplesamlphp/cert"
    
    mkdir -p "$cert_dir" "$simplesaml_cert_dir"
    
    # Generate self-signed certificate for development
    openssl req -x509 -newkey rsa:2048 -keyout "$cert_dir/saml-sp.key" -out "$cert_dir/saml-sp.crt" \
        -days 365 -nodes \
        -subj "/CN=$domain/O=UVA Library Dev/OU=Digital Humanities/L=Charlottesville/ST=Virginia/C=US"
    
    # Copy to SimpleSAMLphp directory
    cp "$cert_dir/saml-sp.crt" "$simplesaml_cert_dir/server.crt"
    cp "$cert_dir/saml-sp.key" "$simplesaml_cert_dir/server.key"
    
    # Set permissions
    chmod 644 "$simplesaml_cert_dir/server.crt"
    chmod 600 "$simplesaml_cert_dir/server.key"
    
    log "✅ Development certificates generated"
    warn "Development certificates are temporary and excluded from git"
}

# Validate certificate and key
validate_certificate() {
    local cert_file="$1"
    local key_file="$2"
    
    if [ ! -f "$cert_file" ] || [ ! -f "$key_file" ]; then
        warn "Certificate or key file missing - cannot validate"
        return 1
    fi
    
    # Check if certificate and key match
    local cert_modulus=$(openssl x509 -noout -modulus -in "$cert_file" 2>/dev/null | openssl md5)
    local key_modulus=$(openssl rsa -noout -modulus -in "$key_file" 2>/dev/null | openssl md5)
    
    if [ "$cert_modulus" = "$key_modulus" ]; then
        log "✅ Certificate and private key match"
        
        # Show certificate details
        info "Certificate details:"
        openssl x509 -in "$cert_file" -noout -subject -dates -issuer
    else
        error "❌ Certificate and private key do NOT match!"
        return 1
    fi
}

# Show certificate information
show_certificate_info() {
    local env="${1:-all}"
    
    echo "🔍 SAML Certificate Information"
    echo "================================"
    
    if [ "$env" = "all" ] || [ "$env" = "dev" ]; then
        echo
        echo "📋 Development Environment:"
        local dev_cert="$PROJECT_ROOT/simplesamlphp/cert/server.crt"
        if [ -f "$dev_cert" ]; then
            openssl x509 -in "$dev_cert" -noout -subject -dates -issuer
        else
            echo "  No development certificate found"
        fi
    fi
    
    if [ "$env" = "all" ] || [ "$env" = "staging" ]; then
        echo
        echo "📋 Staging Environment:"
        local staging_cert="$SAML_CERT_DIR/staging/saml-sp.crt"
        if [ -f "$staging_cert" ]; then
            openssl x509 -in "$staging_cert" -noout -subject -dates -issuer
        else
            echo "  No staging certificate found in git repository"
        fi
    fi
    
    if [ "$env" = "all" ] || [ "$env" = "production" ]; then
        echo
        echo "📋 Production Environment:"
        local prod_cert="$SAML_CERT_DIR/production/saml-sp.crt"
        if [ -f "$prod_cert" ]; then
            openssl x509 -in "$prod_cert" -noout -subject -dates -issuer
        else
            echo "  No production certificate found in git repository"
        fi
    fi
}

# Main script logic
case "$1" in
    "bootstrap-secrets")
        if [ -z "$2" ]; then
            error "Environment required: staging or production"
            exit 1
        fi
        bootstrap_secrets "$2"
        ;;
    "generate-keys")
        if [ -z "$2" ]; then
            error "Environment required: staging or production"
            exit 1
        fi
        
        # Check for --force flag
        force_flag="false"
        if [ "$4" = "--force" ] || [ "$3" = "--force" ]; then
            force_flag="true"
            warn "⚠️  FORCE MODE ENABLED: Will regenerate existing keys/certificates"
        fi
        
        # Handle domain parameter (may be before or after --force)
        domain=""
        if [ -n "$3" ] && [ "$3" != "--force" ]; then
            domain="$3"
        fi
        
        generate_keys_for_terraform "$2" "$domain" "$force_flag"
        ;;
    "deploy")
        if [ -z "$2" ]; then
            error "Environment required: dev, staging, or production"
            exit 1
        fi
        deploy_certificates "$2" "$3"
        ;;
    "encrypt-existing")
        if [ -z "$2" ] || [ -z "$3" ]; then
            error "Usage: $0 encrypt-existing [environment] [key-file]"
            exit 1
        fi
        encrypt_existing_key "$2" "$3"
        ;;
    "info")
        show_certificate_info "$2"
        ;;
    *)
        echo "SAML Certificate Management with Terraform Infrastructure Integration"
        echo "================================================================="
        echo
        echo "Usage: $0 [command] [environment] [domain]"
        echo
        echo "Commands:"
        echo "  bootstrap-secrets [env]         Bootstrap AWS secrets for key encryption passphrases"
        echo "  generate-keys [env] [domain] [--force]  Generate encrypted private keys (idempotent)"
        echo "  deploy [env] [domain]           Deploy certificates using terraform-decrypted keys"
        echo "  encrypt-existing [env] [key]    Encrypt existing private key for terraform storage"
        echo "  info [env]                      Show certificate information"
        echo
        echo "Environments: dev, staging, production"
        echo
        echo "Examples:"
        echo "  $0 bootstrap-secrets staging"
        echo "  $0 generate-keys staging dh-staging.library.virginia.edu"
        echo "  $0 deploy production"
        echo "  $0 encrypt-existing staging ./existing-key.pem"
        echo "  $0 info staging"
        echo
        echo "Environment Variables:"
        echo "  TERRAFORM_REPO_PATH     Path to terraform-infrastructure repo (default: ../terraform-infrastructure)"
        echo
        echo "AWS Secrets & Terraform Integration:"
        echo "  - AWS secrets store encryption passphrases using terraform-infrastructure/scripts/add-secret.ksh"
        echo "  - Private keys are encrypted using terraform-infrastructure/scripts/crypt-key.ksh"
        echo "  - Encrypted keys are stored in terraform-infrastructure repository"
        echo "  - Deployment uses terraform-infrastructure/scripts/decrypt-key.ksh"
        echo "  - Public certificates are stored in git repository (safe)"
        echo
        echo "Typical Workflow:"
        echo "  1. $0 bootstrap-secrets staging    # Create AWS secret for passphrase"
        echo "  2. $0 generate-keys staging        # Generate encrypted private key & self-signed cert"  
        echo "  3. Commit certificate to git and register with NetBadge"
        echo "  4. $0 deploy staging               # Deploy during CI/CD"
        echo
        echo "Idempotency and Safety:"
        echo "  - All commands are idempotent and safe to run multiple times"
        echo "  - bootstrap-secrets: Will not overwrite existing AWS secrets"
        echo "  - generate-keys: Will not overwrite existing keys/certificates without --force"
        echo "  - Use --force flag with generate-keys to regenerate existing keys (DESTRUCTIVE)"
        echo "  - Always coordinate with NetBadge admin before regenerating certificates"
        echo
        exit 1
        ;;
esac
