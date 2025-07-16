#!/bin/bash

# SAML Implementation Validation Script
# Validates the entire SAML certificate lifecycle implementation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔍 SAML Implementation Validation"
echo "================================="
echo "Project: $PROJECT_ROOT"
echo "Date: $(date)"
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    
    if [ "$result" = "pass" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $test_name - $message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    elif [ "$result" = "warn" ]; then
        echo -e "${YELLOW}⚠️  WARN${NC}: $test_name - $message"
    else
        echo -e "${RED}❌ FAIL${NC}: $test_name - $message"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "1. Directory Structure Validation"
echo "--------------------------------"

# Check for required directories
if [ -d "$PROJECT_ROOT/saml-config/certificates" ]; then
    test_result "Certificate Directory" "pass" "saml-config/certificates exists"
else
    test_result "Certificate Directory" "fail" "saml-config/certificates missing"
fi

if [ -d "$PROJECT_ROOT/saml-config/dev" ]; then
    test_result "Dev Certificate Directory" "pass" "saml-config/dev exists"
else
    test_result "Dev Certificate Directory" "fail" "saml-config/dev missing"
fi

if [ -d "$PROJECT_ROOT/scripts" ]; then
    test_result "Scripts Directory" "pass" "scripts directory exists"
else
    test_result "Scripts Directory" "fail" "scripts directory missing"
fi

echo
echo "2. Script Validation"
echo "--------------------"

# Check for required scripts
scripts=(
    "generate-saml-certificates.sh"
    "deploy-saml-certificates.sh"
    "manage-saml-certificates.sh"
    "manage-saml-certificates-enhanced.sh"
    "setup-dev-saml-ecosystem.sh"
)

for script in "${scripts[@]}"; do
    if [ -f "$PROJECT_ROOT/scripts/$script" ]; then
        if [ -x "$PROJECT_ROOT/scripts/$script" ]; then
            test_result "Script $script" "pass" "exists and is executable"
        else
            test_result "Script $script" "warn" "exists but not executable"
        fi
    else
        test_result "Script $script" "fail" "missing"
    fi
done

echo
echo "3. Documentation Validation"
echo "---------------------------"

# Check for required documentation
docs=(
    "SAML_CERTIFICATE_LIFECYCLE.md"
    "DEV_WORKFLOW.md"
    "SAML_REDIRECT_LOOP_TROUBLESHOOTING.md"
    "saml-config/README.md"
)

for doc in "${docs[@]}"; do
    if [ -f "$PROJECT_ROOT/$doc" ]; then
        test_result "Documentation $doc" "pass" "exists"
    else
        test_result "Documentation $doc" "fail" "missing"
    fi
done

echo
echo "4. .gitignore Validation"
echo "------------------------"

if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    # Check for critical entries
    critical_entries=(
        "*.key"
        "*.pem"
        "saml-config/dev/"
        "saml-config/temp/"
        "simplesamlphp/log/"
        "simplesamlphp/tmp/"
        "web/saml-debug.php"
        "web/test-*.php"
    )
    
    for entry in "${critical_entries[@]}"; do
        if grep -q "$entry" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
            test_result "Gitignore $entry" "pass" "excluded from git"
        else
            test_result "Gitignore $entry" "warn" "not explicitly excluded"
        fi
    done
else
    test_result "Gitignore File" "fail" ".gitignore missing"
fi

echo
echo "5. Certificate Generation Test"
echo "------------------------------"

# Test certificate generation in safe temp directory
TEST_DIR="/tmp/saml-cert-test-$$"
mkdir -p "$TEST_DIR"

if [ -f "$PROJECT_ROOT/scripts/generate-saml-certificates.sh" ]; then
    cd "$TEST_DIR"
    
    # Generate test certificates
    if "$PROJECT_ROOT/scripts/generate-saml-certificates.sh" --dev --output-dir "$TEST_DIR" --force 2>/dev/null; then
        if [ -f "$TEST_DIR/sp.crt" ] && [ -f "$TEST_DIR/sp.key" ]; then
            test_result "Certificate Generation" "pass" "can generate SP certificates"
        else
            test_result "Certificate Generation" "fail" "script ran but files missing"
        fi
    else
        test_result "Certificate Generation" "fail" "script execution failed"
    fi
    
    # Cleanup
    rm -rf "$TEST_DIR"
else
    test_result "Certificate Generation" "fail" "script missing"
fi

echo
echo "6. Docker Configuration Validation"
echo "----------------------------------"

# Check Dockerfile
if [ -f "$PROJECT_ROOT/package/Dockerfile" ]; then
    if grep -q "scripts" "$PROJECT_ROOT/package/Dockerfile" 2>/dev/null; then
        test_result "Dockerfile Scripts" "pass" "includes scripts directory"
    else
        test_result "Dockerfile Scripts" "warn" "may not copy scripts"
    fi
    
    if grep -q "saml" "$PROJECT_ROOT/package/Dockerfile" 2>/dev/null; then
        test_result "Dockerfile SAML" "pass" "includes SAML configuration"
    else
        test_result "Dockerfile SAML" "warn" "may not include SAML config"
    fi
else
    test_result "Dockerfile" "fail" "missing"
fi

echo
echo "7. SimpleSAMLphp Configuration"
echo "-----------------------------"

# Check SimpleSAMLphp directories
if [ -d "$PROJECT_ROOT/simplesamlphp" ]; then
    test_result "SimpleSAMLphp Directory" "pass" "exists"
    
    # Check for cert directory
    if [ -d "$PROJECT_ROOT/simplesamlphp/cert" ]; then
        test_result "SimpleSAMLphp Cert Dir" "pass" "cert directory exists"
        
        # Check if there are certificates
        if ls "$PROJECT_ROOT/simplesamlphp/cert"/*.crt 2>/dev/null | head -1 >/dev/null; then
            test_result "SimpleSAMLphp Certificates" "pass" "certificates present"
        else
            test_result "SimpleSAMLphp Certificates" "warn" "no certificates found"
        fi
    else
        test_result "SimpleSAMLphp Cert Dir" "fail" "cert directory missing"
    fi
else
    test_result "SimpleSAMLphp Directory" "fail" "missing"
fi

echo
echo "8. Git Repository Validation"
echo "----------------------------"

# Check git status for sensitive files
cd "$PROJECT_ROOT"

# Check if any .key files are tracked
if git ls-files | grep -q "\.key$" 2>/dev/null; then
    test_result "Git Key Files" "fail" "private key files are tracked"
else
    test_result "Git Key Files" "pass" "no private key files tracked"
fi

# Check if any .pem files are tracked (excluding public certs)
if git ls-files | grep -q "\.pem$" 2>/dev/null; then
    pem_files=$(git ls-files | grep "\.pem$")
    test_result "Git PEM Files" "warn" "PEM files tracked: $pem_files"
else
    test_result "Git PEM Files" "pass" "no PEM files tracked"
fi

echo
echo "9. Development Environment Test"
echo "------------------------------"

# Check if DDEV is available and configured
if command -v ddev >/dev/null 2>&1; then
    test_result "DDEV Available" "pass" "DDEV command found"
    
    # Check for DDEV config
    if [ -f "$PROJECT_ROOT/.ddev/config.yaml" ]; then
        test_result "DDEV Config" "pass" "DDEV configuration exists"
    else
        test_result "DDEV Config" "warn" "DDEV configuration not found"
    fi
else
    test_result "DDEV Available" "warn" "DDEV not available"
fi

echo
echo "10. Diagnostic Tools Validation"
echo "-------------------------------"

# Check diagnostic scripts
if [ -f "$PROJECT_ROOT/web/saml-debug.php" ]; then
    test_result "SAML Debug Tool" "pass" "diagnostic tool exists"
else
    test_result "SAML Debug Tool" "fail" "diagnostic tool missing"
fi

echo
echo "=============================="
echo "📊 VALIDATION SUMMARY"
echo "=============================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}🎉 All critical tests passed!${NC}"
    echo "Your SAML certificate lifecycle implementation is ready."
else
    echo -e "${RED}⚠️  Some tests failed.${NC}"
    echo "Please review the failed tests above and fix any issues."
    exit 1
fi

echo
echo "📋 NEXT STEPS:"
echo "1. Run setup-dev-saml-ecosystem.sh to set up development environment"
echo "2. Generate staging/production certificates using generate-saml-certificates.sh"
echo "3. Submit CSRs to UVA CA for signing"
echo "4. Deploy certificates using deploy-saml-certificates.sh"
echo "5. Test SAML authentication flow"
echo "6. Use saml-debug.php to diagnose any issues"
