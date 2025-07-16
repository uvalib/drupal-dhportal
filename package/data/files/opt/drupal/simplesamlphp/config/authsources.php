<?php
/**
 * Authentication sources configuration for drupal-dhportal (Production)
 * This configures the connection to the production SAML IdP
 */

$config = [
    // Default SP configuration - connects to production IdP
    'default-sp' => [
        'saml:SP',
        'entityID' => getenv('SIMPLESAMLPHP_SP_ENTITY_ID') ?: 'https://drupal-dhportal.example.com',
        'idp' => '__DEFAULT__',
        'discoURL' => null,
        
        // Enable signature validation
        'validate.response' => true,
        'validate.assertion' => true,
        'signature.algorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256',
        
        // Production certificate settings
        'privatekey' => 'sp.key',
        'certificate' => 'sp.crt',
        
        // Assertion consumer service
        'AssertionConsumerService' => [
            [
                'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST',
                'Location' => (getenv('SIMPLESAMLPHP_SP_ENTITY_ID') ?:
                    'https://drupal-dhportal.example.com') .
                    '/simplesaml/module.php/saml/sp/saml2-acs.php/default-sp',
            ],
        ],
        
        // Single logout service
        'SingleLogoutService' => [
            [
                'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
                'Location' => (getenv('SIMPLESAMLPHP_SP_ENTITY_ID') ?:
                    'https://drupal-dhportal.example.com') .
                    '/simplesaml/module.php/saml/sp/saml2-logout.php/default-sp',
            ],
        ],
    ],
];
