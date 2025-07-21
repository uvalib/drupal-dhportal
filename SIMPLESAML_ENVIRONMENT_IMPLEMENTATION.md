# SimpleSAMLphp Environment Configuration Implementation

## Overview
This document summarizes the implementation of environment-specific SimpleSAMLphp configuration for the Digital Humanities Portal project, addressing the deployment issue where AWS environments were receiving DDEV configurations instead of appropriate environment-specific settings.

## Problem Statement
- **Original Issue**: Apache mod_headers error in SimpleSAMLphp web interface
- **Root Cause**: Missing mod_headers module and overly restrictive .htaccess rules
- **Deployment Issue**: AWS dev environment receiving DDEV configs instead of environment-appropriate configurations
- **Solution**: Implemented Ansible-based environment management with three-tier configuration strategy

## Architecture

### Three-Tier Environment Strategy
1. **DDEV (Local Development)**
   - Configuration: Git-managed files in `simplesamlphp/config/` directory
   - Domain: `*.ddev.site`
   - Security: Relaxed for development (unsecured cookies, debug logging)
   
2. **AWS Staging Environment** 
   - Configuration: Ansible templates in `terraform-infrastructure/staging/`
   - Domain: `dhportal-dev.internal.lib.virginia.edu`
   - Security: Production-like with INFO logging
   
3. **AWS Production Environment**
   - Configuration: Ansible templates in `terraform-infrastructure/production.new/`
   - Domain: `dh.library.virginia.edu`
   - Security: Maximum security (NOTICE logging, assertion encryption)

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

## Conclusion

The implementation successfully addresses the original deployment configuration issue by:

1. **Fixing immediate Apache errors** - Resolved mod_headers compatibility issues
2. **Implementing environment-specific configuration management** - Created Ansible-based templates for staging and production
3. **Establishing proper security boundaries** - Environment-appropriate security settings
4. **Creating comprehensive testing infrastructure** - Validation scripts and deployment procedures
5. **Documenting the complete solution** - Clear documentation for maintenance and troubleshooting

The solution leverages existing terraform-infrastructure patterns and Ansible deployment processes, ensuring consistency with established DevOps practices while providing the flexibility needed for environment-specific SimpleSAMLphp configuration management.
