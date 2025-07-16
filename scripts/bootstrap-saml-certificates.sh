#!/bin/bash

# SAML Certificate Lifecycle Bootstrap Script
# 
# This script bootstraps the complete SAML certificate lifecycle by:
# 1. Generating encrypted private keys for terraform storage
# 2. Creating AWS secrets for encryption passphrases (integrates with add-secret.ksh)
# 3. Generating CSRs for UVA CA submission
# 4. Setting up the complete infrastructure for SAML certificate management
#
# USAGE:
#   ./bootstrap-saml-certificates.sh [environment]
#
# ENVIRONMENTS: staging, production, both

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

# Configuration - adjust these paths as needed
TERRAFORM_REPO_PATH="${TERRAFORM_REPO_PATH:-../terraform-infrastructure}"
DRUPAL_DHPORTAL_PATH="${DRUPAL_DHPORTAL_PATH:-$PROJECT_ROOT}"

# Environment configuration
get_environment_config() {
    local env="$1"
    case "$env" in
        "staging")
            DOMAIN="dh-staging.library.virginia.edu"
            KEY_PATH="dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem"
            SECRET_NAME="dh-drupal-staging-saml-passphrase"
            SECRET_DESCRIPTION="Passphrase for SAML private key encryption (staging environment)"
            ;;
        "production")
            DOMAIN="dh.library.virginia.edu"
            KEY_PATH="dh.library.virginia.edu/production/keys/dh-drupal-production-saml.pem"
            SECRET_NAME="dh-drupal-production-saml-passphrase"
            SECRET_DESCRIPTION="Passphrase for SAML private key encryption (production environment)"
            ;;
        *)
            error "Unknown environment: $env"
            exit 1
            ;;
    esac
}

# Check prerequisites
check_prerequisites() {
    info "Checking prerequisites..."
    
    # Check if terraform infrastructure is available
    if [ ! -d "$TERRAFORM_REPO_PATH" ]; then
        error "Terraform infrastructure not found at: $TERRAFORM_REPO_PATH"
        error "Please clone terraform-infrastructure or set TERRAFORM_REPO_PATH environment variable"
        exit 1
    fi
    
    # Check if required terraform scripts exist
    for script in "add-secret.ksh" "crypt-key.ksh" "get-secret.ksh"; do
        if [ ! -f "$TERRAFORM_REPO_PATH/scripts/$script" ]; then
            error "Required script not found: $TERRAFORM_REPO_PATH/scripts/$script"
            exit 1
        fi
    done
    
    # Check if drupal-dhportal project is available
    if [ ! -d "$DRUPAL_DHPORTAL_PATH" ]; then
        error "drupal-dhportal project not found at: $DRUPAL_DHPORTAL_PATH"
        error "Please set DRUPAL_DHPORTAL_PATH environment variable"
        exit 1
    fi
    
    # Check if required tools are available
    for tool in openssl aws jq; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            error "Required tool not found: $tool"
            exit 1
        fi
    done
    
    log "Prerequisites check passed"
}

# Bootstrap SAML certificates for a specific environment
bootstrap_environment() {
    local env="$1"
    
    get_environment_config "$env"
    
    info "Bootstrapping SAML certificates for $env environment"
    info "Domain: $DOMAIN"
    info "Key path: $KEY_PATH"
    
    # Create temporary directory for key generation
    local temp_dir=$(mktemp -d)
    local temp_key="$temp_dir/saml-sp.key"
    local temp_csr="$temp_dir/saml-sp.csr"
    
    # Step 1: Generate private key
    log "Generating RSA private key..."
    openssl genrsa -out "$temp_key" 2048
    
    # Step 2: Generate CSR
    log "Generating Certificate Signing Request..."
    openssl req -new -key "$temp_key" -out "$temp_csr" \
        -subj "/CN=$DOMAIN/O=University of Virginia Library/OU=Digital Humanities/L=Charlottesville/ST=Virginia/C=US"
    
    # Step 3: Create AWS secret for encryption passphrase
    log "Creating AWS secret for encryption passphrase..."
    cd "$TERRAFORM_REPO_PATH"
    if ./scripts/add-secret.ksh "$SECRET_NAME" "$SECRET_DESCRIPTION"; then
        log "AWS secret created: $SECRET_NAME"
    else
        warn "AWS secret may already exist or creation failed - continuing..."
    fi
    
    # Step 4: Create target directory in terraform repo
    local terraform_key_dir=$(dirname "$TERRAFORM_REPO_PATH/$KEY_PATH")
    mkdir -p "$terraform_key_dir"
    
    # Step 5: Copy key to terraform location
    cp "$temp_key" "$TERRAFORM_REPO_PATH/$KEY_PATH"
    
    # Step 6: Encrypt the key using terraform infrastructure
    log "Encrypting private key using terraform infrastructure..."
    cd "$TERRAFORM_REPO_PATH"
    if ./scripts/crypt-key.ksh "$KEY_PATH"; then
        log "Private key encrypted successfully"
    else
        error "Failed to encrypt private key"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Step 7: Remove unencrypted key
    rm -f "$TERRAFORM_REPO_PATH/$KEY_PATH"
    
    # Step 8: Store CSR in drupal-dhportal project
    local csr_dir="$DRUPAL_DHPORTAL_PATH/saml-config/csr"
    mkdir -p "$csr_dir"
    cp "$temp_csr" "$csr_dir/${env}-saml-sp.csr"
    
    # Step 9: Create certificate directory structure in drupal-dhportal
    local cert_dir="$DRUPAL_DHPORTAL_PATH/saml-config/certificates/$env"
    mkdir -p "$cert_dir"
    
    # Create placeholder certificate file with instructions
    cat > "$cert_dir/README.md" << EOF
# $env SAML Certificate

## Certificate Status
⏳ **Pending CA Signing**

## Next Steps
1. Submit CSR to UVA Certificate Authority: \`../../../saml-config/csr/${env}-saml-sp.csr\`
2. Once signed, store certificate as: \`saml-sp.crt\`
3. Store CA chain (if provided) as: \`saml-sp-chain.crt\`

## Deployment
- Private key: Encrypted in terraform-infrastructure repository
- Certificate: Will be stored in this directory (safe for git)
- Deployment: Automatic via CI/CD pipeline

## Generated
- Date: $(date)
- Domain: $DOMAIN
- Environment: $env
EOF
    
    # Cleanup temporary files
    rm -rf "$temp_dir"
    
    log "✅ Bootstrap complete for $env environment:"
    log "   Encrypted key: $TERRAFORM_REPO_PATH/${KEY_PATH}.cpt"
    log "   AWS Secret:    $SECRET_NAME"
    log "   CSR:           $DRUPAL_DHPORTAL_PATH/saml-config/csr/${env}-saml-sp.csr"
    log "   Certificate:   $DRUPAL_DHPORTAL_PATH/saml-config/certificates/$env/"
}

# Validate bootstrap results
validate_bootstrap() {
    local env="$1"
    
    get_environment_config "$env"
    
    info "Validating bootstrap for $env..."
    
    # Check encrypted key exists
    if [ -f "$TERRAFORM_REPO_PATH/${KEY_PATH}.cpt" ]; then
        log "✅ Encrypted private key exists"
    else
        error "❌ Encrypted private key missing: $TERRAFORM_REPO_PATH/${KEY_PATH}.cpt"
        return 1
    fi
    
    # Check AWS secret exists
    cd "$TERRAFORM_REPO_PATH"
    if ./scripts/get-secret.ksh "$SECRET_NAME" >/dev/null 2>&1; then
        log "✅ AWS secret accessible: $SECRET_NAME"
    else
        error "❌ AWS secret not accessible: $SECRET_NAME"
        return 1
    fi
    
    # Check CSR exists
    if [ -f "$DRUPAL_DHPORTAL_PATH/saml-config/csr/${env}-saml-sp.csr" ]; then
        log "✅ CSR file exists"
    else
        error "❌ CSR file missing"
        return 1
    fi
    
    # Check certificate directory
    if [ -d "$DRUPAL_DHPORTAL_PATH/saml-config/certificates/$env" ]; then
        log "✅ Certificate directory exists"
    else
        error "❌ Certificate directory missing"
        return 1
    fi
    
    log "✅ Bootstrap validation passed for $env"
}

# Show status of SAML certificate infrastructure
show_status() {
    echo "🔍 SAML Certificate Infrastructure Status"
    echo "========================================"
    echo
    
    for env in staging production; do
        get_environment_config "$env"
        
        echo "📋 $env Environment:"
        echo "  Domain: $DOMAIN"
        
        # Check encrypted key
        if [ -f "$TERRAFORM_REPO_PATH/${KEY_PATH}.cpt" ]; then
            echo "  Private Key: ✅ Encrypted and stored"
        else
            echo "  Private Key: ❌ Not found"
        fi
        
        # Check AWS secret
        cd "$TERRAFORM_REPO_PATH"
        if ./scripts/get-secret.ksh "$SECRET_NAME" >/dev/null 2>&1; then
            echo "  AWS Secret:  ✅ Available"
        else
            echo "  AWS Secret:  ❌ Not found"
        fi
        
        # Check CSR
        if [ -f "$DRUPAL_DHPORTAL_PATH/saml-config/csr/${env}-saml-sp.csr" ]; then
            echo "  CSR:         ✅ Ready for CA submission"
        else
            echo "  CSR:         ❌ Not generated"
        fi
        
        # Check certificate
        if [ -f "$DRUPAL_DHPORTAL_PATH/saml-config/certificates/$env/saml-sp.crt" ]; then
            echo "  Certificate: ✅ Signed and stored"
            # Show certificate details
            cert_info=$(openssl x509 -in "$DRUPAL_DHPORTAL_PATH/saml-config/certificates/$env/saml-sp.crt" -noout -subject -dates 2>/dev/null)
            echo "               $cert_info"
        else
            echo "  Certificate: ⏳ Pending CA signing"
        fi
        
        echo
    done
}

# Generate deployment instructions
generate_instructions() {
    cat << EOF

🚀 SAML Certificate Bootstrap Complete!
=====================================

## What Was Created:

### Terraform Infrastructure:
$(for env in staging production; do
    get_environment_config "$env"
    echo "- $TERRAFORM_REPO_PATH/${KEY_PATH}.cpt (encrypted private key)"
done)

### AWS Secrets Manager:
$(for env in staging production; do
    get_environment_config "$env"
    echo "- $SECRET_NAME (encryption passphrase)"
done)

### Drupal DHPortal Project:
$(for env in staging production; do
    echo "- saml-config/csr/${env}-saml-sp.csr (for UVA CA submission)"
    echo "- saml-config/certificates/${env}/ (certificate storage)"
done)

## Next Steps:

### 1. Commit Infrastructure Changes:
\`\`\`bash
cd $TERRAFORM_REPO_PATH
git add dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem.cpt
git add dh.library.virginia.edu/production/keys/dh-drupal-production-saml.pem.cpt
git commit -m "Add encrypted SAML private keys for drupal-dhportal"
\`\`\`

### 2. Submit CSRs to UVA Certificate Authority:
$(for env in staging production; do
    echo "- Submit: $DRUPAL_DHPORTAL_PATH/saml-config/csr/${env}-saml-sp.csr"
done)

### 3. Store Signed Certificates:
\`\`\`bash
# Once you receive signed certificates from UVA CA:
cp staging-signed.crt $DRUPAL_DHPORTAL_PATH/saml-config/certificates/staging/saml-sp.crt
cp production-signed.crt $DRUPAL_DHPORTAL_PATH/saml-config/certificates/production/saml-sp.crt

cd $DRUPAL_DHPORTAL_PATH
git add saml-config/certificates/
git commit -m "Add UVA CA signed SAML certificates"
\`\`\`

### 4. Test Deployment:
\`\`\`bash
# Your deployment pipeline will automatically:
# - Decrypt SAML private keys using existing terraform infrastructure
# - Deploy certificates using stored public certificates
# - Configure SimpleSAMLphp for authentication
\`\`\`

### 5. Verify with Status Check:
\`\`\`bash
./scripts/bootstrap-saml-certificates.sh status
\`\`\`

## Security Notes:
✅ Private keys encrypted and stored in terraform-infrastructure  
✅ AWS secrets created for encryption passphrases  
✅ Public certificates safe for git storage  
✅ Integrates with existing deployment pipeline  

EOF
}

# Main script logic
case "$1" in
    "staging"|"production")
        check_prerequisites
        bootstrap_environment "$1"
        validate_bootstrap "$1"
        echo
        generate_instructions
        ;;
    "both")
        check_prerequisites
        bootstrap_environment "staging"
        validate_bootstrap "staging"
        echo
        bootstrap_environment "production" 
        validate_bootstrap "production"
        echo
        generate_instructions
        ;;
    "status")
        check_prerequisites
        show_status
        ;;
    "validate")
        check_prerequisites
        if [ -n "$2" ]; then
            validate_bootstrap "$2"
        else
            validate_bootstrap "staging"
            validate_bootstrap "production"
        fi
        ;;
    *)
        echo "SAML Certificate Lifecycle Bootstrap"
        echo "==================================="
        echo
        echo "This script bootstraps the complete SAML certificate infrastructure by:"
        echo "1. Generating encrypted private keys for terraform storage"
        echo "2. Creating AWS secrets for encryption passphrases"
        echo "3. Generating CSRs for UVA CA submission"
        echo "4. Setting up certificate storage structure"
        echo
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "  staging     Bootstrap staging environment only"
        echo "  production  Bootstrap production environment only"
        echo "  both        Bootstrap both staging and production"
        echo "  status      Show current infrastructure status"
        echo "  validate    Validate bootstrap completion"
        echo
        echo "Environment Variables:"
        echo "  TERRAFORM_REPO_PATH     Path to terraform-infrastructure repo"
        echo "  DRUPAL_DHPORTAL_PATH    Path to drupal-dhportal project"
        echo
        echo "Prerequisites:"
        echo "  - terraform-infrastructure repository cloned"
        echo "  - AWS CLI configured with appropriate permissions"
        echo "  - OpenSSL, jq, and other required tools installed"
        echo
        echo "Examples:"
        echo "  $0 both                    # Bootstrap both environments"
        echo "  $0 staging                 # Bootstrap staging only"
        echo "  $0 status                  # Check current status"
        exit 1
        ;;
esac
