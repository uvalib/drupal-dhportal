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
        'idp' => '__DEFAULT__',
        'discoURL' => null,
        
        // Enable signature validation
        'validate.response' => true,
        'validate.assertion' => true,
        'signature.algorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256',
    ],
];
