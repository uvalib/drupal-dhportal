#!/bin/bash

# SAML Certificate Availability Checker
# Checks if encrypted SAML certificates are available in terraform-infrastructure

set -e

TERRAFORM_REPO_PATH="${TERRAFORM_REPO_PATH:-/tmp/terraform-infrastructure}"
ENVIRONMENT="${1:-staging}"

echo "🔍 Checking SAML Certificate Availability"
echo "Environment: ${ENVIRONMENT}"
echo "Terraform Repo Path: ${TERRAFORM_REPO_PATH}"

function check_encrypted_certificates() {
    local environment="${1}"
    
    case "${environment}" in
        "production")
            SAML_KEY_PATH="${TERRAFORM_REPO_PATH}/dh.library.virginia.edu/production.new/keys/dh-drupal-production-saml.pem.cpt"
            ;;
        "staging")
            SAML_KEY_PATH="${TERRAFORM_REPO_PATH}/dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem.cpt"
            ;;
        *)
            echo "❌ Invalid environment: ${environment}"
            echo "Valid environments: staging, production"
            exit 1
            ;;
    esac
    
    echo ""
    echo "🔐 Checking for encrypted SAML certificate:"
    echo "   Expected path: ${SAML_KEY_PATH}"
    
    if [[ -f "${SAML_KEY_PATH}" ]]; then
        echo "✅ Encrypted SAML certificate found!"
        
        # Get file info
        local file_size=$(ls -lh "${SAML_KEY_PATH}" | awk '{print $5}')
        local file_date=$(ls -l "${SAML_KEY_PATH}" | awk '{print $6, $7, $8}')
        
        echo "   File size: ${file_size}"
        echo "   Last modified: ${file_date}"
        
        # Check if decrypt script exists
        local decrypt_script="${TERRAFORM_REPO_PATH}/scripts/decrypt-key.ksh"
        if [[ -f "${decrypt_script}" ]]; then
            echo "✅ Decryption script found: ${decrypt_script}"
            echo ""
            echo "💡 To decrypt (example):"
            echo "   ${decrypt_script} ${SAML_KEY_PATH} dh.library.virginia.edu/${environment}/keys/dh-drupal-${environment}-saml.pem"
        else
            echo "⚠️  Decryption script not found: ${decrypt_script}"
        fi
        
        return 0
    else
        echo "❌ Encrypted SAML certificate not found"
        echo ""
        echo "💡 This means the deployment will fall back to:"
        echo "   1. AWS Secrets Manager (dhportal/${environment}/simplesamlphp/private-key)"
        echo "   2. Environment variables (SIMPLESAMLPHP_SP_PRIVATE_KEY)"
        echo "   3. Self-signed certificates (fallback)"
        
        return 1
    fi
}

function check_aws_secrets() {
    local environment="${1}"
    
    echo ""
    echo "🌐 Checking AWS Secrets Manager availability..."
    
    if ! command -v aws &> /dev/null; then
        echo "⚠️  AWS CLI not available"
        return 1
    fi
    
    local private_key_secret="dhportal/${environment}/simplesamlphp/private-key"
    local certificate_secret="dhportal/${environment}/simplesamlphp/certificate"
    
    echo "   Checking secret: ${private_key_secret}"
    if aws secretsmanager describe-secret --secret-id "${private_key_secret}" >/dev/null 2>&1; then
        echo "   ✅ Private key secret exists"
    else
        echo "   ❌ Private key secret not found"
    fi
    
    echo "   Checking secret: ${certificate_secret}"
    if aws secretsmanager describe-secret --secret-id "${certificate_secret}" >/dev/null 2>&1; then
        echo "   ✅ Certificate secret exists"
    else
        echo "   ❌ Certificate secret not found"
    fi
}

function check_terraform_repo() {
    echo ""
    echo "📁 Terraform Infrastructure Repository Status:"
    
    if [[ ! -d "${TERRAFORM_REPO_PATH}" ]]; then
        echo "❌ Terraform repository not found at: ${TERRAFORM_REPO_PATH}"
        echo ""
        echo "💡 To check manually:"
        echo "   1. Clone terraform-infrastructure repository"
        echo "   2. Set TERRAFORM_REPO_PATH environment variable"
        echo "   3. Run this script again"
        return 1
    fi
    
    echo "✅ Terraform repository found"
    
    # Check if it's a git repository
    if [[ -d "${TERRAFORM_REPO_PATH}/.git" ]]; then
        echo "   Repository type: Git"
        local current_branch=$(cd "${TERRAFORM_REPO_PATH}" && git branch --show-current 2>/dev/null || echo "unknown")
        echo "   Current branch: ${current_branch}"
    else
        echo "   Repository type: Directory (not git)"
    fi
    
    # List key directories
    echo "   Available environments:"
    if [[ -d "${TERRAFORM_REPO_PATH}/dh.library.virginia.edu" ]]; then
        ls -1 "${TERRAFORM_REPO_PATH}/dh.library.virginia.edu/" 2>/dev/null | grep -v "^\." | sed 's/^/     - /' || echo "     (none found)"
    else
        echo "     ❌ dh.library.virginia.edu directory not found"
    fi
}

function main() {
    check_terraform_repo
    
    if [[ -d "${TERRAFORM_REPO_PATH}" ]]; then
        check_encrypted_certificates "${ENVIRONMENT}"
    fi
    
    check_aws_secrets "${ENVIRONMENT}"
    
    echo ""
    echo "=== Summary ==="
    echo "For ${ENVIRONMENT} environment, certificates will be sourced in this priority order:"
    echo "1. 🔐 Encrypted terraform-infrastructure files (if SAML_KEY_AVAILABLE=true)"
    echo "2. 🌐 AWS Secrets Manager (if secrets exist)"
    echo "3. 📧 Environment variables (if SIMPLESAMLPHP_SP_* variables set)"
    echo "4. 🔧 Self-signed certificates (automatic fallback)"
}

# Handle command line arguments
case "${1:-staging}" in
    staging|production)
        main
        ;;
    help|--help|-h)
        echo "Usage: $(basename $0) [staging|production]"
        echo ""
        echo "Checks availability of SAML certificates for the specified environment"
        echo ""
        echo "Environment Variables:"
        echo "  TERRAFORM_REPO_PATH - Path to terraform-infrastructure repository"
        echo "                        (default: /tmp/terraform-infrastructure)"
        exit 0
        ;;
    *)
        echo "❌ Invalid environment: ${1}"
        echo "Valid environments: staging, production"
        echo "Use '$(basename $0) help' for usage information"
        exit 1
        ;;
esac
