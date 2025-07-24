<?php
/**
 * SimpleSAMLphp configuration for drupal-dhportal (Production Service Provider)
 * This configuration is used in the production container environment
 */

$config = [
    // Basic configuration
    'baseurlpath' => '/simplesaml/',
    'certdir' => 'cert/',
    'loggingdir' => 'log/',
    'datadir' => 'data/',
    'tempdir' => '/tmp/simplesamlphp',
    'metadatadir' => 'metadata/',

    // Security settings (should be overridden by environment variables in production)
    'secretsalt' => getenv('SIMPLESAMLPHP_SECRET_SALT') ?: 'default-salt-change-in-production',
    'auth.adminpassword' => getenv('SIMPLESAMLPHP_ADMIN_PASSWORD') ?: 'admin',
    'admin.protectindexpage' => false, // Explicitly disable admin protection for development
    'admin.protectmetadata' => false, // Also disable metadata protection

    // Technical contact
    'technicalcontact_name' => getenv('SIMPLESAMLPHP_TECH_NAME') ?: 'DH Portal Admin',
    'technicalcontact_email' => getenv('SIMPLESAMLPHP_TECH_EMAIL') ?: 'admin@example.com',

    // Session configuration
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

    // Store configuration
    'store.type' => 'sql',
    'store.sql.dsn' => getenv('SIMPLESAMLPHP_DB_DSN') ?: 'sqlite:/var/run/sqlite/simplesamlphp.db',
    'store.sql.username' => getenv('DB_USER') ?: null,
    'store.sql.password' => getenv('DB_PASSWORD') ?: null,

    // Logging - enhanced for development environments
    'logging.level' => (getenv('PHP_MODE') === 'development') ? SimpleSAML\Logger::DEBUG : SimpleSAML\Logger::NOTICE,
    'logging.handler' => (getenv('PHP_MODE') === 'development') ? 'stderr' : 'file',
    'logging.logfile' => 'simplesamlphp.log',

    // Timezone
    'timezone' => 'America/New_York',

    // Statistics
    'statistics.enable' => false,

    // Session duration (8 hours)
    'session.duration' => 28800,

    // Trusted URLs (should be set via environment)
    'trusted.url.domains' => array_filter(explode(',', getenv('TRUSTED_URL_DOMAINS') ?: '')),

    // Proxy configuration
    'proxy' => null,

    // Production settings - enable debugging in development mode
    'debug' => (getenv('PHP_MODE') === 'development'),
    'showerrors' => (getenv('PHP_MODE') === 'development'),
    'errorreporting' => (getenv('PHP_MODE') === 'development'),

    // Security headers
    'headers.security' => [
        'Content-Security-Policy' => "default-src 'self'; script-src 'self' 'unsafe-inline'; " .
                                     "style-src 'self' 'unsafe-inline'",
        'X-Frame-Options' => 'DENY',
        'X-Content-Type-Options' => 'nosniff',
    ],
];
