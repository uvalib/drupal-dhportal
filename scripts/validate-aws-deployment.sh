#!/bin/bash

# Validate AWS Deployment Configuration
# This script helps validate that the SimpleSAMLphp configuration 
# is properly deployed in AWS environments

echo "🔍 AWS Deployment Validation Script"
echo "=================================="
echo

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate staging deployment
validate_staging() {
    echo "🏗️  Validating Staging Deployment..."
    echo "Environment: dhportal-dev.internal.lib.virginia.edu"
    
    # Check if curl is available
    if ! command_exists curl; then
        echo "❌ curl is not available. Please install curl to test endpoints."
        return 1
    fi
    
    STAGING_URL="https://dhportal-dev.internal.lib.virginia.edu"
    SIMPLESAML_URL="${STAGING_URL}/simplesaml"
    
    echo "  🌐 Testing main site accessibility..."
    if curl -s -I "${STAGING_URL}" | grep -q "200 OK"; then
        echo "  ✅ Main site is accessible"
    else
        echo "  ❌ Main site is not accessible or returning error"
    fi
    
    echo "  🔐 Testing SimpleSAMLphp endpoint..."
    if curl -s -I "${SIMPLESAML_URL}" | grep -q -E "(200 OK|302 Found)"; then
        echo "  ✅ SimpleSAMLphp endpoint is accessible"
    else
        echo "  ❌ SimpleSAMLphp endpoint is not accessible"
    fi
    
    echo "  📊 Testing metadata endpoint..."
    METADATA_URL="${SIMPLESAML_URL}/module.php/saml/sp/metadata.php/default-sp"
    if curl -s -I "${METADATA_URL}" | head -1 | grep -q -E "(200|302)"; then
        echo "  ✅ Metadata endpoint responds"
        echo "     URL: ${METADATA_URL}"
    else
        echo "  ❌ Metadata endpoint not accessible"
    fi
    
    echo
}

# Function to validate production deployment
validate_production() {
    echo "🏭 Validating Production Deployment..."
    echo "Environment: dh.library.virginia.edu"
    
    if ! command_exists curl; then
        echo "❌ curl is not available. Please install curl to test endpoints."
        return 1
    fi
    
    PROD_URL="https://dh.library.virginia.edu"
    SIMPLESAML_URL="${PROD_URL}/simplesaml"
    
    echo "  🌐 Testing main site accessibility..."
    if curl -s -I "${PROD_URL}" | grep -q "200 OK"; then
        echo "  ✅ Main site is accessible"
    else
        echo "  ❌ Main site is not accessible or returning error"
    fi
    
    echo "  🔐 Testing SimpleSAMLphp endpoint..."
    if curl -s -I "${SIMPLESAML_URL}" | grep -q -E "(200 OK|302 Found)"; then
        echo "  ✅ SimpleSAMLphp endpoint is accessible"
    else
        echo "  ❌ SimpleSAMLphp endpoint is not accessible"
    fi
    
    echo "  📊 Testing metadata endpoint..."
    METADATA_URL="${SIMPLESAML_URL}/module.php/saml/sp/metadata.php/default-sp"
    if curl -s -I "${METADATA_URL}" | head -1 | grep -q -E "(200|302)"; then
        echo "  ✅ Metadata endpoint responds"
        echo "     URL: ${METADATA_URL}"
    else
        echo "  ❌ Metadata endpoint not accessible"
    fi
    
    echo
}

# Function to check Ansible deployment readiness
check_ansible_readiness() {
    echo "🔧 Checking Ansible Deployment Readiness..."
    
    TERRAFORM_DIR="/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu"
    
    # Check staging
    echo "  📋 Staging environment:"
    if [[ -f "${TERRAFORM_DIR}/staging/ansible/templates/simplesamlphp/config.php.j2" ]]; then
        echo "    ✅ Config template ready"
    else
        echo "    ❌ Config template missing"
    fi
    
    if [[ -f "${TERRAFORM_DIR}/staging/ansible/templates/simplesamlphp/authsources.php.j2" ]]; then
        echo "    ✅ Authsources template ready"
    else
        echo "    ❌ Authsources template missing"
    fi
    
    if grep -q "SIMPLESAMLPHP_" "${TERRAFORM_DIR}/staging/ansible/container_1.env" 2>/dev/null; then
        echo "    ✅ Container environment variables configured"
    else
        echo "    ❌ Container environment variables missing"
    fi
    
    # Check production
    echo "  📋 Production environment:"
    if [[ -f "${TERRAFORM_DIR}/production.new/ansible/templates/simplesamlphp/config.php.j2" ]]; then
        echo "    ✅ Config template ready"
    else
        echo "    ❌ Config template missing"
    fi
    
    if [[ -f "${TERRAFORM_DIR}/production.new/ansible/templates/simplesamlphp/authsources.php.j2" ]]; then
        echo "    ✅ Authsources template ready"
    else
        echo "    ❌ Authsources template missing"
    fi
    
    if grep -q "SIMPLESAMLPHP_" "${TERRAFORM_DIR}/production.new/ansible/container_0.env" 2>/dev/null; then
        echo "    ✅ Container environment variables configured"
    else
        echo "    ❌ Container environment variables missing"
    fi
    
    echo
}

# Function to show deployment commands
show_deployment_commands() {
    echo "🚀 Deployment Commands"
    echo "====================="
    echo
    echo "To deploy to staging:"
    echo "  cd /Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/staging/ansible"
    echo "  ansible-playbook deploy_backend_1.yml"
    echo
    echo "To deploy to production:"
    echo "  cd /Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/production.new/ansible" 
    echo "  ansible-playbook deploy_backend.yml"
    echo
    echo "Note: Make sure you have the appropriate AWS credentials and"
    echo "      Ansible vault passwords configured before deployment."
    echo
}

# Function to show next steps
show_next_steps() {
    echo "📝 Next Steps"
    echo "============"
    echo
    echo "1. 🧪 Test DDEV SimpleSAMLphp interface:"
    echo "   https://drupal-dhportal.ddev.site:8443/simplesaml"
    echo
    echo "2. 🏗️  Deploy to staging and test:"
    echo "   - Deploy using Ansible playbook"
    echo "   - Test SimpleSAMLphp endpoint"
    echo "   - Verify environment-specific settings"
    echo "   - Test SAML authentication flow"
    echo
    echo "3. 🏭 Deploy to production once staging validated:"
    echo "   - Deploy using Ansible playbook"
    echo "   - Register SP metadata with NetBadge IDP"
    echo "   - Test production SAML authentication"
    echo
    echo "4. 📋 Register Service Provider with NetBadge:"
    echo "   - Submit staging metadata for testing"
    echo "   - Submit production metadata for go-live"
    echo "   - Configure attribute mappings"
    echo
}

# Main execution
main() {
    case "${1:-all}" in
        "staging")
            validate_staging
            ;;
        "production")
            validate_production
            ;;
        "ansible")
            check_ansible_readiness
            ;;
        "commands")
            show_deployment_commands
            ;;
        "next")
            show_next_steps
            ;;
        "all"|*)
            check_ansible_readiness
            validate_staging
            validate_production
            show_deployment_commands
            show_next_steps
            ;;
    esac
}

# Run main function with command line argument
main "$1"
