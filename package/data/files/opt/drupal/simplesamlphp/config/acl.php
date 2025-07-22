<?php
/**
 * Access Control Lists for SimpleSAMLphp Administration
 * This file defines access control for administrative functions
 */

$config = [
    // Admin access list - controls who can access admin interface
    'adminlist' => [
        // Allow access based on admin password authentication
        ['allow'],
    ],
    
    // Allow all authenticated admins full access
    'admin-allow-all' => [
        ['allow'],
    ],
];
