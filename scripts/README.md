# Scripts Directory

This directory contains the essential scripts for setting up SAML authentication and dual login menu functionality.

## Quick Start with NPM

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