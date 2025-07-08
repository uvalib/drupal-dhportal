# Scripts Directory - Complete Developer Guide

**This directory contains the essential scripts for setting up SAML authentication and dual login menu functionality.**

## 🎯 Script Architecture & Context

### Purpose of This Directory

These scripts solve the complex problem of setting up a **dual authentication system** in Drupal 10 with:
- **NetBadge SAML authentication** for university users  
- **Local Drupal authentication** for partner users
- **Clean account menu structure** without core menu conflicts

### Why Scripts Are Needed

**Without these scripts**, setting up the system would require:
1. Manual module installation and configuration (20+ steps)
2. Complex SAML configuration with external IdP coordination  
3. Manual menu item creation with specific UUID management
4. Custom module enabling and cache clearing
5. Troubleshooting numerous Drupal menu caching issues

**With these scripts**: 2-command setup that works reliably on fresh installations.

### Script Dependencies

```
Script Execution Order & Dependencies:
├── 1. setup-saml-integration.sh
│   ├── Installs: simplesamlphp_auth, externalauth modules
│   ├── Configures: SAML authentication sources
│   └── Enables: SimpleSAMLphp integration
└── 2. setup-account-menu-complete.sh  
    ├── Depends: SAML modules from script 1
    ├── Creates: Complete menu structure
    ├── Enables: dhportal_account_menu module
    └── Validates: Final configuration
```

## 🚀 Quick Start with NPM (Recommended)

**Recommended approach using NPM scripts:**

```bash
# Complete setup (both SAML and menu)
npm run setup

# Or run individually
npm run setup:saml
npm run setup:menu

# Test the setup
npm run test:menu
npm run status
```

See the main [TESTING_GUIDE.md](../TESTING_GUIDE.md) for comprehensive testing procedures.

## Core Setup Scripts

### `setup-saml-integration.sh`

- **Purpose**: Sets up SimpleSAMLphp integration with Drupal
- **Usage**: Run once to install and configure SAML authentication
- **Dependencies**: Requires drupal-netbadge IdP to be running for testing

### `setup-account-menu-complete.sh`

- **Purpose**: Complete setup of dual login account menu structure
- **Usage**: Run after SAML setup to create the entire menu structure
- **Features**:
  - Enables custom module to hide core menu items
  - Clears any existing menu items
  - Creates "My Profile" parent with `<nolink>` for visibility
  - Adds all login and profile menu items as children
  - Automatically detects and uses dynamic UUIDs
  - Verifies setup and provides troubleshooting info

## Custom Module

A custom module `dhportal_account_menu` is automatically enabled by the scripts to:

- Hide core "My account" and "Log in" menu items
- Ensure clean menu structure
- Located at: `web/modules/custom/dhportal_account_menu/`

## Utility Scripts

### `fetch-db-from-remote.sh`

- **Purpose**: Database synchronization from remote server
- **Usage**: Development utility for syncing database state

### `fetch-remote-files.sh`

- **Purpose**: File synchronization from remote server
- **Usage**: Development utility for syncing files

## Setup Order

**For a fresh installation or reset database:**

1. `./scripts/setup-saml-integration.sh`
2. `./scripts/setup-account-menu-complete.sh`

That's it! Just **2 simple steps** for complete setup.

## Current Menu Structure

**Anonymous Users:**

- My Profile (no link)
  - Netbadge Login → /saml_login
  - Partner Login → /user/login

**Authenticated Users:**

- My Profile (no link)
  - View Profile → /user
  - Logout → /user/logout

## Troubleshooting

- **Core menu items still showing**: Clear cache with `ddev drush cache-rebuild`
- **Menu not appearing**: Ensure custom module is enabled: `ddev drush en dhportal_account_menu -y`
- **SAML not working**: Check SimpleSAMLphp configuration and ensure drupal-netbadge IdP is running
- **Menu structure broken**: Re-run `./scripts/setup-account-menu-complete.sh` to rebuild from scratch