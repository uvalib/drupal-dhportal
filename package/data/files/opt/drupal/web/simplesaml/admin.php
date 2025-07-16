<?php

declare(strict_types=1);

require_once('_include.php');

use SimpleSAML\Configuration;
use SimpleSAML\Utils;
use SimpleSAML\XHTML\Template;

// Initialize configuration
$config = Configuration::getInstance();

// Create template
$t = new Template($config, 'admin.twig');

// Set template variables
$t->data['title'] = 'SimpleSAMLphp Administration';
$t->data['pageid'] = 'admin';

// Show the template
$t->show();
