<?php
/**
 * SimpleSAMLphp configuration template
 * This template uses environment variables for dynamic configuration
 * Environment variables should be set during container deployment
 */

// Get environment-specific values with fallbacks
$environment = getenv('DEPLOYMENT_ENVIRONMENT') ?: 'development';
$baseUrl = getenv('SIMPLESAMLPHP_BASE_URL') ?: 'https://localhost';
$cookieDomain = getenv('COOKIE_DOMAIN');
$secretSalt = getenv('SIMPLESAMLPHP_SECRET_SALT');
$adminPassword = getenv('SIMPLESAMLPHP_ADMIN_PASSWORD');
$trustedDomains = getenv('TRUSTED_URL_DOMAINS') ? explode(',', getenv('TRUSTED_URL_DOMAINS')) : [];

// Validate required environment variables
if (!$secretSalt) {
    throw new Exception('SIMPLESAMLPHP_SECRET_SALT environment variable is required');
}
if (!$adminPassword) {
    throw new Exception('SIMPLESAMLPHP_ADMIN_PASSWORD environment variable is required');
}

$config = [
    // Basic configuration
    'baseurlpath' => '/simplesaml/',
    'certdir' => 'cert/',
    'loggingdir' => 'log/',
    'datadir' => 'data/',
    'tempdir' => '/tmp/simplesamlphp',
    'metadatadir' => 'metadata/',

    // Security settings
    'secretsalt' => $secretSalt,
    'auth.adminpassword' => $adminPassword,
    'admin.protectindexpage' => ($environment === 'production'),
    'admin.protectmetadata' => ($environment === 'production'),

    // Technical contact
    'technicalcontact_name' => getenv('SIMPLESAMLPHP_TECH_NAME') ?: 'DH Portal Admin',
    'technicalcontact_email' => getenv('SIMPLESAMLPHP_TECH_EMAIL') ?: 'admin@example.com',

    // Session configuration - environment-specific
    'session.cookie.name' => 'SimpleSAMLSessionID',
    'session.phpsession.cookiename' => 'SimpleSAMLphpSession',
    'session.cookie.lifetime' => 0,
    'session.cookie.path' => '/',
    'session.cookie.domain' => $cookieDomain,
    'session.cookie.secure' => ($environment !== 'development'),
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
    'store.sql.username' => getenv('DB_USER'),
    'store.sql.password' => getenv('DB_PASSWORD'),

    // Logging - environment-specific
    'logging.level' => match ($environment) {
        'development' => SimpleSAML\Logger::DEBUG,
        'staging' => SimpleSAML\Logger::INFO,
        'production' => SimpleSAML\Logger::NOTICE,
        default => SimpleSAML\Logger::INFO
    },
    'logging.handler' => 'stderr', // Always use stderr for container logging
    'logging.logfile' => 'simplesamlphp.log',

    // Timezone
    'timezone' => 'America/New_York',

    // Statistics
    'statistics.enable' => false,

    // Session duration (8 hours)
    'session.duration' => 28800,

    // Trusted URLs
    'trusted.url.domains' => $trustedDomains,

    // Proxy configuration
    'proxy' => null,

    // Environment-specific settings
    'debug' => ($environment === 'development'),
    'showerrors' => ($environment !== 'production'),
    'errorreporting' => ($environment === 'development'),

    // Security headers for production
    'headers.security' => ($environment === 'production') ? [
        'Content-Security-Policy' => "default-src 'self'; script-src 'self' 'unsafe-inline'; " .
                                     "style-src 'self' 'unsafe-inline'",
        'X-Frame-Options' => 'DENY',
        'X-Content-Type-Options' => 'nosniff',
        'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
    ] : [],
];

// Log configuration summary for debugging
error_log(sprintf(
    '[SimpleSAML-Config] Environment: %s, BaseURL: %s, Logging: %s, Debug: %s',
    $environment,
    $baseUrl,
    $config['logging.level'],
    $config['debug'] ? 'enabled' : 'disabled'
));
