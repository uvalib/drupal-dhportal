<?php
/**
 * Authentication sources configuration for drupal-dhportal
 * This configures the connection to the drupal-netbadge SAML IdP
 */

$config = [
    // Default SP configuration - connects to drupal-netbadge
    'default-sp' => [
        'saml:SP',
        'entityID' => 'https://drupal-dhportal.ddev.site:8443',
        'idp' => 'netbadge-idp',
        'discoURL' => null,
        'acs' => [
            'https://drupal-dhportal.ddev.site:8443/simplesaml/module.php/saml/sp/saml2-acs.php/default-sp',
        ],
        'sls' => [
            'https://drupal-dhportal.ddev.site:8443/simplesaml/module.php/saml/sp/saml2-logout.php/default-sp',
        ],
    ],

    // The drupal-netbadge Identity Provider configuration
    'netbadge-idp' => [
        'saml:External',
        'entityId' => 'https://drupal-netbadge.ddev.site:8443',
        'singleSignOnService' => 'https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/SSOService.php',
        'singleLogoutService' => 'https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/SingleLogoutService.php',
        'certificate' => null, // We'll use HTTP for development (not recommended for production)
        'name' => [
            'en' => 'NetBadge Authentication',
        ],
        'description' => [
            'en' => 'NetBadge SAML Identity Provider',
        ],
    ],
];
