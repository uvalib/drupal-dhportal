<?php
/**
 * SAML Integration Test Page
 * 
 * This page helps test and debug SAML authentication integration.
 */

require_once 'autoload.php';

// Include SimpleSAMLphp configuration
$simplesaml_config_dir = '/var/www/html/simplesamlphp/config';
if (getenv('SIMPLESAMLPHP_CONFIG_DIR')) {
    $simplesaml_config_dir = getenv('SIMPLESAMLPHP_CONFIG_DIR');
}

try {
    \SimpleSAML\Configuration::setConfigDir($simplesaml_config_dir);
    $config = \SimpleSAML\Configuration::getInstance();
    $auth = new \SimpleSAML\Auth\Simple('default-sp');
} catch (Exception $e) {
    echo "<h1>SimpleSAMLphp Configuration Error</h1>";
    echo "<p><strong>Error:</strong> " . htmlspecialchars($e->getMessage()) . "</p>";
    echo "<p><strong>Config Dir:</strong> " . htmlspecialchars($simplesaml_config_dir) . "</p>";
    
    if (file_exists($simplesaml_config_dir . '/config.php')) {
        echo "<p>✅ config.php found</p>";
    } else {
        echo "<p>❌ config.php not found</p>";
    }
    
    if (file_exists($simplesaml_config_dir . '/authsources.php')) {
        echo "<p>✅ authsources.php found</p>";
    } else {
        echo "<p>❌ authsources.php not found</p>";
    }
    
    exit;
}

?>
<!DOCTYPE html>
<html>
<head>
    <title>SAML Integration Test</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .success { color: green; }
        .error { color: red; }
        .info { color: blue; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ccc; }
        pre { background: #f5f5f5; padding: 10px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>🔐 SAML Authentication Integration Test</h1>
    
    <div class="section">
        <h2>Authentication Status</h2>
        <?php if ($auth->isAuthenticated()): ?>
            <p class="success">✅ <strong>User is authenticated!</strong></p>
            
            <h3>User Attributes:</h3>
            <pre><?php print_r($auth->getAttributes()); ?></pre>
            
            <h3>Auth Data:</h3>
            <pre><?php print_r($auth->getAuthData()); ?></pre>
            
            <p><a href="<?php echo $auth->getLogoutURL(); ?>">🚪 Logout</a></p>
            
        <?php else: ?>
            <p class="info">❌ User is not authenticated</p>
            <p><a href="<?php echo $auth->getLoginURL(); ?>" style="background: #007cba; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">🔑 Login with NetBadge SAML</a></p>
        <?php endif; ?>
    </div>
    
    <div class="section">
        <h2>Configuration Status</h2>
        <p><strong>SimpleSAMLphp Config Dir:</strong> <?php echo htmlspecialchars($simplesaml_config_dir); ?></p>
        <p><strong>Base URL:</strong> <?php echo htmlspecialchars($config->getString('baseurlpath')); ?></p>
        <p><strong>Auth Source:</strong> default-sp</p>
        
        <?php
        try {
            $authsources = \SimpleSAML\Configuration::getConfig('authsources.php');
            $sp_config = $authsources->getArray('default-sp');
            echo "<p class='success'>✅ SP Configuration loaded</p>";
            echo "<p><strong>Entity ID:</strong> " . htmlspecialchars($sp_config['entityID']) . "</p>";
        } catch (Exception $e) {
            echo "<p class='error'>❌ Could not load SP configuration: " . htmlspecialchars($e->getMessage()) . "</p>";
        }
        ?>
    </div>
    
    <div class="section">
        <h2>IdP Metadata Status</h2>
        <?php
        try {
            $metadata = \SimpleSAML\Configuration::getConfig('metadata/saml20-idp-remote.php');
            $idps = $metadata->toArray();
            echo "<p class='success'>✅ IdP metadata loaded</p>";
            echo "<p><strong>Configured IdPs:</strong> " . count($idps) . "</p>";
            foreach ($idps as $entityId => $idp) {
                echo "<p>• " . htmlspecialchars($entityId) . "</p>";
            }
        } catch (Exception $e) {
            echo "<p class='error'>❌ Could not load IdP metadata: " . htmlspecialchars($e->getMessage()) . "</p>";
        }
        ?>
    </div>
    
    <div class="section">
        <h2>Useful Links</h2>
        <ul>
            <li><a href="/simplesaml/">SimpleSAMLphp Admin Interface</a></li>
            <li><a href="/simplesaml/module.php/saml/sp/metadata.php/default-sp">SP Metadata</a></li>
            <li><a href="https://drupal-netbadge.ddev.site:8443/simplesaml/">NetBadge IdP Admin</a></li>
            <li><a href="https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/metadata.php">IdP Metadata</a></li>
        </ul>
    </div>
    
    <div class="section">
        <h2>Test Users (NetBadge IdP)</h2>
        <ul>
            <li><strong>Student:</strong> username: <code>student</code>, password: <code>studentpass</code></li>
            <li><strong>Staff:</strong> username: <code>staff</code>, password: <code>staffpass</code></li>
            <li><strong>Faculty:</strong> username: <code>faculty</code>, password: <code>facultypass</code></li>
        </ul>
    </div>
</body>
</html>
