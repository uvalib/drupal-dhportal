<?php
/**
 * SAML 2.0 remote IdP metadata for drupal-dhportal
 * This defines the connection to the drupal-netbadge SAML IdP
 */

$metadata['https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/metadata.php'] = [
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
    // Certificate for SAML signature validation
    'keys' => [
        [
            'encryption' => false,
            'signing' => true,
            'type' => 'X509Certificate',
            'X509Certificate' => 'MIIDKTCCAhGgAwIBAgIUa3UMB3WEP3hX7mg5DI31qBULMNUwDQYJKoZIhvcNAQEL' .
                'BQAwJDEiMCAGA1UEAwwZZHJ1cGFsLW5ldGJhZGdlLmRkZXYuc2l0ZTAeFw0yNTA3' .
                'MDcyMzQxMjJaFw0yNjA3MDcyMzQxMjJaMCQxIjAgBgNVBAMMGWRydXBhbC1uZXRi' .
                'YWRnZS5kZGV2LnNpdGUwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCv' .
                'TTFKAhWq+58/2Bmb2qtYxyUeUcHYGoFcgTgn84uiRyYA85ve3fP9JH0qRAtsrxn0' .
                'q5Vp+MohpI/heN6Gh5YzAiJnE8WHR0k+PAn9gIV0YNuipogXHWUjzRNASHTZrODQ' .
                'gwbBYuPOQEbqizEBTu6rDRdMLJk1ab3bUmUozl47vGcOOBx4mcsn/aTdjHlCMTir' .
                '5OMqrGrM7jODKL95c0fcoMdl5ZsFvhfGobW6rG55BHoxPtg98+Oqa/7i0IpHLUpg' .
                '9myZztoGSdjKsm5ufRUDSAtswH9TiHDkkvhpequn//7rzOnxnb1b1p4C8LE3KT8y' .
                'S4nPTtGkepMw1nkz76YJAgMBAAGjUzBRMB0GA1UdDgQWBBT+idSN4Qx/FdtkeKzJ' .
                'ruHW33rQ/TAfBgNVHSMEGDAWgBT+idSN4Qx/FdtkeKzJruHW33rQ/TAPBgNVHRMB' .
                'Af8EBTADAQH/MA0GCSqGSIb3DQEBCwUAA4IBAQAlh3jB/wHNjd0PYhWbzrOBL+1Y' .
                'dy6geZ60Yl/x5FEAtVim6BP06doZnYe76Lvsm5MJSPSJiC2G55mj7s2FSQ5uvhqF' .
                '9mNs0l2noi0unpKmuHWL2k9t3NaFMrPA9N4GI+WAv3SCPGaVg7i1R67Oj2qYIWj7' .
                '2oKXgO3hH7Hu5YO/yHWMroTbCcTceTaP1e19B/TokdzCdWJYLQjbCiulw6ospO0b' .
                'wV5QDc4U4FqDR68am8lHswnxQ3ZPFAT/7QnojaDk0otgKAJd1+dq2HvebtKhrAxV' .
                'wM0K8LW6oG7CbBZ7XdAA4tlL/MuYxZVfFOY0BITGUMgOBfSTaRaEgwf0r2Ml',
        ],
    ],
    'NameIDFormat' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    'validate.authnrequest' => false,
    'validate.logout' => false,
    'sign.logout' => false,
    'validate.signature' => false,
];
