#!/bin/bash

# SAML Certificate Management Script
# This script generates and manages SAML certificates for different environments
# Supports both development (self-signed) and production certificates

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    local install_commands=()
    
    # Check for openssl (required for certificate generation)
    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
        case "$(uname -s)" in
            Linux*)
                if command -v apt-get &> /dev/null; then
                    install_commands+=("sudo apt-get update && sudo apt-get install -y openssl")
                elif command -v yum &> /dev/null; then
                    install_commands+=("sudo yum install -y openssl")
                elif command -v dnf &> /dev/null; then
                    install_commands+=("sudo dnf install -y openssl")
                elif command -v apk &> /dev/null; then
                    install_commands+=("sudo apk add openssl")
                else
                    install_commands+=("Install openssl package using your system's package manager")
                fi
                ;;
            Darwin*)
                if command -v brew &> /dev/null; then
                    install_commands+=("brew install openssl")
                else
                    install_commands+=("Install Homebrew, then run: brew install openssl")
                fi
                ;;
            *)
                install_commands+=("Install openssl package")
                ;;
        esac
    fi
    
    # Check for jq (required for AWS Secrets Manager JSON parsing)
    if [ -n "$AWS_SECRET_NAME" ]; then
        if ! command -v jq &> /dev/null; then
            missing_deps+=("jq")
            case "$(uname -s)" in
                Linux*)
                    if command -v apt-get &> /dev/null; then
                        install_commands+=("sudo apt-get update && sudo apt-get install -y jq")
                    elif command -v yum &> /dev/null; then
                        install_commands+=("sudo yum install -y jq")
                    elif command -v dnf &> /dev/null; then
                        install_commands+=("sudo dnf install -y jq")
                    elif command -v apk &> /dev/null; then
                        install_commands+=("sudo apk add jq")
                    else
                        install_commands+=("Install jq package using your system's package manager")
                    fi
                    ;;
                Darwin*)
                    if command -v brew &> /dev/null; then
                        install_commands+=("brew install jq")
                    else
                        install_commands+=("Install Homebrew, then run: brew install jq")
                    fi
                    ;;
                *)
                    install_commands+=("Install jq package")
                    ;;
            esac
        fi
        
        # Check for aws CLI (optional, but needed for AWS integration)
        if ! command -v aws &> /dev/null; then
            missing_deps+=("aws")
            install_commands+=("Install AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html")
        fi
    fi
    
    # Report missing dependencies
    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        echo ""
        echo "🔧 Installation instructions:"
        for i in "${!missing_deps[@]}"; do
            echo "   ${missing_deps[$i]}: ${install_commands[$i]}"
        done
        echo ""
        echo "💡 After installing dependencies, re-run this script."
        return 1
    fi
    
    return 0
}

# Detect environment and set variables
detect_environment() {
    DRUPAL_ROOT=""
    if [ -f "/opt/drupal/web/index.php" ]; then
        DRUPAL_ROOT="/opt/drupal"
        ENVIRONMENT="server"
        info "Detected server environment: /opt/drupal"
    elif [ -f "/var/www/html/web/index.php" ]; then
        DRUPAL_ROOT="/var/www/html"
        ENVIRONMENT="container"
        info "Detected container environment: /var/www/html"
    else
        # Not in container, assume we're in project directory
        if [ -f "web/index.php" ]; then
            DRUPAL_ROOT="$(pwd)"
            ENVIRONMENT="ddev"
            info "Detected DDEV/local environment: $(pwd)"
        else
            error "Not in a recognized Drupal environment"
            exit 1
        fi
    fi

    CERT_DIR="$DRUPAL_ROOT/simplesamlphp/cert"
    CONFIG_DIR="$DRUPAL_ROOT/simplesamlphp/config"
}

# Create certificate directory if it doesn't exist
setup_cert_directory() {
    if [ ! -d "$CERT_DIR" ]; then
        log "Creating certificate directory: $CERT_DIR"
        mkdir -p "$CERT_DIR"
    fi
}

# Generate self-signed certificate for development
generate_dev_certificate() {
    local domain="$1"
    local cert_name="$2"
    
    log "Generating self-signed certificate for development environment"
    log "Domain: $domain"
    log "Certificate name: $cert_name"
    
    # Generate private key
    openssl genrsa -out "$CERT_DIR/${cert_name}.key" 2048
    
    # Generate certificate signing request
    openssl req -new -key "$CERT_DIR/${cert_name}.key" -out "$CERT_DIR/${cert_name}.csr" -subj "/C=US/ST=Virginia/L=Charlottesville/O=University of Virginia/OU=Digital Humanities Portal/CN=${domain}"
    
    # Generate self-signed certificate
    openssl x509 -req -days 365 -in "$CERT_DIR/${cert_name}.csr" -signkey "$CERT_DIR/${cert_name}.key" -out "$CERT_DIR/${cert_name}.crt"
    
    # Create PEM file (private key + certificate)
    cat "$CERT_DIR/${cert_name}.key" "$CERT_DIR/${cert_name}.crt" > "$CERT_DIR/${cert_name}.pem"
    
    # Set appropriate permissions
    chmod 600 "$CERT_DIR/${cert_name}.key" "$CERT_DIR/${cert_name}.pem"
    chmod 644 "$CERT_DIR/${cert_name}.crt" "$CERT_DIR/${cert_name}.csr"
    
    # Clean up CSR
    rm "$CERT_DIR/${cert_name}.csr"
    
    log "✅ Generated certificate files:"
    log "   - Private Key: $CERT_DIR/${cert_name}.key"
    log "   - Certificate: $CERT_DIR/${cert_name}.crt"
    log "   - Combined PEM: $CERT_DIR/${cert_name}.pem"
}

# Setup production certificate from environment variables or files
setup_production_certificate() {
    local cert_name="$1"
    
    log "Setting up production certificate: $cert_name"
    
    # Check for certificate in environment variables
    if [ -n "$SAML_PRIVATE_KEY" ] && [ -n "$SAML_CERTIFICATE" ]; then
        log "Found certificate in environment variables"
        
        # Decode base64 if needed
        if echo "$SAML_PRIVATE_KEY" | base64 -d >/dev/null 2>&1; then
            echo "$SAML_PRIVATE_KEY" | base64 -d > "$CERT_DIR/${cert_name}.key"
        else
            echo "$SAML_PRIVATE_KEY" > "$CERT_DIR/${cert_name}.key"
        fi
        
        if echo "$SAML_CERTIFICATE" | base64 -d >/dev/null 2>&1; then
            echo "$SAML_CERTIFICATE" | base64 -d > "$CERT_DIR/${cert_name}.crt"
        else
            echo "$SAML_CERTIFICATE" > "$CERT_DIR/${cert_name}.crt"
        fi
        
        # Create PEM file
        cat "$CERT_DIR/${cert_name}.key" "$CERT_DIR/${cert_name}.crt" > "$CERT_DIR/${cert_name}.pem"
        
        # Set permissions
        chmod 600 "$CERT_DIR/${cert_name}.key" "$CERT_DIR/${cert_name}.pem"
        chmod 644 "$CERT_DIR/${cert_name}.crt"
        
        log "✅ Production certificate installed from environment variables"
        
    # Check for certificate files in mounted volume
    elif [ -f "/secrets/${cert_name}.key" ] && [ -f "/secrets/${cert_name}.crt" ]; then
        log "Found certificate in mounted secrets volume"
        
        cp "/secrets/${cert_name}.key" "$CERT_DIR/${cert_name}.key"
        cp "/secrets/${cert_name}.crt" "$CERT_DIR/${cert_name}.crt"
        
        # Create PEM file
        cat "$CERT_DIR/${cert_name}.key" "$CERT_DIR/${cert_name}.crt" > "$CERT_DIR/${cert_name}.pem"
        
        # Set permissions
        chmod 600 "$CERT_DIR/${cert_name}.key" "$CERT_DIR/${cert_name}.pem"
        chmod 644 "$CERT_DIR/${cert_name}.crt"
        
        log "✅ Production certificate copied from secrets volume"
        
    # Check AWS Secrets Manager
    elif command -v aws >/dev/null 2>&1 && [ -n "$AWS_SECRET_NAME" ]; then
        log "Attempting to retrieve certificate from AWS Secrets Manager"
        
        # Retrieve secret
        SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$AWS_SECRET_NAME" --query SecretString --output text)
        
        if [ $? -eq 0 ]; then
            # Extract key and certificate from JSON
            echo "$SECRET_JSON" | jq -r '.private_key' > "$CERT_DIR/${cert_name}.key"
            echo "$SECRET_JSON" | jq -r '.certificate' > "$CERT_DIR/${cert_name}.crt"
            
            # Create PEM file
            cat "$CERT_DIR/${cert_name}.key" "$CERT_DIR/${cert_name}.crt" > "$CERT_DIR/${cert_name}.pem"
            
            # Set permissions
            chmod 600 "$CERT_DIR/${cert_name}.key" "$CERT_DIR/${cert_name}.pem"
            chmod 644 "$CERT_DIR/${cert_name}.crt"
            
            log "✅ Production certificate retrieved from AWS Secrets Manager"
        else
            error "Failed to retrieve certificate from AWS Secrets Manager"
            return 1
        fi
        
    else
        warn "No production certificate source found. Falling back to self-signed certificate."
        return 1
    fi
}

# Display certificate information
show_certificate_info() {
    local cert_file="$1"
    
    if [ -f "$cert_file" ]; then
        log "Certificate information for: $cert_file"
        openssl x509 -in "$cert_file" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After)"
        echo
    fi
}

# Main certificate setup function
setup_certificates() {
    local mode="$1"
    local domain="$2"
    local cert_name="${3:-server}"
    
    detect_environment
    
    # Check dependencies before proceeding
    info "Checking required dependencies..."
    if ! check_dependencies; then
        exit 1
    fi
    info "✅ All dependencies are available"
    
    setup_cert_directory
    
    case "$mode" in
        "dev"|"development")
            if [ -z "$domain" ]; then
                case "$ENVIRONMENT" in
                    "ddev")
                        domain="drupal-dhportal.ddev.site"
                        ;;
                    "container")
                        domain="localhost"
                        ;;
                    "server")
                        domain="${HOSTNAME:-localhost}"
                        ;;
                esac
            fi
            
            generate_dev_certificate "$domain" "$cert_name"
            ;;
            
        "prod"|"production")
            if ! setup_production_certificate "$cert_name"; then
                warn "Production certificate setup failed, generating temporary self-signed certificate"
                domain="${domain:-${HOSTNAME:-localhost}}"
                generate_dev_certificate "$domain" "$cert_name"
            fi
            ;;
            
        "info")
            if [ -f "$CERT_DIR/${cert_name}.crt" ]; then
                show_certificate_info "$CERT_DIR/${cert_name}.crt"
            else
                error "Certificate not found: $CERT_DIR/${cert_name}.crt"
            fi
            ;;
            
        *)
            error "Invalid mode: $mode"
            echo "Usage: $0 {dev|prod|info} [domain] [cert_name]"
            echo "Examples:"
            echo "  $0 dev drupal-dhportal.ddev.site"
            echo "  $0 prod production.university.edu"
            echo "  $0 info server"
            exit 1
            ;;
    esac
    
    # Show certificate info if generated/installed
    if [ "$mode" != "info" ] && [ -f "$CERT_DIR/${cert_name}.crt" ]; then
        show_certificate_info "$CERT_DIR/${cert_name}.crt"
    fi
}

# Check if script is being run directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # Script is being executed directly
    MODE="${1:-dev}"
    DOMAIN="$2"
    CERT_NAME="${3:-server}"
    
    log "🔐 SAML Certificate Management Starting..."
    setup_certificates "$MODE" "$DOMAIN" "$CERT_NAME"
    log "🎉 Certificate management completed!"
fi
