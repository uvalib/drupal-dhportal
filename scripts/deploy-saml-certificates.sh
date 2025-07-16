#!/bin/bash

# SAML Certificate Setup for Container Deployment
# This script is called during Ansible deployment to set up SAML certificates

set -e

# Source environment variables from deployment
if [ -f "/tmp/env" ]; then
    source /tmp/env
fi

DEPLOYMENT_ENV="${DEPLOYMENT_ENVIRONMENT:-staging}"

echo "🔐 Setting up SAML certificates for $DEPLOYMENT_ENV environment..."

# Ensure terraform infrastructure is available in container
if [ -n "$TERRAFORM_INFRA_DIR" ] && [ -d "$TERRAFORM_INFRA_DIR" ]; then
    # Copy terraform infrastructure to container for certificate access
    docker exec drupal-0 mkdir -p /opt/drupal/terraform-infrastructure
    docker cp "$TERRAFORM_INFRA_DIR/." drupal-0:/opt/drupal/terraform-infrastructure/
    
    # Set environment variables in container
    docker exec drupal-0 bash -c "export TERRAFORM_INFRA_DIR=/opt/drupal/terraform-infrastructure"
    docker exec drupal-0 bash -c "export DEPLOYMENT_ENVIRONMENT=$DEPLOYMENT_ENV"
    
    # Run enhanced certificate setup in container
    docker exec drupal-0 /opt/drupal/scripts/manage-saml-certificates-enhanced.sh "$DEPLOYMENT_ENV"
    
    echo "✅ SAML certificates configured for $DEPLOYMENT_ENV environment"
else
    echo "⚠️  Terraform infrastructure not available, using fallback certificate setup"
    docker exec drupal-0 /opt/drupal/scripts/manage-saml-certificates-enhanced.sh dev
fi

echo "🎉 SAML certificate setup completed!"
