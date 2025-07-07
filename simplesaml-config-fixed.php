<?php

/**
 * SimpleSAMLphp configuration for drupal-dhportal (Service Provider)
 * This will authenticate against the drupal-netbadge container
 */

$config = [

    /*******************************
     | BASIC CONFIGURATION OPTIONS |
     *******************************/

    'baseurlpath' => '/simplesaml/',

    'application' => [
        'baseURL' => 'https://drupal-dhportal.ddev.site:8443/',
    ],

    /*
     * The 'certdir' option specifies the directory where SimpleSAMLphp will
     * look for certificates. The default is the cert/ directory under the
     * SimpleSAMLphp installation directory.
     */
    'certdir' => 'cert/',

    /*
     * The 'loggingdir' option specifies the directory where SimpleSAMLphp will
     * write its log files. The default is the log/ directory under the
     * SimpleSAMLphp installation directory.
     */
    'loggingdir' => 'log/',

    /*
     * The 'datadir' option specifies the directory where SimpleSAMLphp will
     * store its data files. The default is the data/ directory under the
     * SimpleSAMLphp installation directory.
     */
    'datadir' => 'data/',

    /*
     * The 'tempdir' option specifies the directory where SimpleSAMLphp will
     * store temporary files. The default is the system temp directory.
     */
    'tempdir' => '/tmp/simplesamlphp',

    /*
     * This is a secret salt used by SimpleSAMLphp when it needs to generate a secure hash
     * of a password. It must be changed from the default value to a secret value.
     */
    'secretsalt' => 'dhportal-secret-salt-for-development-only',

    /*
     * This password must be kept secret, and modified from the default value 123.
     */
    'auth.adminpassword' => 'admin123',

    /*
     * Set this option to true to indicate that your installation of SimpleSAMLphp
     * is running in a production environment. This will affect the way resources
     * are used, offering an optimized version when running in production, and an
     * easy-to-debug one when not. Set it to false when you are testing or
     * developing the software, in which case a banner will be displayed to remind
     * users that they're dealing with a non-production instance.
     */
    'production' => false,

    /*
     * The 'debug' option allows you to control how SimpleSAMLphp behaves in certain
     * situations where further action may be taken
     */
    'debug' => [
        'saml' => true,
        'backtraces' => true,
        'validatexml' => false,
    ],

    /*
     * When 'showerrors' is enabled, all error messages and stack traces will be output
     * to the browser.
     */
    'showerrors' => true,

    /*
     * When 'errorreporting' is enabled, a form will be presented for the user to report
     * the error to 'technicalcontact_email'.
     */
    'errorreporting' => true,

    /*
     * The 'technicalcontact_email' option specifies the email address to which
     * questions about the SimpleSAMLphp installation should be sent.
     */
    'technicalcontact_email' => 'dev@localhost',

    /*
     * The 'technicalcontact_name' option specifies the name of the person
     * responsible for the technical operation of the SimpleSAMLphp installation.
     */
    'technicalcontact_name' => 'DH Portal Development',

    /*
     * The timezone of the server. This option should be set to the timezone you want
     * SimpleSAMLphp to report the time in. The default is to guess the timezone based
     * on your system timezone.
     */
    'timezone' => 'America/New_York',

    /*
     * Define the minimum log level to log. Available levels:
     * - SimpleSAML\Logger::ERR     No statistics, only errors
     * - SimpleSAML\Logger::WARNING No statistics, only warnings/errors
     * - SimpleSAML\Logger::NOTICE  Statistics and errors
     * - SimpleSAML\Logger::INFO    Verbose logs
     * - SimpleSAML\Logger::DEBUG   Full debug logs - not recommended for production
     */
    'logging.level' => SimpleSAML\Logger::DEBUG,

    /*
     * Choose logging handler.
     *
     * Options: [syslog,file,errorlog,stderr]
     */
    'logging.handler' => 'file',

    /*
     * Specify the format of the log file. Available options:
     * - %date{<format>}: current date/time, with an optional format specifier
     * - %process: the PID of the current process
     * - %level: the log level
     * - %stat: if available, the current memory usage
     * - %trackid: the track ID of the current request
     * - %srcip: the IP address of the current client
     * - %msg: the log message
     *
     * The default format string is: %date{%b %d %H:%M:%S} %process %level %stat [%trackid] %msg
     */
    'logging.format' => '%date{%b %d %H:%M:%S} %process %level %stat [%trackid] %msg',

    /*
     * The 'logging.logfile' option specifies the name of the log file.
     * If left unset, the log file will be named 'simplesamlphp.log'.
     */
    'logging.logfile' => 'simplesamlphp.log',

    /*
     * The 'admin.protectindexpage' option controls whether the index page of the
     * administration interface is protected by authentication.
     */
    'admin.protectindexpage' => false,

    /*
     * The 'admin.protectmetadata' option controls whether the metadata pages are
     * protected by authentication.
     */
    'admin.protectmetadata' => false,

    /*
     * The 'session.cookie.name' option specifies the name of the session cookie.
     * The default is 'SimpleSAMLSessionID'.
     */
    'session.cookie.name' => 'SimpleSAMLSessionID',

    /*
     * The 'session.cookie.lifetime' option specifies the lifetime of the session
     * cookie in seconds. The default is 0, which means the cookie will expire
     * when the browser is closed.
     */
    'session.cookie.lifetime' => 0,

    /*
     * The 'session.cookie.path' option specifies the path of the session cookie.
     * The default is '/'.
     */
    'session.cookie.path' => '/',

    /*
     * The 'session.cookie.domain' option specifies the domain of the session cookie.
     * The default is null, which means the cookie will be sent to the current domain.
     */
    'session.cookie.domain' => '.drupal-dhportal.ddev.site',

    /*
     * The 'session.cookie.secure' option specifies whether the session cookie should
     * be sent over secure connections only.
     */
    'session.cookie.secure' => false,

    /*
     * The 'session.cookie.httponly' option specifies whether the session cookie should
     * be accessible through HTTP only.
     */
    'session.cookie.httponly' => true,

    /*
     * The 'session.cookie.samesite' option specifies the SameSite attribute of the
     * session cookie.
     */
    'session.cookie.samesite' => 'Lax',

    /*
     * The 'session.duration' option specifies the duration of the session in seconds.
     * The default is 8 hours.
     */
    'session.duration' => 28800,

    /*
     * The 'session.datastore.timeout' option specifies the timeout for the session
     * data store in seconds. The default is 4 hours.
     */
    'session.datastore.timeout' => 14400,

    /*
     * The 'session.state.timeout' option specifies the timeout for the session state
     * in seconds. The default is 1 hour.
     */
    'session.state.timeout' => 3600,

    /*
     * The 'session.cookie.lifetime' option specifies the lifetime of the session
     * cookie in seconds. The default is 0, which means the cookie will expire
     * when the browser is closed.
     */
    'session.rememberme.enable' => false,

    /*
     * The 'session.rememberme.checked' option specifies whether the "Remember me"
     * checkbox should be checked by default.
     */
    'session.rememberme.checked' => false,

    /*
     * The 'session.rememberme.lifetime' option specifies the lifetime of the
     * "Remember me" cookie in seconds. The default is 14 days.
     */
    'session.rememberme.lifetime' => 1209600,

    /*
     * The 'language.available' option specifies the list of languages available
     * for the user interface. The default is all languages.
     */
    'language.available' => [
        'en' => 'English',
    ],

    /*
     * The 'language.rtl' option specifies the list of languages that are written
     * right-to-left. The default is an empty array.
     */
    'language.rtl' => [],

    /*
     * The 'language.default' option specifies the default language for the user
     * interface. The default is 'en'.
     */
    'language.default' => 'en',

    /*
     * The 'language.parameter.name' option specifies the name of the parameter
     * that will be used to override the language selection.
     */
    'language.parameter.name' => 'language',

    /*
     * The 'language.parameter.value' option specifies the value of the parameter
     * that will be used to override the language selection.
     */
    'language.parameter.value' => 'en',

    /*
     * The 'language.cookie.name' option specifies the name of the cookie that
     * will be used to store the language selection.
     */
    'language.cookie.name' => 'language',

    /*
     * The 'language.cookie.domain' option specifies the domain of the cookie that
     * will be used to store the language selection.
     */
    'language.cookie.domain' => '.drupal-dhportal.ddev.site',

    /*
     * The 'language.cookie.path' option specifies the path of the cookie that
     * will be used to store the language selection.
     */
    'language.cookie.path' => '/',

    /*
     * The 'language.cookie.secure' option specifies whether the cookie that
     * will be used to store the language selection should be sent over secure
     * connections only.
     */
    'language.cookie.secure' => false,

    /*
     * The 'language.cookie.httponly' option specifies whether the cookie that
     * will be used to store the language selection should be accessible through
     * HTTP only.
     */
    'language.cookie.httponly' => false,

    /*
     * The 'language.cookie.lifetime' option specifies the lifetime of the cookie
     * that will be used to store the language selection in seconds.
     */
    'language.cookie.lifetime' => 60 * 60 * 24 * 900,

    /*
     * Options to override the default settings for the theme. An array that
     * contains theme-specific options. Each option is also an array with at least
     * the 'name' index, and probably a 'values' index as well, to set the
     * available options for the theme. The 'name' index contains the name of the
     * option, and the 'values' index contains the available values for the option.
     * If you want to disable an option, set the 'name' index to false.
     */
    'theme.use' => 'default',

    /*
     * The 'theme.header' option specifies the header template to use.
     */
    'theme.header' => 'header',

    /*
     * The 'theme.footer' option specifies the footer template to use.
     */
    'theme.footer' => 'footer',

    /*
     * The 'template.auto_reload' option specifies whether Twig templates should
     * be automatically reloaded when they are changed.
     */
    'template.auto_reload' => false,

    /*
     * The 'production' option specifies whether SimpleSAMLphp is running in
     * production mode.
     */
    'production' => false,

    /*
     * The 'trusted.url.domains' option specifies the list of domains that are
     * trusted for URL redirection.
     */
    'trusted.url.domains' => ['drupal-dhportal.ddev.site', 'drupal-netbadge.ddev.site'],

    /*
     * The 'trusted.url.regex' option specifies the regular expression that is
     * used to validate URLs.
     */
    'trusted.url.regex' => false,

    /*
     * The 'enable.http_post' option specifies whether HTTP POST is enabled.
     */
    'enable.http_post' => false,

    /*
     * The 'enable.saml20-idp' option specifies whether SAML 2.0 IdP is enabled.
     */
    'enable.saml20-idp' => false,

    /*
     * The 'enable.shib13-idp' option specifies whether Shibboleth 1.3 IdP is enabled.
     */
    'enable.shib13-idp' => false,

    /*
     * The 'enable.adfs-idp' option specifies whether ADFS IdP is enabled.
     */
    'enable.adfs-idp' => false,

    /*
     * The 'enable.wsfed-sp' option specifies whether WS-Federation SP is enabled.
     */
    'enable.wsfed-sp' => false,

    /*
     * The 'enable.authmemcookie' option specifies whether authmemcookie is enabled.
     */
    'enable.authmemcookie' => false,

    /*
     * The 'store.type' option specifies the type of store to use.
     */
    'store.type' => 'phpsession',

    /*
     * The 'store.sql.dsn' option specifies the DSN for the SQL store.
     */
    'store.sql.dsn' => 'sqlite::memory:',

    /*
     * The 'store.sql.username' option specifies the username for the SQL store.
     */
    'store.sql.username' => null,

    /*
     * The 'store.sql.password' option specifies the password for the SQL store.
     */
    'store.sql.password' => null,

    /*
     * The 'store.sql.prefix' option specifies the prefix for the SQL store.
     */
    'store.sql.prefix' => 'SimpleSAMLphp',

    /*
     * The 'store.redis.host' option specifies the host for the Redis store.
     */
    'store.redis.host' => 'localhost',

    /*
     * The 'store.redis.port' option specifies the port for the Redis store.
     */
    'store.redis.port' => 6379,

    /*
     * The 'store.redis.prefix' option specifies the prefix for the Redis store.
     */
    'store.redis.prefix' => 'SimpleSAMLphp',

    /*
     * The 'store.redis.password' option specifies the password for the Redis store.
     */
    'store.redis.password' => null,

    /*
     * The 'store.redis.database' option specifies the database for the Redis store.
     */
    'store.redis.database' => 0,

    /*
     * The 'store.redis.timeout' option specifies the timeout for the Redis store.
     */
    'store.redis.timeout' => 5,

    /*
     * This value is the duration of the session in seconds.
     */
    'session.duration' => 28800,

    /*
     * The 'session.datastore.timeout' option specifies the timeout for the session
     * data store in seconds. The default is 4 hours.
     */
    'session.datastore.timeout' => 14400,

    /*
     * The 'session.state.timeout' option specifies the timeout for the session state
     * in seconds. The default is 1 hour.
     */
    'session.state.timeout' => 3600,

    /*
     * The 'session.cookie.lifetime' option specifies the lifetime of the session
     * cookie in seconds. The default is 0, which means the cookie will expire
     * when the browser is closed.
     */
    'session.rememberme.enable' => false,

    /*
     * The 'session.rememberme.checked' option specifies whether the "Remember me"
     * checkbox should be checked by default.
     */
    'session.rememberme.checked' => false,

    /*
     * The 'session.rememberme.lifetime' option specifies the lifetime of the
     * "Remember me" cookie in seconds. The default is 14 days.
     */
    'session.rememberme.lifetime' => 1209600,

    /*
     * The 'session.cookie.lifetime' option specifies the lifetime of the session
     * cookie in seconds. The default is 0, which means the cookie will expire
     * when the browser is closed.
     */
    'session.cookie.lifetime' => 0,

    /*
     * The 'session.cookie.path' option specifies the path of the session cookie.
     * The default is '/'.
     */
    'session.cookie.path' => '/',

    /*
     * The 'session.cookie.domain' option specifies the domain of the session cookie.
     * The default is null, which means the cookie will be sent to the current domain.
     */
    'session.cookie.domain' => '.drupal-dhportal.ddev.site',

    /*
     * The 'session.cookie.secure' option specifies whether the session cookie should
     * be sent over secure connections only.
     */
    'session.cookie.secure' => false,

    /*
     * The 'session.cookie.httponly' option specifies whether the session cookie should
     * be accessible through HTTP only.
     */
    'session.cookie.httponly' => true,

    /*
     * The 'session.cookie.samesite' option specifies the SameSite attribute of the
     * session cookie.
     */
    'session.cookie.samesite' => 'Lax',

    /*
     * The 'session.check_address' option specifies whether the session should be
     * tied to the IP address of the client.
     */
    'session.check_address' => false,

    /*
     * The 'session.phpsession.cookiename' option specifies the name of the PHP
     * session cookie.
     */
    'session.phpsession.cookiename' => null,

    /*
     * The 'session.phpsession.savepath' option specifies the path where PHP
     * session files are stored.
     */
    'session.phpsession.savepath' => null,

    /*
     * The 'session.phpsession.httponly' option specifies whether the PHP session
     * cookie should be accessible through HTTP only.
     */
    'session.phpsession.httponly' => true,

];
