# SAML Testing Suite

This directory contains comprehensive tests for the SAML authentication integration between the drupal-dhportal (SP) and drupal-netbadge (IdP) DDEV projects.

## Overview

The SAML integration includes:
- **Service Provider (SP)**: drupal-dhportal - Drupal 10 site with SimpleSAMLphp Auth module
- **Identity Provider (IdP)**: drupal-netbadge - SimpleSAMLphp SAML IdP with test users

## Test Scripts

### 1. `test-saml-flow.sh`
Tests the complete HTTPS SAML authentication flow:
- SP-initiated login redirects
- IdP metadata accessibility
- Login form presentation
- Cookie domain configuration

```bash
cd saml-test && ./test-saml-flow.sh
```

### 2. `test-saml-signing.sh`
Tests cryptographic signing implementation:
- Certificate and private key validation
- IdP signing configuration
- SP signature validation setup
- Certificate/key pair matching

```bash
cd saml-test && ./test-saml-signing.sh
```

### 3. `test-saml-attributes.sh`
Tests SAML attribute mapping:
- IdP attribute configuration (eduPersonPrincipalName, mail, etc.)
- Drupal attribute expectations
- User attribute mappings for test accounts

```bash
cd saml-test && ./test-saml-attributes.sh
```

### 4. `test-simplesaml-direct.php`
Direct SimpleSAMLphp configuration test:
- Tests SimpleSAMLphp library loading
- Configuration validation
- Auth instance creation

```bash
# From drupal-dhportal web root:
php saml-test/test-simplesaml-direct.php
```

### 5. `comprehensive-saml-test.php`
Web-based comprehensive SAML test suite:
- Integration testing from web context
- Configuration validation
- Attribute checking

```bash
# Access via browser:
https://drupal-dhportal.ddev.site:8443/saml-test/comprehensive-saml-test.php
```

## SAML Configuration

### Service Provider (drupal-dhportal)
- **Entity ID**: `https://drupal-dhportal.ddev.site:8443`
- **Login URL**: `https://drupal-dhportal.ddev.site:8443/saml_login`
- **Config Files**:
  - `simplesaml-config.php`
  - `simplesaml-authsources.php`
  - `simplesaml-idp-remote.php`

### Identity Provider (drupal-netbadge)
- **Entity ID**: `https://drupal-netbadge.ddev.site:8443/simplesaml/saml2/idp/metadata.php`
- **Test Users**:
  - `student/studentpass` → `student@example.edu`
  - `staff/staffpass` → `staff@example.edu`
  - `faculty/facultypass` → `faculty@example.edu`

## Security Features

### Cryptographic Signing
- **Algorithm**: RSA-SHA256
- **IdP Signs**: SAML responses and assertions
- **SP Validates**: All signatures using IdP certificate
- **Certificate**: Self-signed for development

### Attribute Mapping
- **Username**: `eduPersonPrincipalName` (e.g., `student@example.edu`)
- **Email**: `mail` (e.g., `student@example.edu`)
- **Affiliation**: `eduPersonAffiliation` (e.g., `member`, `student`)
- **Display Name**: `displayName` (e.g., `Test Student`)

## Browser Testing

1. **Start SAML Login**:
   ```
   https://drupal-dhportal.ddev.site:8443/saml_login
   ```

2. **Accept Certificate Warnings** (self-signed certs in development)

3. **Login with Test Credentials**:
   - Username: `student`
   - Password: `studentpass`

4. **Expected Result**:
   - Successful authentication
   - Redirect back to Drupal
   - User created/logged in with username `student@example.edu`

## Troubleshooting

### Common Issues

1. **"Missing cookie" error**:
   - Cookie domain issues
   - Check session configuration in configs

2. **"Cannot retrieve metadata" error**:
   - IdP/SP metadata mismatch
   - Check entity IDs match

3. **"Missing certificate" error**:
   - Signature validation issues
   - Check certificate configuration

4. **"No valid eduPersonPrincipalName attribute" error**:
   - Attribute mapping issues
   - Check IdP user attributes

### Debug Commands

```bash
# Check DDEV status
cd /Users/ys2n/Code/ddev/drupal-dhportal && ddev status
cd /Users/ys2n/Code/ddev/drupal-netbadge && ddev status

# Check Drupal SAML config
cd /Users/ys2n/Code/ddev/drupal-dhportal && ddev drush config:get simplesamlphp_auth.settings

# Test direct SAML endpoint
curl -k -I -L "https://drupal-dhportal.ddev.site:8443/saml_login"
```

## File Structure

```
saml-test/
├── README.md                          # This file
├── test-saml-flow.sh                  # HTTPS flow tests
├── test-saml-signing.sh               # Signing/crypto tests
├── test-saml-attributes.sh            # Attribute mapping tests
├── test-simplesaml-direct.php         # Direct library tests
└── comprehensive-saml-test.php        # Web-based integration tests
```

## Next Steps

After successful testing:
1. Commit all SAML configuration to git
2. Document production deployment requirements
3. Configure production certificates
4. Set up real user directory integration
