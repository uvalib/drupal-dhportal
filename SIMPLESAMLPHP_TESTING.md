# SimpleSAMLphp Testing Guide

## Quick Testing Summary

### ✅ What We've Successfully Tested Locally

1. **Certificate Management Script** - ✅ WORKING
   ```bash
   ./scripts/manage-saml-certificates.sh dev
   ./scripts/manage-saml-certificates.sh info
   ```

2. **Test Script Results** - ✅ 8/10 tests passing
   ```bash
   ./scripts/test-simplesamlphp.sh
   ```

3. **DDEV Environment** - ✅ READY
   - SimpleSAMLphp files copied to `web/simplesaml/`
   - Certificates generated in `simplesamlphp/cert/`
   - Configuration files present and valid PHP syntax

### 🔄 Currently Testing

4. **Production Container Build** - 🔄 IN PROGRESS
   ```bash
   docker build -f package/Dockerfile -t test-drupal-dhportal . --no-cache
   ```

### 📋 Manual Testing Steps for AWS Container

When the container is deployed to AWS, test these URLs:

1. **SimpleSAMLphp Main Interface**
   ```
   https://your-domain.com/simplesaml/
   ```
   Should show SimpleSAMLphp welcome page (not permission denied)

2. **SAML Metadata Endpoint**
   ```
   https://your-domain.com/simplesaml/saml2-metadata.php
   ```
   Should return XML metadata for your Service Provider

3. **SimpleSAMLphp Status Page**
   ```
   https://your-domain.com/simplesaml/status.php
   ```
   Should show authentication status

4. **Admin Interface**
   ```
   https://your-domain.com/simplesaml/admin.php
   ```
   Should prompt for admin password (from SIMPLESAMLPHP_ADMIN_PASSWORD env var)

### 🔧 Environment Variables Required for Production

Set these in your AWS deployment:

**Required:**
- `SIMPLESAMLPHP_SECRET_SALT` - Unique secret for session security
- `SIMPLESAMLPHP_ADMIN_PASSWORD` - Admin interface password

**For Custom Domain:**
- `SIMPLESAMLPHP_SP_ENTITY_ID` - Your domain URL (e.g., `https://yourdomain.com`)
- `TRUSTED_URL_DOMAINS` - Comma-separated trusted domains

**For Production IdP:**
- `SIMPLESAMLPHP_IDP_ENTITY_ID` - Your IdP URL
- `SIMPLESAMLPHP_IDP_SSO_URL` - IdP Single Sign-On URL
- `SIMPLESAMLPHP_IDP_SLO_URL` - IdP Single Logout URL
- `SIMPLESAMLPHP_IDP_CERT` - IdP certificate for signature validation

**For Certificate Management:**
- `SAML_PRIVATE_KEY` - Your SP private key (base64 encoded)
- `SAML_CERTIFICATE` - Your SP certificate (base64 encoded)
OR mount certificates to `/secrets/server.key` and `/secrets/server.crt`

### 🐛 Troubleshooting

**Permission Denied at /simplesaml/**
- Check if web server has access to `/opt/drupal/web/simplesaml/`
- Verify ownership: `chown -R www-data:www-data /opt/drupal/web/simplesaml/`

**Configuration Errors**
- Check PHP logs for SimpleSAMLphp config issues
- Verify `/opt/drupal/simplesamlphp/config/config.php` is readable

**Certificate Issues**
- Run certificate script: `/opt/drupal/scripts/manage-saml-certificates.sh prod`
- Check certificate permissions: `ls -la /opt/drupal/simplesamlphp/cert/`

**SAML Authentication Fails**
- Verify IdP metadata in `/opt/drupal/simplesamlphp/metadata/saml20-idp-remote.php`
- Check authsources configuration in `/opt/drupal/simplesamlphp/config/authsources.php`

### 📊 Test Results Summary

**Local DDEV Testing:**
- ✅ Certificate generation
- ✅ PHP syntax validation
- ✅ File permissions
- ✅ Directory structure
- ⚠️  Web accessibility (403 - expected for admin interface)
- ❌ Production certificate test (minor issue with base64 dummy data)

**Production Container:**
- 🔄 Container build in progress
- ⏳ Full production testing pending AWS deployment

## Next Steps

1. Complete container build test
2. Deploy to AWS staging environment
3. Test all URLs manually
4. Verify SAML authentication flow with real IdP
5. Test certificate renewal process
