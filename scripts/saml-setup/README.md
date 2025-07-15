# SAML Setup Scripts

This directory contains all scripts and templates related to SAML/NetBadge integration and account menu configuration for the drupal-dhportal project.

## Scripts

### `setup-saml-integration-container.sh` (Universal)

Main SAML integration setup script with environment auto-detection.

**Usage:**

```bash
# Normal mode - performs full SAML setup
./scripts/saml-setup/setup-saml-integration-container.sh

# Test mode - generates test configurations only
./scripts/saml-setup/setup-saml-integration-container.sh --test-only

# Help
./scripts/saml-setup/setup-saml-integration-container.sh --help
```

**Features:**

- Environment auto-detection (DDEV, container, server)
- Template-based configuration generation using `envsubst`
- Multi-environment support (dev/container/production)
- Test generation mode for safe configuration validation
- Automatic certificate management integration
- Comprehensive error handling and logging

### `setup-account-menu-complete-container.sh` (Universal)

Account menu setup script for dual-login functionality with environment auto-detection.

**Usage:**

```bash
# Setup dual-login account menu
./scripts/saml-setup/setup-account-menu-complete-container.sh

# Help
./scripts/saml-setup/setup-account-menu-complete-container.sh --help
```

**Features:**

- Environment auto-detection (DDEV, container, server)
- Creates "My Profile" parent menu with SAML and local login options
- Configures user dashboard, settings, and logout for authenticated users
- Integrates with `dhportal_account_menu` module to hide core menu items

### `setup-saml-integration.sh` (Legacy)

DDEV-specific SAML integration setup script (deprecated - use universal version).

### `setup-account-menu-complete-ddev-legacy.sh` (Legacy)

DDEV-specific account menu setup script (deprecated - use universal version).

### `manage-saml-certificates.sh`

Certificate management utilities for SAML integration.

**Features:**

- Self-signed certificate generation for development
- Production certificate management
- Certificate validation and renewal

**Features:**
- Self-signed certificate generation for development
- Production certificate management
- Certificate validation and renewal

## Templates

The `templates/` directory contains configuration file templates that use environment variable substitution:

- `config.php.template` - Main SimpleSAMLphp configuration template
- `authsources.php.template` - Authentication sources template for SP configuration
- `saml20-idp-remote.php.template` - IdP metadata template

### Template Variables

Templates use `envsubst` for variable substitution. Key variables include:
- `ENVIRONMENT` - Target environment (dev/container/production)
- `SP_ENTITY_ID` - Service Provider entity ID
- `IDP_ENTITY_ID` - Identity Provider entity ID
- `SECRET_SALT` - SimpleSAMLphp secret salt
- `ADMIN_PASSWORD` - Admin interface password
- `GENERATION_DATE` - Template generation timestamp

## Test Generation

The test generation feature creates configuration files for all supported environments in a `test-output/` directory (git-ignored).

**Usage:**
```bash
./scripts/saml-setup/setup-saml-integration-container.sh --test-only
```

This generates:
- `test-output/dev/` - Development environment configs
- `test-output/container/` - Container environment configs  
- `test-output/production/` - Production environment configs

Each directory includes:
- Generated configuration files
- Environment-specific README with details
- Usage instructions

## Environment Support

### Development (dev)
- Uses `.ddev.site` domain
- Self-signed certificates
- Local drupal-netbadge container as IdP
- Debug-friendly settings

### Container 
- Container-specific paths and database settings
- Local drupal-netbadge container as IdP
- Simplified authentication for testing

### Production (server)
- Official UVA NetBadge IdP endpoints
- Environment variable-based configuration
- Production-grade security settings
- Requires ITS registration

## Documentation

The following comprehensive documentation is available in this directory:

### Implementation Guides

- **`SAML_INTEGRATION_SUMMARY.md`** - Complete overview of SAML implementation architecture and setup
- **`UVA_NETBADGE_IMPLEMENTATION.md`** - Detailed UVA NetBadge compliance implementation guide
- **`CERTIFICATE_MANAGEMENT.md`** - Certificate management strategy across all environments

### Post-Authentication Setup

- **`ACCOUNT_MENU_FINAL_SUMMARY.md`** - Dual-login account menu implementation for SAML and local authentication

### Configuration and Testing

- **`SAML_CONFIGURATION_FILES.md`** - Overview of SimpleSAMLphp configuration files structure
- **`SAML_TESTING_SUITE.md`** - Comprehensive SAML testing procedures and utilities

### Maintenance and Analysis

- **`SCRIPTS_CONSISTENCY_ANALYSIS.md`** - Scripts organization and redundancy elimination analysis

## UVA NetBadge Integration

This system is designed for integration with the University of Virginia's NetBadge authentication system:

- **Entity ID Format:** `{domain}/shibboleth` (must match virtual host per UVA requirements)
- **IdP Entity ID:** `urn:mace:incommon:virginia.edu` (production)
- **Attributes:** `uid`, `eduPersonPrincipalName`, `eduPersonAffiliation`, etc.
- **Registration:** Required through UVA ITS for production use

## File Organization

```
scripts/saml-setup/
├── README.md                                    # This file
├── setup-saml-integration-container.sh         # Main container setup script
├── setup-saml-integration.sh                   # DDEV setup script
├── manage-saml-certificates.sh                 # Certificate management
└── templates/                                  # Configuration templates
    ├── config.php.template                     # SimpleSAMLphp main config
    ├── authsources.php.template                # SP authentication sources
    └── saml20-idp-remote.php.template          # IdP metadata
```

## Related Directories

- `saml-config/` - Static configuration files and examples
- `saml-test/` - SAML integration testing utilities
- `web/test-saml-integration.php` - Web-based SAML test page
