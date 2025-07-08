# DHPortal Account Menu Testing Guide

**Complete testing procedures for the DHPortal dual authentication system and custom account menu structure.**

## 🎯 Testing Context & Architecture

### What This Testing Guide Covers

This guide provides comprehensive testing for:

1. **Dual Authentication System** - NetBadge SAML + Local Drupal login
2. **Custom Account Menu Structure** - Clean "My Profile" dropdown interface  
3. **Core Menu Conflict Prevention** - Ensuring Drupal's default menu items don't interfere
4. **Custom Module Functionality** - `dhportal_account_menu` module behavior
5. **Cross-Platform Development Tools** - NPM-based testing scripts

### System Architecture Being Tested

```
DHPortal System Components:
├── Authentication Layer
│   ├── SimpleSAMLphp (SAML 2.0 for NetBadge)
│   ├── External Auth (User mapping)
│   └── Drupal User System (Local accounts)
├── Menu Management Layer  
│   ├── Custom Menu Structure (My Profile dropdown)
│   ├── dhportal_account_menu Module (Hides core items)
│   └── Access Control (Context-aware menu items)
└── Development/Testing Layer
    ├── DDEV (Local environment)
    ├── NPM Scripts (Cross-platform tools)
    └── Automated Validation (Menu structure testing)
```

### Key Testing Scenarios

**Primary Use Cases Tested:**
1. **Anonymous User Experience** - Should see NetBadge/Partner login options
2. **Authenticated User Experience** - Should see Profile/Logout options  
3. **Menu Conflict Detection** - No duplicate or core menu items visible
4. **Module Integration** - All dependencies working together correctly
5. **Fresh Installation** - Setup scripts work on clean database

## 🛠️ Testing Tools & Commands

```bash
# Test the complete menu structure
npm run test:menu

# Validate menu configuration
npm run menu:validate

# Check overall project status
npm run status

# Show admin interface URLs
npm run admin
```

## Manual Testing Procedures

### 1. Fresh Installation Testing

**Scenario**: Testing on a completely fresh database installation.

```bash
# 1. Reset to clean state
npm run reset

# 2. Verify the setup completed successfully
npm run status

# 3. Test menu structure
npm run test:menu
```

**Expected Results:**
- ✅ DDEV environment running
- ✅ `dhportal_account_menu` module enabled
- ✅ SAML modules (`simplesamlphp_auth`, `externalauth`) enabled
- ✅ Account menu contains expected structure

### 2. Account Menu Structure Testing

#### Anonymous User Testing

**Access the site as an anonymous user:**
```bash
# Open the site
open "https://drupal-dhportal.ddev.site"
```

**Expected Menu Structure:**
```
🔍 Look for "My Profile" dropdown in the navigation
└── My Profile (dropdown parent)
    ├── NetBadge Login → /saml_login
    └── Partner Login → /user/login
```

**What Should NOT Appear:**
- ❌ "My account" link
- ❌ "Log in" link (core Drupal)
- ❌ Any duplicate login options

#### Authenticated User Testing

**Log in as any user and check the menu:**

**Expected Menu Structure:**
```
🔍 Look for "My Profile" dropdown in the navigation
└── My Profile (dropdown parent)
    ├── View Profile → /user
    └── Logout → /user/logout
```

**What Should NOT Appear:**
- ❌ NetBadge Login option
- ❌ Partner Login option
- ❌ Core "My account" link

### 3. SAML Authentication Flow Testing

#### NetBadge Login Testing

**Prerequisites:**
- SimpleSAMLphp IdP running (e.g., drupal-netbadge project)
- SAML configuration completed

**Test Steps:**
1. **Start as anonymous user**
2. **Click "My Profile" → "NetBadge Login"**
3. **Should redirect to SAML IdP**
4. **Complete SAML authentication**
5. **Should return to Drupal site logged in**
6. **Menu should show authenticated user options**

**Validation Commands:**
```bash
# Check SAML module status
ddev drush pm:list --filter=simplesamlphp_auth

# Check external auth mapping
ddev drush eval "
  \$users = \Drupal::entityTypeManager()->getStorage('user')->loadByProperties(['name' => 'YOUR_SAML_USERNAME']);
  foreach (\$users as \$user) {
    echo 'User: ' . \$user->getAccountName() . ' (ID: ' . \$user->id() . ')' . PHP_EOL;
    echo 'Email: ' . \$user->getEmail() . PHP_EOL;
  }
"
```

#### Local Drupal Login Testing

**Test Steps:**
1. **Start as anonymous user**
2. **Click "My Profile" → "Partner Login"**
3. **Should redirect to `/user/login`**
4. **Use local Drupal credentials**
5. **Should login successfully**
6. **Menu should show authenticated user options**

### 4. Custom Module Testing

#### Module Functionality Testing

```bash
# Test that core menu items are hidden
npm run test:menu

# Manually check for conflicts
ddev drush eval "
  \$menu_tree = \Drupal::menuTree();
  \$parameters = \$menu_tree->getCurrentRouteMenuTreeParameters('account');
  \$tree = \$menu_tree->load('account', \$parameters);
  \$manipulators = array(
    array('callable' => 'menu.default_tree_manipulators:checkAccess'),
    array('callable' => 'menu.default_tree_manipulators:generateIndexAndSort'),
  );
  \$tree = \$menu_tree->transform(\$tree, \$manipulators);
  foreach (\$tree as \$element) {
    \$route = \$element->link->getUrlObject()->getRouteName();
    if (in_array(\$route, ['user.page', 'user.logout', 'user.login'])) {
      echo 'CONFLICT: ' . \$element->link->getTitle() . ' (' . \$route . ')' . PHP_EOL;
    }
  }
  echo 'Module test complete.' . PHP_EOL;
"
```

#### Module Hook Testing

**Test `hook_menu_links_discovered_alter()`:**
```bash
# Verify core user menu items are being hidden
ddev drush eval "
  \$links = [];
  \$links['user.page'] = ['title' => 'Test User Page'];
  \$links['user.logout'] = ['title' => 'Test Logout'];
  dhportal_account_menu_menu_links_discovered_alter(\$links);
  echo 'Remaining links: ' . count(\$links) . PHP_EOL;
  if (count(\$links) == 0) {
    echo '✅ Hook working correctly - core links removed';
  } else {
    echo '❌ Hook not working - links still present';
  }
"
```

### 5. Database State Testing

#### Menu Link Validation

```bash
# Check account menu structure in database
ddev drush eval "
  \$query = \Drupal::entityQuery('menu_link_content')
    ->condition('menu_name', 'account')
    ->sort('weight', 'ASC');
  \$ids = \$query->execute();
  \$links = \Drupal::entityTypeManager()->getStorage('menu_link_content')->loadMultiple(\$ids);
  
  foreach (\$links as \$link) {
    echo \$link->getTitle() . ' (Weight: ' . \$link->getWeight() . ', Parent: ' . \$link->getParent() . ')' . PHP_EOL;
  }
"
```

#### UUID Consistency Testing

```bash
# Verify UUIDs are properly set and consistent
npm run menu:validate
```

## Automated Testing Scripts

### Menu Structure Validation Script

```bash
# Run comprehensive menu testing
npm run test:menu
```

This script will:
- ✅ Check menu structure
- ✅ Verify custom module status  
- ✅ Test for core menu conflicts
- ✅ Validate expected menu items

### Project Status Check

```bash
# Get complete project status
npm run status
```

This script will:
- ✅ Check DDEV status
- ✅ Verify site accessibility
- ✅ Check custom module status
- ✅ Check SAML module status

## Troubleshooting Common Issues

### Menu Items Not Appearing

**Symptoms**: Expected menu items missing from account menu

**Diagnosis:**
```bash
npm run menu:validate
```

**Solutions:**
```bash
# Rebuild menu cache
npm run menu:rebuild

# Re-run menu setup
npm run setup:menu
```

### Core Menu Items Still Visible

**Symptoms**: Seeing "My account" or duplicate "Log in" links

**Diagnosis:**
```bash
npm run test:menu
```

**Solutions:**
```bash
# Check custom module status
ddev drush pm:list --filter=dhportal_account_menu

# Re-enable custom module if needed
ddev drush en dhportal_account_menu
ddev drush cr
```

### SAML Authentication Issues

**Symptoms**: NetBadge login not working

**Diagnosis:**
```bash
# Check SAML module status
ddev drush pm:list --filter="simplesamlphp_auth|externalauth"

# Check SAML configuration
ddev drush config:get simplesamlphp_auth.settings
```

**Solutions:**
```bash
# Re-run SAML setup
npm run setup:saml

# Check IdP connectivity
curl -I https://your-idp-url/metadata
```

### Menu Structure Corruption

**Symptoms**: Menu structure is completely wrong

**Solutions:**
```bash
# Nuclear option - complete reset
npm run reset

# Less nuclear - rebuild just the menu
npm run setup:menu
```

## Test User Accounts

### Local Drupal Test Users

Create these users for testing the Partner Login flow:

```bash
# Create test partner user
ddev drush user:create partner_test --mail="partner@example.com" --password="testpass123"

# Create test admin user  
ddev drush user:create admin_test --mail="admin@example.com" --password="adminpass123"
ddev drush user:role:add administrator admin_test
```

### SAML Test Users

Refer to your SimpleSAMLphp IdP documentation for available test users.

**Common test accounts** (if using drupal-netbadge):
- **Username**: `student` / **Password**: `studentpass`
- **Username**: `staff` / **Password**: `staffpass`  
- **Username**: `faculty` / **Password**: `facultypass`

## Performance Testing

### Menu Load Performance

```bash
# Test menu loading performance
ddev drush eval "
  \$start = microtime(true);
  \$menu_tree = \Drupal::menuTree();
  \$parameters = \$menu_tree->getCurrentRouteMenuTreeParameters('account');
  \$tree = \$menu_tree->load('account', \$parameters);
  \$end = microtime(true);
  echo 'Menu load time: ' . ((\$end - \$start) * 1000) . 'ms' . PHP_EOL;
"
```

### Cache Performance

```bash
# Test cache effectiveness
ddev drush cr
npm run test:menu
# Run twice to test cache warming
npm run test:menu
```

## Continuous Integration Testing

For CI/CD pipelines, create this test sequence:

```bash
#!/bin/bash
# CI testing script

set -e

echo "🚀 Starting CI tests for DHPortal..."

# 1. Start environment
npm run start

# 2. Run setup
npm run setup

# 3. Validate installation
npm run status

# 4. Test menu structure  
npm run test:menu

# 5. Validate menu configuration
npm run menu:validate

echo "✅ All CI tests passed!"
```

## Reporting Issues

When reporting issues, include:

1. **Environment info**: `npm run status`
2. **Menu structure**: `npm run test:menu`  
3. **Error logs**: `npm run logs`
4. **Steps to reproduce**
5. **Expected vs actual behavior**

For more detailed debugging, see the main project README.md troubleshooting section.
