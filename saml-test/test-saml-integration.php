<?php
/**
 * Test SAML authentication from drupal-dhportal to drupal-netbadge
 */

// Include SimpleSAMLphp autoloader  
require_once '../vendor/simplesamlphp/simplesamlphp/src/_autoload.php';

use SimpleSAML\Auth\Simple;

echo '<h1>SAML Authentication Test - DH Portal to NetBadge</h1>';

try {
    // Initialize SimpleSAMLphp with the default-sp configuration
    $as = new Simple('default-sp');
    
    echo '<h2>SimpleSAMLphp Configuration Status:</h2>';
    echo '<ul>';
    echo '<li>Auth source: default-sp</li>';
    echo '<li>IdP: netbadge-idp (drupal-netbadge.ddev.site)</li>';
    echo '<li>SP Entity ID: https://drupal-dhportal.ddev.site:8443</li>';
    echo '</ul>';
    
    // Check if user is authenticated
    if (!$as->isAuthenticated()) {
        echo '<h2>🔒 You are NOT authenticated</h2>';
        echo '<p>Click the button below to authenticate via NetBadge (drupal-netbadge container):</p>';
        echo '<p><a href="' . $as->getLoginURL() . '" style="background: #0073aa; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">🚀 Login with NetBadge SAML</a></p>';
        
        echo '<hr>';
        echo '<h3>🔧 Technical Details:</h3>';
        echo '<ul>';
        echo '<li><strong>Login URL:</strong> ' . htmlspecialchars($as->getLoginURL()) . '</li>';
        echo '<li><strong>SP Metadata:</strong> <a href="/simplesaml/module.php/saml/sp/metadata.php/default-sp">View SP Metadata</a></li>';
        echo '<li><strong>Test IdP:</strong> <a href="https://drupal-netbadge.ddev.site:8443/simplesaml/">NetBadge SimpleSAMLphp Admin</a></li>';
        echo '</ul>';
        
    } else {
        echo '<h2>✅ Authentication SUCCESSFUL!</h2>';
        echo '<p>You have been successfully authenticated via NetBadge SAML.</p>';
        
        // Get user attributes
        $attributes = $as->getAttributes();
        
        echo '<h3>👤 User Information:</h3>';
        echo '<table border="1" cellpadding="5" cellspacing="0" style="border-collapse: collapse;">';
        echo '<tr><th>Attribute</th><th>Value(s)</th></tr>';
        
        foreach ($attributes as $name => $values) {
            echo '<tr>';
            echo '<td><strong>' . htmlspecialchars($name) . '</strong></td>';
            echo '<td>';
            if (is_array($values)) {
                echo htmlspecialchars(implode(', ', $values));
            } else {
                echo htmlspecialchars($values);
            }
            echo '</td>';
            echo '</tr>';
        }
        echo '</table>';
        
        echo '<hr>';
        echo '<h3>🔧 Session Details:</h3>';
        echo '<ul>';
        echo '<li><strong>Auth Source:</strong> ' . htmlspecialchars($as->getAuthSource()) . '</li>';
        echo '<li><strong>Logout URL:</strong> <a href="' . $as->getLogoutURL() . '">Logout from SAML</a></li>';
        echo '</ul>';
        
        echo '<p><a href="' . $as->getLogoutURL() . '" style="background: #dc3545; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">🚪 Logout</a></p>';
    }
    
} catch (Exception $e) {
    echo '<h2>❌ Error</h2>';
    echo '<p style="color: red;">Error initializing SAML authentication: ' . htmlspecialchars($e->getMessage()) . '</p>';
    echo '<p><strong>Error details:</strong></p>';
    echo '<pre>' . htmlspecialchars($e->getTraceAsString()) . '</pre>';
    
    echo '<hr>';
    echo '<h3>🔧 Troubleshooting:</h3>';
    echo '<ul>';
    echo '<li>Check SimpleSAMLphp configuration files</li>';
    echo '<li>Verify that both containers are running</li>';
    echo '<li>Check SimpleSAMLphp admin interfaces:</li>';
    echo '<ul>';
    echo '<li><a href="https://drupal-dhportal.ddev.site:8443/simplesaml/">DH Portal SimpleSAMLphp</a></li>';
    echo '<li><a href="https://drupal-netbadge.ddev.site:8443/simplesaml/">NetBadge SimpleSAMLphp</a></li>';
    echo '</ul>';
    echo '</ul>';
}

echo '<hr>';
echo '<h3>🔗 Useful Links:</h3>';
echo '<ul>';
echo '<li><a href="/">Return to DH Portal Home</a></li>';
echo '<li><a href="/simplesaml/">DH Portal SimpleSAMLphp Admin</a></li>';
echo '<li><a href="https://drupal-netbadge.ddev.site:8443/simplesaml/">NetBadge SimpleSAMLphp Admin</a></li>';
echo '<li><a href="https://drupal-netbadge.ddev.site:8443/test-saml.php">NetBadge SAML Test Page</a></li>';
echo '</ul>';
