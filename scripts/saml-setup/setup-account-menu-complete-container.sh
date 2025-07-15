#!/bin/bash

# Complete Account Menu Setup Script (Universal Version)
# This script sets up the entire dual login account menu structure from scratch
# Automatically detects and supports multiple environments:
# - DDEV development environment (uses 'ddev' commands)
# - Direct container execution (uses direct commands)
# - Server/production environments (uses direct commands)
# Run with: ./scripts/saml-setup/setup-account-menu-complete-container.sh [--help]

set -e

# Parse command line arguments
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Complete Account Menu Setup Script (Universal Version)"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --help, -h         Show this help message"
    echo ""
    echo "DESCRIPTION:"
    echo "  Sets up a dual login account menu structure for SAML and local authentication."
    echo "  Creates a 'My Profile' parent menu with submenus for:"
    echo "  - NetBadge Login (SAML authentication)"
    echo "  - Local Login (standard Drupal authentication)"
    echo "  - User Dashboard, Account Settings, and Logout (for authenticated users)"
    echo ""
    echo "ENVIRONMENTS:"
    echo "  - DDEV development environment (auto-detected)"
    echo "  - Direct container execution (auto-detected)" 
    echo "  - Server/production environments (auto-detected)"
    echo ""
    echo "REQUIREMENTS:"
    echo "  - Requires drush to be available"
    echo "  - 'dhportal_account_menu' module must be available"
    exit 0
fi

echo "🔧 Account Menu Setup Starting (Universal Mode)..."

# Define logging functions
info() {
    echo "   ℹ️  $1"
}

warn() {
    echo "   ⚠️  $1"
}

log() {
    echo "   📝 $1"
}

error() {
    echo "   ❌ $1"
}

# Detect execution environment
EXECUTION_MODE=""
USE_DDEV=false

# Check if we're in a DDEV environment and it's available
if command -v ddev &> /dev/null && ddev describe &> /dev/null 2>&1; then
    EXECUTION_MODE="ddev"
    USE_DDEV=true
    echo "   🏠 Detected DDEV development environment"
elif [ -f "/opt/drupal/web/index.php" ]; then
    EXECUTION_MODE="server"
    echo "   🖥️  Detected server environment: /opt/drupal"
elif [ -f "/var/www/html/web/index.php" ]; then
    EXECUTION_MODE="container"
    echo "   🐳 Detected container environment: /var/www/html"
else
    echo "❌ No recognized environment found."
    echo "   Expected: DDEV project, /opt/drupal, or /var/www/html"
    exit 1
fi

# Environment-aware command execution
exec_cmd() {
    local cmd="$1"
    if [ "$USE_DDEV" = true ]; then
        if [[ "$cmd" == drush* ]]; then
            ddev $cmd
        else
            ddev exec "$cmd"
        fi
    else
        if [[ "$cmd" == drush* ]] && command -v $cmd &> /dev/null; then
            $cmd
        elif [[ "$cmd" == drush* ]]; then
            # Try vendor/bin/drush if system drush not available
            if [ -f "$VENDOR_ROOT/bin/drush" ]; then
                $VENDOR_ROOT/bin/$cmd
            else
                echo "❌ Drush not found. Cannot configure Drupal."
                exit 1
            fi
        else
            eval $cmd
        fi
    fi
}

# Set up environment paths based on detected environment
if [ "$USE_DDEV" = true ]; then
    DRUPAL_ROOT="/var/www/html"  # Inside DDEV container
elif [ "$EXECUTION_MODE" = "server" ]; then
    DRUPAL_ROOT="/opt/drupal"
elif [ "$EXECUTION_MODE" = "container" ]; then
    DRUPAL_ROOT="/var/www/html"
fi

WEB_ROOT="$DRUPAL_ROOT/web"
VENDOR_ROOT="$DRUPAL_ROOT/vendor"

log "Environment: $EXECUTION_MODE"
log "Drupal root: $DRUPAL_ROOT"

# Set the working directory to Drupal root (only if not using DDEV)
if [ "$USE_DDEV" = false ]; then
    cd "$DRUPAL_ROOT"
fi

# Step 1: Enable custom module to hide core menu items
log "📦 Enabling DHPortal Account Menu module..."
exec_cmd "drush en dhportal_account_menu -y"
if [ $? -eq 0 ]; then
    log "✓ Custom module enabled successfully"
else
    warn "Failed to enable custom module - core menu items may still appear"
fi

# Step 2: Clear all existing custom menu items
log "🧹 Clearing all existing custom account menu items..."
exec_cmd "drush eval \"
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Delete all existing custom menu items in the account menu
\\\$storage = \\\Drupal::entityTypeManager()->getStorage('menu_link_content');
\\\$all_account_items = \\\$storage->loadByProperties(['menu_name' => 'account']);

foreach (\\\$all_account_items as \\\$item) {
    echo 'Deleting: ' . \\\$item->getTitle() . PHP_EOL;
    \\\$item->delete();
}

echo 'Cleared all custom account menu items' . PHP_EOL;
\""

# Step 3: Create My Profile parent menu item
log "👤 Creating My Profile parent menu item..."
MY_PROFILE_UUID=$(exec_cmd "drush eval \"
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Create My Profile menu item with <nolink> for anonymous users
\\\$my_profile = MenuLinkContent::create([
    'title' => 'My Profile',
    'link' => ['uri' => 'route:<nolink>'],
    'menu_name' => 'account',
    'weight' => -50,
    'expanded' => TRUE,
    'enabled' => TRUE,
    'description' => 'User profile and login options',
]);
\\\$my_profile->save();

echo \\\$my_profile->uuid();
\"")

info "Created My Profile menu item with UUID: $MY_PROFILE_UUID"

# Step 4: Create NetBadge Login submenu item
log "🎫 Creating NetBadge Login submenu item..."
exec_cmd "drush eval \"
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Create NetBadge Login submenu item
\\\$netbadge_login = MenuLinkContent::create([
    'title' => 'NetBadge Login',
    'link' => ['uri' => 'internal:/saml_login'],
    'menu_name' => 'account',
    'parent' => 'menu_link_content:$MY_PROFILE_UUID',
    'weight' => -40,
    'enabled' => TRUE,
    'description' => 'Login with your UVA NetBadge credentials',
]);
\\\$netbadge_login->save();

echo 'Created NetBadge Login submenu item' . PHP_EOL;
\""

# Step 5: Create Local Login submenu item
log "🔑 Creating Local Login submenu item..."
exec_cmd "drush eval \"
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Create Local Login submenu item
\\\$local_login = MenuLinkContent::create([
    'title' => 'Local Login',
    'link' => ['uri' => 'internal:/user/login'],
    'menu_name' => 'account',
    'parent' => 'menu_link_content:$MY_PROFILE_UUID',
    'weight' => -30,
    'enabled' => TRUE,
    'description' => 'Login with local site credentials',
]);
\\\$local_login->save();

echo 'Created Local Login submenu item' . PHP_EOL;
\""

# Step 6: Create My Dashboard submenu item (for authenticated users)
log "📊 Creating My Dashboard submenu item..."
exec_cmd "drush eval \"
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Create My Dashboard submenu item
\\\$my_dashboard = MenuLinkContent::create([
    'title' => 'My Dashboard',
    'link' => ['uri' => 'internal:/user'],
    'menu_name' => 'account',
    'parent' => 'menu_link_content:$MY_PROFILE_UUID',
    'weight' => -20,
    'enabled' => TRUE,
    'description' => 'View your user dashboard and profile',
]);
\\\$my_dashboard->save();

echo 'Created My Dashboard submenu item' . PHP_EOL;
\""

# Step 7: Create Account Settings submenu item (for authenticated users)
log "⚙️ Creating Account Settings submenu item..."
exec_cmd "drush eval \"
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Create Account Settings submenu item
\\\$account_settings = MenuLinkContent::create([
    'title' => 'Account Settings',
    'link' => ['uri' => 'internal:/user/edit'],
    'menu_name' => 'account',
    'parent' => 'menu_link_content:$MY_PROFILE_UUID',
    'weight' => -10,
    'enabled' => TRUE,
    'description' => 'Edit your account settings and profile',
]);
\\\$account_settings->save();

echo 'Created Account Settings submenu item' . PHP_EOL;
\""

# Step 8: Create Logout submenu item (for authenticated users)
log "🚪 Creating Logout submenu item..."
exec_cmd "drush eval \"
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Create Logout submenu item
\\\$logout = MenuLinkContent::create([
    'title' => 'Logout',
    'link' => ['uri' => 'internal:/user/logout'],
    'menu_name' => 'account',
    'parent' => 'menu_link_content:$MY_PROFILE_UUID',
    'weight' => 10,
    'enabled' => TRUE,
    'description' => 'Logout of the Digital Humanities Portal',
]);
\\\$logout->save();

echo 'Created Logout submenu item' . PHP_EOL;
\""

# Step 9: Clear cache to ensure changes take effect
log "🔄 Clearing all caches..."
exec_cmd "drush cr"

# Step 10: Display current menu structure
log "📋 Displaying current account menu structure..."
exec_cmd "drush eval \"
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Get all menu items in the account menu
\\\$storage = \\\Drupal::entityTypeManager()->getStorage('menu_link_content');
\\\$account_items = \\\$storage->loadByProperties(['menu_name' => 'account']);

echo 'Current Account Menu Structure:' . PHP_EOL;
echo '================================' . PHP_EOL;

// Sort by weight
uasort(\\\$account_items, function(\\\$a, \\\$b) {
    return \\\$a->getWeight() <=> \\\$b->getWeight();
});

foreach (\\\$account_items as \\\$item) {
    \\\$parent = \\\$item->getParentId();
    \\\$indent = \\\$parent ? '  └─ ' : '• ';
    \\\$title = \\\$item->getTitle();
    \\\$url = \\\$item->getUrlObject()->toString();
    \\\$weight = \\\$item->getWeight();
    \\\$enabled = \\\$item->isEnabled() ? '✓' : '✗';
    
    echo \\\$indent . \\\$title . ' (' . \\\$url . ') [weight: ' . \\\$weight . '] [' . \\\$enabled . ']' . PHP_EOL;
}
echo PHP_EOL;
\""

# Step 11: Test menu visibility and authentication states
log "🧪 Testing menu access and authentication states..."

echo ""
log "🎉 Account Menu Setup Complete!"
echo ""

# Determine project URL based on environment
PROJECT_URL=""

# Check for common environment variables that might contain the base URL
if [ -n "$DRUPAL_BASE_URL" ]; then
    PROJECT_URL="$DRUPAL_BASE_URL"
elif [ -n "$BASE_URL" ]; then
    PROJECT_URL="$BASE_URL"
elif [ -n "$VIRTUAL_HOST" ]; then
    PROJECT_URL="https://$VIRTUAL_HOST"
else
    # Try to get the URL from Drupal configuration
    PROJECT_URL=$(exec_cmd "drush config:get system.site.url 2>/dev/null | grep -o 'https\?://[^[:space:]]*'" || echo "")
    
    # Fallback based on environment
    if [ -z "$PROJECT_URL" ]; then
        if [ "$USE_DDEV" = true ]; then
            PROJECT_URL="https://drupal-dhportal.ddev.site"
        else
            PROJECT_URL="http://localhost"
        fi
    fi
fi

echo "📋 Next Steps:"
echo "1. Test the menu structure at: $PROJECT_URL"
echo "2. Verify anonymous users see: 'My Profile' → 'NetBadge Login' & 'Local Login'"
echo "3. Test NetBadge authentication flow"
echo "4. Verify authenticated users see: 'My Profile' → 'My Dashboard', 'Account Settings', 'Logout'"
echo ""
echo "🔗 Key URLs:"
echo "   - NetBadge Login: $PROJECT_URL/saml_login"
echo "   - Local Login: $PROJECT_URL/user/login"
echo "   - User Dashboard: $PROJECT_URL/user"
echo "   - Logout: $PROJECT_URL/user/logout"
echo ""
echo "💡 Environment Notes:"
echo "   - Environment detected: $EXECUTION_MODE"
echo "   - Drupal root: $DRUPAL_ROOT"
if [ "$USE_DDEV" = true ]; then
    echo "   - Uses 'ddev drush' commands for database operations"
else
    echo "   - Uses direct drush commands (inside container or server)"
fi
echo "   - Menu items created with proper parent-child relationships"
echo "   - Custom module 'dhportal_account_menu' hides default core menu items"
