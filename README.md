# Drupal DHPortal with Dual SAML/Local Authentication

A Drupal 10 installation with dual login capabilities: NetBadge SAML authentication for university users and local Drupal authentication for partner users. Features a custom account menu structure and automated setup scripts.

## 🎯 Project Context & Architecture

### Problem Statement
This project solves the challenge of providing **two distinct authentication methods** in a single Drupal installation:
1. **NetBadge SAML** - For university users with institutional credentials
2. **Local Drupal** - For external partner users without institutional access

### Technical Challenge Solved
**Core Issue**: Drupal's default user module automatically adds conflicting menu items ("My account", "Log in") that interfere with a clean dual login interface.

**Solution**: Custom menu structure with a `dhportal_account_menu` module that:
- Hides core user menu items using Drupal hooks
- Provides a clean "My Profile" dropdown with context-aware children
- Maintains separate login paths for different user types

### Key Architecture Decisions

#### 1. Menu Structure Design
```
My Profile (visible to all, <nolink> route)
├── Anonymous Users See:
│   ├── NetBadge Login → /saml_login (SAML authentication)
│   └── Partner Login → /user/login (local Drupal)
└── Authenticated Users See:
    ├── View Profile → /user (user profile page)
    └── Logout → /user/logout (sign out)
```

#### 2. Module Dependencies
- **SimpleSAMLphp Auth** (`simplesamlphp_auth`) - SAML 2.0 integration
- **External Auth** (`externalauth`) - Maps SAML users to Drupal accounts  
- **Custom Module** (`dhportal_account_menu`) - Menu conflict prevention

#### 3. Authentication Flow
```
University User:    Anonymous → NetBadge Login → SAML IdP → Auto-provisioned Drupal Account
Partner User:       Anonymous → Partner Login → Local Drupal Login → Existing Account
```

#### 4. Development Tooling
- **DDEV**: Local development environment (Drupal 10 + PHP 8.3 + MariaDB 10.11)
- **NPM Scripts**: Cross-platform development commands with emoji-rich output
- **Automated Setup**: 2-command installation with dynamic UUID handling
- **Testing Framework**: Comprehensive validation of menu structure and module status

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

## 🔐 SimpleSAMLphp Production Implementation

This project includes a comprehensive SimpleSAMLphp implementation designed for AWS load balancer environments with enhanced security and proper container deployment.

### Infrastructure Architecture

#### Container Structure

- **Base Image**: `drupal:10.4.4` with `/opt/drupal/web` DocumentRoot
- **SimpleSAMLphp Location**: `/opt/drupal/web/simplesaml/` (web-accessible)
- **Configuration**: `/opt/drupal/simplesamlphp/config/` (secure, not web-accessible)
- **Assets**: Vendor assets preserved during deployment for CSS/JS functionality

#### AWS Load Balancer Integration

- **SSL Termination**: At load balancer (standard AWS pattern)
- **Internal Traffic**: HTTP between load balancer and containers
- **HTTPS Detection**: Configured via `application.baseURL` and proper `baseurlpath`
- **Reverse Proxy**: SimpleSAMLphp configured for load balancer environment per official docs

### Security Implementation

#### Password Security

- **Admin Passwords**: Argon2 hashed using SimpleSAMLphp utility
- **YAML Escaping**: Single quotes prevent shell interpretation
- **Environment Variables**: Stored in secure container environment files
- **Rotation Support**: Easy password updates via environment configuration

#### Certificate Management

- **Development**: Self-signed certificates generated by deployment scripts
- **Staging/Production**: Real certificates deployed via Ansible during container deployment
- **Private Keys**: Stored in terraform-infrastructure with encryption
- **Certificate Deployment**: Automated via Ansible templates during staging deployment

#### Session Security

- **Secure Cookies**: HTTPS-only cookies for load balancer environments
- **Session Storage**: Database-backed sessions for container scalability
- **Cookie Configuration**: SameSite=Lax for proper cross-domain SAML flows
- **Session Duration**: 8-hour sessions for production use

### Configuration Management

#### Environment-Specific Configuration

```yaml
# Staging Configuration (Ansible Template)
baseurlpath: 'https://dhportal-dev.internal.lib.virginia.edu/simplesaml/'
application.baseURL: 'https://dhportal-dev.internal.lib.virginia.edu/'
admin.requirehttps: true
session.cookie.secure: true
```

#### Container Environment Variables

```bash
# Secure variables stored in container_1.env
SIMPLESAMLPHP_SECRET_SALT="strong-32-character-secret"
SIMPLESAMLPHP_ADMIN_PASSWORD="$argon2id$v=19$..."  # Argon2 hashed
SIMPLESAMLPHP_TECH_EMAIL="dhportal-staging@virginia.edu"
```

#### Database Integration

- **Session Storage**: MySQL-backed sessions for container environments
- **Connection Pooling**: Configured via environment variables
- **Failover Support**: Database configuration supports multiple hosts

### Asset Deployment Architecture

#### Issue Resolution

**Issue**: SimpleSAMLphp CSS/JavaScript assets were returning 404 errors in containerized deployment
**Root Cause**: Deployment infrastructure using incorrect `/var/www/html` paths instead of `/opt/drupal/web`
**Solution**: Fixed deployment scripts to use correct container paths

#### Implementation Details

```dockerfile
# Dockerfile: Preserve vendor assets while overlaying custom config
RUN rsync -av /opt/drupal/vendor/simplesamlphp/simplesamlphp/public/ /opt/drupal/web/simplesaml/
COPY package/data/files/opt/drupal/web/simplesaml/.htaccess /opt/drupal/web/simplesaml/.htaccess
# Selectively overlay only custom files, preserve vendor assets
```

```yaml
# Fixed deployment script paths
container_fs: /opt/drupal/web  # Was: /var/www/html
volumes:
  - "{{ host_fs }}/{{ container_name }}/sites/default/files:{{ container_fs }}/sites/default/files:z"
```

#### Asset Serving

- **Apache Configuration**: Proper rewrite rules for direct asset serving
- **Vendor Preservation**: No duplication of vendor code in repository
- **Upgrade Path**: Clean SimpleSAMLphp updates via composer
- **Performance**: Direct Apache serving bypasses PHP routing

### Compatibility & Standards

#### SimpleSAMLphp 2.x Compatibility

- **NameIDPolicy**: Array format required for 2.x compatibility
- **Admin Authentication**: Requires admin auth source configuration
- **Password Hashing**: Mandatory Argon2 hashing for admin passwords
- **API Changes**: Updated to modern SimpleSAMLphp APIs

#### UVA Library Conventions

- **Environment Files**: Following `container_*.env` pattern
- **Secret Management**: Ansible-deployed secure environment variables
- **Documentation**: Comprehensive troubleshooting in `SIMPLESAML_ENVIRONMENT_IMPLEMENTATION.md`
- **Commit Tracking**: All fixes documented with commit references

### Deployment Process

#### Container Build

1. **Base Setup**: Drupal 10.4.4 container with SimpleSAMLphp via composer
2. **Vendor Assets**: Complete SimpleSAMLphp public directory copied to web root
3. **Custom Overlay**: Selective file overlay preserving vendor assets
4. **Permissions**: Proper www-data ownership and 755 permissions
5. **Configuration**: Ansible templates deployed during container startup

#### AWS Deployment

1. **Container Build**: AWS CodePipeline builds container with latest code
2. **Image Push**: Container pushed to ECR with build tags
3. **Deployment**: Ansible pulls latest image and deploys to staging
4. **Configuration**: Environment-specific config deployed via templates
5. **Certificate Deployment**: SAML certificates deployed securely

### Production Readiness Features

#### Load Balancer Support

- **HTTPS Detection**: Proper `application.baseURL` configuration
- **Asset Loading**: Full HTTPS URLs in `baseurlpath` for reverse proxy
- **Security Headers**: X-Forwarded headers ignored per SimpleSAMLphp security design
- **Cookie Security**: HTTPS-only cookies with proper SameSite configuration

#### Monitoring & Debugging

- **Logging**: INFO-level logging to `/opt/drupal/simplesamlphp/log/`
- **Debug Configuration**: Staging environment with enhanced error display
- **Health Checks**: Status endpoint available for monitoring
- **Error Handling**: Comprehensive error pages with contact information

#### Security Hardening

- **Admin Protection**: Metadata and admin interfaces protected
- **Force HTTPS**: Admin interface requires HTTPS access
- **Input Validation**: All configuration validated during deployment
- **Access Control**: Proper Apache directives for sensitive files

### Troubleshooting & Maintenance

#### Common Issues & Solutions

1. **Empty Assets Directory**: Fixed by correcting deployment script paths
2. **404 on CSS/JS**: Resolved by preserving vendor assets during deployment
3. **Mixed Content Warnings**: Fixed by proper HTTPS `baseurlpath` configuration
4. **Admin Login Failures**: Resolved by Argon2 password hashing implementation
5. **NameIDPolicy Errors**: Fixed by updating to array format for SimpleSAMLphp 2.x

#### Maintenance Procedures

- **Password Rotation**: Update environment variables and redeploy
- **Certificate Renewal**: Replace certificates in terraform-infrastructure
- **SimpleSAMLphp Updates**: Update composer.json and rebuild container
- **Configuration Changes**: Update Ansible templates and redeploy

#### Documentation References

- **Complete Implementation Guide**: `SIMPLESAML_ENVIRONMENT_IMPLEMENTATION.md`
- **Security Documentation**: Covers all password hashing and certificate procedures
- **Troubleshooting**: Comprehensive issue resolution with commit references
- **Environment Setup**: Step-by-step staging environment configuration

This SimpleSAMLphp implementation provides production-ready SAML authentication with proper security, scalability, and maintainability for AWS container environments.

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

### SAML Development Workflow

For local development, you have two options for SAML certificates:

#### 🔗 Complete SAML Ecosystem (Recommended)
```bash
# Setup coordinated IDP + SP certificates with drupal-netbadge test server
./scripts/setup-dev-saml-ecosystem.sh ../drupal-netbadge

# ... do your development work with full SAML testing ...

# Clean up when done
./scripts/setup-dev-saml-ecosystem.sh cleanup
```

#### 📋 SP-Only Development
```bash
# Generate only SP certificates (for external IDP testing)
./scripts/generate-saml-certificates.sh dev

# ... do your development work ...

# Clean up when done
./scripts/generate-saml-certificates.sh cleanup-dev
```

📋 **Quick Reference**: See [DEV_WORKFLOW.md](DEV_WORKFLOW.md) for complete development workflow.  
🔐 **Certificate Lifecycle**: See [SAML_CERTIFICATE_LIFECYCLE.md](SAML_CERTIFICATE_LIFECYCLE.md) for staging/production setup.

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

### Legacy DDEV Commands

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

## 🤖 GitHub Copilot Context & Developer Onboarding

### For Future AI-Assisted Development Sessions

**This section provides comprehensive context for GitHub Copilot and future developers working on this codebase.**

### Project Architecture Summary

**This is a Drupal 10 dual authentication system with:**
- **Primary Challenge**: Providing both SAML (NetBadge) and local Drupal authentication in one interface
- **Core Solution**: Custom account menu structure with automated setup scripts
- **Key Innovation**: `dhportal_account_menu` module prevents core menu conflicts
- **Development Approach**: NPM-based cross-platform tooling with comprehensive testing

### Critical File Locations & Their Purposes

```
Project Structure for AI Context:
├── README.md                                    # Complete project overview (this file)
├── TESTING_GUIDE.md                            # Comprehensive testing procedures  
├── package.json                                # NPM development scripts
├── scripts/
│   ├── dev.js                                  # Cross-platform development utilities
│   ├── setup-saml-integration.sh              # SAML/SimpleSAMLphp setup
│   ├── setup-account-menu-complete.sh         # Menu structure creation
│   └── README.md                               # Script documentation
└── web/modules/custom/dhportal_account_menu/
    ├── dhportal_account_menu.module            # Core menu conflict prevention
    ├── dhportal_account_menu.info.yml          # Module definition
    └── MODULE_README_COMPLETE.md               # Complete module documentation
```

### Key Technical Concepts

#### 1. The Menu Conflict Problem
**Issue**: Drupal automatically adds "My account" and "Log in" menu items to the account menu
**Solution**: Custom module with 3 hooks (`hook_menu_links_discovered_alter`, `hook_menu_local_actions_alter`, `hook_preprocess_menu`)
**Result**: Clean "My Profile" dropdown with only custom items

#### 2. Dual Authentication Architecture  
**NetBadge Flow**: Anonymous → "NetBadge Login" → SAML IdP → Auto-provisioned Account
**Partner Flow**: Anonymous → "Partner Login" → Local Drupal → Existing Account
**Menu Adaptation**: Same menu shows different options based on authentication state

#### 3. NPM Development Tooling
**Why NPM**: Cross-platform compatibility (Windows/Mac/Linux)
**Key Commands**: `npm run setup`, `npm run test:menu`, `npm run status`
**Architecture**: Node.js scripts call Drush/DDEV commands with enhanced UX

### Development Workflow for AI Assistance

#### When Working on Menu Issues:
1. **Test current state**: `npm run test:menu`
2. **Check module status**: `npm run status`  
3. **Review menu structure**: Navigate to `/admin/structure/menu/manage/account`
4. **Clear caches**: `npm run menu:rebuild`
5. **Validate changes**: `npm run menu:validate`

#### When Working on Authentication:
1. **Check SAML status**: `ddev drush pm:list --filter=simplesamlphp_auth`
2. **Test authentication flow**: Use test users from drupal-netbadge project
3. **Review SAML config**: Check `saml-config/` directory
4. **Debug auth issues**: Check DDEV logs with `npm run logs`

#### When Working on Scripts:
1. **Test on fresh install**: `npm run reset` then `npm run setup`
2. **Validate script output**: Each script should provide success/failure feedback
3. **Check UUID handling**: Scripts must detect UUIDs dynamically, never hardcode
4. **Cross-platform testing**: Test on Windows/Mac/Linux environments

### Common AI-Assisted Tasks & Context

#### Task: "Fix menu items not showing"
**Likely causes**: 
- `dhportal_account_menu` module not enabled
- Menu cache issues  
- Parent menu item missing `<nolink>` route
**Debugging approach**: `npm run test:menu` then `npm run status`

#### Task: "SAML authentication not working"  
**Dependencies**: 
- drupal-netbadge project running as IdP
- SimpleSAMLphp modules enabled
- Certificates properly configured
**Debugging approach**: Check `ddev logs` and SAML module status

#### Task: "Setup scripts failing"
**Common issues**:
- DDEV not running (`ddev start`)
- Database not accessible
- Missing dependencies
**Recovery approach**: `npm run reset` for complete rebuild

#### Task: "Add new menu item"
**Process**:
1. Add to `setup-account-menu-complete.sh` script
2. Test with `npm run setup:menu`
3. Validate with `npm run test:menu`
4. Update expected items in `scripts/dev.js` validation

### Integration Points & Dependencies

#### External Dependencies:
- **drupal-netbadge**: Separate project providing SimpleSAMLphp IdP for testing
- **DDEV**: Required for local development environment
- **Node.js**: Required for NPM development scripts

#### Internal Dependencies:
- **Menu structure** depends on **custom module** being enabled
- **SAML auth** depends on **external IdP** being available  
- **Testing scripts** depend on **DDEV** being operational

### Code Quality & Testing Standards

#### Before Committing Changes:
```bash
# Always run these before committing
npm run test:menu     # Validate menu structure
npm run status        # Check system health  
npm run setup         # Test fresh installation
```

#### Documentation Standards:
- **All new scripts** must have usage examples and error handling
- **Module changes** must update MODULE_README_COMPLETE.md
- **Menu changes** must update TESTING_GUIDE.md procedures

### Troubleshooting Context for AI

#### "Menu items appearing twice"
**Root cause**: Core module override or caching issue
**Solution path**: Check custom module status → Clear caches → Rebuild menu

#### "NPM scripts not working"  
**Root cause**: Node.js version incompatibility or missing dependencies
**Solution path**: Check Node.js version → `npm install` → Verify DDEV status

#### "Authentication redirecting to wrong page"
**Root cause**: SAML configuration or route mapping issue
**Solution path**: Check SimpleSAMLphp config → Verify external auth mapping → Test IdP connectivity

### Future Enhancement Context

**When adding new features, consider:**
1. **Cross-platform compatibility** - Test on Windows/Mac/Linux
2. **Fresh installation compatibility** - Must work with `npm run reset && npm run setup`
3. **Menu structure preservation** - Don't break existing dual-login interface
4. **Testing integration** - Add validation to `scripts/dev.js` testing functions
5. **Documentation updates** - Update relevant README files

This context enables GitHub Copilot and future developers to understand the complete system architecture, common issues, and development workflow for effective code assistance.
