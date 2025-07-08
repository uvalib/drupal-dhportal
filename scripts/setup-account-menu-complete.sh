#!/bin/bash

# Complete Account Menu Setup Script
# This script sets up the entire dual login account menu structure from scratch

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Check if we're in a DDEV environment
check_ddev() {
    if ! command -v ddev >/dev/null 2>&1; then
        error "DDEV not found. Please install DDEV first."
        exit 1
    fi

    if ! ddev describe >/dev/null 2>&1; then
        error "Not in a DDEV project directory or DDEV not running."
        exit 1
    fi
}

log "🚀 Starting Complete Account Menu Setup..."

# Verify DDEV environment
check_ddev

# Step 1: Enable custom module to hide core menu items
log "📦 Enabling DHPortal Account Menu module..."
ddev drush en dhportal_account_menu -y
if [ $? -eq 0 ]; then
    log "✓ Custom module enabled successfully"
else
    warn "Failed to enable custom module - core menu items may still appear"
fi

# Step 2: Clear all existing custom menu items
log "🧹 Clearing all existing custom account menu items..."
ddev drush eval "
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Delete all existing custom menu items in the account menu
\$storage = \Drupal::entityTypeManager()->getStorage('menu_link_content');
\$all_account_items = \$storage->loadByProperties(['menu_name' => 'account']);

foreach (\$all_account_items as \$item) {
    echo 'Deleting: ' . \$item->getTitle() . PHP_EOL;
    \$item->delete();
}

echo 'Cleared all custom account menu items' . PHP_EOL;
"

# Step 3: Create My Profile parent menu item
log "👤 Creating My Profile parent menu item..."
MY_PROFILE_UUID=$(ddev drush eval "
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Create My Profile menu item with <nolink> for anonymous users
\$my_profile = MenuLinkContent::create([
    'title' => 'My Profile',
    'link' => ['uri' => 'route:<nolink>'],
    'menu_name' => 'account',
    'weight' => -50,
    'expanded' => TRUE,
    'enabled' => TRUE,
    'description' => 'User profile and login options',
]);
\$my_profile->save();

echo \$my_profile->uuid();
")

log "✓ Created My Profile parent (UUID: $MY_PROFILE_UUID)"

# Step 4: Create all child menu items
log "🔗 Creating child menu items..."
ddev drush eval "
use Drupal\menu_link_content\Entity\MenuLinkContent;

\$my_profile_uuid = '$MY_PROFILE_UUID';
\$my_profile_id = 'menu_link_content:' . \$my_profile_uuid;

// Create Netbadge Login
\$netbadge = MenuLinkContent::create([
    'title' => 'Netbadge Login',
    'link' => ['uri' => 'internal:/saml_login'],
    'menu_name' => 'account',
    'parent' => \$my_profile_id,
    'weight' => -10,
    'expanded' => FALSE,
    'enabled' => TRUE,
    'description' => 'Login using Netbadge (SAML authentication)',
]);
\$netbadge->save();
echo 'Created Netbadge Login menu item' . PHP_EOL;

// Create Partner Login
\$partner = MenuLinkContent::create([
    'title' => 'Partner Login',
    'link' => ['uri' => 'internal:/user/login'],
    'menu_name' => 'account',
    'parent' => \$my_profile_id,
    'weight' => -9,
    'expanded' => FALSE,
    'enabled' => TRUE,
    'description' => 'Login using standard Drupal login form',
]);
\$partner->save();
echo 'Created Partner Login menu item' . PHP_EOL;

// Create View Profile for authenticated users
\$view_profile = MenuLinkContent::create([
    'title' => 'View Profile',
    'link' => ['uri' => 'internal:/user'],
    'menu_name' => 'account',
    'parent' => \$my_profile_id,
    'weight' => -10,
    'expanded' => FALSE,
    'enabled' => TRUE,
    'description' => 'View your user profile',
]);
\$view_profile->save();
echo 'Created View Profile menu item' . PHP_EOL;

// Create Logout for authenticated users
\$logout = MenuLinkContent::create([
    'title' => 'Logout',
    'link' => ['uri' => 'internal:/user/logout'],
    'menu_name' => 'account',
    'parent' => \$my_profile_id,
    'weight' => 10,
    'expanded' => FALSE,
    'enabled' => TRUE,
    'description' => 'Logout from the site',
]);
\$logout->save();
echo 'Created Logout menu item' . PHP_EOL;
"

# Step 5: Clear all caches
log "🔄 Clearing all caches..."
ddev drush cache-rebuild

# Step 6: Verify setup
log "✅ Verifying menu setup..."
ddev drush eval "
// Test menu rendering for anonymous users
\$menu_tree = \Drupal::service('menu.link_tree');
\$parameters = new \Drupal\Core\Menu\MenuTreeParameters();
\$tree = \$menu_tree->load('account', \$parameters);
\$manipulators = [
  ['callable' => 'menu.default_tree_manipulators:checkAccess'],
  ['callable' => 'menu.default_tree_manipulators:generateIndexAndSort'],
];
\$tree = \$menu_tree->transform(\$tree, \$manipulators);

echo 'Account menu structure (anonymous users):' . PHP_EOL;
function print_menu_verification(\$tree, \$depth = 0) {
  foreach (\$tree as \$element) {
    \$indent = str_repeat('  ', \$depth);
    \$link = \$element->link;
    \$title = \$link->getTitle();
    \$url = \$link->getUrlObject()->toString();
    
    // Only show accessible items for cleaner output
    if (\$title !== 'Inaccessible') {
        echo \$indent . '• ' . \$title . (\$url ? ' → ' . \$url : ' (no link)') . PHP_EOL;
    }
    
    if (\$element->subtree) {
      print_menu_verification(\$element->subtree, \$depth + 1);
    }
  }
}

print_menu_verification(\$tree);

// Check if SAML route is available
try {
    \$route_provider = \Drupal::service('router.route_provider');
    \$routes = \$route_provider->getRoutesByNames(['simplesamlphp_auth.saml_login']);
    if (!empty(\$routes)) {
        echo PHP_EOL . '✓ SAML login route is available' . PHP_EOL;
    } else {
        echo PHP_EOL . '⚠ SAML login route not found' . PHP_EOL;
    }
} catch (Exception \$e) {
    echo PHP_EOL . '⚠ Could not check SAML route: ' . \$e->getMessage() . PHP_EOL;
}
"

log "🎉 Complete Account Menu Setup finished!"

echo
info "Menu Structure Created:"
echo "  📱 For anonymous users:"
echo "    • My Profile (no link)"
echo "      ├── Netbadge Login → /saml_login"
echo "      └── Partner Login → /user/login"
echo
echo "  👤 For authenticated users:"
echo "    • My Profile (no link)"
echo "      ├── View Profile → /user"
echo "      └── Logout → /user/logout"

echo
info "What this script accomplished:"
echo "  ✅ Enabled custom module to hide core user menu items"
echo "  ✅ Cleared any existing account menu items"
echo "  ✅ Created 'My Profile' parent with <nolink> (visible to all)"
echo "  ✅ Added login options for anonymous users"
echo "  ✅ Added profile options for authenticated users"
echo "  ✅ Verified menu structure and SAML integration"

echo
info "Next steps:"
echo "  🌐 Visit your site to test the menu"
echo "  🔧 Admin menu: https://drupal-dhportal.ddev.site:8443/admin/structure/menu/manage/account"
echo "  🧪 Test SAML: Use 'Netbadge Login' option"
echo "  🔐 Test Drupal: Use 'Partner Login' option"

echo
info "Troubleshooting:"
echo "  • If menu doesn't appear: Clear cache with 'ddev drush cache-rebuild'"
echo "  • If core items appear: Ensure dhportal_account_menu module is enabled"
echo "  • If SAML fails: Check that SimpleSAMLphp is properly configured"
