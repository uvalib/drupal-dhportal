<?php
/**
 * SimpleSAMLphp configuration for AWS Production Environment
 */

$config = [
    // Basic configuration
    'baseurlpath' => '/simplesaml/',
    'certdir' => 'cert/',
    'loggingdir' => 'log/',
    'datadir' => 'data/',
    'tempdir' => '/tmp/simplesamlphp',
    'metadatadir' => '/opt/drupal/simplesamlphp/metadata/',

    // Security settings - strict for production
    'secretsalt' => getenv('SIMPLESAMLPHP_SECRET_SALT') ?: 'production-secret-salt-must-be-changed',
    'auth.adminpassword' => getenv('SIMPLESAMLPHP_ADMIN_PASSWORD') ?: 'production-admin-password',
    'admin.protectindexpage' => true,
    'admin.protectmetadata' => true,

    // Technical contact
    'technicalcontact_name' => getenv('SIMPLESAMLPHP_TECH_NAME') ?: 'DH Portal Production Admin',
    'technicalcontact_email' => getenv('SIMPLESAMLPHP_TECH_EMAIL') ?: 'dhportal@virginia.edu',

    // Session configuration - secure for production
    'session.cookie.name' => 'SimpleSAMLSessionID',
    'session.phpsession.cookiename' => 'SimpleSAMLphpSession',
    'session.cookie.lifetime' => 0,
    'session.cookie.path' => '/',
    'session.cookie.domain' => getenv('COOKIE_DOMAIN') ?: null,
    'session.cookie.secure' => true,
    'session.cookie.httponly' => true,
    'session.cookie.samesite' => 'Lax',

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

    // Store configuration - use database for session storage
    'store.type' => 'sql',
    'store.sql.dsn' => getenv('DATABASE_URL') ?: 'mysql:host=localhost;dbname=simplesaml',
    'store.sql.username' => getenv('DATABASE_USER') ?: 'simplesaml',
    'store.sql.password' => getenv('DATABASE_PASSWORD') ?: 'simplesaml',

    // Logging - NOTICE level for production (minimal logging)
    'logging.level' => SimpleSAML\Logger::NOTICE,
    'logging.handler' => 'file',
    'logging.logfile' => 'simplesamlphp.log',

    // Timezone
    'timezone' => 'America/New_York',

    // Statistics
    'statistics.enable' => false,

    // Session duration - 4 hours for production security
    'session.duration' => 14400,

    // Trusted URLs - production domains
    'trusted.url.domains' => [
        getenv('PRODUCTION_DOMAIN') ?: 'dh.library.virginia.edu',
        getenv('IDP_DOMAIN') ?: 'netbadge.virginia.edu'
    ],

    // Proxy configuration
    'proxy' => null,

    // Production settings - strict
    'debug' => false,
    'showerrors' => false,
    'errorreporting' => false,
];
