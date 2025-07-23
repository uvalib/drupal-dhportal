# SimpleSAMLphp Environment Configuration Implementation

## Overview
This document summarizes the implementation of environment-specific SimpleSAMLphp configuration for the Digital Humanities Portal project, addressing deployment issues and implementing comprehensive security improvements for AWS load balancer environments.

## Problem Statement
- **Original Issue**: Apache mod_headers error in SimpleSAMLphp web interface
- **Root Cause**: Missing mod_headers module and overly restrictive .htaccess rules
- **Deployment Issue**: AWS environments receiving DDEV configs instead of environment-appropriate configurations
- **Security Issues**: Missing admin authentication, weak default passwords, improper HTTPS detection behind load balancers
- **Solution**: Implemented Ansible-based environment management with comprehensive security hardening

## Architecture

### Three-Tier Environment Strategy
1. **DDEV (Local Development)**
   - Configuration: Git-managed files in `simplesamlphp/config/` directory
   - Domain: `*.ddev.site`
   - Security: Relaxed for development (unsecured cookies, debug logging)
   
2. **AWS Staging Environment** 
   - Configuration: Ansible templates in `terraform-infrastructure/staging/`
   - Domain: `dhportal-dev.internal.lib.virginia.edu`
   - Security: Production-like with INFO logging, strong credentials
   
3. **AWS Production Environment**
   - Configuration: Ansible templates in `terraform-infrastructure/production.new/`
   - Domain: `dh.library.virginia.edu`
   - Security: Maximum security (NOTICE logging, assertion encryption, strong credentials)

## Security Enhancements (Latest Implementation)

### Load Balancer HTTPS Configuration

**Challenge**: AWS load balancers terminate SSL, making internal traffic HTTP while requiring HTTPS-only cookies for security.

**Solution**: Configure SimpleSAMLphp with proper HTTPS base URLs:

```php
// Basic configuration - Force HTTPS base URL for load balancer environments
'baseurlpath' => 'https://{{ staging_domain | default("dhportal-dev.internal.lib.virginia.edu") }}/simplesaml/',

// Application configuration - critical for load balancer HTTPS detection
'application' => [
    'baseURL' => 'https://{{ staging_domain | default("dhportal-dev.internal.lib.virginia.edu") }}/',
],

// Maintain secure cookies as SimpleSAMLphp now knows it's HTTPS
'session.cookie.secure' => true, // Force secure cookies (HTTPS only)
```

**Key Points**:
- SimpleSAMLphp deliberately ignores `X-Forwarded-*` headers for security
- The proper solution requires both `baseurlpath` and `application.baseURL` configured with HTTPS
- This tells SimpleSAMLphp the canonical HTTPS URLs even when internal traffic is HTTP
- Secure cookies work correctly once SimpleSAMLphp knows it's in an HTTPS environment

### Container Environment Security

**Implementation**: Strong credential management using UVA Library container environment pattern:

- Staging: `container_1.env` with 32-character admin password and secret salt
- Production: `container_0.env` with production-specific strong credentials
- Variables loaded by Ansible during deployment, eliminating plaintext storage

### Admin Authentication Security

**Problem**: SimpleSAMLphp v2.x requires explicit admin authentication source configuration.

**Solution**: Added admin auth source to all Ansible templates:

```php
// Admin authentication - required for SimpleSAMLphp v2.x
'auth.adminpassword' => '{{ simplesamlphp_admin_password }}',
'admin.protectindexpage' => true,
'admin.protectmetadata' => true,
'admin.requirehttps' => true,
'admin.forcehttps' => true,
```

### Recent Security Fixes (Latest Commits)

**Latest Updates - July 2025**:

#### Commit `4bf4f7308` - Fix CSS/JavaScript Mixed Content Issues
**Problem**: SimpleSAMLphp pages were completely unstyled due to mixed content blocking (HTTPS pages loading HTTP assets).

**Root Cause**: Behind AWS load balancers that terminate SSL, SimpleSAMLphp was generating HTTP URLs for CSS and JavaScript, causing browsers to block these assets.

**Solution**: Use full HTTPS URL in `baseurlpath` per official SimpleSAMLphp documentation:

```php
// Official SimpleSAMLphp reverse proxy configuration
'baseurlpath' => 'https://{{ staging_domain | default("dhportal-dev.internal.lib.virginia.edu") }}/simplesaml/',
```

**Key Documentation Finding**: SimpleSAMLphp documentation explicitly states:
> "if you are running behind a reverse proxy and you are offloading TLS to it, the proper way to tell SimpleSAMLphp that its base URL should use HTTPS is to set the `baseurlpath` configuration option properly. SimpleSAMLphp deliberately **ignores** the `X-Forwarded-*` set of headers that your proxy might be setting, so **do not rely on those**."

#### Commit `9564b6038` - Fix NameIDPolicy Array Configuration
**Problem**: SimpleSAMLphp 2.x assertion error: "NameIDPolicy is not an array"

**Solution**: Updated authsources.php templates to use proper array format:

```php
// Old (SimpleSAMLphp 1.x format)
'NameIDPolicy' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',

// New (SimpleSAMLphp 2.x format)
'NameIDPolicy' => [
    'Format' => 'urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress',
    'AllowCreate' => true,
],
```

#### Commit `4499c1046` - Fix Argon2 Password Hash Escaping
**Problem**: Ansible deployment failure due to YAML parsing errors with Argon2 password hashes.

**Root Cause**: Dollar signs (`$`) in Argon2 hashes were treated as YAML escape characters when in double quotes.

**Solution**: Use single quotes for Argon2 hashes in container environment files:

```bash
# Fixed escaping issue
SIMPLESAMLPHP_ADMIN_PASSWORD: '$argon2id$v=19$m=64,t=4,p=1$...'
```

#### Commit `92f074d74` - Implement Argon2 Password Hashing
**Problem**: "Admin password not set to a hashed value" error in SimpleSAMLphp 2.x.

**Solution**: Generated proper Argon2 password hashes using SimpleSAMLphp's pwgen.php utility:

```bash
# Generate Argon2 hash
ddev exec php vendor/simplesamlphp/simplesamlphp/bin/pwgen.php
```

**Security Enhancement**: Replaced plain text passwords with Argon2id hashes in container environment files.

#### Password Manager Interference Resolution
**Issue**: Admin login form username field disabled by browser password managers.

**Root Cause**: SimpleSAMLphp `core:AdminPassword` authentication source pre-fills username as "admin" and disables the field (correct behavior).

**Solution**: Use private browsing mode for admin access, or temporarily disable password manager for the domain.

**Commit**: `12e39af84` - Add application.baseURL for proper HTTPS detection

**Issues Resolved**:

1. "Setting secure cookie on plain HTTP is not allowed" error
2. SimpleSAMLphp not detecting HTTPS behind AWS load balancer
3. Incorrect reliance on proxy headers that SimpleSAMLphp ignores

**Implementation**:

- Added `application.baseURL` configuration with HTTPS URLs for both environments
- Removed ineffective proxy configuration (SimpleSAMLphp deliberately ignores X-Forwarded headers)
- Based on official SimpleSAMLphp documentation and GitHub issue #879
- Maintained `session.cookie.secure => true` for security while enabling proper HTTPS detection

## Implementation Details

### 1. Apache mod_headers Fix
**Files Modified:**
- `/Users/ys2n/Code/ddev/drupal-dhportal/web/simplesaml/.htaccess`

**Changes:**
- Wrapped header directives in `<IfModule mod_headers.c>` checks
- Removed overly broad `deny from all` rule
- Added proper access control for web interface

**Docker Integration:**
- Enabled mod_headers in Dockerfile for container environments
- Ensured consistency across development and production containers

### 2. Ansible Environment Management

#### Staging Environment
**Location:** `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/staging/ansible/`

**Files Created/Modified:**
- `templates/simplesamlphp/config.php.j2` - Main configuration template
- `templates/simplesamlphp/authsources.php.j2` - Authentication sources template  
- `container_1.env` - Container environment variables
- `deploy_backend_1.yml` - Updated deployment playbook

**Configuration Highlights:**
- Logging level: `SimpleSAML\Logger::INFO`
- Admin protection: `true`
- Session duration: 8 hours
- Secure cookies: `true`
- Domain: `{{ staging_domain | default("dhportal-dev.internal.lib.virginia.edu") }}`

#### Production Environment
**Location:** `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/production.new/ansible/`

**Files Created/Modified:**
- `templates/simplesamlphp/config.php.j2` - Main configuration template
- `templates/simplesamlphp/authsources.php.j2` - Authentication sources template
- `container_0.env` - Container environment variables  
- `deploy_backend.yml` - Updated deployment playbook

**Configuration Highlights:**
- Logging level: `SimpleSAML\Logger::NOTICE` (minimal)
- Admin protection: `true`
- Session duration: 4 hours
- Secure cookies: `true`
- Additional security: Assertion encryption, signed logout
- Domain: `{{ production_domain | default("dh.library.virginia.edu") }}`

### 3. Environment Variables

#### Container Environment Variables
Each environment defines SimpleSAMLphp-specific variables:

```bash
# Common variables
DEPLOYMENT_ENVIRONMENT=staging|production
SIMPLESAMLPHP_SECRET_SALT=<environment-specific-salt>
SIMPLESAMLPHP_ADMIN_PASSWORD=<hashed-password>
SIMPLESAMLPHP_DOMAIN=<environment-domain>
SIMPLESAMLPHP_BASE_URL=https://<domain>

# Environment-specific variables
SIMPLESAMLPHP_SESSION_DURATION=<hours>
SIMPLESAMLPHP_LOGGING_LEVEL=INFO|NOTICE
SIMPLESAMLPHP_SECURE_COOKIES=true
SIMPLESAMLPHP_ADMIN_PROTECT_METADATA=true
```

#### Jinja2 Template Variables
Templates use Ansible variables for dynamic configuration:
- `{{ simplesamlphp_secret_salt }}`
- `{{ simplesamlphp_admin_password }}`
- `{{ staging_domain }}` / `{{ production_domain }}`
- `{{ simplesamlphp_session_duration }}`
- Environment-specific security settings

### 4. Deployment Process

#### Ansible Deployment Tasks
Both environments include SimpleSAMLphp deployment tasks in their playbooks:

```yaml
# Copy SimpleSAMLphp configuration templates
- name: Create SimpleSAMLphp config directory
  file:
    path: "{{ backend_root }}/simplesamlphp/config"
    state: directory
    mode: '0755'

- name: Deploy SimpleSAMLphp config.php
  template:
    src: templates/simplesamlphp/config.php.j2
    dest: "{{ backend_root }}/simplesamlphp/config/config.php"
    mode: '0644'

- name: Deploy SimpleSAMLphp authsources.php  
  template:
    src: templates/simplesamlphp/authsources.php.j2
    dest: "{{ backend_root }}/simplesamlphp/config/authsources.php"
    mode: '0644'
```

#### Deployment Commands
**Staging:**
```bash
cd /Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/staging/ansible
ansible-playbook deploy_backend_1.yml
```

**Production:**
```bash
cd /Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/production.new/ansible
ansible-playbook deploy_backend.yml
```

#### Critical Deployment Sequence
**⚠️ IMPORTANT**: When making changes that span both repositories, always commit and push terraform-infrastructure changes BEFORE drupal-dhportal changes:

1. **First**: Commit and push terraform-infrastructure changes
2. **Second**: Commit and push drupal-dhportal changes

**Reason**: The drupal-dhportal repository has CI/CD triggers that will immediately start a build process. If the terraform-infrastructure changes aren't already deployed, the CI/CD build may fail or deploy with outdated configurations.

## Security Considerations

### Environment-Specific Security Settings

#### DDEV (Development)
- Unsecured cookies for local testing
- Debug-level logging
- Admin protection disabled
- Relaxed security for development workflow

#### Staging
- Secure cookies enabled
- INFO-level logging for debugging
- Admin protection enabled
- Production-like security with debugging capabilities

#### Production
- Maximum security settings
- NOTICE-level logging (minimal)
- Admin protection enabled
- Assertion encryption enabled
- Signed logout requests
- Short session duration (4 hours)

### Access Control
- SimpleSAMLphp web interface properly protected via .htaccess
- Admin pages require authentication
- Metadata endpoints protected in production
- Environment-specific access patterns

## Testing Strategy

### Validation Scripts
Created comprehensive testing scripts:

1. **`scripts/test-environment-configuration.sh`**
   - Validates Ansible template existence
   - Checks container environment variables
   - Verifies deployment playbook configuration
   - Tests environment-specific settings

2. **`scripts/validate-aws-deployment.sh`**
   - Tests AWS endpoint accessibility
   - Validates SimpleSAMLphp interface availability
   - Checks metadata endpoint responses
   - Provides deployment command guidance

### Testing Process
1. **DDEV Testing**: Verify local SimpleSAMLphp interface functionality
2. **Staging Validation**: Deploy and test staging environment configuration
3. **Production Deployment**: Deploy to production after staging validation
4. **SAML Integration**: Register with NetBadge IDP and test authentication flow

## Next Steps

### Immediate Actions
1. ✅ **DDEV Environment**: SimpleSAMLphp interface accessible and functional
2. 🔄 **Staging Deployment**: Deploy using Ansible and test configuration
3. 🔄 **Staging Validation**: Test SAML authentication flow
4. 🔄 **Production Deployment**: Deploy after staging validation
5. 🔄 **NetBadge Registration**: Submit metadata to UVA NetBadge IDP

### Integration Steps
1. **Service Provider Registration**
   - Generate staging metadata: `https://dhportal-dev.internal.lib.virginia.edu/simplesaml/module.php/saml/sp/metadata.php/default-sp`
   - Generate production metadata: `https://dh.library.virginia.edu/simplesaml/module.php/saml/sp/metadata.php/default-sp`
   - Submit to NetBadge administrators for IDP configuration

2. **Authentication Flow Testing**
   - Test user login via NetBadge
   - Verify attribute mapping (username, email, groups)
   - Test logout functionality
   - Validate session management

3. **Monitoring and Maintenance**
   - Monitor SimpleSAMLphp logs in each environment
   - Set up log rotation and retention policies
   - Document troubleshooting procedures
   - Plan certificate renewal processes

## File Summary

### Modified Files
- `/Users/ys2n/Code/ddev/drupal-dhportal/web/simplesaml/.htaccess` - Fixed Apache mod_headers compatibility
- `/Users/ys2n/Code/ddev/drupal-dhportal/package/Dockerfile` - Removed obsolete saml-config references
- `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/staging/ansible/container_1.env` - Added SimpleSAMLphp environment variables
- `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/staging/ansible/deploy_backend_1.yml` - Added SimpleSAMLphp deployment tasks
- `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/production.new/ansible/container_0.env` - Added SimpleSAMLphp environment variables
- `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/production.new/ansible/deploy_backend.yml` - Added SimpleSAMLphp deployment tasks

### Created Files
- `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/staging/ansible/templates/simplesamlphp/config.php.j2` - Staging configuration template
- `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/staging/ansible/templates/simplesamlphp/authsources.php.j2` - Staging authentication sources template
- `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/production.new/ansible/templates/simplesamlphp/config.php.j2` - Production configuration template
- `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/production.new/ansible/templates/simplesamlphp/authsources.php.j2` - Production authentication sources template
- `/Users/ys2n/Code/ddev/drupal-dhportal/scripts/test-environment-configuration.sh` - Environment configuration test script
- `/Users/ys2n/Code/ddev/drupal-dhportal/scripts/validate-aws-deployment.sh` - AWS deployment validation script
- `/Users/ys2n/Code/ddev/drupal-dhportal/SIMPLESAML_ENVIRONMENT_IMPLEMENTATION.md` - This documentation file

## Cleanup Summary

### Files/Directories Removed from drupal-dhportal

After moving environment-specific configurations to terraform-infrastructure, the following obsolete files were removed:

**Directories:**

- `ansible-templates/` - Moved to terraform-infrastructure
- `saml-config/` - Environment configs now in terraform-infrastructure  
- `saml-test/` - Replaced by validation scripts
- `scripts/saml-setup/` - Obsolete setup scripts
- `scripts/templates/` - Template files moved to terraform-infrastructure

**Scripts:**

- `bootstrap-saml-certificates.sh`
- `configure-container-environment.sh`
- `deploy-saml-certificates.sh`
- `generate-saml-certificates.sh`
- `manage-saml-certificates*.sh`
- `setup-dev-saml-ecosystem.sh`
- `setup-saml-integration-container.sh`
- `test-aws-infrastructure.sh`
- `test-ddev-infrastructure.sh`
- `test-deployspec-saml-simulation.sh`
- `test-production-paths.sh`
- `test-simplesamlphp.sh`
- `test-staging-saml-validation.sh`
- `validate-saml-implementation.sh`

**Documentation:**

- Multiple redundant SAML implementation guides
- Obsolete architecture and deployment documentation
- Certificate management guides (functionality moved to terraform-infrastructure)

**Temporary Files:**

- `cookies.txt`
- `server.crt`

### Retained Files

**Essential for DDEV:**

- `simplesamlphp/` - Contains DDEV-specific configuration files
- `scripts/test-environment-configuration.sh` - Tests all environments
- `scripts/validate-aws-deployment.sh` - AWS validation script
- `SIMPLESAML_ENVIRONMENT_IMPLEMENTATION.md` - Main implementation documentation
- `TESTING_GUIDE.md` - Testing procedures

## Deployment Error Fixes

### Certificate Security Configuration

#### SAML Service Provider Certificate Management
The implementation properly integrates with the existing terraform-infrastructure encrypted key management system:

**Certificate Sources**:

1. **Production/Staging Deployment**: Uses existing `terraform-infrastructure/scripts/decrypt-key.ksh` and `crypt-key.ksh` infrastructure
   - **Encrypted Keys**: Stored in terraform-infrastructure repository as `.cpt` files
   - **Decryption**: AWS CodeBuild deployment pipeline uses `decrypt-key.ksh` to decrypt private keys
   - **Integration**: Ansible deployment checks for decrypted keys and reuses them
   - **Fallback**: Generates self-signed certificates if encrypted keys not available

2. **Self-Signed Fallback**: When terraform infrastructure keys are not available
   - **Algorithm**: RSA 2048-bit keys with SHA-256 signatures (SAML standard)
   - **Validity**: 365 days (appropriate for SAML certificates)
   - **Standard Practice**: Self-signed certificates are normal for SAML Service Provider use
   - **Subject**: Includes environment-specific CN for identification

**Deployment Integration**:

**AWS CodeBuild Pipeline**:
```bash
# Existing decrypt process in deployspec.yml
${CODEBUILD_SRC_DIR}/terraform-infrastructure/scripts/decrypt-key.ksh ${SAML_PRIVATE_KEY}.cpt ${SAML_SECRET_NAME}
```

**Ansible Certificate Deployment**:
1. **Check for decrypted terraform keys**: Looks for keys in `terraform-infrastructure/.../keys/dh-drupal-{env}-saml.pem`
2. **Use existing infrastructure**: If terraform key available, generates certificate from existing private key
3. **Self-signed fallback**: If terraform key not available, generates new self-signed certificate pair
4. **Container deployment**: Copies certificates to SimpleSAMLphp cert directory with proper permissions

**Staging Certificates**:
- **CN**: `dhportal-dev.internal.lib.virginia.edu`
- **Location**: `/opt/drupal/vendor/simplesamlphp/simplesamlphp/cert/`
- **Files**: `saml.crt` (public certificate), `saml.pem` (private key)

**Production Certificates**:
- **CN**: `dh.library.virginia.edu`
- **Location**: `/opt/drupal/vendor/simplesamlphp/simplesamlphp/cert/`
- **Files**: `saml.crt` (public certificate), `saml.pem` (private key)

**Security Measures**:
- Private keys (`saml.pem`) have 600 permissions (owner read/write only)
- Public certificates (`saml.crt`) have 644 permissions
- Files owned by `www-data:www-data` for proper container access
- Certificates automatically generated during deployment if not present

**Certificate Deployment Process**:
1. **Check terraform-infrastructure**: Ansible checks for decrypted SAML keys from deployment pipeline
2. **Primary method**: If terraform key exists, generates certificate from existing private key using `openssl req -new -x509`
3. **Fallback method**: If terraform key not available, generates new RSA 2048-bit self-signed certificate pair
4. **Container integration**: Copies certificates into SimpleSAMLphp cert directory within container
5. **Security**: Sets proper ownership (`www-data:www-data`) and permissions (600 for private keys, 644 for certificates)
6. **Cleanup**: Removes temporary files after deployment

**Integration with Existing Infrastructure**:
- **Leverages existing encryption**: Uses same `ccrypt`-based encryption as SSH keys
- **Pipeline compatibility**: Works with existing `decrypt-key.ksh` scripts in deployment pipeline
- **Key management**: SAML private keys encrypted and stored in terraform-infrastructure alongside other secrets
- **Deployment flow**: AWS CodeBuild → decrypt keys → Ansible → deploy certificates to container

**Production Security Features**:
- **Assertion Encryption**: `'assertion.encryption' => true` (requires certificates)
- **Signed Logout**: `'sign.logout' => true` (requires private key)
- **Response Validation**: `'validate.response' => true` and `'validate.assertion' => true`
- **SHA-256 Signatures**: `'signature.algorithm' => 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256'`

#### Certificate Management for SAML

**SAML Certificate Purpose**:
Self-signed certificates are the standard and recommended approach for SAML Service Provider certificates. These certificates are used for:
- Signing SAML requests to the Identity Provider
- Encrypting SAML assertions (when encryption is enabled)
- Digital signatures for authentication, not transport security

**Certificate Lifecycle**:
1. **Self-Signed is Standard**: SAML SP certificates are typically self-signed and don't require CA validation
2. **Long Validity Period**: Generated certificates have 365-day validity, appropriate for SAML use
3. **Key Rotation**: Plan for periodic certificate regeneration and metadata updates
4. **Metadata Updates**: When certificates change, update SP metadata with the Identity Provider

**DDEV Environment**:
- Uses SimpleSAMLphp default certificates for local development
- No certificate configuration specified in authsources.php (uses defaults)
- Perfectly appropriate for development and testing

### AWS Staging Deployment Errors
During the initial AWS staging deployment, several errors were encountered and resolved:

#### 1. Docker Build Error - Missing saml-config Directory
**Error**: `ERROR: failed to solve: "/saml-config": not found`

**Cause**: Dockerfile was trying to copy the `saml-config` directory that was removed during cleanup

**Fix**: Updated `package/Dockerfile` to remove obsolete `COPY saml-config` command and script references

#### 2. SimpleSAMLphp Configuration Error - Invalid debug Option
**Error**: `The option 'debug' is not an array or null`

**Cause**: Configuration templates had `'debug' => false` instead of the required `'debug' => null`

**Fix**: Updated both staging and production config templates to use `'debug' => null`

#### 4. SimpleSAMLphp Proxy Configuration Error
**Error**: `Setting secure cookie on plain HTTP is not allowed`

**Cause**: AWS environment uses HTTPS termination at load balancer/proxy, but internal traffic to container is HTTP

**Fix**: Updated configuration templates to handle proxy setup:
- Set `'session.cookie.secure' => false` for internal HTTP traffic
- Added proxy headers configuration: `'proxy' => ['X-Forwarded-Proto', 'X-Forwarded-For']`
- Allows SimpleSAMLphp to detect HTTPS from proxy headers while accepting internal HTTP connections
**Error**: `Unable to create file /opt/drupal/vendor/simplesamlphp/simplesamlphp/log/simplesamlphp.log`

#### 5. SimpleSAMLphp Logging Directory Missing
**Error**: `Unable to create file /opt/drupal/vendor/simplesamlphp/simplesamlphp/log/simplesamlphp.log`

**Cause**: Log directory not being created during deployment and incorrect logging path

**Fixes**:
- Updated config templates to use absolute path: `'loggingdir' => '/opt/drupal/simplesamlphp/log/'`
- Added directory creation tasks in deployment playbooks
- Added proper permissions setting for SimpleSAMLphp directories

## Conclusion

The implementation successfully addresses the original deployment configuration issue by:

1. **Fixing immediate Apache errors** - Resolved mod_headers compatibility issues
2. **Implementing environment-specific configuration management** - Created Ansible-based templates for staging and production
3. **Establishing proper security boundaries** - Environment-appropriate security settings
4. **Creating comprehensive testing infrastructure** - Validation scripts and deployment procedures
5. **Documenting the complete solution** - Clear documentation for maintenance and troubleshooting

### Latest Security and Deployment Fixes (July 2025)

The solution has been enhanced with comprehensive fixes for SimpleSAMLphp 2.x compatibility and AWS load balancer environments:

1. **Fixed CSS/JavaScript Mixed Content Issues** - Implemented proper HTTPS base URL configuration per official SimpleSAMLphp documentation
2. **Resolved SimpleSAMLphp 2.x Compatibility** - Updated NameIDPolicy array format and password hashing requirements  
3. **Implemented Secure Password Management** - Added Argon2 password hashing with proper YAML escaping
4. **Documented Browser Compatibility Issues** - Password manager interference and private browsing solutions

**Key Technical Learning**: SimpleSAMLphp deliberately ignores X-Forwarded headers for security. The proper solution for reverse proxy/load balancer environments is to configure `baseurlpath` with the full HTTPS URL, not rely on proxy headers.

The solution leverages existing terraform-infrastructure patterns and Ansible deployment processes, ensuring consistency with established DevOps practices while providing the flexibility needed for environment-specific SimpleSAMLphp configuration management.
