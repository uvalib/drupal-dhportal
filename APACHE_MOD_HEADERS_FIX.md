# Apache mod_headers Fix for SimpleSAMLphp

## Problem

SimpleSAMLphp web interface was failing with Apache error:

```text
[core:alert] Invalid command 'Header', perhaps misspelled or defined by a module not included in the server configuration
```

This occurred because the SimpleSAMLphp `.htaccess` file contained `Header` directives for security headers, but the Apache `mod_headers` module was not enabled.

## Root Cause Analysis

1. **Missing Apache Module**: The `mod_headers` module was not enabled in the Docker container
2. **Unsafe .htaccess Configuration**: Header directives were not wrapped in module availability checks
3. **Overly Restrictive Access Rules**: The `.htaccess` file had a wildcard deny rule that blocked access to all files, including explicitly allowed ones

## Solution Implemented

### 1. Enable Apache mod_headers Module

**File**: `package/Dockerfile`

```dockerfile
# Enable Apache mod_headers module for SimpleSAMLphp security headers
RUN a2enmod headers
```

### 2. Make .htaccess More Defensive

**File**: `web/simplesaml/.htaccess` and `package/data/files/opt/drupal/web/simplesaml/.htaccess`

**Before**:

```apache
# Security headers
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
Header always set X-XSS-Protection "1; mode=block"
```

**After**:

```apache
# Security headers (requires mod_headers)
<IfModule mod_headers.c>
    Header always set X-Frame-Options DENY
    Header always set X-Content-Type-Options nosniff
    Header always set X-XSS-Protection "1; mode=block"
</IfModule>
```

### 3. Fix Access Control Rules

**Before**:

```apache
# Default deny for other files
<Files "*">
    Require all denied
</Files>

# Override for CSS, JS, and image files if they exist
<FilesMatch "\.(css|js|png|jpg|jpeg|gif|ico)$">
    Require all granted
</FilesMatch>
```

**After**:

```apache
# Allow access to CSS, JS, and image files
<FilesMatch "\.(css|js|png|jpg|jpeg|gif|ico)$">
    Require all granted
</FilesMatch>

# Deny access to sensitive files
<FilesMatch "\.(conf|ini|log|bak|old|tmp)$">
    Require all denied
</FilesMatch>
```

## Post-Fix Issues Discovered

After resolving the Apache mod_headers issue, new SimpleSAMLphp configuration issues were discovered:

### Session Cookie Name Conflict

**Error**:
```text
SimpleSAMLphp WARNING: There is already a PHP session with the same name as SimpleSAMLphp's session, or the 'session.phpsession.cookiename' configuration option is not set.
```

**Cause**: SimpleSAMLphp and Drupal are using the same session cookie name, causing conflicts.

**Solution**: Added explicit session cookie configuration to avoid conflicts:

```php
// Session configuration  
'session.cookie.name' => 'SimpleSAMLSessionID',
'session.phpsession.cookiename' => 'SimpleSAMLphpSession',
```

### Authentication Session Issues

**Error**:

```text
SimpleSAMLphp DEBUG: Session: 'default-sp' not valid because we are not authenticated.
```

**Cause**: This is expected behavior when no user is authenticated yet - it's a debug message indicating the SAML authentication flow is ready to begin.

## Verification

### Local Testing (DDEV)

```bash
# Check mod_headers is enabled
ddev exec "apache2ctl -M | grep headers"
# Output: headers_module (shared)

# Test SimpleSAMLphp interface
curl -k -s -o /dev/null -w "%{http_code}" https://drupal-dhportal.ddev.site:8443/simplesaml/
# Output: 200

# Verify security headers
curl -k -I https://drupal-dhportal.ddev.site:8443/simplesaml/ | grep -E "(x-frame-options|x-content-type-options|x-xss-protection)"
# Output:
# x-content-type-options: nosniff
# x-frame-options: DENY
# x-xss-protection: 1; mode=block
```

### Production Impact

- Docker containers built from the updated Dockerfile will have `mod_headers` enabled
- SimpleSAMLphp web interface will be accessible without Apache errors
- Security headers will be properly sent to browsers
- SAML authentication workflow can proceed normally

## Files Modified

### Apache mod_headers Fix

- `package/Dockerfile` - Added `RUN a2enmod headers`
- `web/simplesaml/.htaccess` - Wrapped Header directives, fixed access rules
- `package/data/files/opt/drupal/web/simplesaml/.htaccess` - Same fixes for container deployment

### Session Cookie Conflict Fix

- `simplesamlphp/config/config.php` - Added `session.phpsession.cookiename` configuration for DDEV
- `package/data/files/opt/drupal/simplesamlphp/config/config.php` - Added session configuration for production deployment

## Next Steps

1. ✅ **Completed**: Enable Apache mod_headers in deployment
2. ✅ **Completed**: Fix .htaccess configuration issues
3. ✅ **Completed**: Validate SimpleSAMLphp web interface accessibility
4. **Next**: Deploy to staging/production and test SAML authentication flow
5. **Next**: Register SP metadata with NetBadge IDP for production

## Related Documentation

- [SAML Certificate Lifecycle](SAML_CERTIFICATE_LIFECYCLE.md)
- [SAML Implementation Summary](SAML_IMPLEMENTATION_SUMMARY.md)
- [Testing Guide](TESTING_GUIDE.md)
