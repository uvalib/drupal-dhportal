#!/bin/bash

# SimpleSAMLphp Production Entrypoint
# This script sets up SAML certificates and starts the web server

set -e

echo "🔐 Setting up SAML certificates for production..."

# Run certificate setup with production mode
/opt/drupal/scripts/manage-saml-certificates.sh prod

echo "✅ SAML certificate setup completed"

# Continue with the original entrypoint
exec "$@"
