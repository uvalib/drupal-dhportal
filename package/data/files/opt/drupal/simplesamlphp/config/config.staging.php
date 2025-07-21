<?php
/**
 * SimpleSAMLphp configuration for AWS Staging Environment
 * Used for AWS dev deployment (not local DDEV)
 */

$config = [
    // Basic configuration
    'baseurlpath' => '/simplesaml/',
    'certdir' => 'cert/',
    'loggingdir' => 'log/',
    'datadir' => 'data/',
    'tempdir' => '/tmp/simplesamlphp',
    'metadatadir' => '/opt/drupal/simplesamlphp/metadata/',

    // Security settings - more secure than DDEV but not as strict as prod
    'secretsalt' => getenv('SIMPLESAMLPHP_SECRET_SALT') ?: 'change-this-default-salt',
    'auth.adminpassword' => getenv('SIMPLESAMLPHP_ADMIN_PASSWORD') ?: 'admin-staging',
    'admin.protectindexpage' => true,
    'admin.protectmetadata' => true,

    // Technical contact
    'technicalcontact_name' => getenv('SIMPLESAMLPHP_TECH_NAME') ?: 'DH Portal Staging Admin',
    'technicalcontact_email' => getenv('SIMPLESAMLPHP_TECH_EMAIL') ?: 'dhportal-staging@virginia.edu',

    // Session configuration - secure for AWS
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

    // Logging - INFO level for staging
    'logging.level' => SimpleSAML\Logger::INFO,
    'logging.handler' => 'file',
    'logging.logfile' => 'simplesamlphp.log',

    // Timezone
    'timezone' => 'America/New_York',

    // Statistics
    'statistics.enable' => false,

    // Session duration - 8 hours
    'session.duration' => 28800,

    // Trusted URLs - staging domains
    'trusted.url.domains' => [
        getenv('STAGING_DOMAIN') ?: 'dh-staging.library.virginia.edu',
        getenv('IDP_DOMAIN') ?: 'netbadge-staging.virginia.edu'
    ],

    // Proxy configuration
    'proxy' => null,

    // Development settings - less permissive than DDEV
    'debug' => false,
    'showerrors' => true,
    'errorreporting' => false,
];
