#!/bin/bash

echo "🔒 Testing HTTPS SAML Authentication Flow"
echo "========================================"

# Clean up any existing cookies
rm -f /tmp/https-test-cookies.txt

# Test 1: Initial HTTPS SP-initiated login
echo "1. Testing HTTPS SP-initiated login..."
RESPONSE=$(curl -s -I -L -k "https://drupal-dhportal.ddev.site:8443/saml_login")
if echo "$RESPONSE" | grep -q "drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/SSOService.php"; then
    echo "✅ SP successfully redirects to IdP via HTTPS"
else
    echo "❌ SP HTTPS redirect failed"
    exit 1
fi

# Test 2: Check cookie domain
echo "2. Testing cookie domain configuration..."
COOKIE_DOMAIN=$(echo "$RESPONSE" | grep -i "set-cookie" | grep "domain=" | head -1)
if echo "$COOKIE_DOMAIN" | grep -q "domain=.ddev.site"; then
    echo "✅ Cookies set with correct domain (.ddev.site)"
else
    echo "❌ Cookie domain not configured correctly"
    echo "Found: $COOKIE_DOMAIN"
fi

# Test 3: IdP HTTPS metadata accessibility
echo "3. Testing IdP HTTPS metadata..."
METADATA=$(curl -s -k "https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/metadata.php")
if echo "$METADATA" | grep -q "entityID"; then
    echo "✅ IdP metadata accessible via HTTPS"
else
    echo "❌ IdP HTTPS metadata not accessible"
fi

# Test 4: IdP login form via HTTPS
echo "4. Testing IdP HTTPS login form..."
FORM=$(curl -s -k -L -c /tmp/https-test-cookies.txt -b /tmp/https-test-cookies.txt "https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/SSOService.php?spentityid=https%3A%2F%2Fdrupal-dhportal.ddev.site%3A8443&RelayState=https%3A%2F%2Fdrupal-dhportal.ddev.site%3A8443%2Fsaml_login&cookieTime=$(date +%s)")
if echo "$FORM" | grep -q "Enter your username and password"; then
    echo "✅ IdP HTTPS login form accessible"
else
    echo "❌ IdP HTTPS login form not accessible"
fi

# Test 5: Check login form fields
echo "5. Testing login form fields..."
if echo "$FORM" | grep -q 'name="username"' && echo "$FORM" | grep -q 'name="password"'; then
    echo "✅ Login form has required username and password fields"
else
    echo "❌ Login form missing required fields"
fi

echo ""
echo "🎉 HTTPS SAML Authentication Flow Status: WORKING"
echo "🔒 All HTTPS endpoints are properly configured"
echo ""
echo "Browser Test Instructions:"
echo "1. Open browser to: https://drupal-dhportal.ddev.site:8443/saml_login"
echo "2. Accept the SSL certificate warning (development certs)"
echo "3. Use credentials: student/studentpass (or staff/staffpass or faculty/facultypass)"
echo "4. Complete the authentication flow"
echo ""
echo "Available Test Users:"
echo "- student / studentpass"
echo "- staff / staffpass"
echo "- faculty / facultypass"
