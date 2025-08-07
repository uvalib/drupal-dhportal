#!/bin/bash

# SimpleSAMLphp Configuration Manager
# Handles all configuration setup in a single, testable script

set -e

CONFIG_DIR="/opt/drupal/simplesamlphp/config"
CERT_DIR="/opt/drupal/simplesamlphp/cert"
ENVIRONMENT="${DEPLOYMENT_ENVIRONMENT:-development}"

echo "=== SimpleSAML Configuration Manager ==="
echo "Environment: ${ENVIRONMENT}"

# Function to validate required environment variables
validate_environment() {
    local required_vars=()
    
    if [[ "${ENVIRONMENT}" != "development" ]]; then
        required_vars+=("SIMPLESAMLPHP_SECRET_SALT")
        required_vars+=("SIMPLESAMLPHP_ADMIN_PASSWORD")
    fi
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var}" ]]; then
            echo "ERROR: Required environment variable ${var} is not set"
            exit 1
        fi
    done
}

# Function to setup configuration
setup_configuration() {
    echo "📋 Setting up SimpleSAML configuration..."
    
    # Use template if available, otherwise use static config
    if [[ -f "${CONFIG_DIR}/config.template.php" ]]; then
        echo "Using template-based configuration"
        # The template is designed to be used directly
        ln -sf config.template.php "${CONFIG_DIR}/config.php"
    elif [[ -f "${CONFIG_DIR}/config.${ENVIRONMENT}.php" ]]; then
        echo "Using environment-specific configuration: ${ENVIRONMENT}"
        ln -sf "config.${ENVIRONMENT}.php" "${CONFIG_DIR}/config.php"
    else
        echo "Using default configuration file"
        # Assume config.php already exists
    fi
}

# Function to setup certificates
setup_certificates() {
    echo "🔐 Setting up SAML certificates..."
    
    # Use terraform integration if available, otherwise use standard management
    if [[ -f "/opt/drupal/scripts/manage-saml-certificates-terraform.sh" ]]; then
        echo "Using terraform-integrated certificate management"
        /opt/drupal/scripts/manage-saml-certificates-terraform.sh deploy "${ENVIRONMENT}"
    else
        echo "Using standard certificate management"
        /opt/drupal/scripts/manage-saml-certificates.sh "${ENVIRONMENT}"
    fi
}

# Function to validate setup
validate_setup() {
    echo "✅ Validating configuration..."
    
    local errors=0
    
    # Check required files
    if [[ ! -f "${CONFIG_DIR}/config.php" ]]; then
        echo "ERROR: config.php not found"
        ((errors++))
    fi
    
    if [[ ! -f "${CERT_DIR}/sp.key" ]] || [[ ! -f "${CERT_DIR}/sp.crt" ]]; then
        echo "WARNING: SAML certificates not found (may be provided via environment)"
    fi
    
    # Test PHP syntax
    if ! php -l "${CONFIG_DIR}/config.php" >/dev/null 2>&1; then
        echo "ERROR: config.php has syntax errors"
        ((errors++))
    fi
    
    # Test Apache configuration
    if ! apache2ctl configtest >/dev/null 2>&1; then
        echo "ERROR: Apache configuration is invalid"
        ((errors++))
    fi
    
    if ((errors > 0)); then
        echo "Configuration validation failed with ${errors} errors"
        exit 1
    fi
    
    echo "Configuration validation passed"
}

# Main execution
main() {
    validate_environment
    setup_configuration
    setup_certificates
    validate_setup
    
    echo "🎯 SimpleSAML configuration completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
