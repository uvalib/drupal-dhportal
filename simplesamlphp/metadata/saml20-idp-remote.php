<?php
/**
 * SAML 2.0 remote IdP metadata for drupal-dhportal
 * This defines the connection to the drupal-netbadge SAML IdP
 */

$metadata['__DEFAULT__'] = [
    'entityid' => 'https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/metadata.php',
    'name' => [
        'en' => 'NetBadge Authentication',
    ],
    'description' => [
        'en' => 'NetBadge SAML Identity Provider',
    ],
    'SingleSignOnService' => [
        [
            'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
            'Location' => 'https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/SSOService.php',
        ],
    ],
    'SingleLogoutService' => [
        [
            'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
            'Location' => 'https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/SingleLogoutService.php',
        ],
    ],
    // No certificate for development - using HTTP
    'keys' => [],
    'NameIDFormat' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    'validate.authnrequest' => false,
    'validate.logout' => false,
];
