#!/bin/bash

# SimpleSAMLphp Production Entrypoint
# This script sets up SAML certificates and starts the web server

set -e

echo "🔐 Setting up SAML certificates for production..."

# Run certificate setup with production mode
/opt/drupal/scripts/manage-saml-certificates.sh prod

echo "✅ SAML certificate setup completed"

echo "🔍 Runtime SimpleSAMLphp debugging:"
echo "Web directory contents:"
ls -la /opt/drupal/web/ | grep -E "(simplesaml|total)"
echo "Symlink details:"
file /opt/drupal/web/simplesaml || echo "Symlink does not exist"
ls -la /opt/drupal/web/simplesaml/ 2>/dev/null | head -5 || echo "Cannot list symlink contents"
echo "Target directory:"
ls -la /opt/drupal/vendor/simplesamlphp/simplesamlphp/public/ 2>/dev/null | head -5 || echo "Target directory not accessible"
echo "Index.php check:"
ls -la /opt/drupal/web/simplesaml/index.php || echo "index.php not accessible via symlink"
echo "Apache user can access:"
su www-data -s /bin/bash -c "ls -la /opt/drupal/web/simplesaml/index.php" || echo "www-data cannot access index.php"
echo "Full path resolution test:"
realpath /opt/drupal/web/simplesaml/index.php || echo "Cannot resolve real path"
echo "Directory permissions on symlink path:"
ls -ld /opt/drupal/web/simplesaml
ls -ld /opt/drupal/vendor/simplesamlphp/simplesamlphp/public
echo "Apache configuration check:"
grep -A 5 -B 2 "DocumentRoot\|Directory.*drupal" /etc/apache2/sites-enabled/000-default.conf

# Continue with the original entrypoint
exec "$@"
