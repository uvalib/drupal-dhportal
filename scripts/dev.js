#!/usr/bin/env node

/**
 * DHPortal Development Script
 * Cross-platform development utilities for Drupal DHPortal
 */

const { exec, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// Colors for console output
const colors = {
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  reset: '\x1b[0m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function execAsync(command) {
  return new Promise((resolve, reject) => {
    exec(command, (error, stdout, stderr) => {
      if (error) {
        reject({ error, stderr });
      } else {
        resolve(stdout.trim());
      }
    });
  });
}

async function showHelp() {
  log('\n🎯 DHPortal Development Commands\n', 'cyan');
  
  log('📋 Setup Commands:', 'yellow');
  log('  npm run start         🚀 Start DDEV environment');
  log('  npm run setup         ⚙️  Run complete setup (SAML + Menu)');
  log('  npm run setup:saml    🔐 Setup SAML integration only');
  log('  npm run setup:menu    🎯 Setup account menu only');
  log('  npm run reset         🔄 Reset to fresh state');
  
  log('\n🧪 Testing Commands:', 'yellow');
  log('  npm run test:menu     🎯 Test account menu structure');
  log('  npm run menu:validate ✅ Validate menu configuration');
  log('  npm run status        📊 Show project status');
  
  log('\n🔧 Development Commands:', 'yellow');
  log('  npm run drush         🔧 Open Drush shell');
  log('  npm run admin         👤 Show admin URLs');
  log('  npm run logs          📋 Show DDEV logs');
  log('  npm run menu:rebuild  🔨 Rebuild menu cache');
  
  log('\n🧹 Maintenance Commands:', 'yellow');
  log('  npm run clean         🧹 Clean up containers');
  log('  npm run config:export 📤 Export configuration');
  log('  npm run config:import 📥 Import configuration');
  
  log('\n📚 For more help:', 'cyan');
  log('  README.md             📖 Full documentation');
  log('  TESTING_GUIDE.md      🧪 Testing procedures');
  log('  scripts/README.md     📋 Script documentation\n');
}

async function getProjectStatus() {
  log('\n📊 DHPortal Project Status\n', 'cyan');
  
  try {
    // Check DDEV status
    log('🐳 DDEV Status:', 'yellow');
    const ddevStatus = await execAsync('ddev describe');
    const statusLines = ddevStatus.split('\n').slice(0, 5);
    statusLines.forEach(line => log(`  ${line}`, 'green'));
    
    // Check if site is accessible
    log('\n🌐 Site Status:', 'yellow');
    try {
      await execAsync('curl -f -s -k https://drupal-dhportal.ddev.site:8443 > /dev/null');
      log('  ✅ Site is accessible', 'green');
    } catch {
      log('  ❌ Site is not accessible', 'red');
    }
    
    // Check custom module status
    log('\n📦 Custom Module Status:', 'yellow');
    try {
      const moduleStatus = await execAsync('ddev drush pm:list --filter=dhportal_account_menu --format=json');
      const modules = JSON.parse(moduleStatus);
      if (modules.dhportal_account_menu) {
        const status = modules.dhportal_account_menu.status;
        log(`  dhportal_account_menu: ${status === 'Enabled' ? '✅' : '❌'} ${status}`, 
            status === 'Enabled' ? 'green' : 'red');
      } else {
        log('  ❌ dhportal_account_menu: Not found', 'red');
      }
    } catch (error) {
      log('  ⚠️  Could not check module status', 'yellow');
    }
    
    // Check SAML modules
    log('\n🔐 SAML Module Status:', 'yellow');
    try {
      // Check each module individually since the filter doesn't support OR syntax
      const moduleNames = ['simplesamlphp_auth', 'externalauth'];
      
      for (const moduleName of moduleNames) {
        try {
          const moduleInfo = await execAsync(`ddev drush pm:list --filter="${moduleName}" --format=json`);
          const modules = JSON.parse(moduleInfo);
          
          if (modules[moduleName]) {
            const status = modules[moduleName].status;
            log(`  ${moduleName}: ${status === 'Enabled' ? '✅' : '❌'} ${status}`, 
                status === 'Enabled' ? 'green' : 'red');
          } else {
            log(`  ${moduleName}: ❌ Not installed`, 'red');
          }
        } catch (moduleError) {
          log(`  ${moduleName}: ❌ Not installed`, 'red');
        }
      }
    } catch (error) {
      log('  ⚠️  Could not check SAML module status', 'yellow');
    }
    
  } catch (error) {
    log('❌ Error getting project status:', 'red');
    log(`   ${error.message}`, 'red');
  }
  
  log(''); // Empty line
}

async function testAccountMenu() {
  log('\n🎯 Testing Account Menu Structure\n', 'cyan');
  
  try {
    // Test basic menu structure first
    log('📋 Checking menu structure...', 'yellow');
    
    const menuCheck = await execAsync(`ddev drush eval "
      \\$menu_tree = \\Drupal::menuTree();
      \\$parameters = new \\Drupal\\Core\\Menu\\MenuTreeParameters();
      \\$parameters->setRoot('')->setMaxDepth(2)->excludeRoot();
      \\$tree = \\$menu_tree->load('account', \\$parameters);
      foreach (\\$tree as \\$item) {
        \\$link = \\$item->link;
        echo 'Item: ' . \\$link->getTitle() . ' | Route: ' . \\$link->getUrlObject()->getRouteName() . ' | UUID: ' . \\$link->getPluginId() . PHP_EOL;
        if (\\$item->subtree) {
          foreach (\\$item->subtree as \\$child) {
            \\$child_link = \\$child->link;
            echo '  Child: ' . \\$child_link->getTitle() . ' | Route: ' . \\$child_link->getUrlObject()->getRouteName() . ' | UUID: ' . \\$child_link->getPluginId() . PHP_EOL;
          }
        }
      }
    "`);
    
    log('Current menu structure:', 'blue');
    console.log(menuCheck);
    
    // Analyze the structure
    const lines = menuCheck.split('\n').filter(line => line.trim());
    const parentItems = lines.filter(line => !line.startsWith('  '));
    const childItems = lines.filter(line => line.startsWith('  '));
    
    log(`\n📊 Menu Analysis:`, 'blue');
    log(`  Parent items: ${parentItems.length}`, 'blue');
    log(`  Child items: ${childItems.length}`, 'blue');
    
    // Check for expected structure
    const hasMyProfile = lines.some(line => line.includes('My Profile') && line.includes('<nolink>'));
    const hasNetbadgeLogin = lines.some(line => line.includes('Netbadge Login') && line.includes('simplesamlphp_auth.saml_login'));
    const hasPartnerLogin = lines.some(line => line.includes('Partner Login') && line.includes('user.login'));
    
    log(`\n✅ Structure validation:`, 'green');
    log(`  My Profile parent: ${hasMyProfile ? '✅' : '❌'}`, hasMyProfile ? 'green' : 'red');
    log(`  Netbadge Login child: ${hasNetbadgeLogin ? '✅' : '❌'}`, hasNetbadgeLogin ? 'green' : 'red');
    log(`  Partner Login child: ${hasPartnerLogin ? '✅' : '❌'}`, hasPartnerLogin ? 'green' : 'red');
    
    // Test custom module status
    log('\n📦 Checking custom module status...', 'yellow');
    const moduleCheck = await execAsync('ddev drush pm:list --type=module --status=enabled | grep dhportal');
    if (moduleCheck.includes('dhportal_account_menu')) {
      log('✅ dhportal_account_menu module is enabled', 'green');
    } else {
      log('❌ dhportal_account_menu module is not enabled', 'red');
    }
    
    // Note about the menu items we see
    const coreRoutes = lines.filter(line => 
      line.includes('user.login') || line.includes('user.page') || line.includes('user.logout')
    );
    
    if (coreRoutes.length > 0) {
      log('\n📝 Note about core routes in menu:', 'yellow');
      log('  The following items use core user routes but are custom menu items:', 'yellow');
      coreRoutes.forEach(route => log(`    ${route.trim()}`, 'yellow'));
      log('  This is expected - our custom module only prevents core menu', 'yellow');
      log('  items from auto-appearing, but these are manually created.', 'yellow');
    }
    
  } catch (error) {
    log('❌ Error testing account menu:', 'red');
    log(`   ${error.stderr || error.message}`, 'red');
  }
  
  log(''); // Empty line
}

async function validateMenu() {
  log('\n✅ Validating Account Menu Configuration\n', 'cyan');
  
  try {
    // Get all account menu items at once
    log('🔍 Fetching all account menu items...', 'yellow');
    
    const allMenuItems = await execAsync(`ddev drush eval "
      \\$menu_tree = \\Drupal::menuTree();
      \\$parameters = new \\Drupal\\Core\\Menu\\MenuTreeParameters();
      \\$parameters->setRoot('')->setMaxDepth(2)->excludeRoot();
      \\$tree = \\$menu_tree->load('account', \\$parameters);
      \\$items = [];
      foreach (\\$tree as \\$item) {
        \\$link = \\$item->link;
        \\$items[] = \\$link->getTitle();
        if (\\$item->subtree) {
          foreach (\\$item->subtree as \\$child) {
            \\$child_link = \\$child->link;
            \\$items[] = \\$child_link->getTitle();
          }
        }
      }
      echo implode(',', \\$items);
    "`);
    
    const foundItems = allMenuItems.split(',').filter(item => item.trim());
    
    // Check expected structure
    const expectedItems = [
      { name: 'My Profile', required: true, type: 'parent' },
      { name: 'Netbadge Login', required: true, type: 'child' },
      { name: 'Partner Login', required: true, type: 'child' },
      { name: 'View Profile', required: true, type: 'child' },
      { name: 'Logout', required: true, type: 'child' }
    ];
    
    log('\n� Menu items validation:', 'blue');
    
    let allValid = true;
    for (const expected of expectedItems) {
      const found = foundItems.some(item => item.includes(expected.name));
      if (found) {
        log(`  ✅ ${expected.name} (${expected.type})`, 'green');
      } else if (expected.required) {
        log(`  ❌ ${expected.name} (${expected.type}) - MISSING`, 'red');
        allValid = false;
      } else {
        log(`  ⚠️  ${expected.name} (${expected.type}) - optional`, 'yellow');
      }
    }
    
    // Check for unexpected items (excluding expected ones)
    const unexpectedItems = foundItems.filter(item => 
      !expectedItems.some(expected => item.includes(expected.name))
    );
    
    if (unexpectedItems.length > 0) {
      log('\n⚠️  Unexpected menu items found:', 'yellow');
      unexpectedItems.forEach(item => log(`    ${item}`, 'yellow'));
    }
    
    // Overall status
    log('\n📊 Validation Summary:', 'blue');
    log(`  Total items found: ${foundItems.length}`, 'blue');
    log(`  Expected items: ${expectedItems.length}`, 'blue');
    log(`  Status: ${allValid ? '✅ VALID' : '❌ ISSUES FOUND'}`, allValid ? 'green' : 'red');
    
    if (allValid) {
      log('\n🎉 Account menu configuration is valid!', 'green');
    } else {
      log('\n❌ Please run setup scripts to fix menu configuration.', 'red');
    }
    
  } catch (error) {
    log('❌ Error validating menu:', 'red');
    log(`   ${error.stderr || error.message}`, 'red');
  }
  
  log(''); // Empty line
}

async function main() {
  const command = process.argv[2];
  
  switch (command) {
    case 'help':
      await showHelp();
      break;
    case 'status':
      await getProjectStatus();
      break;
    case 'testMenu':
      await testAccountMenu();
      break;
    case 'validateMenu':
      await validateMenu();
      break;
    default:
      log('❌ Unknown command. Run "npm run help" for available commands.', 'red');
      process.exit(1);
  }
}

if (require.main === module) {
  main().catch(error => {
    log(`❌ Error: ${error.message}`, 'red');
    process.exit(1);
  });
}

module.exports = {
  showHelp,
  getProjectStatus,
  testAccountMenu,
  validateMenu
};
