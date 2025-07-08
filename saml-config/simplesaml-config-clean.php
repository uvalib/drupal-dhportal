<?php

/**
 * SimpleSAMLphp configuration for drupal-dhportal (Service Provider)
 */

$config = [
    // Basic configuration
    'baseurlpath' => 'https://drupal-dhportal.ddev.site:8443/simplesaml/',
    'application' => [
        'baseURL' => 'https://drupal-dhportal.ddev.site:8443/',
    ],
    'certdir' => 'cert/',
    'loggingdir' => 'log/',
    'datadir' => 'data/',
    'tempdir' => '/tmp/simplesamlphp',

    // Security settings
    'secretsalt' => 'dhportal-secret-salt-for-development-only',
    'auth.adminpassword' => 'admin123',
    'admin.protectindexpage' => false,
    'admin.protectmetadata' => false,
    'production' => false,

    // Technical contact
    'technicalcontact_name' => 'DH Portal Development',
    'technicalcontact_email' => 'dev@localhost',
    'timezone' => 'America/New_York',

    // Debug and errors
    'debug' => [
        'saml' => true,
        'backtraces' => true,
        'validatexml' => false,
    ],
    'showerrors' => true,
    'errorreporting' => true,

    // Logging
    'logging.level' => SimpleSAML\Logger::DEBUG,
    'logging.handler' => 'file',
    'logging.logfile' => 'simplesamlphp.log',
    'logging.format' => '%date{%b %d %H:%M:%S} %process %level %stat [%trackid] %msg',

    // Session configuration
    'session.cookie.name' => 'SimpleSAMLSessionID',
    'session.cookie.lifetime' => 0,
    'session.cookie.path' => '/',
    'session.cookie.domain' => '.drupal-dhportal.ddev.site',
    'session.cookie.secure' => false,
    'session.cookie.httponly' => true,
    'session.cookie.samesite' => 'Lax',
    'session.duration' => 28800,
    'session.datastore.timeout' => 14400,
    'session.state.timeout' => 3600,
    'session.rememberme.enable' => false,
    'session.check_address' => false,

    // Language settings
    'language.available' => ['en'],
    'language.rtl' => [],
    'language.default' => 'en',
    'language.parameter.name' => 'language',
    'language.cookie.name' => 'language',
    'language.cookie.domain' => '.drupal-dhportal.ddev.site',
    'language.cookie.path' => '/',
    'language.cookie.secure' => false,
    'language.cookie.httponly' => false,
    'language.cookie.lifetime' => 60 * 60 * 24 * 900,

    // Store configuration
    'store.type' => 'phpsession',

    // Theme settings
    'theme.use' => 'default',
    'template.auto_reload' => false,

    // Trusted URLs
    'trusted.url.domains' => [
        'drupal-dhportal.ddev.site',
        'drupal-netbadge.ddev.site'
    ],
    'trusted.url.regex' => false,

    // Module configuration
    'enable.http_post' => false,
    'enable.saml20-idp' => false,
    'enable.shib13-idp' => false,
    'enable.adfs-idp' => false,
    'enable.wsfed-sp' => false,
    'enable.authmemcookie' => false,
];
