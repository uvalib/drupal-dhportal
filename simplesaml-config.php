<?php
/**
 * SimpleSAMLphp configuration for drupal-dhportal (Service Provider)
 * This will authenticate against the drupal-netbadge container
 */

$config = [
    // Basic configuration
    'baseurlpath' => '/simplesaml/',
    'certdir' => 'cert/',
    'loggingdir' => 'log/',
    'datadir' => 'data/',
    'tempdir' => '/tmp/simplesamlphp',

    // Security settings
    'secretsalt' => 'dhportal-secret-salt-for-development-only',
    'auth.adminpassword' => 'admin123',
    'admin.protectindexpage' => false,
    'admin.protectmetadata' => false,

    // Technical contact
    'technicalcontact_name' => 'DH Portal Development',
    'technicalcontact_email' => 'dev@localhost',

    // Session configuration
    'session.cookie.name' => 'SimpleSAMLSessionID',
    'session.cookie.lifetime' => 0,
    'session.cookie.path' => '/',
    'session.cookie.domain' => '.drupal-dhportal.ddev.site',
    'session.cookie.secure' => false,

    // Language settings
    'language.available' => ['en'],
    'language.rtl' => [],
    'language.default' => 'en',

    // Module configuration
    'module.enable' => [
        'core' => true,
        'admin' => true,
        'saml' => true,
    ],

    // Store configuration
    'store.type' => 'phpsession',

    // Logging
    'logging.level' => SimpleSAML\Logger::DEBUG,
    'logging.handler' => 'file',
    'logging.logfile' => 'simplesamlphp.log',

    // Development settings
    'debug' => true,
    'showerrors' => true,
    'errorreporting' => true,

    // Timezone
    'timezone' => 'America/New_York',
];
