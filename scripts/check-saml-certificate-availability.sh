#!/bin/bash

# SimpleSAMLphp Certificate Availability Checker
# Checks certificate availability across different sources and environments

set -e

ENVIRONMENT="${1:-staging}"
CERT_DIR="/opt/drupal/simplesamlphp/cert"

echo "🔍 SAML Certificate Availability Check"
echo "Environment: ${ENVIRONMENT}"
echo "Certificate Directory: ${CERT_DIR}"
echo ""

function check_local_certificates() {
    echo "📁 Local Certificate Files:"
    if [[ -d "${CERT_DIR}" ]]; then
        for cert in "${CERT_DIR}"/*.{key,crt,pem}; do
            if [[ -f "${cert}" ]]; then
                local filename=$(basename "${cert}")
                local size=$(stat -f%z "${cert}" 2>/dev/null || stat -c%s "${cert}" 2>/dev/null || echo "unknown")
                echo "  ✅ ${filename} (${size} bytes)"
                
                # Quick validation
                case "${filename}" in
                    *.key)
                        if openssl rsa -in "${cert}" -check -noout 2>/dev/null; then
                            echo "      🔑 Valid private key"
                        else
                            echo "      ❌ Invalid private key"
                        fi
                        ;;
                    *.crt|*.pem)
                        if openssl x509 -in "${cert}" -noout 2>/dev/null; then
                            local expiry=$(openssl x509 -in "${cert}" -enddate -noout | cut -d= -f2)
                            echo "      📜 Valid certificate (expires: ${expiry})"
                        else
                            echo "      ❌ Invalid certificate"
                        fi
                        ;;
                esac
            fi
        done
        
        if ! ls "${CERT_DIR}"/*.{key,crt,pem} >/dev/null 2>&1; then
            echo "  ⚠️  No certificate files found"
        fi
    else
        echo "  ❌ Certificate directory does not exist"
    fi
    echo ""
}

function check_aws_secrets() {
    echo "☁️  AWS Secrets Manager:"
    if command -v aws >/dev/null 2>&1; then
        local secrets=(
            "dhportal/${ENVIRONMENT}/simplesamlphp/private-key"
            "dhportal/${ENVIRONMENT}/simplesamlphp/certificate"
            "dhportal/${ENVIRONMENT}/simplesamlphp/admin-password"
            "dhportal/${ENVIRONMENT}/simplesamlphp/secret-salt"
        )
        
        for secret in "${secrets[@]}"; do
            if aws secretsmanager describe-secret --secret-id "${secret}" >/dev/null 2>&1; then
                echo "  ✅ ${secret}"
            else
                echo "  ❌ ${secret} (not found)"
            fi
        done
    else
        echo "  ⚠️  AWS CLI not available"
    fi
    echo ""
}

function check_terraform_certificates() {
    echo "🏗️  Terraform Infrastructure:"
    
    # Try to find terraform-infrastructure
    local terraform_paths=(
        "/Users/ys2n/Code/uvalib/terraform-infrastructure"
        "${CODEBUILD_SRC_DIR}/terraform-infrastructure"
        "/tmp/terraform-infrastructure"
        "../terraform-infrastructure"
        "./terraform-infrastructure"
    )
    
    local terraform_path=""
    for path in "${terraform_paths[@]}"; do
        if [[ -d "${path}" ]]; then
            terraform_path="${path}"
            break
        fi
    done
    
    if [[ -n "${terraform_path}" ]]; then
        echo "  📁 Found terraform at: ${terraform_path}"
        
        local dh_path="${terraform_path}/dh.library.virginia.edu"
        if [[ -d "${dh_path}" ]]; then
            local env_dir=""
            case "${ENVIRONMENT}" in
                production)
                    env_dir="${dh_path}/production.new"
                    ;;
                staging)
                    env_dir="${dh_path}/staging"
                    ;;
            esac
            
            if [[ -n "${env_dir}" && -d "${env_dir}" ]]; then
                echo "  📋 Environment: ${ENVIRONMENT}"
                local keys_dir="${env_dir}/keys"
                
                if [[ -d "${keys_dir}" ]]; then
                    echo "  🔑 Available keys:"
                    for key_file in "${keys_dir}"/dh-drupal-*-saml*; do
                        if [[ -f "${key_file}" ]]; then
                            local key_name=$(basename "${key_file}")
                            if [[ "${key_name}" == *.cpt ]]; then
                                echo "    🔐 ${key_name} (encrypted)"
                            else
                                echo "    🔓 ${key_name} (decrypted)"
                            fi
                        fi
                    done
                else
                    echo "  ❌ Keys directory not found: ${keys_dir}"
                fi
            else
                echo "  ❌ Environment directory not found for: ${ENVIRONMENT}"
            fi
        else
            echo "  ❌ DH Portal configuration not found"
        fi
    else
        echo "  ❌ Terraform infrastructure not found"
    fi
    echo ""
}

function check_environment_variables() {
    echo "🌍 Environment Variables:"
    local env_vars=(
        "SIMPLESAMLPHP_SP_PRIVATE_KEY"
        "SIMPLESAMLPHP_SP_CERTIFICATE"
        "SIMPLESAMLPHP_ADMIN_PASSWORD"
        "SIMPLESAMLPHP_SECRET_SALT"
        "DEPLOYMENT_ENVIRONMENT"
        "SAML_KEY_AVAILABLE"
    )
    
    for var in "${env_vars[@]}"; do
        if [[ -n "${!var}" ]]; then
            if [[ "${var}" == *"PASSWORD"* || "${var}" == *"SECRET"* || "${var}" == *"KEY"* ]]; then
                echo "  ✅ ${var} (set, ${#!var} characters)"
            else
                echo "  ✅ ${var}=${!var}"
            fi
        else
            echo "  ⚠️  ${var} (not set)"
        fi
    done
    echo ""
}

function main() {
    check_local_certificates
    check_terraform_certificates
    check_aws_secrets
    check_environment_variables
    
    echo "🎯 Summary:"
    echo "Run 'manage-saml-certificates-terraform.sh deploy ${ENVIRONMENT}' to deploy certificates"
    echo "Run 'check-saml-certificates.sh' for detailed certificate health check"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi