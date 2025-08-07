#!/bin/bash

# SimpleSAMLphp Certificate Management with Terraform Integration
# Bridges the gap between terraform-infrastructure and container deployment

set -e

COMMAND="${1:-help}"
ENVIRONMENT="${2:-staging}"
CERT_DIR="${CERT_DIR:-/opt/drupal/simplesamlphp/cert}"

# Try to find terraform-infrastructure in multiple locations
TERRAFORM_REPO_PATH="${TERRAFORM_REPO_PATH:-}"
if [[ -z "${TERRAFORM_REPO_PATH}" ]]; then
    # Common locations where terraform-infrastructure might be found
    for path in \
        "/Users/ys2n/Code/uvalib/terraform-infrastructure" \
        "${CODEBUILD_SRC_DIR}/terraform-infrastructure" \
        "/tmp/terraform-infrastructure" \
        "../terraform-infrastructure" \
        "./terraform-infrastructure"; do
        if [[ -d "${path}" ]]; then
            TERRAFORM_REPO_PATH="${path}"
            break
        fi
    done
fi

# Default to a reasonable path if none found
TERRAFORM_REPO_PATH="${TERRAFORM_REPO_PATH:-/tmp/terraform-infrastructure}"

echo "🔐 SAML Certificate Management with Terraform Integration"
echo "Command: ${COMMAND}, Environment: ${ENVIRONMENT}"
echo "Terraform Path: ${TERRAFORM_REPO_PATH}"

function help_and_exit() {
    echo "Usage: $(basename $0) <command> <environment>"
    echo ""
    echo "Commands:"
    echo "  deploy     Deploy certificates for environment"
    echo "  validate   Validate existing certificates"
    echo "  rotate     Generate new certificates and update secrets"
    echo "  info       Show terraform infrastructure information"
    echo "  test       Test certificate extraction from PEM file (test <pem-file>)"
    echo "  help       Show this help message"
    echo ""
    echo "Environment: development | staging | production"
    echo ""
    echo "Environment Variables:"
    echo "  TERRAFORM_REPO_PATH - Path to terraform-infrastructure repository"
    echo "  SAML_KEY_AVAILABLE  - Set by pipeline if encrypted keys are available"
    echo "  CERT_DIR           - Output directory for certificates (default: /opt/drupal/simplesamlphp/cert)"
    exit 1
}

function validate_environment() {
    case "${ENVIRONMENT}" in
        development|staging|production)
            ;;
        *)
            echo "Error: Invalid environment '${ENVIRONMENT}'"
            help_and_exit
            ;;
    esac
}

function deploy_certificates() {
    echo "📦 Deploying certificates for ${ENVIRONMENT}..."
    
    mkdir -p "${CERT_DIR}"
    
    case "${ENVIRONMENT}" in
        "production"|"staging")
            # First try terraform-infrastructure encrypted files (legacy)
            if [[ "${SAML_KEY_AVAILABLE}" == "true" && -d "${TERRAFORM_REPO_PATH}" ]]; then
                echo "🔑 Using terraform-infrastructure encrypted certificates"
                deploy_from_terraform
            else
                echo "🌐 Using AWS Secrets Manager or fallback"
                /opt/drupal/scripts/manage-saml-certificates.sh "${ENVIRONMENT}"
            fi
            ;;
        "development")
            echo "🔧 Using development certificate management"
            /opt/drupal/scripts/manage-saml-certificates.sh dev
            ;;
    esac
    
    validate_certificates
}

function deploy_from_terraform() {
    local base_path="${TERRAFORM_REPO_PATH}/dh.library.virginia.edu"
    local env_path=""
    
    # Determine the correct environment path
    case "${ENVIRONMENT}" in
        "production")
            env_path="${base_path}/production.new"
            ;;
        "staging")
            env_path="${base_path}/staging"
            ;;
        *)
            echo "❌ Unsupported environment for terraform deployment: ${ENVIRONMENT}"
            return 1
            ;;
    esac
    
    local key_file="${env_path}/keys/dh-drupal-${ENVIRONMENT}-saml.pem"
    local encrypted_key_file="${key_file}.cpt"
    
    echo "🔍 Looking for SAML certificates in: ${env_path}/keys/"
    
    # Check if encrypted file exists
    if [[ -f "${encrypted_key_file}" ]]; then
        echo "✅ Found encrypted SAML certificate: ${encrypted_key_file}"
        
        # For now, we'll use the decrypted version if available
        # In the pipeline, this would be decrypted by the deployment process
        if [[ -f "${key_file}" ]]; then
            echo "📝 Using decrypted certificate file: ${key_file}"
            extract_certificates_from_pem "${key_file}"
        else
            echo "⚠️  Encrypted file found but no decrypted version available"
            echo "🔄 In deployment pipeline, this should be decrypted first"
            echo "🔄 Falling back to AWS Secrets Manager"
            /opt/drupal/scripts/manage-saml-certificates.sh "${ENVIRONMENT}"
        fi
    else
        echo "⚠️  Terraform certificate file not found: ${encrypted_key_file}"
        echo "🔄 Falling back to AWS Secrets Manager"
        /opt/drupal/scripts/manage-saml-certificates.sh "${ENVIRONMENT}"
    fi
}

function extract_certificates_from_pem() {
    local pem_file="${1}"
    
    echo "📝 Extracting certificates from PEM file: ${pem_file}"
    
    # Ensure certificate directory exists
    mkdir -p "${CERT_DIR}"
    
    # Extract private key
    if grep -q "BEGIN PRIVATE KEY\|BEGIN RSA PRIVATE KEY\|BEGIN EC PRIVATE KEY" "${pem_file}"; then
        echo "🔐 Extracting private key..."
        if openssl pkey -in "${pem_file}" -out "${CERT_DIR}/sp.key" 2>/dev/null || openssl rsa -in "${pem_file}" -out "${CERT_DIR}/sp.key" 2>/dev/null; then
            chmod 600 "${CERT_DIR}/sp.key"
            echo "✅ Private key extracted to ${CERT_DIR}/sp.key"
        else
            echo "❌ Failed to extract private key"
            return 1
        fi
    else
        echo "⚠️  No private key found in PEM file"
        return 1
    fi
    
    # Extract certificate
    if grep -q "BEGIN CERTIFICATE" "${pem_file}"; then
        echo "📜 Extracting certificate..."
        openssl x509 -in "${pem_file}" -out "${CERT_DIR}/sp.crt"
        chmod 644 "${CERT_DIR}/sp.crt"
        echo "✅ Certificate extracted to ${CERT_DIR}/sp.crt"
    else
        echo "⚠️  No certificate found in PEM file - generating self-signed certificate"
        echo "🔧 Generating self-signed certificate from private key..."
        
        # Generate self-signed certificate from the private key
        # This is common for SAML SP certificates where CA validation isn't required
        openssl req -new -x509 -key "${CERT_DIR}/sp.key" -out "${CERT_DIR}/sp.crt" -days 3650 \
            -subj "/C=US/ST=Virginia/L=Charlottesville/O=University of Virginia/OU=Library/CN=dh.library.virginia.edu" 2>/dev/null
        
        if [[ $? -eq 0 && -f "${CERT_DIR}/sp.crt" ]]; then
            chmod 644 "${CERT_DIR}/sp.crt"
            echo "✅ Self-signed certificate generated: ${CERT_DIR}/sp.crt"
        else
            echo "❌ Failed to generate self-signed certificate"
            return 1
        fi
    fi
    
    # Verify extraction was successful
    if [[ -f "${CERT_DIR}/sp.key" && -f "${CERT_DIR}/sp.crt" ]]; then
        echo "✅ Terraform certificates deployed successfully"
    else
        echo "❌ Certificate extraction failed"
        return 1
    fi
}

function validate_certificates() {
    echo "🔍 Validating certificates..."
    
    local errors=0
    
    # Check if certificate files exist
    if [[ ! -f "${CERT_DIR}/sp.key" ]]; then
        echo "❌ Private key not found: ${CERT_DIR}/sp.key"
        ((errors++))
    fi
    
    if [[ ! -f "${CERT_DIR}/sp.crt" ]]; then
        echo "❌ Certificate not found: ${CERT_DIR}/sp.crt"
        ((errors++))
    fi
    
    if ((errors > 0)); then
        echo "💥 Certificate validation failed with ${errors} errors"
        return 1
    fi
    
    # Validate private key
    if ! openssl rsa -in "${CERT_DIR}/sp.key" -check -noout 2>/dev/null; then
        echo "❌ Private key validation failed"
        ((errors++))
    fi
    
    # Validate certificate
    if ! openssl x509 -in "${CERT_DIR}/sp.crt" -noout 2>/dev/null; then
        echo "❌ Certificate validation failed"
        ((errors++))
    fi
    
    # Check certificate expiration
    local expiry_date=$(openssl x509 -in "${CERT_DIR}/sp.crt" -enddate -noout | cut -d= -f2)
    local expiry_epoch=$(date -d "${expiry_date}" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "${expiry_date}" +%s 2>/dev/null)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    if ((days_until_expiry < 30)); then
        echo "⚠️  Certificate expires in ${days_until_expiry} days: ${expiry_date}"
        if ((days_until_expiry < 0)); then
            echo "❌ Certificate has expired!"
            ((errors++))
        fi
    else
        echo "✅ Certificate valid until: ${expiry_date} (${days_until_expiry} days)"
    fi
    
    # Verify key and certificate match
    local key_hash=$(openssl rsa -in "${CERT_DIR}/sp.key" -pubout 2>/dev/null | openssl md5 | cut -d' ' -f2)
    local cert_hash=$(openssl x509 -in "${CERT_DIR}/sp.crt" -pubkey -noout 2>/dev/null | openssl md5 | cut -d' ' -f2)
    
    if [[ "${key_hash}" == "${cert_hash}" ]]; then
        echo "✅ Private key and certificate match"
    else
        echo "❌ Private key and certificate do not match!"
        ((errors++))
    fi
    
    if ((errors == 0)); then
        echo "🎯 Certificate validation passed"
        return 0
    else
        echo "💥 Certificate validation failed with ${errors} errors"
        return 1
    fi
}

function rotate_certificates() {
    echo "🔄 Rotating certificates for ${ENVIRONMENT}..."
    
    # Backup existing certificates
    if [[ -f "${CERT_DIR}/sp.key" ]]; then
        cp "${CERT_DIR}/sp.key" "${CERT_DIR}/sp.key.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    if [[ -f "${CERT_DIR}/sp.crt" ]]; then
        cp "${CERT_DIR}/sp.crt" "${CERT_DIR}/sp.crt.backup.$(date +%Y%m%d-%H%M%S)"
    fi
    
    # Generate new certificates
    /opt/drupal/scripts/manage-saml-certificates.sh "${ENVIRONMENT}"
    
    # For production/staging, offer to update AWS Secrets Manager
    if [[ "${ENVIRONMENT}" != "development" ]]; then
        echo "💡 New certificates generated. Consider updating AWS Secrets Manager:"
        echo "   aws secretsmanager update-secret --secret-id 'dhportal/${ENVIRONMENT}/simplesamlphp/private-key' --secret-string \"\$(cat ${CERT_DIR}/sp.key)\""
        echo "   aws secretsmanager update-secret --secret-id 'dhportal/${ENVIRONMENT}/simplesamlphp/certificate' --secret-string \"\$(cat ${CERT_DIR}/sp.crt)\""
    fi
}

function show_terraform_info() {
    echo "🏗️  Terraform Infrastructure Information"
    echo "Terraform Repository: ${TERRAFORM_REPO_PATH}"
    
    if [[ ! -d "${TERRAFORM_REPO_PATH}" ]]; then
        echo "❌ Terraform repository not found at: ${TERRAFORM_REPO_PATH}"
        return 1
    fi
    
    local dh_path="${TERRAFORM_REPO_PATH}/dh.library.virginia.edu"
    if [[ ! -d "${dh_path}" ]]; then
        echo "❌ DH Portal configuration not found at: ${dh_path}"
        return 1
    fi
    
    echo "✅ DH Portal terraform configuration found"
    echo ""
    
    # Show available environments
    echo "📁 Available environments:"
    for env_dir in "${dh_path}"/*/; do
        if [[ -d "${env_dir}" ]]; then
            local env_name=$(basename "${env_dir}")
            echo "  - ${env_name}"
            
            # Check for SAML certificates
            local keys_dir="${env_dir}keys"
            if [[ -d "${keys_dir}" ]]; then
                echo "    📋 Available keys in ${env_name}:"
                for key_file in "${keys_dir}"/dh-drupal-*-saml*; do
                    if [[ -f "${key_file}" ]]; then
                        local key_name=$(basename "${key_file}")
                        if [[ "${key_name}" == *.cpt ]]; then
                            echo "      🔐 ${key_name} (encrypted)"
                        else
                            echo "      🔓 ${key_name} (decrypted)"
                        fi
                    fi
                done
            fi
            
            # Check for ansible templates
            local templates_dir="${env_dir}ansible/templates/simplesamlphp"
            if [[ -d "${templates_dir}" ]]; then
                echo "    📋 SimpleSAML templates:"
                for template in "${templates_dir}"/*.j2; do
                    if [[ -f "${template}" ]]; then
                        echo "      📝 $(basename "${template}")"
                    fi
                done
            fi
            echo ""
        fi
    done
}

# Main execution
case "${COMMAND}" in
    deploy)
        validate_environment
        deploy_certificates
        ;;
    validate)
        validate_certificates
        ;;
    rotate)
        validate_environment
        rotate_certificates
        ;;
    info)
        show_terraform_info
        ;;
    test)
        if [[ -n "${ENVIRONMENT}" && -f "${ENVIRONMENT}" ]]; then
            echo "🧪 Testing certificate extraction from: ${ENVIRONMENT}"
            extract_certificates_from_pem "${ENVIRONMENT}"
        else
            echo "❌ Usage: ${0} test <path-to-pem-file>"
            exit 1
        fi
        ;;
    help|*)
        help_and_exit
        ;;
esac
