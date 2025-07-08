# DHPortal Account Menu Module - Complete Technical Documentation

**File Location**: `web/modules/custom/dhportal_account_menu/`  
**Module Name**: `dhportal_account_menu`  
**Drupal Version**: 10.x  
**Dependencies**: Core User module  

## 🎯 Module Purpose & Context

### The Problem This Module Solves

**Scenario**: When implementing dual authentication (SAML + Local Drupal login) with a custom account menu structure, Drupal's core User module automatically injects conflicting menu items into the account menu.

**Without this module**: Users see confusing duplicate/conflicting options:
```
Account Menu (BROKEN):
├── My Profile (custom)          ← What we want
├── My account (core)            ← Drupal automatically adds this
├── NetBadge Login (custom)      ← What we want  
├── Partner Login (custom)       ← What we want
├── Log in (core)                ← Drupal automatically adds this
└── Log out (core)               ← Drupal automatically adds this
```

**With this module**: Clean menu structure:
```
Account Menu (CLEAN):
└── My Profile (custom)
    ├── NetBadge Login (custom)
    ├── Partner Login (custom)  
    ├── View Profile (custom)
    └── Logout (custom)
```

## 🔧 Technical Implementation

### Architecture Overview

This module implements **three complementary Drupal hooks** to ensure core user menu items are completely hidden from the account menu at different stages of Drupal's menu processing pipeline:

1. **Discovery Stage** - `hook_menu_links_discovered_alter()`
2. **Local Actions Stage** - `hook_menu_local_actions_alter()`  
3. **Rendering Stage** - `hook_preprocess_menu()`

### Hook Implementation Details

#### 1. `hook_menu_links_discovered_alter()` - Discovery Stage Prevention

```php
function dhportal_account_menu_menu_links_discovered_alter(&$links) {
  // Hide core user menu items from the account menu
  if (isset($links['user.page'])) {
    unset($links['user.page']);        // Removes "My account" 
  }
  
  if (isset($links['user.logout'])) {
    unset($links['user.logout']);      // Removes "Log in/Log out" toggle
  }
}
```

**When it runs**: During Drupal's menu link discovery phase, before menu items are processed or cached.

**What it prevents**: 
- `user.page` → "My account" menu item (routes to `/user`)
- `user.logout` → "Log in" or "Log out" menu item (dynamic based on user state)

**Why this hook**: Intercepts menu items at the earliest possible stage, preventing them from entering Drupal's menu system entirely.

#### 2. `hook_menu_local_actions_alter()` - Local Actions Prevention

```php
function dhportal_account_menu_menu_local_actions_alter(&$local_actions) {
  // Additional safety check for any user-related local actions
  foreach ($local_actions as $key => $action) {
    if (strpos($key, 'user.') === 0) {
      unset($local_actions[$key]);      // Removes any user.* local actions
    }
  }
}
```

**When it runs**: When Drupal processes local actions (action buttons/links on pages).

**What it prevents**: Any local actions that start with `user.` prefix from appearing in the account menu context.

**Why this hook**: Provides additional coverage for user-related actions that might not be caught by the menu links hook.

#### 3. `hook_preprocess_menu()` - Rendering Stage Cleanup

```php
function dhportal_account_menu_preprocess_menu(&$variables) {
  // Ensure core user menu items don't appear in the account menu
  if ($variables['menu_name'] == 'account') {
    // Remove any core user menu items that might still appear
    foreach ($variables['items'] as $key => $item) {
      if (isset($item['url']) && $item['url']->getRouteName() == 'user.page') {
        unset($variables['items'][$key]);     // Final removal of "My account"
      }
      if (isset($item['url']) && $item['url']->getRouteName() == 'user.logout') {
        unset($variables['items'][$key]);     // Final removal of "Log in/out"
      }
    }
  }
}
```

**When it runs**: During template preprocessing, just before menu rendering.

**What it prevents**: Any core user menu items that somehow made it through the earlier hooks from appearing in the final rendered account menu.

**Why this hook**: Final safety net to ensure absolutely no core user items appear in the account menu, regardless of caching or other Drupal behaviors.

## 📁 File Structure

```
web/modules/custom/dhportal_account_menu/
├── dhportal_account_menu.info.yml     # Module definition
├── dhportal_account_menu.module       # Hook implementations
└── MODULE_README_COMPLETE.md          # This documentation
```

### Module Definition (`dhportal_account_menu.info.yml`)

```yaml
name: 'DHPortal Account Menu'
type: module
description: 'Customizes the account menu to hide core user menu items and manage dual login structure.'
core_version_requirement: ^10
package: DHPortal
dependencies:
  - drupal:user
```

## 🧪 Testing & Validation

### Automated Testing (via NPM scripts)

```bash
# Test menu structure and detect conflicts
npm run test:menu

# Validate all expected menu items are present  
npm run menu:validate

# Check overall module and system status
npm run status
```

### Manual Testing Steps

1. **Enable the module**: `ddev drush en dhportal_account_menu`
2. **Clear cache**: `ddev drush cr`
3. **Check account menu**: Navigate to `/admin/structure/menu/manage/account`
4. **Verify no conflicts**: Should see only custom "My Profile" structure

### Expected Test Results

**✅ Correct behavior**:
- Account menu shows only "My Profile" with custom children
- No "My account" or "Log in" items from core Drupal
- Custom menu items function properly

**❌ Module not working**:
- Multiple "account" or "login" options visible
- Core Drupal menu items appearing alongside custom ones

## 🔄 Integration with DHPortal Setup Scripts

This module is automatically enabled by the setup scripts:

1. **`setup-saml-integration.sh`** - Installs SAML dependencies
2. **`setup-account-menu-complete.sh`** - Creates menu structure AND enables this module

### Script Integration Point

```bash
# From setup-account-menu-complete.sh
echo "Enabling custom account menu module..."
drush en dhportal_account_menu -y
drush cr
```

## 🚨 Troubleshooting

### Common Issues

#### "My account" still appearing
**Symptoms**: Core "My account" menu item visible despite module being enabled
**Diagnosis**: 
```bash
npm run test:menu  # Should show conflicts
ddev drush pm:list --filter=dhportal_account_menu  # Check module status
```
**Solutions**:
```bash
ddev drush en dhportal_account_menu -y  # Re-enable module
ddev drush cr                           # Clear cache
```

#### Menu items missing entirely
**Symptoms**: No menu items in account menu
**Diagnosis**: Check if custom menu items were created
**Solution**: Re-run setup script: `npm run setup:menu`

#### Module not taking effect
**Symptoms**: Changes not visible after enabling module
**Root cause**: Drupal menu caching
**Solution**: 
```bash
ddev drush cr              # Clear all caches
npm run menu:rebuild       # Rebuild menu cache specifically
```

## 🔍 Code Context for Future Development

### When to Modify This Module

**Add new hooks** if you notice core menu items still appearing:
- Check what routes the conflicting items use
- Add them to the existing hook implementations
- Test with `npm run test:menu`

**Example of adding new route prevention**:
```php
// In hook_menu_links_discovered_alter()
if (isset($links['user.register'])) {
  unset($links['user.register']);  // Hide user registration link
}
```

### Integration Points

**This module works with**:
- Custom menu items created by `setup-account-menu-complete.sh`
- SimpleSAMLphp authentication routes (`simplesamlphp_auth.saml_login`)
- Standard Drupal user routes (`user.login`, `user.page`, `user.logout`)

**This module does NOT**:
- Create custom menu items (that's done by setup scripts)
- Handle authentication logic (that's SimpleSAMLphp modules)
- Modify user permissions (that's standard Drupal)

### Future GitHub Copilot Context

**When working on this module**:
1. The goal is HIDING core menu items, not creating custom ones
2. Multiple hooks are needed due to Drupal's complex menu processing
3. Test changes with `npm run test:menu` to verify no conflicts
4. This is part of a larger dual-authentication system
5. The module must be enabled for the menu structure to work properly

**File locations for related functionality**:
- Menu creation: `scripts/setup-account-menu-complete.sh`
- SAML setup: `scripts/setup-saml-integration.sh`  
- Testing tools: `scripts/dev.js`
- Project docs: `README.md`, `TESTING_GUIDE.md`

## 📋 Development History & Decisions

### Why Three Hooks Instead of One?

**Initial attempt**: Used only `hook_menu_links_discovered_alter()`
**Problem**: Some menu items still appeared due to Drupal's complex caching and processing
**Solution**: Added `hook_menu_local_actions_alter()` and `hook_preprocess_menu()` for comprehensive coverage

### Why Not Use Menu Access Control?

**Alternative considered**: Use Drupal's menu access permissions to hide items
**Problem**: Would affect ALL menus, not just the account menu
**Chosen approach**: Surgically remove items only from account menu context

### Why Custom Module vs Configuration?

**Alternative considered**: Use Drupal's menu configuration to disable core items
**Problem**: Core user module automatically re-enables items, overriding configuration
**Chosen approach**: Code-based prevention that can't be overridden by core modules

## 🚀 Future Enhancement Opportunities

### Potential Improvements

1. **Configuration interface**: Add admin form to control which items to hide
2. **Menu-specific targeting**: Allow different behavior for different menus
3. **Route-based exclusions**: More granular control over which routes to hide
4. **Cache optimization**: More efficient caching strategy for menu processing

### Code Expansion Examples

```php
// Future: Configurable route exclusions
function dhportal_account_menu_get_excluded_routes() {
  return \Drupal::config('dhportal_account_menu.settings')
    ->get('excluded_routes') ?: ['user.page', 'user.logout'];
}

// Future: Menu-specific behavior  
function dhportal_account_menu_preprocess_menu(&$variables) {
  $target_menus = ['account', 'main']; // Configurable list
  if (in_array($variables['menu_name'], $target_menus)) {
    // Apply hiding logic
  }
}
```

This documentation provides complete context for future GitHub Copilot sessions to understand, maintain, and extend this module effectively.
