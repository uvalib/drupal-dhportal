<?php
// Direct test of SimpleSAMLphp from web context
error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "Testing SimpleSAMLphp configuration...\n";

try {
    // Check if the simplesamlphp_dir setting is available
    if (function_exists('drupal_get_path')) {
        echo "Drupal context detected\n";
        $simplesaml_dir = \Drupal\Core\Site\Settings::get('simplesamlphp_dir');
        echo "SimpleSAMLphp dir from Drupal: " . $simplesaml_dir . "\n";
    }
    
    // Try to load SimpleSAMLphp
    $autoload_paths = [
        '/var/www/html/vendor/simplesamlphp/simplesamlphp/lib/_autoload.php',
        '/var/simplesamlphp/lib/_autoload.php'
    ];
    
    $loaded = false;
    foreach ($autoload_paths as $path) {
        if (file_exists($path)) {
            echo "Found autoload at: $path\n";
            require_once $path;
            $loaded = true;
            break;
        }
    }
    
    if (!$loaded) {
        echo "ERROR: Could not find SimpleSAMLphp autoload file\n";
        exit(1);
    }
    
    // Try to get configuration
    $config = \SimpleSAML\Configuration::getInstance();
    echo "Configuration loaded successfully\n";
    echo "Base URL path: " . $config->getString('baseurlpath') . "\n";
    
    // Check debug setting
    $debug = $config->getOptionalArray('debug', []);
    echo "Debug setting: " . var_export($debug, true) . "\n";
    
    // Try to create a Simple SAML auth instance
    $auth = new \SimpleSAML\Auth\Simple('default-sp');
    echo "SimpleSAML Auth Simple instance created successfully\n";
    
    echo "All tests passed!\n";
    
} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage() . "\n";
    echo "File: " . $e->getFile() . ":" . $e->getLine() . "\n";
    echo "Trace:\n" . $e->getTraceAsString() . "\n";
}
?>
