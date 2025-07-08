# DHPortal Account Menu Module

Custom Drupal module for managing the dual-login account menu structure in the DHPortal project.

## Purpose

This module solves the core menu conflict problem that occurs when implementing dual authentication options in Drupal. Without this module, both custom menu items and Drupal's default "My account" and "Log in" menu items would appear, creating a confusing user experience.

## Features

- **Hides core user menu items** from the account menu
- **Prevents menu conflicts** between custom and core items
- **Clean account menu structure** for dual authentication
- **Multiple hook implementations** for comprehensive coverage

## Technical Implementation

### Hook: `menu_links_discovered_alter()`

```php
function dhportal_account_menu_menu_links_discovered_alter(&$links) {
  // Remove core user menu items at discovery time
  if (isset($links['user.page'])) {
    unset($links['user.page']);
  }
  
  if (isset($links['user.logout'])) {
    unset($links['user.logout']);
  }
}
```

**Purpose**: Removes core menu link definitions before they're processed by Drupal's menu system.

**When it runs**: During menu link discovery phase, before menu cache is built.

**What it removes**:
- `user.page` - "My account" menu item
- `user.logout` - "Log in" menu item (confusingly named, but this is the logout/login toggle)

### Hook: `menu_local_actions_alter()`

```php
function dhportal_account_menu_menu_local_actions_alter(&$local_actions) {
  // Additional safety check for any user-related local actions
  foreach ($local_actions as $key => $action) {
    if (strpos($key, 'user.') === 0) {
      unset($local_actions[$key]);
    }
  }
}
```

**Purpose**: Safety net to remove any user-related local action items that might interfere.

**When it runs**: During local action processing.

**What it removes**: Any local action items with keys starting with "user."

### Hook: `preprocess_menu()`

```php
function dhportal_account_menu_preprocess_menu(&$variables) {
  // Final cleanup during menu rendering
  if ($variables['menu_name'] == 'account') {
    foreach ($variables['items'] as $key => $item) {
      if (isset($item['url']) && $item['url']->getRouteName() == 'user.page') {
        unset($variables['items'][$key]);
      }
      if (isset($item['url']) && $item['url']->getRouteName() == 'user.logout') {
        unset($variables['items'][$key]);
      }
    }
  }
}
```

**Purpose**: Final cleanup during template rendering phase as a last resort.

**When it runs**: During menu template preprocessing, just before rendering.

**What it removes**: Any remaining menu items that route to core user pages.

## Why Multiple Hooks?

The module uses three different hooks to ensure complete coverage:

1. **Discovery Level** (`menu_links_discovered_alter`): Prevents items from being discovered
2. **Action Level** (`menu_local_actions_alter`): Handles local actions separately  
3. **Render Level** (`preprocess_menu`): Final cleanup before output

This comprehensive approach ensures that no core user menu items slip through under any circumstances.

## Installation

The module is automatically enabled by the setup script:

```bash
./scripts/setup-account-menu-complete.sh
```

Or manually:

```bash
ddev drush en dhportal_account_menu -y
ddev drush cache-rebuild
```

## Verification

To verify the module is working:

```bash
# Check module status
ddev drush pml | grep dhportal

# Test menu structure (should show no core user items)
ddev drush eval "
\$menu_tree = \Drupal::service('menu.link_tree');
\$tree = \$menu_tree->load('account', new \Drupal\Core\Menu\MenuTreeParameters());
foreach (\$tree as \$element) {
  \$plugin_id = \$element->link->getPluginId();
  if (in_array(\$plugin_id, ['user.page', 'user.logout'])) {
    echo 'ERROR: Found core item: ' . \$plugin_id . PHP_EOL;
  }
}
echo 'Verification complete' . PHP_EOL;
"
```

## Troubleshooting

**Core menu items still appearing:**

1. Verify module is enabled: `ddev drush pml | grep dhportal`
2. Clear all caches: `ddev drush cache-rebuild`
3. Check for conflicting modules that might re-add core items

**Module not taking effect:**

1. Ensure proper file permissions
2. Verify module files are in correct location: `web/modules/custom/dhportal_account_menu/`
3. Check for PHP syntax errors in module file

## Integration with Setup Scripts

This module is designed to work seamlessly with the DHPortal setup scripts:

- **Enabled automatically** by `setup-account-menu-complete.sh`
- **Validates functionality** as part of script verification
- **Provides clean foundation** for custom menu structure

## Security Considerations

- **Module scope**: Only affects account menu, no other menu structures
- **Permission respect**: Does not bypass Drupal's access control
- **Core compatibility**: Uses standard Drupal hooks and APIs
- **No data modification**: Only affects menu display, not underlying data
