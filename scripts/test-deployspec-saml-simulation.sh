#!/bin/bash

# Deployspec.yml SAML Logic Simulation Test
# 
# This script simulates the exact SAML certificate logic from deployspec.yml
# to validate that the deployment pipeline will work correctly.

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

echo "🔄 Deployspec.yml SAML Logic Simulation"
echo "======================================="

# Simulate CodeBuild environment variables (from deployspec.yml)
DEPLOYMENT_ENVIRONMENT="${DEPLOYMENT_ENVIRONMENT:-staging}"
CODEBUILD_SRC_DIR="${CODEBUILD_SRC_DIR:-/Users/ys2n/Code/ddev/drupal-dhportal}"
TERRAFORM_REPO_PATH="${TERRAFORM_REPO_PATH:-/Users/ys2n/Code/uvalib/terraform-infrastructure}"

# For simulation, we need to use the actual terraform repo location
SIMULATED_TERRAFORM_PATH="$TERRAFORM_REPO_PATH"

echo "Environment: $DEPLOYMENT_ENVIRONMENT"
echo "Source Directory: $CODEBUILD_SRC_DIR"
echo "Terraform Repo: $TERRAFORM_REPO_PATH"
echo

# Create temporary environment file (like deployspec.yml does)
ENV_FILE="/tmp/deployspec-test-env"
rm -f "$ENV_FILE"

echo "1️⃣  Simulating deployspec.yml pre_build phase"
echo "--------------------------------------------"

info "Setting up SAML key variables (from deployspec.yml lines 48-58)"

# Extract exact logic from deployspec.yml  if [ "$DEPLOYMENT_ENVIRONMENT" = "production" ]; then
    SAML_KEY_NAME=dh.library.virginia.edu/production.new/keys/dh-drupal-production-saml.pem
    SAML_SECRET_NAME=dh.library.virginia.edu/production.new/keys/dh-drupal-production-saml.pem
  else
    SAML_KEY_NAME=dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem
    SAML_SECRET_NAME=dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem
fi

SAML_PRIVATE_KEY=${SIMULATED_TERRAFORM_PATH}/${SAML_KEY_NAME}

info "SAML_KEY_NAME: $SAML_KEY_NAME"
info "SAML_SECRET_NAME: $SAML_SECRET_NAME"
info "SAML_PRIVATE_KEY: $SAML_PRIVATE_KEY"

# Simulate the exact conditional logic from deployspec.yml (lines 59-70)
if [ -f "${SAML_PRIVATE_KEY}.cpt" ]; then
    echo "Decrypting SAML private key for $DEPLOYMENT_ENVIRONMENT..."
    
    # This is the exact command from deployspec.yml (but using our simulated terraform path)
    if ${SIMULATED_TERRAFORM_PATH}/scripts/decrypt-key.ksh ${SAML_PRIVATE_KEY}.cpt ${SAML_SECRET_NAME}; then
        chmod 600 ${SAML_PRIVATE_KEY}
        echo "SAML_KEY_AVAILABLE=true" >> $ENV_FILE
        log "SAML private key decrypted successfully"
    else
        echo "SAML_KEY_AVAILABLE=false" >> $ENV_FILE
        error "SAML private key decryption failed"
        exit 1
    fi
else
    echo "SAML private key not found: ${SAML_PRIVATE_KEY}.cpt"
    echo "SAML_KEY_AVAILABLE=false" >> $ENV_FILE
    error "SAML private key file not found"
    exit 1
fi

echo

echo "2️⃣  Simulating deployspec.yml build phase"
echo "-----------------------------------------"

# Set THEME_ONLY=false to trigger full deploy logic
echo "THEME_ONLY=false" >> $ENV_FILE

# Source the environment file (like deployspec.yml does)
info "Sourcing environment variables"
source $ENV_FILE

info "SAML_KEY_AVAILABLE=$SAML_KEY_AVAILABLE"
info "THEME_ONLY=$THEME_ONLY"

# Simulate the conditional logic from deployspec.yml (lines 106-120)
if [ "$THEME_ONLY" = "true" ]; then
    echo "DEBUG: Running limited theme update..."
    echo "Skipping Redundant checkout... "
else
    echo "DEBUG: Running full rebuild and deploy..."
    echo "Setup SAML certificates using decrypted infrastructure keys"
    echo "Setting up SAML certificates for $DEPLOYMENT_ENVIRONMENT environment..."
    
    # Make terraform infrastructure available for container certificate setup
    echo "TERRAFORM_REPO_PATH=${SIMULATED_TERRAFORM_PATH}" >> $ENV_FILE
    echo "DEPLOYMENT_ENVIRONMENT=${DEPLOYMENT_ENVIRONMENT}" >> $ENV_FILE
    
    # Deploy SAML certificates if available (exact logic from deployspec.yml)
    if [ "$SAML_KEY_AVAILABLE" = "true" ]; then
        echo "Deploying SAML certificates for $DEPLOYMENT_ENVIRONMENT..."
        cd ${CODEBUILD_SRC_DIR}
        
        # This is the exact command from deployspec.yml
        if ./scripts/manage-saml-certificates-terraform.sh deploy $DEPLOYMENT_ENVIRONMENT; then
            log "SAML certificate deployment successful"
        else
            error "SAML certificate deployment failed"
            exit 1
        fi
    else
        echo "SAML certificates not available - skipping SAML setup"
        warn "SAML setup was skipped"
    fi
fi

echo

echo "3️⃣  Validating Deployment Results"
echo "--------------------------------"

# Check that SimpleSAMLphp certificates exist and are valid
SIMPLESAML_CERT="$CODEBUILD_SRC_DIR/simplesamlphp/cert/server.crt"
SIMPLESAML_KEY="$CODEBUILD_SRC_DIR/simplesamlphp/cert/server.key"

if [ -f "$SIMPLESAML_CERT" ] && [ -f "$SIMPLESAML_KEY" ]; then
    log "SimpleSAMLphp certificates deployed"
    
    # Verify they're valid and matching
    if openssl x509 -in "$SIMPLESAML_CERT" -noout >/dev/null 2>&1 && \
       openssl rsa -in "$SIMPLESAML_KEY" -check -noout >/dev/null 2>&1; then
        log "Deployed certificates are valid"
        
        # Check they match
        CERT_PUBLIC_KEY=$(openssl x509 -in "$SIMPLESAML_CERT" -pubkey -noout)
        KEY_PUBLIC_KEY=$(openssl rsa -in "$SIMPLESAML_KEY" -pubout 2>/dev/null)
        
        if [ "$CERT_PUBLIC_KEY" = "$KEY_PUBLIC_KEY" ]; then
            log "Deployed certificate and key match"
        else
            error "Deployed certificate and key do NOT match"
            exit 1
        fi
    else
        error "Deployed certificates are not valid"
        exit 1
    fi
    
    # Show certificate details
    info "Deployed certificate details:"
    openssl x509 -in "$SIMPLESAML_CERT" -noout -subject -dates | sed 's/^/   /'
else
    error "SimpleSAMLphp certificates not found after deployment"
    exit 1
fi

echo

echo "🧹 Cleanup (Security Best Practice)"
echo "-----------------------------------"

# Remove decrypted key (as production deployspec.yml should do)
if [ -f "$SAML_PRIVATE_KEY" ]; then
    info "Removing decrypted private key"
    rm -f "$SAML_PRIVATE_KEY"
    log "Decrypted private key removed"
fi

# Clean up test environment file
rm -f "$ENV_FILE"

echo

echo "✅ Deployspec.yml Simulation Results"
echo "===================================="
log "✅ SAML key decryption simulation successful"
log "✅ Environment variable handling correct"
log "✅ Conditional deployment logic working"
log "✅ Certificate deployment successful"
log "✅ SimpleSAMLphp integration verified"
log "✅ Security cleanup performed"

echo
echo "🎉 Deployspec.yml SAML logic simulation PASSED!"
echo
info "The actual AWS CodeBuild deployment should work identically"
echo "Ready for CI/CD pipeline deployment! 🚀"
