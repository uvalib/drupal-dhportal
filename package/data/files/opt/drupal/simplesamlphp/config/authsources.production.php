<?php
/**
 * Authentication sources configuration for AWS Production Environment
 * Connects to production NetBadge IDP
 */

$config = [
    // Admin authentication source - required for SimpleSAMLphp administration
    'admin' => [
        'core:AdminPassword',
    ],

    // Default SP configuration - connects to production NetBadge
    'default-sp' => [
        'saml:SP',
        'entityID' => getenv('SP_ENTITY_ID') ?: 'https://dh.library.virginia.edu',
        'idp' => '__DEFAULT__',
        'discoURL' => null,
        
        // Strict signature validation for production
        'validate.response' => true,
        'validate.assertion' => true,
        'signature.algorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256',
        
        // Production security settings
        'assertion.encryption' => true, // Require encryption in production
        'NameIDPolicy' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
        
        // Additional production security
        'sign.logout' => true,
        'redirect.sign' => true,
    ],
];
