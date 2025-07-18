<?php

declare(strict_types=1);

// Set start-time for debugging purposes
define('SIMPLESAMLPHP_START', hrtime(true));

// Use production bootstrap for container environment
if (file_exists('/opt/drupal/simplesamlphp/bootstrap.php')) {
    // Production container environment
    require_once('/opt/drupal/simplesamlphp/bootstrap.php');
} else {
    // Development environment fallback
    require_once(dirname(__FILE__, 2) . '/src/_autoload.php');
}

use SAML2\Compat\ContainerSingleton;
use SimpleSAML\Compat\SspContainer;
use SimpleSAML\Configuration;
use SimpleSAML\Error;
use SimpleSAML\Utils;

$exceptionHandler = new Error\ExceptionHandler();
set_exception_handler([$exceptionHandler, 'customExceptionHandler']);

$errorHandler = new Error\ErrorHandler();
set_error_handler([$errorHandler, 'customErrorHandler']);

try {
    Configuration::getInstance();
} catch (Exception $e) {
    throw new Error\CriticalConfigurationError(
        $e->getMessage(),
    );
}

// set the timezone
$timeUtils = new Utils\Time();
$timeUtils->initTimezone();

// set the SAML2 container
$container = new SspContainer();
ContainerSingleton::setContainer($container);
