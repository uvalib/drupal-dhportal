<?php
/**
 * SimpleSAMLphp configuration bootstrap for production container
 * This file sets up SimpleSAMLphp to use code from vendor but config from separate directory
 */

// Set the configuration directory for production container
putenv('SIMPLESAMLPHP_CONFIG_DIR=/opt/drupal/simplesamlphp/config');

// Include the SimpleSAMLphp autoloader from vendor
require_once '/opt/drupal/vendor/simplesamlphp/simplesamlphp/src/_autoload.php';
