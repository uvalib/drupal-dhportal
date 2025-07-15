# SAML Authentication Implementation Guide

This is the comprehensive implementation guide for SAML authentication in the drupal-dhportal project.

## 🎯 Quick Start

For a quick setup, use the universal scripts:

```bash
# 1. Set up SAML integration
./scripts/saml-setup/setup-saml-integration-container.sh

# 2. Set up account menu for dual login
./scripts/saml-setup/setup-account-menu-complete-container.sh
```

## 🏗️ Architecture Overview

### Production Architecture
```
UVA NetBadge IdP ←──── SAML Auth ────→ drupal-dhportal (SP)
(urn:mace:incommon:virginia.edu)      (Production Drupal site)
```

### Development Architecture  
```
drupal-netbadge (Test IdP) ←──── SAML Auth ────→ drupal-dhportal (SP)
(Local test container)                           (Development Drupal site)
```

## 🌍 Environment Support

This implementation supports three environments with automatic detection:

| Environment | Description | Script Behavior |
|-------------|-------------|-----------------|
| **DDEV** | Development with `ddev` commands | Uses `ddev drush` and `ddev exec` |
| **Container** | Direct container execution | Uses direct `drush` commands inside container |
| **Server** | Production server deployment | Adapts paths and uses production settings |

## � Quick Start

### 1. Automatic Dependency Checking

All scripts automatically check for required dependencies and provide installation guidance:

**Common Dependencies:**

- `envsubst` (from gettext package) - Template processing
- `drush` - Drupal configuration (auto-detected in DDEV)
- `openssl` - Certificate generation
- `jq` - JSON processing (AWS integration only)
- `aws` CLI - AWS Secrets Manager (optional)

**Installation Guidance:**

Scripts provide platform-specific installation commands for missing dependencies.

### 2. Core Scripts

- **`setup-saml-integration-container.sh`** - Main SAML setup (universal)
- **`setup-account-menu-complete-container.sh`** - Account menu setup (universal)  
- **`manage-saml-certificates.sh`** - Certificate management

### 2. Configuration Templates

Templates in `scripts/saml-setup/templates/`:
- **`config.php.template`** - SimpleSAMLphp main configuration
- **`authsources.php.template`** - Service Provider configuration
- **`saml20-idp-remote.php.template`** - Identity Provider metadata

### 3. Generated Configurations

The scripts generate these files automatically:
- `simplesamlphp/config/config.php`
- `simplesamlphp/config/authsources.php`  
- `simplesamlphp/metadata/saml20-idp-remote.php`
- `simplesamlphp/cert/server.crt` and `server.key`

## 🎓 UVA NetBadge Integration

### Production Configuration

**Entity IDs:**
- SP Entity ID: `{your-domain}/shibboleth` (must match virtual host)
- IdP Entity ID: `urn:mace:incommon:virginia.edu`

**Endpoints:**
- SSO URL: `https://shibidp.its.virginia.edu/idp/profile/SAML2/Redirect/SSO`
- SLO URL: `https://shibidp.its.virginia.edu/idp/profile/SAML2/Redirect/SLO`
- Metadata: `https://shibidp.its.virginia.edu/idp/shibboleth/uva-idp-metadata.xml`

**Required Attributes:**
- `uid` - User identifier
- `eduPersonPrincipalName` - Principal name
- `eduPersonAffiliation` - User role/affiliation
- `mail` - Email address

### Development Configuration

**Entity IDs:**
- SP Entity ID: `https://drupal-dhportal.ddev.site/shibboleth`
- IdP Entity ID: `https://drupal-netbadge.ddev.site/simplesaml/saml2/idp/metadata.php`

**Test Users (from drupal-netbadge container):**
- Student: `username=student, password=studentpass`
- Staff: `username=staff, password=staffpass`  
- Faculty: `username=faculty, password=facultypass`

## 🚀 Setup Procedures

### For DDEV Development

```bash
# 1. Start both containers
cd /path/to/drupal-netbadge && ddev start
cd /path/to/drupal-dhportal && ddev start

# 2. Run SAML setup
./scripts/saml-setup/setup-saml-integration-container.sh

# 3. Set up account menu
./scripts/saml-setup/setup-account-menu-complete-container.sh

# 4. Test the integration
# Visit: https://drupal-dhportal.ddev.site/test-saml-integration.php
```

### For Container/Server Deployment

```bash
# Inside the container/server
cd /var/www/html  # or /opt/drupal

# Run setup
./scripts/saml-setup/setup-saml-integration-container.sh

# Set up account menu  
./scripts/saml-setup/setup-account-menu-complete-container.sh
```

### For Production Deployment

```bash
# 1. Set environment variables
export SAML_DOMAIN="your-domain.virginia.edu"
export SAML_SECRET_SALT="your-secure-salt"
export SAML_ADMIN_PASSWORD="your-secure-password"

# 2. Run production setup
./scripts/saml-setup/setup-saml-integration-container.sh

# 3. Register with UVA ITS
# Use form at: https://virginia.service-now.com/esc?id=emp_taxonomy_topic&topic_id=123cf54e9359261081bcf5c56aba108d
```

## 🧪 Testing

### Test Generation

Generate test configurations for all environments:

```bash
./scripts/saml-setup/setup-saml-integration-container.sh --test-only
```

This creates `test-output/` with configurations for:
- `dev/` - Development environment
- `container/` - Container environment  
- `production/` - Production environment

### Manual Testing

1. **Access SimpleSAMLphp Admin:**
   - URL: `{your-site}/simplesaml/`
   - Check SP metadata and configuration

2. **Test SAML Flow:**
   - URL: `{your-site}/test-saml-integration.php`
   - Try login with test users

3. **Verify Account Menu:**
   - Check "My Profile" dropdown appears
   - Verify NetBadge and Local login options

## 🔐 Certificate Management

The system handles certificates automatically:

- **Development**: Self-signed certificates generated automatically
- **Production**: Environment variables or external certificate management
- **Renewal**: Handled by `manage-saml-certificates.sh`

## 📋 Post-Deployment Checklist

- [ ] SAML modules enabled (`simplesamlphp_auth`, `externalauth`)
- [ ] Configuration files generated and valid
- [ ] Certificates present and valid
- [ ] SimpleSAMLphp symlink created
- [ ] .htaccess rules configured
- [ ] Account menu configured with dual login
- [ ] Test authentication flow working
- [ ] Production: SP registered with UVA ITS

## 🆘 Troubleshooting

### Common Issues

**Configuration files not found:**
```bash
# Regenerate configurations
./scripts/saml-setup/setup-saml-integration-container.sh
```

**Certificate errors:**
```bash
# Regenerate certificates
./scripts/saml-setup/manage-saml-certificates.sh
```

**SimpleSAMLphp not accessible:**
- Check symlink: `ls -la web/simplesaml`
- Check permissions: `chmod -R 755 vendor/simplesamlphp/simplesamlphp/public`

### Logs and Debugging

- **SimpleSAMLphp Logs**: `simplesamlphp/log/`
- **Drupal Logs**: Check Recent log messages in admin
- **Apache/Nginx Logs**: Check web server error logs

## 📚 Additional Documentation

For specific details, see:

- **`CERTIFICATE_MANAGEMENT.md`** - Certificate strategy details
- **`ACCOUNT_MENU_FINAL_SUMMARY.md`** - Account menu implementation details
- **`SAML_TESTING_SUITE.md`** - Comprehensive testing procedures
- **`SAML_CONFIGURATION_FILES.md`** - Configuration file structure
