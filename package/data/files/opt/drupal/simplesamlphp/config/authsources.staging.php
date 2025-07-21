<?php
/**
 * Authentication sources configuration for AWS Staging Environment
 * Connects to staging NetBadge IDP
 */

$config = [
    // Default SP configuration - connects to staging NetBadge
    'default-sp' => [
        'saml:SP',
        'entityID' => getenv('SP_ENTITY_ID') ?: 'https://dh-staging.library.virginia.edu',
        'idp' => '__DEFAULT__',
        'discoURL' => null,
        
        // Enable signature validation for staging
        'validate.response' => true,
        'validate.assertion' => true,
        'signature.algorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256',
        
        // Staging-specific settings
        'assertion.encryption' => false, // Can be more relaxed in staging
        'NameIDPolicy' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    ],
];
