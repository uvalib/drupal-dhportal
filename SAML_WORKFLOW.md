# SAML Certificate Workflow - Static Certificate Strategy

## 🎯 **Overview**

The SAML certificates are **static after initial creation** because:
- NetBadge admin configures their IDP with your public certificate data
- Changing certificates breaks the SAML trust relationship  
- Consistent certificates ensure reliable authentication across deployments

## 📋 **One-Time Setup Workflow**

### **Step 1: Generate Certificates (Initial Setup Only)**
```bash
# Run the certificate generation script
./scripts/generate-saml-certificates.sh

# This creates:
# - saml-config/temp/staging/saml-sp-staging.csr
# - saml-config/temp/production/saml-sp-production.csr
# - Private keys and self-signed certificates for testing
```

### **Step 2: Get Certificates Signed by UVA CA**
```bash
# Submit CSRs to University of Virginia Certificate Authority
# Wait for signed certificates to be returned
```

### **Step 3: Store Signed Certificates in Git**
```bash
# Copy signed certificates to permanent locations
cp signed-staging-cert.crt saml-config/certificates/staging/saml-sp.crt
cp signed-production-cert.crt saml-config/certificates/production/saml-sp.crt

# Commit to git repository (public certificates are safe)
git add saml-config/certificates/
git commit -m "Add static SAML certificates for staging and production"
git push
```

### **Step 4: Send Certificate Data to NetBadge Admin**
```bash
# Extract certificate data for NetBadge admin
echo "=== STAGING CERTIFICATE DATA ==="
openssl x509 -in saml-config/certificates/staging/saml-sp.crt -text -noout

echo "=== PRODUCTION CERTIFICATE DATA ==="  
openssl x509 -in saml-config/certificates/production/saml-sp.crt -text -noout

# Send this certificate information to NetBadge admin for IDP configuration
```

## 🚀 **Deployment Process (Every Deploy)**

### **Ansible Integration**
Add this single task to your `deploy_backend_1.yml`:

```yaml
- name: Setup static SAML certificates
  shell: |
    # Setup certificates using stored certificates + infrastructure private keys
    export DEPLOYMENT_ENVIRONMENT="{{ deployment_environment | default('staging') }}"
    export TERRAFORM_INFRA_DIR="{{ ansible_env.PWD }}/../../terraform-infrastructure"
    
    # Run certificate setup in container (uses existing certificates)
    docker exec drupal-0 bash -c "
      export TERRAFORM_INFRA_DIR=/opt/drupal/terraform-infrastructure &&
      /opt/drupal/scripts/manage-saml-certificates-enhanced.sh \$DEPLOYMENT_ENVIRONMENT
    "
    
    # Validate setup
    docker exec drupal-0 /opt/drupal/scripts/test-simplesamlphp.sh
  tags: saml-certificates
```

### **What Happens During Each Deployment:**
1. **Enhanced script detects environment** (staging vs production)
2. **Uses decrypted infrastructure private key** (from deployspec.yml)
3. **Pairs with stored public certificate** (from git repository)
4. **Creates certificate files** in container for SimpleSAMLphp
5. **Validates certificate setup**

## 🔄 **Certificate Renewal (Annual/Before Expiration)**

### **When to Renew:**
- Certificate approaching expiration (typically annually)
- Security policy requires rotation
- Certificate compromise (emergency renewal)

### **Renewal Process:**
```bash
# 1. Generate new CSR using existing private key
./scripts/generate-saml-certificates.sh  # (updates CSRs only)

# 2. Submit new CSRs to UVA CA
# 3. Receive new signed certificates

# 4. Coordinate with NetBadge admin BEFORE updating
# 5. Update certificates in git repository
cp new-signed-staging-cert.crt saml-config/certificates/staging/saml-sp.crt
cp new-signed-production-cert.crt saml-config/certificates/production/saml-sp.crt

# 6. Commit and deploy
git add saml-config/certificates/
git commit -m "Renew SAML certificates - coordinated with NetBadge admin"
git push

# 7. Deploy to environments
```

## 📁 **File Structure (Final)**

```
saml-config/
├── certificates/
│   ├── staging/
│   │   └── saml-sp.crt           # ✅ Static staging certificate (in git)
│   └── production/
│       └── saml-sp.crt           # ✅ Static production certificate (in git)
├── temp/                         # 🚫 Ignored (temporary files)
└── README.md                     # ✅ Documentation (in git)
```

## 🛡️ **Security Summary**

- ✅ **Public certificates**: Stored in git, static across deployments
- 🔐 **Private keys**: Encrypted in terraform-infrastructure, never in git
- 🔄 **Certificate pairing**: Happens automatically during deployment
- 📧 **NetBadge coordination**: Required for any certificate changes
- 🏷️ **Certificate validation**: Automated testing during deployment

This approach ensures **consistent SAML authentication** while maintaining security and operational simplicity.
