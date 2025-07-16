<?php
/**
 * SAML Redirect Loop Diagnostic Tool
 * 
 * This script helps diagnose SAML redirect loops by checking:
 * - SP Configuration
 * - IdP Metadata
 * - URL configurations
 * - Certificate validation
 */

require_once 'autoload.php';

// Set up error reporting
error_reporting(E_ALL);
ini_set('display_errors', 1);

?>
<!DOCTYPE html>
<html>
<head>
    <title>SAML Redirect Loop Diagnostic</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .success { color: green; background: #f0f8f0; padding: 10px; border-left: 5px solid green; }
        .error { color: red; background: #fdf0f0; padding: 10px; border-left: 5px solid red; }
        .warning { color: orange; background: #fff8f0; padding: 10px; border-left: 5px solid orange; }
        .info { color: blue; background: #f0f8ff; padding: 10px; border-left: 5px solid blue; }
        .section { margin: 20px 0; padding: 15px; border: 1px solid #ccc; }
        pre { background: #f5f5f5; padding: 10px; overflow-x: auto; font-size: 12px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .status-ok { color: green; font-weight: bold; }
        .status-error { color: red; font-weight: bold; }
        .status-warning { color: orange; font-weight: bold; }
    </style>
</head>
<body>
    <h1>🔍 SAML Redirect Loop Diagnostic</h1>
    <p><strong>Date:</strong> <?php echo date('Y-m-d H:i:s'); ?></p>
    <p><strong>Server:</strong> <?php echo $_SERVER['HTTP_HOST']; ?></p>

<?php

function checkStatus($condition, $message) {
    if ($condition) {
        echo "<span class='status-ok'>✅ $message</span>";
        return true;
    } else {
        echo "<span class='status-error'>❌ $message</span>";
        return false;
    }
}

function checkWarning($condition, $message) {
    if ($condition) {
        echo "<span class='status-warning'>⚠️ $message</span>";
        return true;
    }
    return false;
}

// 1. Basic SimpleSAMLphp Configuration Check
echo "<div class='section'>";
echo "<h2>1. SimpleSAMLphp Configuration</h2>";

$simplesaml_config_dir = '/var/www/html/simplesamlphp/config';
if (getenv('SIMPLESAMLPHP_CONFIG_DIR')) {
    $simplesaml_config_dir = getenv('SIMPLESAMLPHP_CONFIG_DIR');
}

echo "<p><strong>Config Directory:</strong> $simplesaml_config_dir</p>";

try {
    \SimpleSAML\Configuration::setConfigDir($simplesaml_config_dir);
    $config = \SimpleSAML\Configuration::getInstance();
    echo "<div class='success'>";
    checkStatus(true, "SimpleSAMLphp configuration loaded successfully");
    echo "</div>";
    
    echo "<table>";
    echo "<tr><th>Setting</th><th>Value</th><th>Status</th></tr>";
    
    $baseurl = $config->getString('baseurlpath');
    echo "<tr><td>Base URL Path</td><td>$baseurl</td><td>";
    checkStatus(!empty($baseurl), "Base URL configured");
    echo "</td></tr>";
    
    $secretsalt = $config->getString('secretsalt');
    echo "<tr><td>Secret Salt</td><td>" . substr($secretsalt, 0, 20) . "...</td><td>";
    checkStatus(strlen($secretsalt) > 10, "Secret salt configured");
    echo "</td></tr>";
    
    $technicalcontact_email = $config->getString('technicalcontact_email', '');
    echo "<tr><td>Technical Contact</td><td>$technicalcontact_email</td><td>";
    checkStatus(!empty($technicalcontact_email), "Technical contact configured");
    echo "</td></tr>";
    
    echo "</table>";
    
} catch (Exception $e) {
    echo "<div class='error'>";
    echo "<p><strong>❌ SimpleSAMLphp Configuration Error:</strong> " . htmlspecialchars($e->getMessage()) . "</p>";
    echo "</div>";
    exit;
}
echo "</div>";

// 2. SP Configuration Check
echo "<div class='section'>";
echo "<h2>2. Service Provider (SP) Configuration</h2>";

try {
    $authsources = \SimpleSAML\Configuration::getConfig('authsources.php');
    $sp_config = $authsources->getArray('default-sp');
    
    echo "<div class='success'>";
    checkStatus(true, "SP configuration loaded");
    echo "</div>";
    
    echo "<table>";
    echo "<tr><th>Setting</th><th>Value</th><th>Status</th></tr>";
    
    $entityID = $sp_config['entityID'] ?? '';
    echo "<tr><td>Entity ID</td><td>$entityID</td><td>";
    checkStatus(!empty($entityID), "Entity ID configured");
    if (strpos($entityID, $_SERVER['HTTP_HOST']) === false) {
        checkWarning(true, "Entity ID doesn't match current host");
    }
    echo "</td></tr>";
    
    $idp = $sp_config['idp'] ?? '';
    echo "<tr><td>Default IdP</td><td>$idp</td><td>";
    checkStatus(!empty($idp), "Default IdP configured");
    echo "</td></tr>";
    
    $privatekey = $sp_config['privatekey'] ?? '';
    echo "<tr><td>Private Key</td><td>$privatekey</td><td>";
    checkStatus(!empty($privatekey), "Private key configured");
    echo "</td></tr>";
    
    $certificate = $sp_config['certificate'] ?? '';
    echo "<tr><td>Certificate</td><td>$certificate</td><td>";
    checkStatus(!empty($certificate), "Certificate configured");
    echo "</td></tr>";
    
    echo "</table>";
    
    echo "<h3>Full SP Configuration:</h3>";
    echo "<pre>" . htmlspecialchars(print_r($sp_config, true)) . "</pre>";
    
} catch (Exception $e) {
    echo "<div class='error'>";
    echo "<p><strong>❌ SP Configuration Error:</strong> " . htmlspecialchars($e->getMessage()) . "</p>";
    echo "</div>";
}
echo "</div>";

// 3. IdP Metadata Check
echo "<div class='section'>";
echo "<h2>3. Identity Provider (IdP) Metadata</h2>";

try {
    $metadata = \SimpleSAML\Configuration::getConfig('metadata/saml20-idp-remote.php');
    $idps = $metadata->toArray();
    
    echo "<div class='success'>";
    checkStatus(count($idps) > 0, "IdP metadata loaded (" . count($idps) . " IdPs found)");
    echo "</div>";
    
    foreach ($idps as $entityId => $idp_config) {
        echo "<h3>IdP: " . htmlspecialchars($entityId) . "</h3>";
        echo "<table>";
        echo "<tr><th>Setting</th><th>Value</th><th>Status</th></tr>";
        
        $sso_service = $idp_config['SingleSignOnService'][0]['Location'] ?? '';
        echo "<tr><td>SSO Service URL</td><td>$sso_service</td><td>";
        checkStatus(!empty($sso_service), "SSO service configured");
        echo "</td></tr>";
        
        $slo_service = $idp_config['SingleLogoutService'][0]['Location'] ?? '';
        echo "<tr><td>SLO Service URL</td><td>$slo_service</td><td>";
        checkStatus(!empty($slo_service), "SLO service configured");
        echo "</td></tr>";
        
        $certificates = $idp_config['keys'] ?? [];
        echo "<tr><td>Certificates</td><td>" . count($certificates) . " certificate(s)</td><td>";
        checkStatus(count($certificates) > 0, "IdP certificates configured");
        echo "</td></tr>";
        
        echo "</table>";
        
        // Check if this is the configured default IdP
        if (isset($sp_config['idp']) && $sp_config['idp'] === $entityId) {
            echo "<div class='info'>ℹ️ This is the default IdP for the SP</div>";
        }
        
        echo "<h4>Full IdP Configuration:</h4>";
        echo "<pre>" . htmlspecialchars(print_r($idp_config, true)) . "</pre>";
    }
    
} catch (Exception $e) {
    echo "<div class='error'>";
    echo "<p><strong>❌ IdP Metadata Error:</strong> " . htmlspecialchars($e->getMessage()) . "</p>";
    echo "</div>";
}
echo "</div>";

// 4. Certificate Validation
echo "<div class='section'>";
echo "<h2>4. Certificate Validation</h2>";

$cert_dir = '/var/www/html/simplesamlphp/cert';
if (isset($sp_config['certificate'])) {
    $cert_file = $cert_dir . '/' . $sp_config['certificate'];
    echo "<p><strong>SP Certificate:</strong> $cert_file</p>";
    
    if (file_exists($cert_file)) {
        echo "<div class='success'>";
        checkStatus(true, "SP certificate file exists");
        echo "</div>";
        
        $cert_content = file_get_contents($cert_file);
        $cert_info = openssl_x509_parse($cert_content);
        if ($cert_info) {
            echo "<table>";
            echo "<tr><th>Property</th><th>Value</th></tr>";
            echo "<tr><td>Subject</td><td>" . htmlspecialchars($cert_info['name']) . "</td></tr>";
            echo "<tr><td>Valid From</td><td>" . date('Y-m-d H:i:s', $cert_info['validFrom_time_t']) . "</td></tr>";
            echo "<tr><td>Valid To</td><td>" . date('Y-m-d H:i:s', $cert_info['validTo_time_t']) . "</td></tr>";
            echo "<tr><td>Days Until Expiry</td><td>" . round(($cert_info['validTo_time_t'] - time()) / 86400) . "</td></tr>";
            echo "</table>";
            
            if ($cert_info['validTo_time_t'] < time()) {
                echo "<div class='error'>";
                echo "<p>❌ Certificate has expired!</p>";
                echo "</div>";
            } elseif ($cert_info['validTo_time_t'] < time() + (30 * 86400)) {
                echo "<div class='warning'>";
                echo "<p>⚠️ Certificate expires within 30 days</p>";
                echo "</div>";
            }
        }
    } else {
        echo "<div class='error'>";
        checkStatus(false, "SP certificate file not found");
        echo "</div>";
    }
}

if (isset($sp_config['privatekey'])) {
    $key_file = $cert_dir . '/' . $sp_config['privatekey'];
    echo "<p><strong>SP Private Key:</strong> $key_file</p>";
    
    if (file_exists($key_file)) {
        echo "<div class='success'>";
        checkStatus(true, "SP private key file exists");
        echo "</div>";
        
        $perms = substr(sprintf('%o', fileperms($key_file)), -4);
        echo "<p><strong>File permissions:</strong> $perms</p>";
        if ($perms !== '0600' && $perms !== '0400') {
            echo "<div class='warning'>";
            echo "<p>⚠️ Private key permissions should be 600 or 400 for security</p>";
            echo "</div>";
        }
    } else {
        echo "<div class='error'>";
        checkStatus(false, "SP private key file not found");
        echo "</div>";
    }
}
echo "</div>";

// 5. URL Analysis
echo "<div class='section'>";
echo "<h2>5. URL Analysis</h2>";

$protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? 'https' : 'http';
$host = $_SERVER['HTTP_HOST'];
$current_url = $protocol . '://' . $host;

echo "<table>";
echo "<tr><th>URL Type</th><th>URL</th><th>Status</th></tr>";

echo "<tr><td>Current Page</td><td>$current_url" . $_SERVER['REQUEST_URI'] . "</td><td>";
checkStatus(true, "Current page accessible");
echo "</td></tr>";

echo "<tr><td>SimpleSAMLphp Base</td><td>$current_url" . $config->getString('baseurlpath') . "</td><td>";
checkStatus(true, "Base URL configured");
echo "</td></tr>";

if (isset($sp_config['entityID'])) {
    echo "<tr><td>SP Entity ID</td><td>" . htmlspecialchars($sp_config['entityID']) . "</td><td>";
    if (strpos($sp_config['entityID'], $current_url) === 0) {
        checkStatus(true, "Entity ID matches current domain");
    } else {
        checkWarning(true, "Entity ID uses different domain");
    }
    echo "</td></tr>";
}

// Check if URLs are accessible
$test_urls = [
    'SP Metadata' => $current_url . '/simplesaml/module.php/saml/sp/metadata.php/default-sp',
    'SimpleSAMLphp Admin' => $current_url . '/simplesaml/',
];

foreach ($test_urls as $name => $url) {
    echo "<tr><td>$name</td><td>$url</td><td>";
    
    $ch = curl_init();
    curl_setopt($ch, CURLOPT_URL, $url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_FOLLOWLOCATION, false);
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($http_code >= 200 && $http_code < 400) {
        checkStatus(true, "Accessible (HTTP $http_code)");
    } else {
        checkStatus(false, "Not accessible (HTTP $http_code)");
    }
    echo "</td></tr>";
}

echo "</table>";
echo "</div>";

// 6. Common Redirect Loop Causes
echo "<div class='section'>";
echo "<h2>6. Common Redirect Loop Causes</h2>";

echo "<h3>Potential Issues to Check:</h3>";
echo "<ul>";

// Check for entity ID mismatch
if (isset($sp_config['entityID'])) {
    $entity_domain = parse_url($sp_config['entityID'], PHP_URL_HOST);
    if ($entity_domain !== $_SERVER['HTTP_HOST']) {
        echo "<li class='status-warning'>⚠️ <strong>Entity ID domain mismatch:</strong> SP Entity ID uses '$entity_domain' but current host is '{$_SERVER['HTTP_HOST']}'</li>";
    } else {
        echo "<li class='status-ok'>✅ Entity ID domain matches current host</li>";
    }
}

// Check for HTTPS/HTTP mismatch
if (isset($sp_config['entityID'])) {
    $entity_protocol = parse_url($sp_config['entityID'], PHP_URL_SCHEME);
    if ($entity_protocol !== $protocol) {
        echo "<li class='status-warning'>⚠️ <strong>Protocol mismatch:</strong> SP Entity ID uses '$entity_protocol' but current page uses '$protocol'</li>";
    } else {
        echo "<li class='status-ok'>✅ Protocol matches between entity ID and current page</li>";
    }
}

// Check for missing IdP
if (!isset($sp_config['idp']) || empty($sp_config['idp'])) {
    echo "<li class='status-error'>❌ <strong>No default IdP configured</strong> in SP authsource</li>";
} else {
    if (isset($idps[$sp_config['idp']])) {
        echo "<li class='status-ok'>✅ Default IdP '{$sp_config['idp']}' is configured in metadata</li>";
    } else {
        echo "<li class='status-error'>❌ <strong>Default IdP '{$sp_config['idp']}' not found in metadata</strong></li>";
    }
}

echo "</ul>";

echo "<h3>Recommended Actions:</h3>";
echo "<ol>";
echo "<li>Verify that the SP Entity ID exactly matches the current domain and protocol</li>";
echo "<li>Ensure the IdP metadata contains the correct SP entity ID</li>";
echo "<li>Check that IdP SSO and SLO URLs are accessible</li>";
echo "<li>Verify certificate validity and proper file permissions</li>";
echo "<li>Test authentication with SimpleSAMLphp's built-in test pages first</li>";
echo "</ol>";
echo "</div>";

// 7. Test Authentication Flow
echo "<div class='section'>";
echo "<h2>7. Test Authentication</h2>";

try {
    $auth = new \SimpleSAML\Auth\Simple('default-sp');
    
    if ($auth->isAuthenticated()) {
        echo "<div class='success'>";
        echo "<p>✅ <strong>User is currently authenticated!</strong></p>";
        echo "<p><a href='" . $auth->getLogoutURL() . "'>🚪 Logout</a></p>";
        echo "</div>";
        
        echo "<h3>User Attributes:</h3>";
        echo "<pre>" . htmlspecialchars(print_r($auth->getAttributes(), true)) . "</pre>";
    } else {
        echo "<div class='info'>";
        echo "<p>ℹ️ User is not authenticated</p>";
        echo "<p><a href='" . $auth->getLoginURL() . "' style='background: #007cba; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;'>🔑 Test SAML Login</a></p>";
        echo "</div>";
    }
    
} catch (Exception $e) {
    echo "<div class='error'>";
    echo "<p><strong>❌ Authentication Error:</strong> " . htmlspecialchars($e->getMessage()) . "</p>";
    echo "</div>";
}

echo "</div>";

?>

<div class="section">
    <h2>8. Additional Debug Information</h2>
    <p><strong>PHP Version:</strong> <?php echo PHP_VERSION; ?></p>
    <p><strong>SimpleSAMLphp Version:</strong> <?php echo \SimpleSAML\Configuration::VERSION; ?></p>
    <p><strong>Server Time:</strong> <?php echo date('Y-m-d H:i:s T'); ?></p>
    <p><strong>User Agent:</strong> <?php echo htmlspecialchars($_SERVER['HTTP_USER_AGENT'] ?? 'Not available'); ?></p>
</div>

</body>
</html>
