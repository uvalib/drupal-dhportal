<?php

declare(strict_types=1);

require_once('_include.php');

use SimpleSAML\Configuration;
use SimpleSAML\Utils;
use SimpleSAML\XHTML\Template;

// Initialize configuration
$config = Configuration::getInstance();

// Create template
$t = new Template($config, 'frontpage_welcome.twig');

// Set template variables
$t->data['title'] = 'SimpleSAMLphp';
$t->data['pageid'] = 'frontpage_welcome';

// Show the template
$t->show();
