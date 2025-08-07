#!/bin/bash

# SimpleSAMLphp Certificate Health Check
# Monitors certificate expiration and validates certificate health

set -e

CERT_DIR="/opt/drupal/simplesamlphp/cert"
WARNING_DAYS="${WARNING_DAYS:-30}"
CRITICAL_DAYS="${CRITICAL_DAYS:-7}"

echo "🔍 SimpleSAML Certificate Health Check"

function check_certificate_health() {
    local cert_file="${1}"
    local name="${2}"
    
    if [[ ! -f "${cert_file}" ]]; then
        echo "❌ ${name}: Certificate file not found: ${cert_file}"
        return 1
    fi
    
    # Validate certificate format
    if ! openssl x509 -in "${cert_file}" -noout 2>/dev/null; then
        echo "❌ ${name}: Invalid certificate format"
        return 1
    fi
    
    # Get certificate information
    local subject=$(openssl x509 -in "${cert_file}" -subject -noout | sed 's/subject=//')
    local issuer=$(openssl x509 -in "${cert_file}" -issuer -noout | sed 's/issuer=//')
    local start_date=$(openssl x509 -in "${cert_file}" -startdate -noout | cut -d= -f2)
    local end_date=$(openssl x509 -in "${cert_file}" -enddate -noout | cut -d= -f2)
    
    # Calculate days until expiration
    local end_epoch=$(date -d "${end_date}" +%s 2>/dev/null || date -j -f "%b %d %H:%M:%S %Y %Z" "${end_date}" +%s 2>/dev/null)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (end_epoch - current_epoch) / 86400 ))
    
    echo "📋 ${name} Certificate Information:"
    echo "   Subject: ${subject}"
    echo "   Issuer: ${issuer}"
    echo "   Valid From: ${start_date}"
    echo "   Valid Until: ${end_date}"
    echo "   Days Until Expiry: ${days_until_expiry}"
    
    # Determine status
    if ((days_until_expiry < 0)); then
        echo "💥 ${name}: EXPIRED ${days_until_expiry#-} days ago!"
        return 2
    elif ((days_until_expiry <= CRITICAL_DAYS)); then
        echo "🚨 ${name}: CRITICAL - Expires in ${days_until_expiry} days"
        return 2
    elif ((days_until_expiry <= WARNING_DAYS)); then
        echo "⚠️  ${name}: WARNING - Expires in ${days_until_expiry} days"
        return 1
    else
        echo "✅ ${name}: OK - ${days_until_expiry} days until expiry"
        return 0
    fi
}

function verify_key_certificate_match() {
    local key_file="${CERT_DIR}/sp.key"
    local cert_file="${CERT_DIR}/sp.crt"
    
    if [[ ! -f "${key_file}" ]] || [[ ! -f "${cert_file}" ]]; then
        echo "⚠️  Cannot verify key/certificate match - files missing"
        return 1
    fi
    
    local key_hash=$(openssl rsa -in "${key_file}" -pubout 2>/dev/null | openssl md5 | cut -d' ' -f2)
    local cert_hash=$(openssl x509 -in "${cert_file}" -pubkey -noout 2>/dev/null | openssl md5 | cut -d' ' -f2)
    
    if [[ "${key_hash}" == "${cert_hash}" ]]; then
        echo "✅ Private key and certificate match"
        return 0
    else
        echo "❌ Private key and certificate do not match!"
        return 1
    fi
}

function main() {
    local exit_code=0
    
    echo "Certificate Directory: ${CERT_DIR}"
    echo "Warning Threshold: ${WARNING_DAYS} days"
    echo "Critical Threshold: ${CRITICAL_DAYS} days"
    echo ""
    
    # Check main SAML certificates
    check_certificate_health "${CERT_DIR}/sp.crt" "SAML Service Provider"
    local sp_status=$?
    if ((sp_status > exit_code)); then
        exit_code=$sp_status
    fi
    
    echo ""
    
    # Check legacy certificates if they exist
    if [[ -f "${CERT_DIR}/server.crt" ]]; then
        check_certificate_health "${CERT_DIR}/server.crt" "Legacy Server"
        local legacy_status=$?
        if ((legacy_status > exit_code)); then
            exit_code=$legacy_status
        fi
        echo ""
    fi
    
    # Verify key/certificate match
    verify_key_certificate_match
    local match_status=$?
    if ((match_status > exit_code)); then
        exit_code=$match_status
    fi
    
    echo ""
    echo "=== Health Check Summary ==="
    case $exit_code in
        0)
            echo "✅ All certificates are healthy"
            ;;
        1)
            echo "⚠️  Warnings detected - review certificate status"
            ;;
        2)
            echo "🚨 Critical issues detected - immediate action required"
            ;;
    esac
    
    return $exit_code
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
