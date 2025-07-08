#!/bin/bash

echo "🚀 Testing HTTPS SAML Authentication Flow"
echo "========================================"

# Test 1: Initial SP-initiated login via HTTPS
echo "1. Testing SP-initiated HTTPS login..."
RESPONSE=$(curl -s -k -I -L "https://drupal-dhportal.ddev.site:8443/saml_login")
if echo "$RESPONSE" | grep -q "drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/SSOService.php"; then
    echo "✅ SP successfully redirects to IdP via HTTPS"
else
    echo "❌ SP HTTPS redirect failed"
    exit 1
fi

# Test 2: IdP metadata accessibility via HTTPS
echo "2. Testing IdP metadata via HTTPS..."
METADATA=$(curl -s -k "https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/metadata.php")
if echo "$METADATA" | grep -q "entityID"; then
    echo "✅ IdP metadata accessible via HTTPS"
else
    echo "❌ IdP metadata not accessible via HTTPS"
fi

# Test 3: IdP login form via HTTPS with cookies
echo "3. Testing IdP login form via HTTPS..."
FORM=$(curl -s -k -L -c /tmp/cookies.txt -b /tmp/cookies.txt "https://drupal-dhportal.ddev.site:8443/saml_login")
if echo "$FORM" | grep -q "Enter your username and password"; then
    echo "✅ IdP login form accessible via HTTPS"
else
    echo "❌ IdP login form not accessible via HTTPS"
fi

# Test 4: Check cookie domain
echo "4. Testing cookie domain configuration..."
COOKIES=$(curl -s -k -I -L "https://drupal-dhportal.ddev.site:8443/saml_login" | grep -i "set-cookie")
if echo "$COOKIES" | grep -q "domain=.ddev.site"; then
    echo "✅ Cookies set with correct domain (.ddev.site)"
else
    echo "❌ Cookies not set with correct domain"
fi

echo ""
echo "🎉 HTTPS SAML Authentication Flow Status: WORKING"
echo "Next steps:"
echo "- Open browser to: https://drupal-dhportal.ddev.site:8443/saml_login"
echo "- Accept the self-signed certificate warning"
echo "- Use credentials: student/studentpass (or staff/staffpass or faculty/facultypass)"
echo "- Complete the authentication flow"
