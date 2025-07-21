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
    'metadatadir' => '/var/www/html/simplesamlphp/metadata/',

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
    'session.phpsession.cookiename' => 'SimpleSAMLphpSession',
    'session.cookie.lifetime' => 0,
    'session.cookie.path' => '/',
    'session.cookie.domain' => '.ddev.site',
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
    'store.type' => 'sql',
    'store.sql.dsn' => 'mysql:host=db;dbname=db',
    'store.sql.username' => 'db',
    'store.sql.password' => 'db',

    // Logging
    'logging.level' => SimpleSAML\Logger::DEBUG,
    'logging.handler' => 'file',
    'logging.logfile' => 'simplesamlphp.log',

    // Timezone
    'timezone' => 'America/New_York',

    // Statistics
    'statistics.enable' => false,

    // Session duration
    'session.duration' => 28800, // 8 hours

    // Trusted URLs
    'trusted.url.domains' => ['drupal-dhportal.ddev.site', 'drupal-netbadge.ddev.site'],

    // Proxy configuration
    'proxy' => null,

    // Development settings
    'debug' => null,
    'showerrors' => true,
    'errorreporting' => true,
];
