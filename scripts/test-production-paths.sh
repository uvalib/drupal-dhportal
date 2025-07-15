#!/bin/bash

# Test script to verify production container path configuration
# This script validates that the symlink from /opt/drupal/scripts to /opt/drupal/util/drupal-dhportal/scripts
# works correctly and that SAML setup scripts can find their templates.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
IMAGE_NAME="drupal-dhportal-path-test"
BUILD_TAG="test-$(date +%s)"

echo -e "${BLUE}🧪 Production Container Path Testing Script${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Function to print test results
print_result() {
    local test_name="$1"
    local result="$2"
    if [ "$result" = "PASS" ]; then
        echo -e "${GREEN}✅ $test_name: PASS${NC}"
    else
        echo -e "${RED}❌ $test_name: FAIL${NC}"
        exit 1
    fi
}

# Function to run docker command and capture output
run_docker_test() {
    local command="$1"
    docker run --rm "$IMAGE_NAME" bash -c "$command"
}

echo -e "${YELLOW}📦 Building production Docker image...${NC}"
if docker build -t "$IMAGE_NAME" -f package/Dockerfile . --build-arg BUILD_TAG="$BUILD_TAG" > /dev/null 2>&1; then
    print_result "Docker build" "PASS"
else
    print_result "Docker build" "FAIL"
fi

echo ""
echo -e "${YELLOW}🔗 Testing symlink creation...${NC}"

# Test 1: Check if symlink exists and points to correct location
SYMLINK_TEST=$(run_docker_test 'ls -la /opt/drupal/scripts | grep -q "scripts -> /opt/drupal/util/drupal-dhportal/scripts" && echo "PASS" || echo "FAIL"')
print_result "Symlink exists and points correctly" "$SYMLINK_TEST"

echo ""
echo -e "${YELLOW}📁 Testing directory accessibility...${NC}"

# Test 2: Check if SAML setup directory is accessible
SAML_DIR_TEST=$(run_docker_test 'test -d /opt/drupal/scripts/saml-setup && echo "PASS" || echo "FAIL"')
print_result "SAML setup directory accessible" "$SAML_DIR_TEST"

# Test 3: Check if templates directory is accessible
TEMPLATES_DIR_TEST=$(run_docker_test 'test -d /opt/drupal/scripts/saml-setup/templates && echo "PASS" || echo "FAIL"')
print_result "Templates directory accessible" "$TEMPLATES_DIR_TEST"

# Test 4: Check if all required template files exist
TEMPLATE_FILES_TEST=$(run_docker_test '
    files_exist=true
    for file in authsources.php.template config.php.template saml20-idp-remote.php.template; do
        if [ ! -f "/opt/drupal/scripts/saml-setup/templates/$file" ]; then
            files_exist=false
            break
        fi
    done
    if [ "$files_exist" = true ]; then
        echo "PASS"
    else
        echo "FAIL"
    fi
')
print_result "All template files exist" "$TEMPLATE_FILES_TEST"

echo ""
echo -e "${YELLOW}🔧 Testing DRUPAL_ROOT path resolution...${NC}"

# Test 5: Test DRUPAL_ROOT environment variable resolution
DRUPAL_ROOT_TEST=$(run_docker_test '
    export DRUPAL_ROOT="/opt/drupal"
    template_dir="${DRUPAL_ROOT}/scripts/saml-setup/templates"
    if [ -d "$template_dir" ]; then
        echo "PASS"
    else
        echo "FAIL"
    fi
')
print_result "DRUPAL_ROOT path resolution" "$DRUPAL_ROOT_TEST"

# Test 6: Test that scripts are executable
SCRIPT_EXECUTABLE_TEST=$(run_docker_test 'test -x /opt/drupal/scripts/saml-setup/setup-saml-integration-container.sh && echo "PASS" || echo "FAIL"')
print_result "SAML integration script is executable" "$SCRIPT_EXECUTABLE_TEST"

echo ""
echo -e "${YELLOW}📝 Testing script syntax...${NC}"

# Test 7: Verify script syntax is valid
SCRIPT_SYNTAX_TEST=$(run_docker_test 'bash -n /opt/drupal/scripts/saml-setup/setup-saml-integration-container.sh && echo "PASS" || echo "FAIL"')
print_result "SAML integration script syntax" "$SCRIPT_SYNTAX_TEST"

echo ""
echo -e "${YELLOW}🗂️ Testing template file content...${NC}"

# Test 8: Verify template files have content
TEMPLATE_CONTENT_TEST=$(run_docker_test '
    all_have_content=true
    for file in authsources.php.template config.php.template saml20-idp-remote.php.template; do
        if [ ! -s "/opt/drupal/scripts/saml-setup/templates/$file" ]; then
            all_have_content=false
            break
        fi
    done
    if [ "$all_have_content" = true ]; then
        echo "PASS"
    else
        echo "FAIL"
    fi
')
print_result "Template files have content" "$TEMPLATE_CONTENT_TEST"

echo ""
echo -e "${YELLOW}🔍 Testing path resolution from script perspective...${NC}"

# Test 9: Test the exact path resolution logic used in the script
PATH_RESOLUTION_TEST=$(run_docker_test '
    cd /opt/drupal
    DRUPAL_ROOT="/opt/drupal"
    template_dir="${DRUPAL_ROOT}/scripts/saml-setup/templates"
    
    # Count template files (should be 3)
    file_count=$(ls -1 "$template_dir"/*.template 2>/dev/null | wc -l)
    
    if [ "$file_count" -eq 3 ]; then
        echo "PASS"
    else
        echo "FAIL"
    fi
')
print_result "Script perspective path resolution" "$PATH_RESOLUTION_TEST"

echo ""
echo -e "${YELLOW}🧹 Cleaning up test image...${NC}"

# Cleanup: Remove test image
if docker rmi "$IMAGE_NAME" > /dev/null 2>&1; then
    print_result "Test image cleanup" "PASS"
else
    print_result "Test image cleanup" "FAIL"
fi

echo ""
echo -e "${GREEN}🎉 All tests passed! Production container path configuration is working correctly.${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  • Scripts are mounted at: ${YELLOW}/opt/drupal/util/drupal-dhportal/scripts${NC}"
echo -e "  • Scripts expect to find themselves at: ${YELLOW}/opt/drupal/scripts${NC}"
echo -e "  • Symlink successfully bridges the gap: ${YELLOW}/opt/drupal/scripts → /opt/drupal/util/drupal-dhportal/scripts${NC}"
echo -e "  • SAML templates are accessible at: ${YELLOW}\${DRUPAL_ROOT}/scripts/saml-setup/templates/${NC}"
echo -e "  • All SAML setup functionality should work correctly in production${NC}"
echo ""
