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
    ],
];
