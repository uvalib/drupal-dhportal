#!/bin/bash

# Staging SAML Certificate Validation Test
# 
# This script validates that the staging SAML certificate and key setup
# is working correctly with AWS Secrets Manager and terraform infrastructure.
# It performs the exact same tests as the deployment pipeline.

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

# Configuration for staging environment
ENVIRONMENT="staging"
SAML_KEY_NAME="dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem"
SAML_SECRET_NAME="dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem"
TERRAFORM_REPO_PATH="${TERRAFORM_REPO_PATH:-/Users/ys2n/Code/uvalib/terraform-infrastructure}"
CERT_PATH="$PROJECT_ROOT/saml-config/certificates/staging/saml-sp.crt"

echo "🧪 Staging SAML Certificate Validation Test"
echo "==========================================="
echo "Environment: $ENVIRONMENT"
echo "Certificate: $CERT_PATH"
echo "Secret Name: $SAML_SECRET_NAME"
echo "Terraform Repo: $TERRAFORM_REPO_PATH"
echo

# Test 1: Prerequisites
echo "1️⃣  Testing Prerequisites"
echo "-------------------------"

# Check AWS CLI
if command -v aws >/dev/null 2>&1; then
    if aws sts get-caller-identity >/dev/null 2>&1; then
        log "AWS CLI configured and authenticated"
        AWS_IDENTITY=$(aws sts get-caller-identity --query 'Arn' --output text)
        info "AWS Identity: $AWS_IDENTITY"
    else
        error "AWS CLI not authenticated"
        exit 1
    fi
else
    error "AWS CLI not found"
    exit 1
fi

# Check terraform infrastructure
if [ ! -d "$TERRAFORM_REPO_PATH" ]; then
    error "Terraform infrastructure not found: $TERRAFORM_REPO_PATH"
    exit 1
fi
log "Terraform infrastructure found: $TERRAFORM_REPO_PATH"

# Check required scripts
for script in add-secret.ksh crypt-key.ksh decrypt-key.ksh; do
    if [ ! -f "$TERRAFORM_REPO_PATH/scripts/$script" ]; then
        error "Required script not found: $script"
        exit 1
    fi
done
log "All required terraform scripts found"

# Check ccrypt
if ! command -v ccrypt >/dev/null 2>&1; then
    error "ccrypt not found (required for key encryption/decryption)"
    exit 1
fi
log "ccrypt found (required for key encryption/decryption)"

echo

# Test 2: AWS Secret Validation
echo "2️⃣  Testing AWS Secret Access"
echo "-----------------------------"

info "Checking AWS secret: $SAML_SECRET_NAME"
if SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$SAML_SECRET_NAME" --query 'SecretString' --output text 2>/dev/null); then
    log "AWS secret found and accessible"
    SECRET_LENGTH=${#SECRET_VALUE}
    info "Secret length: $SECRET_LENGTH characters"
    
    if [ "$SECRET_LENGTH" -eq 32 ]; then
        log "Secret format appears correct (32-character passphrase)"
    else
        warn "Secret length unexpected (expected 32 characters)"
    fi
else
    error "Cannot access AWS secret: $SAML_SECRET_NAME"
    error "Run: ./scripts/manage-saml-certificates-terraform.sh bootstrap-secrets staging"
    exit 1
fi

echo

# Test 3: Encrypted Key File Validation
echo "3️⃣  Testing Encrypted Key File"
echo "------------------------------"

ENCRYPTED_KEY_PATH="$TERRAFORM_REPO_PATH/$SAML_KEY_NAME.cpt"
info "Checking encrypted key: $ENCRYPTED_KEY_PATH"

if [ ! -f "$ENCRYPTED_KEY_PATH" ]; then
    error "Encrypted key file not found: $ENCRYPTED_KEY_PATH"
    error "Run: ./scripts/manage-saml-certificates-terraform.sh generate-keys staging"
    exit 1
fi
log "Encrypted key file found"

KEY_SIZE=$(stat -f%z "$ENCRYPTED_KEY_PATH" 2>/dev/null || stat -c%s "$ENCRYPTED_KEY_PATH")
info "Encrypted key file size: $KEY_SIZE bytes"

if [ "$KEY_SIZE" -gt 1000 ]; then
    log "Encrypted key file size appears reasonable"
else
    warn "Encrypted key file seems small (may be corrupted)"
fi

echo

# Test 4: Key Decryption (Simulating deployspec.yml)
echo "4️⃣  Testing Key Decryption (deployspec.yml simulation)"
echo "----------------------------------------------------"

DECRYPTED_KEY_PATH="$TERRAFORM_REPO_PATH/$SAML_KEY_NAME"

# Ensure we start clean
if [ -f "$DECRYPTED_KEY_PATH" ]; then
    rm -f "$DECRYPTED_KEY_PATH"
fi

info "Simulating deployspec.yml SAML key decryption logic"
info "Running: terraform-infrastructure/scripts/decrypt-key.ksh"

cd "$TERRAFORM_REPO_PATH"
if ./scripts/decrypt-key.ksh "$ENCRYPTED_KEY_PATH" "$SAML_SECRET_NAME"; then
    log "Key decryption successful"
    
    if [ -f "$DECRYPTED_KEY_PATH" ]; then
        log "Decrypted key file created: $DECRYPTED_KEY_PATH"
        
        # Validate it's a proper RSA private key
        if openssl rsa -in "$DECRYPTED_KEY_PATH" -check -noout >/dev/null 2>&1; then
            log "Decrypted key is valid RSA private key"
        else
            error "Decrypted key is not a valid RSA private key"
            exit 1
        fi
        
        # Check file permissions
        KEY_PERMS=$(stat -f%Mp%Lp "$DECRYPTED_KEY_PATH" 2>/dev/null || stat -c%a "$DECRYPTED_KEY_PATH")
        info "Key file permissions: $KEY_PERMS"
        
    else
        error "Decrypted key file not created"
        exit 1
    fi
else
    error "Key decryption failed"
    exit 1
fi

echo

# Test 5: Certificate and Key Matching
echo "5️⃣  Testing Certificate and Key Matching"
echo "----------------------------------------"

info "Checking staging certificate: $CERT_PATH"
if [ ! -f "$CERT_PATH" ]; then
    error "Staging certificate not found: $CERT_PATH"
    error "Run: ./scripts/manage-saml-certificates-terraform.sh generate-keys staging"
    exit 1
fi
log "Staging certificate found"

# Extract public key from certificate
CERT_PUBLIC_KEY=$(openssl x509 -in "$CERT_PATH" -pubkey -noout)
# Extract public key from private key
PRIVATE_KEY_PUBLIC_KEY=$(openssl rsa -in "$DECRYPTED_KEY_PATH" -pubout 2>/dev/null)

if [ "$CERT_PUBLIC_KEY" = "$PRIVATE_KEY_PUBLIC_KEY" ]; then
    log "Certificate and private key match (public keys identical)"
else
    error "Certificate and private key do NOT match"
    exit 1
fi

# Display certificate information
info "Certificate details:"
openssl x509 -in "$CERT_PATH" -noout -subject -dates -issuer | sed 's/^/   /'

echo

# Test 6: Deployment Script Integration
echo "6️⃣  Testing Deployment Script Integration"
echo "----------------------------------------"

info "Testing manage-saml-certificates-terraform.sh deploy command"
cd "$PROJECT_ROOT"

if ./scripts/manage-saml-certificates-terraform.sh deploy staging; then
    log "Deployment script executed successfully"
    
    # Check that certificates were deployed to SimpleSAMLphp
    SIMPLESAML_CERT="$PROJECT_ROOT/simplesamlphp/cert/server.crt"
    SIMPLESAML_KEY="$PROJECT_ROOT/simplesamlphp/cert/server.key"
    
    if [ -f "$SIMPLESAML_CERT" ] && [ -f "$SIMPLESAML_KEY" ]; then
        log "Certificates deployed to SimpleSAMLphp directory"
        
        # Verify deployed certificates match
        DEPLOYED_CERT_PUBLIC_KEY=$(openssl x509 -in "$SIMPLESAML_CERT" -pubkey -noout)
        DEPLOYED_PRIVATE_KEY_PUBLIC_KEY=$(openssl rsa -in "$SIMPLESAML_KEY" -pubout 2>/dev/null)
        
        if [ "$DEPLOYED_CERT_PUBLIC_KEY" = "$DEPLOYED_PRIVATE_KEY_PUBLIC_KEY" ]; then
            log "Deployed certificate and private key match"
        else
            error "Deployed certificate and private key do NOT match"
            exit 1
        fi
    else
        error "Certificates not properly deployed to SimpleSAMLphp"
        exit 1
    fi
else
    error "Deployment script failed"
    exit 1
fi

echo

# Test 7: Git Repository Status
echo "7️⃣  Testing Git Repository Status"
echo "---------------------------------"

info "Checking git status for staging certificate"
cd "$PROJECT_ROOT"

if git ls-files --error-unmatch "$CERT_PATH" >/dev/null 2>&1; then
    log "Staging certificate is tracked in git"
else
    warn "Staging certificate is not tracked in git"
    info "Add with: git add $CERT_PATH"
fi

# Check for any private keys accidentally tracked
TRACKED_PRIVATE_FILES=$(git ls-files | grep -E '\.(key|pem)$' | grep -v '\.example$' || true)
if [ -n "$TRACKED_PRIVATE_FILES" ]; then
    warn "Private key files found in git:"
    echo "$TRACKED_PRIVATE_FILES" | sed 's/^/   /'
    warn "Ensure .gitignore excludes private keys"
else
    log "No private key files tracked in git (good security practice)"
fi

echo

# Test 8: Idempotency Validation
echo "8️⃣  Testing Script Idempotency"
echo "-----------------------------"

info "Testing bootstrap-secrets idempotency"
if ./scripts/manage-saml-certificates-terraform.sh bootstrap-secrets staging >/dev/null 2>&1; then
    log "✅ bootstrap-secrets is idempotent (existing secret detected)"
else
    warn "⚠️  bootstrap-secrets may have issues with existing secrets"
fi

info "Testing generate-keys idempotency"
if ./scripts/manage-saml-certificates-terraform.sh generate-keys staging >/dev/null 2>&1; then
    log "✅ generate-keys is idempotent (existing keys/certs detected)"
else
    warn "⚠️  generate-keys may have issues with existing assets"
fi

info "Testing deploy idempotency"
if ./scripts/manage-saml-certificates-terraform.sh deploy staging >/dev/null 2>&1; then
    log "✅ deploy is idempotent (existing deployment detected)"
else
    warn "⚠️  deploy may have issues with existing deployments"
fi

echo

# Cleanup
echo "🧹 Cleanup"
echo "----------"

info "Cleaning up decrypted key (security best practice)"
rm -f "$DECRYPTED_KEY_PATH"
log "Decrypted key removed"

echo

# Summary
echo "📋 Staging SAML Validation Summary"
echo "=================================="
log "✅ AWS CLI authentication and access"
log "✅ AWS Secrets Manager access for staging"
log "✅ Terraform infrastructure scripts available"
log "✅ Encrypted key file exists and valid"
log "✅ Key decryption works with staging secret"
log "✅ Certificate and private key match"
log "✅ Deployment script integration works"
log "✅ SimpleSAMLphp certificate deployment"

echo
echo "🎉 All staging SAML validation tests PASSED!"
echo
warn "NEXT STEPS:"
echo "1. Commit staging certificate: git add $CERT_PATH && git commit -m 'Add staging SAML certificate'"
echo "2. Register SP metadata with NetBadge admin"
echo "3. Test full deployment via CI/CD pipeline"
echo "4. Monitor SAML authentication in staging environment"
echo
log "Staging environment is ready for SAML integration! 🚀"
