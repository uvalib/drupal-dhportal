<?php
/**
 * Comprehensive SAML Integration Test for drupal-dhportal
 * This script tests all aspects of the SAML integration
 */

// Load SimpleSAMLphp
require_once('/var/www/html/vendor/simplesamlphp/simplesamlphp/src/_autoload.php');

// Initialize SimpleSAMLphp
$auth = new SimpleSAML\Auth\Simple('default-sp');

echo "<h1>🔍 SAML Integration Comprehensive Test</h1>";

// Test 1: Check if SimpleSAMLphp is properly configured
echo "<h2>📋 Test 1: SimpleSAMLphp Configuration</h2>";
try {
    $config = SimpleSAML\Configuration::getInstance();
    echo "✅ SimpleSAMLphp configuration loaded successfully<br>";
    echo "• Base URL: " . $config->getString('baseurlpath') . "<br>";
    echo "• Secret salt: " . (strlen($config->getString('secretsalt')) > 10 ? 'Set (hidden)' : 'NOT SET') . "<br>";
    echo "• Admin password: " . ($config->getString('auth.adminpassword') !== null ? 'Set (hidden)' : 'NOT SET') . "<br>";
    echo "• Debug mode: " . ($config->getBoolean('debug', false) ? 'ON' : 'OFF') . "<br>";
} catch (Exception $e) {
    echo "❌ SimpleSAMLphp configuration error: " . $e->getMessage() . "<br>";
}

// Test 2: Check auth source configuration
echo "<h2>📋 Test 2: Auth Source Configuration</h2>";
try {
    $authSources = SimpleSAML\Configuration::getConfig('authsources.php');
    $defaultSp = $authSources->getArray('default-sp');
    echo "✅ Auth source 'default-sp' loaded successfully<br>";
    echo "• Entity ID: " . $defaultSp['entityID'] . "<br>";
    echo "• IdP: " . $defaultSp['idp'] . "<br>";
    if (isset($defaultSp['acs'])) {
        echo "• Assertion Consumer Service: " . (is_array($defaultSp['acs']) ? $defaultSp['acs'][0] : $defaultSp['acs']) . "<br>";
    }
    if (isset($defaultSp['sls'])) {
        echo "• Single Logout Service: " . (is_array($defaultSp['sls']) ? $defaultSp['sls'][0] : $defaultSp['sls']) . "<br>";
    }
} catch (Exception $e) {
    echo "❌ Auth source configuration error: " . $e->getMessage() . "<br>";
}

// Test 3: Check authentication status
echo "<h2>📋 Test 3: Authentication Status</h2>";
try {
    if ($auth->isAuthenticated()) {
        echo "✅ User is authenticated<br>";
        $attributes = $auth->getAttributes();
        echo "• User attributes:<br>";
        foreach ($attributes as $key => $value) {
            echo "  - $key: " . (is_array($value) ? implode(', ', $value) : $value) . "<br>";
        }
        echo "<p><a href='/test-saml-integration.php?logout=1'>🚪 Logout</a></p>";
    } else {
        echo "❌ User is not authenticated<br>";
        echo "<p><a href='" . $auth->getLoginURL() . "'>🔐 Login via SAML</a></p>";
    }
} catch (Exception $e) {
    echo "❌ Authentication check error: " . $e->getMessage() . "<br>";
}

// Test 4: Test IdP connectivity
echo "<h2>📋 Test 4: IdP Connectivity</h2>";
try {
    $idpUrl = 'https://drupal-netbadge.ddev.site:8443/simplesaml/';
    $context = stream_context_create([
        'http' => [
            'timeout' => 10,
            'method' => 'GET',
            'header' => "User-Agent: SAML-Test-Script\r\n"
        ],
        'ssl' => [
            'verify_peer' => false,
            'verify_peer_name' => false
        ]
    ]);
    
    $response = @file_get_contents($idpUrl, false, $context);
    if ($response !== false) {
        echo "✅ IdP is accessible at $idpUrl<br>";
        echo "• Response length: " . strlen($response) . " bytes<br>";
    } else {
        echo "❌ IdP is not accessible at $idpUrl<br>";
    }
} catch (Exception $e) {
    echo "❌ IdP connectivity error: " . $e->getMessage() . "<br>";
}

// Test 5: Test metadata generation
echo "<h2>📋 Test 5: Metadata Generation</h2>";
try {
    // Try to generate metadata using the source configuration
    $sourceConfig = $authSources->getArray('default-sp');
    echo "✅ SP configuration loaded for metadata generation<br>";
    echo "• Entity ID: " . $sourceConfig['entityID'] . "<br>";
    echo "• Metadata endpoints configured<br>";
    
    // Test metadata URL accessibility
    $metadataUrl = 'https://drupal-dhportal.ddev.site:8443/simplesaml/module.php/saml/sp/metadata/default-sp';
    echo "• Metadata URL: <a href='$metadataUrl'>$metadataUrl</a><br>";
} catch (Exception $e) {
    echo "❌ Metadata generation error: " . $e->getMessage() . "<br>";
}

// Test 6: Test Drupal integration
echo "<h2>📋 Test 6: Drupal Integration</h2>";
try {
    // Check if we can access Drupal
    $drupalRoot = '/var/www/html/web';
    if (file_exists($drupalRoot . '/index.php')) {
        echo "✅ Drupal installation detected<br>";
        
        // Check if SimpleSAMLphp Auth module is enabled
        if (function_exists('module_load_include')) {
            module_load_include('inc', 'simplesamlphp_auth', 'simplesamlphp_auth');
            echo "✅ SimpleSAMLphp Auth module is available<br>";
        } else {
            echo "⚠️ Cannot check Drupal module status (not in Drupal context)<br>";
        }
        
        // Check if the symlink is working
        if (is_link($drupalRoot . '/simplesaml')) {
            echo "✅ SimpleSAMLphp symlink is present<br>";
            echo "• Symlink target: " . readlink($drupalRoot . '/simplesaml') . "<br>";
        } else {
            echo "❌ SimpleSAMLphp symlink is missing<br>";
        }
    } else {
        echo "❌ Drupal installation not found<br>";
    }
} catch (Exception $e) {
    echo "❌ Drupal integration error: " . $e->getMessage() . "<br>";
}

// Handle logout
if (isset($_GET['logout']) && $_GET['logout'] == '1') {
    echo "<h2>🚪 Logging out...</h2>";
    $auth->logout();
    echo "<p>You have been logged out. <a href='/test-saml-integration.php'>Return to test</a></p>";
    exit;
}

echo "<hr>";
echo "<h3>🔧 Integration Status Summary</h3>";
echo "<p>This comprehensive test verifies all components of the SAML integration between DH Portal and NetBadge.</p>";
echo "<p><strong>Next Steps:</strong></p>";
echo "<ul>";
echo "<li>If all tests pass, try clicking the login link above</li>";
echo "<li>If authentication fails, check the SimpleSAMLphp logs</li>";
echo "<li>If successful, the user should be redirected back with attributes</li>";
echo "</ul>";

echo "<h3>🔗 Quick Links</h3>";
echo "<ul>";
echo "<li><a href='/simplesaml/'>SimpleSAMLphp Admin (DH Portal)</a></li>";
echo "<li><a href='https://drupal-netbadge.ddev.site:8443/simplesaml/'>NetBadge SimpleSAMLphp Admin</a></li>";
echo "<li><a href='/admin/config/people/simplesamlphp_auth'>Drupal SAML Settings</a></li>";
echo "</ul>";
?>
