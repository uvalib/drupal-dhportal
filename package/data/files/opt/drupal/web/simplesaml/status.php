<?php

declare(strict_types=1);

require_once('_include.php');

use SimpleSAML\Auth\Simple;
use SimpleSAML\Configuration;
use SimpleSAML\Utils;
use SimpleSAML\XHTML\Template;

// Get the authentication source from the URL
$as = $_REQUEST['as'] ?? 'default-sp';

// Initialize the authentication source
$auth = new Simple($as);

// Check if user is authenticated
if (!$auth->isAuthenticated()) {
    // Redirect to login
    $auth->requireAuth();
}

// Get user attributes
$attributes = $auth->getAttributes();

// Create template
$config = Configuration::getInstance();
$t = new Template($config, 'status.twig');

// Set template variables
$t->data['title'] = 'Authentication Status';
$t->data['pageid'] = 'status';
$t->data['attributes'] = $attributes;
$t->data['authsource'] = $as;
$t->data['logout_url'] = $auth->getLogoutURL();

// Show the template
$t->show();
