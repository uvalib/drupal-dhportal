<?php
/**
 * SAML 2.0 remote IdP metadata for drupal-dhportal (Production)
 * This defines the connection to the production SAML IdP
 */

$idpEntityId = getenv('SIMPLESAMLPHP_IDP_ENTITY_ID') ?: 'https://netbadge.example.com/idp';
$idpSsoUrl = getenv('SIMPLESAMLPHP_IDP_SSO_URL') ?: 'https://netbadge.example.com/idp/SSOService.php';
$idpSloUrl = getenv('SIMPLESAMLPHP_IDP_SLO_URL') ?: 'https://netbadge.example.com/idp/SingleLogoutService.php';
$idpCert = getenv('SIMPLESAMLPHP_IDP_CERT') ?: '';

$metadata['__DEFAULT__'] = [
    'entityid' => $idpEntityId,
    'name' => [
        'en' => 'NetBadge Authentication',
    ],
    'description' => [
        'en' => 'NetBadge SAML Identity Provider (Production)',
    ],
    'SingleSignOnService' => [
        [
            'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
            'Location' => $idpSsoUrl,
        ],
    ],
    'SingleLogoutService' => [
        [
            'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
            'Location' => $idpSloUrl,
        ],
    ],
    'NameIDFormat' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    'validate.authnrequest' => true,
    'validate.logout' => true,
];

// Only add certificate if provided via environment variable
if (!empty($idpCert)) {
    $metadata['__DEFAULT__']['keys'] = [
        [
            'encryption' => false,
            'signing' => true,
            'type' => 'X509Certificate',
            'X509Certificate' => $idpCert,
        ],
    ];
}
