<?php
/**
 * SimpleSAMLphp router for DDEV nginx-fpm
 * This script routes requests to SimpleSAMLphp when PATH_INFO isn't working properly
 */

// Get the request URI and parse it
$requestUri = $_SERVER['REQUEST_URI'];
$path = parse_url($requestUri, PHP_URL_PATH);
$query = parse_url($requestUri, PHP_URL_QUERY);

// Check if this is a SimpleSAMLphp module request
if (preg_match('#^/simplesaml/module\.php(.*)$#', $path, $matches)) {
    // Set up the PATH_INFO manually
    $pathInfo = $matches[1];
    if ($pathInfo) {
        $_SERVER['PATH_INFO'] = $pathInfo;
        $_SERVER['SCRIPT_NAME'] = '/simplesaml/module.php';
        $_SERVER['SCRIPT_FILENAME'] = __DIR__ . '/simplesaml/module.php';
        
        // Include the SimpleSAMLphp module.php
        include __DIR__ . '/simplesaml/module.php';
        exit;
    }
}

// If not a SimpleSAMLphp request, pass to normal Drupal handling
include __DIR__ . '/index.php';
?>
