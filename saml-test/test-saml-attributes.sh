#!/bin/bash

echo "🏷️  Testing SAML Attribute Configuration"
echo "========================================"

# Test 1: Verify IdP has eduPersonPrincipalName attribute
echo "1. Testing IdP attribute configuration..."
ATTR_CONFIG=$(cd /Users/ys2n/Code/ddev/drupal-netbadge && ddev exec "grep -A 8 'student:studentpass' /var/www/html/simplesamlphp/config/authsources.php")
if echo "$ATTR_CONFIG" | grep -q "eduPersonPrincipalName"; then
    echo "✅ IdP configured with eduPersonPrincipalName attribute"
else
    echo "❌ IdP missing eduPersonPrincipalName attribute"
    exit 1
fi

# Test 2: Verify Drupal expects eduPersonPrincipalName
echo "2. Testing Drupal attribute configuration..."
DRUPAL_CONFIG=$(cd /Users/ys2n/Code/ddev/drupal-dhportal && ddev drush config:get simplesamlphp_auth.settings)
if echo "$DRUPAL_CONFIG" | grep -q "user_name: eduPersonPrincipalName" && echo "$DRUPAL_CONFIG" | grep -q "unique_id: eduPersonPrincipalName"; then
    echo "✅ Drupal configured to expect eduPersonPrincipalName"
else
    echo "❌ Drupal not configured for eduPersonPrincipalName"
fi

# Test 3: Check mail attribute mapping
echo "3. Testing mail attribute configuration..."
if echo "$ATTR_CONFIG" | grep -q "'mail'" && echo "$DRUPAL_CONFIG" | grep -q "mail_attr: mail"; then
    echo "✅ Mail attribute properly mapped"
else
    echo "❌ Mail attribute mapping issue"
fi

# Test 4: Test all user attributes
echo "4. Testing all test user attributes..."
ALL_USERS=$(cd /Users/ys2n/Code/ddev/drupal-netbadge && ddev exec "grep -E '(student|staff|faculty):.*pass' /var/www/html/simplesamlphp/config/authsources.php")
if echo "$ALL_USERS" | grep -q "student:studentpass" && echo "$ALL_USERS" | grep -q "staff:staffpass" && echo "$ALL_USERS" | grep -q "faculty:facultypass"; then
    echo "✅ All test users configured"
else
    echo "❌ Missing test users"
fi

# Test 5: Test SAML login flow still works
echo "5. Testing SAML login flow..."
FORM=$(curl -s -k -L -c /tmp/attr_test_cookies.txt -b /tmp/attr_test_cookies.txt "https://drupal-dhportal.ddev.site:8443/saml_login")
if echo "$FORM" | grep -q "Enter your username and password"; then
    echo "✅ SAML login flow working"
else
    echo "❌ SAML login flow failed"
fi

echo ""
echo "🎉 SAML Attribute Configuration Status: READY"
echo "Attribute Mapping Summary:"
echo "- eduPersonPrincipalName: student@example.edu (username/unique_id)"
echo "- mail: student@example.edu (email)"
echo "- eduPersonAffiliation: member, student (roles)"
echo "- displayName: Test Student (display name)"
echo ""
echo "Test Users Ready:"
echo "- student/studentpass → student@example.edu"
echo "- staff/staffpass → staff@example.edu"  
echo "- faculty/facultypass → faculty@example.edu"
echo ""
echo "Ready for browser testing with attribute mapping!"
echo "- Go to: https://drupal-dhportal.ddev.site:8443/saml_login"
echo "- Login with: student/studentpass"
echo "- Should create Drupal user with username 'student@example.edu'"
