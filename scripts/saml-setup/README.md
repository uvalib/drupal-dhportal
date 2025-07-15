# SAML Setup Scripts

This directory contains all scripts, templates, and documentation for SAML/NetBadge integration and account menu configuration for the drupal-dhportal project.

## 🚀 Quick Start

For a complete SAML setup, run these universal scripts:

```bash
# 1. Set up SAML integration (works in any environment)
./scripts/saml-setup/setup-saml-integration-container.sh

# 2. Set up account menu for dual login  
./scripts/saml-setup/setup-account-menu-complete-container.sh
```

## 📚 Documentation

### **`IMPLEMENTATION_GUIDE.md`** 📋
**→ START HERE** - Complete implementation guide with architecture, setup procedures, and troubleshooting.

### Specialized Guides

- **`CERTIFICATE_MANAGEMENT.md`** - Certificate management strategy
- **`ACCOUNT_MENU_FINAL_SUMMARY.md`** - Dual-login account menu details  
- **`SAML_TESTING_SUITE.md`** - Testing procedures and utilities
- **`SAML_CONFIGURATION_FILES.md`** - Configuration files structure

## 🔧 Scripts

### Universal Scripts (Recommended)

**`setup-saml-integration-container.sh`**
- Main SAML integration setup with environment auto-detection
- Supports DDEV, container, and server environments
- Template-based configuration generation
- Test generation mode (`--test-only`)

**`setup-account-menu-complete-container.sh`**
- Account menu setup for dual-login functionality  
- Environment auto-detection and universal compatibility
- Creates "My Profile" parent menu with SAML and local login options

**`manage-saml-certificates.sh`**
- Certificate management utilities
- Self-signed certificates for development
- Production certificate handling

### Legacy Scripts (Deprecated)

- `setup-saml-integration.sh` - DDEV-only version
- `setup-account-menu-complete-ddev-legacy.sh` - DDEV-only account menu setup

*Use the universal scripts instead for better compatibility.*

## 🎓 UVA NetBadge Integration

This system is designed for integration with the University of Virginia's NetBadge authentication system:

- **Entity ID Format:** `{domain}/shibboleth` (must match virtual host per UVA requirements)
- **IdP Entity ID:** `urn:mace:incommon:virginia.edu` (production)
- **Attributes:** `uid`, `eduPersonPrincipalName`, `eduPersonAffiliation`, etc.
- **Registration:** Required through UVA ITS for production use
