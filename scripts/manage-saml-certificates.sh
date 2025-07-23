#!/bin/bash

# SimpleSAMLphp Certificate Management Script
# Manages SSL certificates for SAML Service Provider functionality
# Uses AWS Secrets Manager for production certificate storage

set -e

MODE="${1:-dev}"
CERT_DIR="/opt/drupal/simplesamlphp/cert"
SP_KEY_FILE="${CERT_DIR}/sp.key"
SP_CERT_FILE="${CERT_DIR}/sp.crt"
SCRIPT_DIR="$(dirname "$0")"

echo "🔐 Managing SAML certificates (Mode: ${MODE})"

# Ensure certificate directory exists
mkdir -p "${CERT_DIR}"

# Function definitions
function fallback_certificate_setup() {
    echo "🔧 Checking environment variables for certificates..."
    
    # Check if certificates are provided via environment variables (legacy support)
    if [[ -n "${SIMPLESAMLPHP_SP_PRIVATE_KEY}" && -n "${SIMPLESAMLPHP_SP_CERTIFICATE}" ]]; then
        echo "✅ Found certificates in environment variables"
        echo "${SIMPLESAMLPHP_SP_PRIVATE_KEY}" > "${SP_KEY_FILE}"
        echo "${SIMPLESAMLPHP_SP_CERTIFICATE}" > "${SP_CERT_FILE}"
        chmod 600 "${SP_KEY_FILE}"
        chmod 644 "${SP_CERT_FILE}"
        echo "✅ Certificates installed from environment"
    elif [[ -f "${SP_KEY_FILE}" && -f "${SP_CERT_FILE}" ]]; then
        echo "✅ Using existing certificates"
    else
        echo "⚠️  No certificates provided via environment or existing files"
        echo "🔧 Generating self-signed certificates for development fallback"
        generate_self_signed_cert
    fi
}

function generate_self_signed_cert() {
    echo "🔧 Generating self-signed certificate..."
    
    # Generate private key
    openssl genrsa -out "${SP_KEY_FILE}" 2048
    
    # Generate certificate
    openssl req -new -x509 -key "${SP_KEY_FILE}" -out "${SP_CERT_FILE}" -days 365 \
        -subj "/C=US/ST=Virginia/L=Charlottesville/O=University of Virginia/OU=Digital Humanities Portal/CN=${SIMPLESAMLPHP_SP_ENTITY_ID:-drupal-dhportal.example.com}"
    
    # Set permissions
    chmod 600 "${SP_KEY_FILE}"
    chmod 644 "${SP_CERT_FILE}"
    
    echo "✅ Self-signed certificate generated"
}

case "${MODE}" in
    "prod"|"production")
        echo "📋 Production mode: Using AWS Secrets Manager"
        
        # Use AWS Secrets Manager for production certificates
        if command -v aws &> /dev/null; then
            echo "🔍 Retrieving certificates from AWS Secrets Manager..."
            
            # Try to get certificates from AWS Secrets Manager
            if "${SCRIPT_DIR}/get-simplesamlphp-secret.sh" production private-key "${SP_KEY_FILE}" && \
               "${SCRIPT_DIR}/get-simplesamlphp-secret.sh" production certificate "${SP_CERT_FILE}"; then
                echo "✅ Certificates retrieved from AWS Secrets Manager"
            else
                echo "⚠️  AWS Secrets Manager certificates not available"
                echo "🔧 Falling back to environment variables or self-signed"
                fallback_certificate_setup
            fi
        else
            echo "⚠️  AWS CLI not available, falling back to environment variables"
            fallback_certificate_setup
        fi
        ;;
        
    "staging")
        echo "📋 Staging mode: Using AWS Secrets Manager"
        
        if command -v aws &> /dev/null; then
            echo "🔍 Retrieving staging certificates from AWS Secrets Manager..."
            
            if "${SCRIPT_DIR}/get-simplesamlphp-secret.sh" staging private-key "${SP_KEY_FILE}" && \
               "${SCRIPT_DIR}/get-simplesamlphp-secret.sh" staging certificate "${SP_CERT_FILE}"; then
                echo "✅ Staging certificates retrieved from AWS Secrets Manager"
            else
                echo "⚠️  Staging certificates not in AWS Secrets Manager"
                echo "🔧 Generating self-signed certificates for staging"
                generate_self_signed_cert
            fi
        else
            echo "⚠️  AWS CLI not available, generating self-signed certificates"
            generate_self_signed_cert
        fi
        ;;
        
    "dev"|"development"|*)
        echo "🔧 Development mode: Generating self-signed certificates"
        generate_self_signed_cert
        ;;
esac

# Set proper ownership and exit
chown -R 33:33 "${CERT_DIR}"
echo "🎯 Certificate setup completed"
