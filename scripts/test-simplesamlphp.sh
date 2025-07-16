#!/bin/bash

# SimpleSAMLphp Test Script
# Tests the complete SimpleSAMLphp setup for both development and production environments

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

TESTS_PASSED=0
TESTS_FAILED=0

# Test function wrapper
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    info "Running test: $test_name"
    
    if eval "$test_command"; then
        log "PASS: $test_name"
        ((TESTS_PASSED++))
    else
        error "FAIL: $test_name"
        ((TESTS_FAILED++))
    fi
    echo
}

# Detect environment
detect_environment() {
    if [ -f "/opt/drupal/web/index.php" ]; then
        DRUPAL_ROOT="/opt/drupal"
        ENVIRONMENT="production"
    elif [ -f "/var/www/html/web/index.php" ]; then
        DRUPAL_ROOT="/var/www/html"
        ENVIRONMENT="container"
    elif [ -f "web/index.php" ]; then
        DRUPAL_ROOT="$(pwd)"
        ENVIRONMENT="ddev"
    else
        error "Cannot detect Drupal environment"
        exit 1
    fi
    
    info "Detected environment: $ENVIRONMENT ($DRUPAL_ROOT)"
}

# Test certificate files exist
test_certificates_exist() {
    local cert_dir="$DRUPAL_ROOT/simplesamlphp/cert"
    
    [ -f "$cert_dir/server.key" ] && \
    [ -f "$cert_dir/server.crt" ] && \
    [ -f "$cert_dir/server.pem" ]
}

# Test certificate permissions
test_certificate_permissions() {
    local cert_dir="$DRUPAL_ROOT/simplesamlphp/cert"
    
    # Private key should be 600
    local key_perms=$(stat -c %a "$cert_dir/server.key" 2>/dev/null || stat -f %A "$cert_dir/server.key" 2>/dev/null)
    [ "$key_perms" = "600" ] || return 1
    
    # Certificate should be 644
    local cert_perms=$(stat -c %a "$cert_dir/server.crt" 2>/dev/null || stat -f %A "$cert_dir/server.crt" 2>/dev/null)
    [ "$cert_perms" = "644" ] || return 1
    
    return 0
}

# Test certificate validity
test_certificate_validity() {
    local cert_dir="$DRUPAL_ROOT/simplesamlphp/cert"
    openssl x509 -in "$cert_dir/server.crt" -noout -checkend 86400 >/dev/null 2>&1
}

# Test SimpleSAMLphp configuration files exist
test_config_files_exist() {
    local config_dir="$DRUPAL_ROOT/simplesamlphp/config"
    
    [ -f "$config_dir/config.php" ] && \
    [ -f "$config_dir/authsources.php" ] && \
    [ -f "$DRUPAL_ROOT/simplesamlphp/metadata/saml20-idp-remote.php" ] && \
    [ -f "$DRUPAL_ROOT/simplesamlphp/bootstrap.php" ]
}

# Test SimpleSAMLphp web interface files exist
test_web_interface_files() {
    local web_dir="$DRUPAL_ROOT/web/simplesaml"
    
    [ -f "$web_dir/index.php" ] && \
    [ -f "$web_dir/status.php" ] && \
    [ -f "$web_dir/admin.php" ] && \
    [ -f "$web_dir/saml2-metadata.php" ] && \
    [ -f "$web_dir/_include.php" ] && \
    [ -f "$web_dir/.htaccess" ]
}

# Test PHP syntax of configuration files
test_php_syntax() {
    local config_dir="$DRUPAL_ROOT/simplesamlphp/config"
    local web_dir="$DRUPAL_ROOT/web/simplesaml"
    
    php -l "$config_dir/config.php" >/dev/null 2>&1 && \
    php -l "$config_dir/authsources.php" >/dev/null 2>&1 && \
    php -l "$DRUPAL_ROOT/simplesamlphp/metadata/saml20-idp-remote.php" >/dev/null 2>&1 && \
    php -l "$web_dir/index.php" >/dev/null 2>&1 && \
    php -l "$web_dir/_include.php" >/dev/null 2>&1
}

# Test SimpleSAMLphp autoloader
test_simplesamlphp_autoloader() {
    if [ "$ENVIRONMENT" = "production" ] || [ "$ENVIRONMENT" = "container" ]; then
        [ -f "$DRUPAL_ROOT/vendor/simplesamlphp/simplesamlphp/src/_autoload.php" ]
    else
        # In DDEV, check if vendor exists
        [ -f "$DRUPAL_ROOT/vendor/autoload.php" ]
    fi
}

# Test directory permissions
test_directory_permissions() {
    local base_dir="$DRUPAL_ROOT/simplesamlphp"
    
    # Check if directories are writable by web server
    [ -w "$base_dir/log" ] && \
    [ -w "$base_dir/tmp" ] && \
    [ -w "$base_dir/cache" ] && \
    [ -w "$base_dir/data" ]
}

# Test web server accessibility (if running)
test_web_accessibility() {
    if [ "$ENVIRONMENT" = "ddev" ]; then
        # Test DDEV URLs
        local base_url="https://drupal-dhportal.ddev.site"
        if command -v curl >/dev/null 2>&1; then
            curl -k -s -o /dev/null -w "%{http_code}" "$base_url/simplesaml/" | grep -q "200\|403"
        else
            warn "curl not available, skipping web accessibility test"
            return 0
        fi
    elif [ "$ENVIRONMENT" = "production" ]; then
        # For production, we'd need the actual domain
        warn "Production web accessibility test requires domain configuration"
        return 0
    else
        warn "Web accessibility test not applicable for container environment"
        return 0
    fi
}

# Test production certificate setup with environment variables
test_production_cert_with_env() {
    if [ "$ENVIRONMENT" != "ddev" ]; then
        warn "Production certificate test only runs in development environment"
        return 0
    fi
    
    # Create temporary environment
    export SAML_PRIVATE_KEY="LS0tLS1CRUdJTiBQUklWQVRFIEtFWS0tLS0t"  # dummy base64
    export SAML_CERTIFICATE="LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0t" # dummy base64
    
    # Test with a different certificate name to avoid conflicts
    ./scripts/manage-saml-certificates.sh prod localhost test-prod
    
    local result=$?
    
    # Clean up
    unset SAML_PRIVATE_KEY
    unset SAML_CERTIFICATE
    rm -f "$DRUPAL_ROOT/simplesamlphp/cert/test-prod.*"
    
    return $result
}

# Generate test report
generate_report() {
    echo
    echo "=================================================="
    echo "           SimpleSAMLphp Test Report"
    echo "=================================================="
    echo "Environment: $ENVIRONMENT"
    echo "Drupal Root: $DRUPAL_ROOT"
    echo "Tests Passed: $TESTS_PASSED"
    echo "Tests Failed: $TESTS_FAILED"
    echo "=================================================="
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log "🎉 All tests passed! SimpleSAMLphp setup is ready."
        return 0
    else
        error "❌ Some tests failed. Please check the issues above."
        return 1
    fi
}

# Main test execution
main() {
    echo "🧪 SimpleSAMLphp Setup Testing Starting..."
    echo
    
    detect_environment
    
    run_test "Certificate files exist" "test_certificates_exist"
    run_test "Certificate permissions" "test_certificate_permissions"
    run_test "Certificate validity" "test_certificate_validity"
    run_test "Configuration files exist" "test_config_files_exist"
    run_test "Web interface files exist" "test_web_interface_files"
    run_test "PHP syntax validation" "test_php_syntax"
    run_test "SimpleSAMLphp autoloader" "test_simplesamlphp_autoloader"
    run_test "Directory permissions" "test_directory_permissions"
    run_test "Web accessibility" "test_web_accessibility"
    run_test "Production certificate with env vars" "test_production_cert_with_env"
    
    generate_report
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
