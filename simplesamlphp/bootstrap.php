<?php
/**
 * SimpleSAMLphp configuration bootstrap
 * This file sets up the configuration directory outside of vendor
 */

// Set the configuration directory
putenv('SIMPLESAMLPHP_CONFIG_DIR=/var/www/html/simplesamlphp/config');

// Include the SimpleSAMLphp autoloader
require_once '/var/www/html/vendor/simplesamlphp/simplesamlphp/src/_autoload.php';
