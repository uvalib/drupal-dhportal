# SAML Redirect Loop Troubleshooting Guide

## 🔄 Understanding SAML Redirect Loops

A SAML redirect loop occurs when the Service Provider (SP) and Identity Provider (IdP) keep redirecting users back and forth without completing authentication. This usually indicates a configuration mismatch.

## 🔍 Immediate Diagnostic Steps

### 1. Access the Debug Tool
Visit: `https://dh-drupal.internal.lib.virginia.edu/saml-debug.php`

This comprehensive diagnostic tool will check:
- ✅ SimpleSAMLphp configuration
- ✅ SP configuration 
- ✅ IdP metadata
- ✅ Certificate validation
- ✅ URL configurations
- ✅ Common redirect loop causes

### 2. Check SimpleSAMLphp Admin Interface
Visit: `https://dh-drupal.internal.lib.virginia.edu/simplesaml/`

This will show if SimpleSAMLphp is properly configured and accessible.

## 🚨 Most Common Causes & Solutions

### 1. **Entity ID Mismatch**

**Problem**: SP Entity ID doesn't match what the IdP expects

**Check**: 
```bash
# In SP authsources.php, verify:
'entityID' => 'https://dh-drupal.internal.lib.virginia.edu/simplesaml/module.php/saml/sp/metadata.php/default-sp'
```

**Solution**: Ensure the Entity ID exactly matches:
- Current domain: `dh-drupal.internal.lib.virginia.edu`
- Protocol: `https://`
- Path: matches SP metadata URL

### 2. **Missing or Incorrect IdP Metadata**

**Problem**: SP can't find or validate the IdP

**Check**: 
- `metadata/saml20-idp-remote.php` exists
- Contains correct NetBadge IdP configuration
- IdP entity ID matches what's configured in SP

**Solution**: Update IdP metadata with correct NetBadge configuration:
```php
// In metadata/saml20-idp-remote.php
$metadata['https://netbadge.virginia.edu/idp/shibboleth'] = [
    'SingleSignOnService' => 'https://netbadge.virginia.edu/idp/profile/SAML2/Redirect/SSO',
    'SingleLogoutService' => 'https://netbadge.virginia.edu/idp/profile/SAML2/Redirect/SLO',
    // ... other NetBadge configuration
];
```

### 3. **Certificate Issues**

**Problem**: SP certificates are missing, expired, or incorrect

**Check**:
```bash
# Verify certificates exist
ls -la /var/www/html/simplesamlphp/cert/

# Check certificate validity
openssl x509 -in /var/www/html/simplesamlphp/cert/saml-sp.crt -text -noout
```

**Solution**: Use production certificates generated with infrastructure keys:
```bash
# Should exist in production:
/var/www/html/simplesamlphp/cert/saml-sp.crt        # Public certificate
/var/www/html/simplesamlphp/cert/saml-sp.key        # Private key (600 permissions)
```

### 4. **URL Configuration Issues**

**Problem**: Base URLs, entity IDs, or callback URLs are incorrect

**Check**:
- SimpleSAMLphp `baseurlpath` setting
- SP entity ID uses correct domain
- AssertionConsumerService URLs are accessible

**Solution**: Verify configuration matches production environment:
```php
// In config.php
'baseurlpath' => '/simplesaml/',

// In authsources.php
'entityID' => 'https://dh-drupal.internal.lib.virginia.edu/simplesaml/module.php/saml/sp/metadata.php/default-sp',
```

### 5. **NetBadge IdP Configuration**

**Problem**: NetBadge IdP doesn't recognize this SP

**Check**: Has your SP metadata been registered with UVA NetBadge admin?

**Solution**: 
1. Generate SP metadata: `https://dh-drupal.internal.lib.virginia.edu/simplesaml/module.php/saml/sp/metadata.php/default-sp`
2. Send metadata to NetBadge administrator
3. Verify SP is registered in NetBadge IdP

## 🔧 Step-by-Step Debugging Process

### Step 1: Verify Basic Configuration
```bash
# Check if SimpleSAMLphp is accessible
curl -I https://dh-drupal.internal.lib.virginia.edu/simplesaml/

# Check SP metadata is generated
curl -I https://dh-drupal.internal.lib.virginia.edu/simplesaml/module.php/saml/sp/metadata.php/default-sp
```

### Step 2: Test SP Configuration
1. Visit SimpleSAMLphp admin: `/simplesaml/`
2. Go to "Authentication" → "Test configured authentication sources"
3. Try "default-sp" - this will show exact error messages

### Step 3: Check Logs
```bash
# Check SimpleSAMLphp logs
tail -f /var/www/html/simplesamlphp/log/simplesamlphp.log

# Check web server logs
tail -f /var/log/apache2/error.log
# or
tail -f /var/log/nginx/error.log
```

### Step 4: Validate Certificates
```bash
# Check certificate and key match
openssl x509 -noout -modulus -in /var/www/html/simplesamlphp/cert/saml-sp.crt | openssl md5
openssl rsa -noout -modulus -in /var/www/html/simplesamlphp/cert/saml-sp.key | openssl md5
# These should produce the same hash
```

## 🛠️ Production Environment Specific Fixes

### 1. Ensure Production Certificates Are Installed
```bash
# Verify certificates are from the static certificate strategy
./scripts/manage-saml-certificates-enhanced.sh production
```

### 2. Check Infrastructure Integration
```bash
# Verify Terraform private keys are properly mounted/accessible
# Check that certificate management script can find infrastructure keys
```

### 3. Validate Production URLs
- Entity ID should use production domain: `dh-drupal.internal.lib.virginia.edu`
- All URLs should use `https://`
- NetBadge IdP URLs should be production NetBadge endpoints

## 📞 If Still Having Issues

### Get Detailed Error Information
1. Run the diagnostic script: `/saml-debug.php`
2. Check SimpleSAMLphp admin interface logs
3. Review web server error logs during authentication attempt

### Configuration Files to Review
```
/var/www/html/simplesamlphp/config/config.php              # Base configuration
/var/www/html/simplesamlphp/config/authsources.php         # SP configuration  
/var/www/html/simplesamlphp/metadata/saml20-idp-remote.php # IdP metadata
/var/www/html/simplesamlphp/cert/                          # Certificates
```

### Contact Information
- **NetBadge Support**: For IdP-side configuration issues
- **UVA CA**: For certificate-related issues
- **Local System Admin**: For server configuration and certificate deployment

## 🎯 Quick Fix Checklist

When experiencing redirect loops, check these in order:

- [ ] SP Entity ID matches current domain and protocol
- [ ] IdP metadata is present and contains correct NetBadge configuration
- [ ] SP certificates exist and are valid
- [ ] Certificate private key permissions are 600
- [ ] SimpleSAMLphp base URL path is correct
- [ ] SP metadata has been registered with NetBadge admin
- [ ] All URLs use HTTPS in production
- [ ] No entity ID conflicts between environments

Run the diagnostic script first - it will identify most of these issues automatically.
