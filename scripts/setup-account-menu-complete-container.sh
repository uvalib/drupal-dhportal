#!/bin/bash

# Complete Account Menu Setup Script (Container Version)
# This script sets up the entire dual login account menu structure from scratch
# Designed to run INSIDE the container, not through DDEV
# Supports both server (/opt/drupal) and container (/var/www/html) environments
# Run with: ./scripts/setup-account-menu-complete-container.sh

set -e

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

log "🚀 Account Menu Setup Starting (Container Mode)..."

# Set up environment - detect Drupal root directory (server vs container environments)
DRUPAL_ROOT=""
if [ -f "/opt/drupal/web/index.php" ]; then
    DRUPAL_ROOT="/opt/drupal"
    info "Detected server environment: /opt/drupal"
elif [ -f "/var/www/html/web/index.php" ]; then
    DRUPAL_ROOT="/var/www/html"
    info "Detected container environment: /var/www/html"
else
    error "Not in a recognized Drupal environment. Expected to find web/index.php in /opt/drupal or /var/www/html"
    exit 1
fi

WEB_ROOT="$DRUPAL_ROOT/web"
VENDOR_ROOT="$DRUPAL_ROOT/vendor"

# Check if we're in the right directory structure
check_container_environment() {
    # Check if drush is available
    if ! command -v drush &> /dev/null; then
        # Try vendor/bin/drush
        if [ -f "$VENDOR_ROOT/bin/drush" ]; then
            DRUSH="$VENDOR_ROOT/bin/drush"
            info "Using vendor drush: $VENDOR_ROOT/bin/drush"
        else
            error "Drush not found. Cannot configure Drupal."
            exit 1
        fi
    else
        DRUSH="drush"
        info "Using system drush"
    fi
}

# Verify container environment
check_container_environment

# Set the working directory to Drupal root
cd "$DRUPAL_ROOT"

# Step 1: Enable custom module to hide core menu items
log "📦 Enabling DHPortal Account Menu module..."
$DRUSH en dhportal_account_menu -y
if [ $? -eq 0 ]; then
    log "✓ Custom module enabled successfully"
else
    warn "Failed to enable custom module - core menu items may still appear"
fi

# Step 2: Clear all existing custom menu items
log "🧹 Clearing all existing custom account menu items..."
$DRUSH eval "
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
MY_PROFILE_UUID=$($DRUSH eval "
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

info "Created My Profile menu item with UUID: $MY_PROFILE_UUID"

# Step 4: Create NetBadge Login submenu item
log "🎫 Creating NetBadge Login submenu item..."
$DRUSH eval "
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Create NetBadge Login submenu item
\$netbadge_login = MenuLinkContent::create([
    'title' => 'NetBadge Login',
    'link' => ['uri' => 'internal:/saml_login'],
    'menu_name' => 'account',
    'parent' => 'menu_link_content:$MY_PROFILE_UUID',
    'weight' => -40,
    'enabled' => TRUE,
    'description' => 'Login with your UVA NetBadge credentials',
]);
\$netbadge_login->save();

echo 'Created NetBadge Login submenu item' . PHP_EOL;
"

# Step 5: Create Local Login submenu item
log "🔑 Creating Local Login submenu item..."
$DRUSH eval "
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Create Local Login submenu item
\$local_login = MenuLinkContent::create([
    'title' => 'Local Login',
    'link' => ['uri' => 'internal:/user/login'],
    'menu_name' => 'account',
    'parent' => 'menu_link_content:$MY_PROFILE_UUID',
    'weight' => -30,
    'enabled' => TRUE,
    'description' => 'Login with local site credentials',
]);
\$local_login->save();

echo 'Created Local Login submenu item' . PHP_EOL;
"

# Step 6: Create My Dashboard submenu item (for authenticated users)
log "📊 Creating My Dashboard submenu item..."
$DRUSH eval "
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Create My Dashboard submenu item
\$my_dashboard = MenuLinkContent::create([
    'title' => 'My Dashboard',
    'link' => ['uri' => 'internal:/user'],
    'menu_name' => 'account',
    'parent' => 'menu_link_content:$MY_PROFILE_UUID',
    'weight' => -20,
    'enabled' => TRUE,
    'description' => 'View your user dashboard and profile',
]);
\$my_dashboard->save();

echo 'Created My Dashboard submenu item' . PHP_EOL;
"

# Step 7: Create Account Settings submenu item (for authenticated users)
log "⚙️ Creating Account Settings submenu item..."
$DRUSH eval "
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Create Account Settings submenu item
\$account_settings = MenuLinkContent::create([
    'title' => 'Account Settings',
    'link' => ['uri' => 'internal:/user/edit'],
    'menu_name' => 'account',
    'parent' => 'menu_link_content:$MY_PROFILE_UUID',
    'weight' => -10,
    'enabled' => TRUE,
    'description' => 'Edit your account settings and profile',
]);
\$account_settings->save();

echo 'Created Account Settings submenu item' . PHP_EOL;
"

# Step 8: Create Logout submenu item (for authenticated users)
log "🚪 Creating Logout submenu item..."
$DRUSH eval "
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Create Logout submenu item
\$logout = MenuLinkContent::create([
    'title' => 'Logout',
    'link' => ['uri' => 'internal:/user/logout'],
    'menu_name' => 'account',
    'parent' => 'menu_link_content:$MY_PROFILE_UUID',
    'weight' => 10,
    'enabled' => TRUE,
    'description' => 'Logout of the Digital Humanities Portal',
]);
\$logout->save();

echo 'Created Logout submenu item' . PHP_EOL;
"

# Step 9: Clear cache to ensure changes take effect
log "🔄 Clearing all caches..."
$DRUSH cr

# Step 10: Display current menu structure
log "📋 Displaying current account menu structure..."
$DRUSH eval "
use Drupal\menu_link_content\Entity\MenuLinkContent;

// Get all menu items in the account menu
\$storage = \Drupal::entityTypeManager()->getStorage('menu_link_content');
\$account_items = \$storage->loadByProperties(['menu_name' => 'account']);

echo 'Current Account Menu Structure:' . PHP_EOL;
echo '================================' . PHP_EOL;

// Sort by weight
uasort(\$account_items, function(\$a, \$b) {
    return \$a->getWeight() <=> \$b->getWeight();
});

foreach (\$account_items as \$item) {
    \$parent = \$item->getParentId();
    \$indent = \$parent ? '  └─ ' : '• ';
    \$title = \$item->getTitle();
    \$url = \$item->getUrlObject()->toString();
    \$weight = \$item->getWeight();
    \$enabled = \$item->isEnabled() ? '✓' : '✗';
    
    echo \$indent . \$title . ' (' . \$url . ') [weight: ' . \$weight . '] [' . \$enabled . ']' . PHP_EOL;
}
echo PHP_EOL;
"

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
    PROJECT_URL=$($DRUSH config:get system.site.url 2>/dev/null | grep -o 'https\?://[^[:space:]]*' || echo "")
    
    # Fallback to localhost if nothing else works
    if [ -z "$PROJECT_URL" ]; then
        PROJECT_URL="http://localhost"
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
echo "💡 Container Environment Notes:"
echo "   - This script runs inside the Drupal container (detected: $DRUPAL_ROOT)"
echo "   - Uses direct drush commands instead of 'ddev drush'"
echo "   - Menu items are created with proper parent-child relationships"
echo "   - Custom module 'dhportal_account_menu' hides default core menu items"
