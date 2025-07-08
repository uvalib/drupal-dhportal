# Drupal DHPortal with Dual SAML/Local Authentication

A Drupal 10 installation with dual login capabilities: NetBadge SAML authentication for university users and local Drupal authentication for partner users. Features a custom account menu structure and automated setup scripts.

## Quick Start

### Prerequisites

- [DDEV](https://ddev.readthedocs.io/en/stable/)
- Docker
- Git
- A running SimpleSAMLphp IdP (like [drupal-netbadge](https://github.com/your-org/drupal-netbadge))

### Setup

1. **Clone and start the project:**
   ```bash
   git clone <your-repo-url>
   cd drupal-dhportal
   npm install
   ddev start
   ```

2. **Run the automated setup:**
   ```bash
   # NPM approach (recommended)
   npm run setup

   # Or manually run both scripts
   ./scripts/setup-saml-integration.sh
   ./scripts/setup-account-menu-complete.sh
   ```

3. **Access your site:**
   - Main site: https://drupal-dhportal.ddev.site:8443
   - Admin: https://drupal-dhportal.ddev.site:8443/admin
   - Menu admin: https://drupal-dhportal.ddev.site:8443/admin/structure/menu/manage/account

## Features

### Dual Authentication System

**For University Users (NetBadge SAML):**
- Single sign-on via institutional NetBadge
- Automatic account creation from SAML attributes
- Integration with university identity provider

**For Partner/External Users:**
- Traditional Drupal username/password login
- Manual account creation by administrators
- Local user management

### Custom Account Menu

**Anonymous Users See:**
- **My Profile** (dropdown parent)
  - **NetBadge Login** → SAML authentication
  - **Partner Login** → Local Drupal login

**Authenticated Users See:**
- **My Profile** (dropdown parent)
  - **View Profile** → User profile page
  - **Logout** → Sign out

### Key Benefits

- ✅ **No conflicting core menu items** - Custom module hides Drupal's default login
- ✅ **Clean, professional interface** - Single "My Profile" dropdown
- ✅ **Automated setup** - No manual configuration needed
- ✅ **Dynamic UUID handling** - No hardcoded values
- ✅ **Production-ready** - Tested on fresh database installs

## Development Commands

### NPM Scripts (Recommended)

```bash
# Setup Commands
npm run help          # Show all available commands
npm run setup         # Complete setup (SAML + Menu)
npm run setup:saml    # Setup SAML integration only
npm run setup:menu    # Setup account menu only

# Testing Commands  
npm run test:menu     # Test account menu structure
npm run menu:validate # Validate menu configuration
npm run status        # Show project status

# Development Commands
npm run start         # Start DDEV
npm run stop          # Stop DDEV  
npm run restart       # Restart DDEV
npm run admin         # Show admin URLs
npm run drush         # Open Drush shell

# Maintenance Commands
npm run clean         # Clean up containers
npm run reset         # Reset to fresh state
npm run menu:rebuild  # Rebuild menu cache
```

### Testing

For comprehensive testing procedures, see [TESTING_GUIDE.md](TESTING_GUIDE.md).

**Quick validation:**
```bash
npm run test:menu     # Test menu structure
npm run status        # Check overall health
```

## Architecture

### Custom Module: `dhportal_account_menu`

Located at `web/modules/custom/dhportal_account_menu/`, this module:

- **Hides core user menu items** using `hook_menu_links_discovered_alter()`
- **Prevents menu conflicts** with multiple hook implementations
- **Ensures clean account menu** without "My account" or duplicate "Log in" items

### SAML Integration

- **SimpleSAMLphp Auth module** for Drupal SAML support
- **External Auth module** for user account mapping
- **Configurable authentication sources** via setup scripts

### Menu Structure Implementation

- **Parent menu item**: "My Profile" with `<nolink>` route (visible to anonymous users)
- **Child menu items**: Context-aware based on authentication status
- **Access control**: Leverages Drupal's built-in menu access system
- **Unified Menu**: Clean account menu structure that adapts based on user authentication state

## 🏗️ Architecture

### Core Components

1. **SimpleSAMLphp Integration**
   - Module: `simplesamlphp_auth`
   - IdP: drupal-netbadge (separate project)
   - Authentication flow: SAML 2.0

2. **Custom Account Menu System**
   - Custom module: `dhportal_account_menu`
   - Menu structure: Hierarchical with dynamic visibility
   - Core menu override: Hides default Drupal user menu items

3. **Menu Structure Logic**

   ```text
   My Profile (parent, <nolink>)
   ├── Anonymous Users:
   │   ├── Netbadge Login → /saml_login
   │   └── Partner Login → /user/login
   └── Authenticated Users:
       ├── View Profile → /user  
       └── Logout → /user/logout
   ```

## 🚀 Quick Setup

**Prerequisites:** DDEV, drupal-netbadge IdP running

```bash
# Clone and start
git clone <repo>
cd drupal-dhportal
ddev start

# Complete setup (2 commands)
./scripts/setup-saml-integration.sh
./scripts/setup-account-menu-complete.sh
```

## 📁 Key Files & Directories

### Scripts (`/scripts/`)
- `setup-saml-integration.sh` - SAML/SimpleSAMLphp configuration
- `setup-account-menu-complete.sh` - Complete menu setup (all-in-one)
- `fetch-db-from-remote.sh` - Database sync utility
- `fetch-remote-files.sh` - File sync utility

### Custom Module (`/web/modules/custom/dhportal_account_menu/`)
- `dhportal_account_menu.module` - Core menu logic
- `dhportal_account_menu.info.yml` - Module definition

### Configuration (`/saml-config/`)
- SimpleSAMLphp configuration files
- IdP metadata and certificates

### Documentation
- `scripts/README.md` - Script usage guide
- `ACCOUNT_MENU_FINAL_SUMMARY.md` - Technical implementation details

## 🛠️ Technical Implementation

### Problem Solved
- **Before**: Single login option, core Drupal menu conflicts, manual UUID management
- **After**: Dual login options, clean menu hierarchy, automated setup

### Key Technical Decisions

1. **Custom Module Approach**: Created `dhportal_account_menu` to cleanly override core menu behavior
   - Uses `hook_menu_links_discovered_alter()` to remove core user menu items
   - Uses `hook_preprocess_menu()` as backup removal method
   - Avoids theme-level hacks or complex configuration overrides

2. **Dynamic UUID Detection**: Scripts auto-detect menu item UUIDs instead of hardcoding
   - Eliminates manual intervention during setup
   - Makes scripts reusable across database resets

3. **`<nolink>` Parent Strategy**: "My Profile" uses `route:<nolink>` to be visible to anonymous users
   - Solves accessibility issue where parents with restricted URLs don't show
   - Maintains proper menu hierarchy

4. **Streamlined Script Architecture**: Consolidated 4+ scripts into 2 essential scripts
   - Reduces complexity and potential for errors
   - Clear separation: SAML setup vs. Menu setup

### Development History & Lessons Learned

- **Multiple iterations**: Started with complex multi-script approach, refined to 2-script solution
- **Core menu challenges**: Drupal core automatically provides user menu items that had to be properly hidden
- **UUID management**: Initially used hardcoded UUIDs, evolved to dynamic detection
- **Menu visibility**: Learned that parent menu items need `<nolink>` to show for anonymous users

## 🔧 Development & Troubleshooting

### Common Issues
- **Core menu items appearing**: Ensure `dhportal_account_menu` module is enabled
- **Menu not visible**: Check that "My Profile" uses `<nolink>` and is enabled
- **SAML failures**: Verify drupal-netbadge IdP is running and certificates match

### Development Commands
```bash
# Check menu structure
ddev drush eval "print_r(\Drupal::service('menu.link_tree')->load('account', new \Drupal\Core\Menu\MenuTreeParameters()));"

# Verify custom module
ddev drush pml | grep dhportal

# Reset and test setup
ddev drush sql-drop -y && ddev drush sql-cli < backup.sql
./scripts/setup-saml-integration.sh
./scripts/setup-account-menu-complete.sh
```

### Architecture Decisions for Future Reference

1. **Why not use menu configuration YAML?**
   - Dynamic UUIDs make exported config fragile
   - Scripts provide more reliable setup across environments

2. **Why custom module vs. theme override?**
   - Module approach is theme-agnostic
   - Cleaner separation of concerns
   - Easier to maintain and debug

3. **Why not use existing contrib modules?**
   - Specific requirements needed custom solution
   - Simpler to maintain small custom module vs. complex contrib config

## 🎯 Future Enhancement Ideas

- Add role-based menu customization
- Implement remember-me functionality for SAML
- Add audit logging for authentication choices
- Consider multi-site support

## 📋 Testing Scenarios

1. **Fresh Install**: Database reset → run 2 scripts → verify menu
2. **Menu Reset**: Clear account menu items → run menu script → verify
3. **SAML Integration**: Test both login paths → verify user creation
4. **Menu Visibility**: Test as anonymous vs. authenticated → verify different options
5. **Cache Clearing**: Clear caches → verify menu still works

---

This project demonstrates a clean approach to dual authentication in Drupal while maintaining a user-friendly interface and robust automated setup process.
