#!/bin/bash

# SimpleSAMLphp Certificate Management Script
# Manages SSL certificates for SAML Service Provider functionality

set -e

MODE="${1:-dev}"
CERT_DIR="/opt/drupal/simplesamlphp/cert"
SP_KEY_FILE="${CERT_DIR}/sp.key"
SP_CERT_FILE="${CERT_DIR}/sp.crt"

echo "🔐 Managing SAML certificates (Mode: ${MODE})"

# Ensure certificate directory exists
mkdir -p "${CERT_DIR}"

case "${MODE}" in
    "prod"|"production")
        echo "📋 Production mode: Using environment-provided certificates"
        
        # Check if certificates are provided via environment variables
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
        ;;
        
    "dev"|"development"|*)
        echo "🔧 Development mode: Generating self-signed certificates"
        generate_self_signed_cert
        ;;
esac

# Set proper ownership
chown -R 33:33 "${CERT_DIR}"

echo "🎯 Certificate setup completed"

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
