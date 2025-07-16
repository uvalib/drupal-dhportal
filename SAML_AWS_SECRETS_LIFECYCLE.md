# SAML Certificate Lifecycle with AWS Secrets Bootstrapping

## 🔐 Complete AWS Secrets Integration

This document extends the SAML certificate lifecycle to include AWS secrets management for encryption passphrases, providing a complete end-to-end secure workflow.

## 🏗️ Enhanced Architecture

### **Complete Security Stack:**
```
AWS Secrets Manager
├── dh-drupal-staging-saml-passphrase     # Staging encryption passphrase
└── dh-drupal-production-saml-passphrase  # Production encryption passphrase

terraform-infrastructure/
├── scripts/
│   ├── add-secret.ksh          # Bootstrap AWS secrets (passphrases)
│   ├── crypt-key.ksh           # Encrypt private keys using passphrases
│   └── decrypt-key.ksh         # Decrypt keys during deployment
└── dh.library.virginia.edu/
    ├── staging/keys/
    │   └── dh-drupal-staging-saml.pem.cpt    # Encrypted SAML private key
    └── production/keys/
        └── dh-drupal-production-saml.pem.cpt # Encrypted SAML private key

drupal-dhportal/
└── saml-config/certificates/
    ├── staging/saml-sp.crt       # Public certificate (safe in git)
    └── production/saml-sp.crt    # Public certificate (safe in git)
```

## 🚀 Complete Implementation Workflow

### **Phase 1: Bootstrap AWS Secrets (One-time Setup)**

#### **1. Create Encryption Passphrases in AWS Secrets Manager:**
```bash
# Bootstrap staging environment secrets
./scripts/manage-saml-certificates-terraform.sh bootstrap-secrets staging

# Bootstrap production environment secrets  
./scripts/manage-saml-certificates-terraform.sh bootstrap-secrets production
```

**What this does:**
- Uses `terraform-infrastructure/scripts/add-secret.ksh` to create AWS secrets
- Generates secure random passphrases (32 characters)
- Stores in AWS Secrets Manager with descriptive names:
  - `dh-drupal-staging-saml-passphrase`
  - `dh-drupal-production-saml-passphrase`

### **Phase 2: Generate Encrypted SAML Private Keys**

#### **2. Generate SAML Private Keys (Encrypted with AWS Secrets):**
```bash
# Generate staging SAML private key (encrypted using AWS secret passphrase)
./scripts/manage-saml-certificates-terraform.sh generate-keys staging dh-staging.library.virginia.edu

# Generate production SAML private key (encrypted using AWS secret passphrase)
./scripts/manage-saml-certificates-terraform.sh generate-keys production dh.library.virginia.edu
```

**What this does:**
- Generates RSA private key and CSR
- Retrieves passphrase from AWS Secrets Manager
- Encrypts private key using `terraform-infrastructure/scripts/crypt-key.ksh`
- Stores encrypted key in terraform-infrastructure repository
- Saves CSR for UVA CA submission

#### **3. Store Encrypted Keys in Terraform Repository:**
```bash
# In terraform-infrastructure repository
git add dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem.cpt
git add dh.library.virginia.edu/production/keys/dh-drupal-production-saml.pem.cpt
git commit -m "Add encrypted SAML private keys for drupal-dhportal"
```

### **Phase 3: Certificate Authority Integration**

#### **4. Submit CSRs to UVA Certificate Authority:**
- Submit `saml-config/csr/staging-saml-sp.csr` to UVA CA
- Submit `saml-config/csr/production-saml-sp.csr` to UVA CA
- Receive signed certificates from UVA CA

#### **5. Store Signed Certificates in Application Repository:**
```bash
# Store signed certificates (public - safe in git)
cp staging-signed-cert.crt saml-config/certificates/staging/saml-sp.crt
cp production-signed-cert.crt saml-config/certificates/production/saml-sp.crt

# Commit to application repository
git add saml-config/certificates/
git commit -m "Add UVA CA signed SAML certificates"
```

### **Phase 4: Automated Deployment**

#### **6. CI/CD Pipeline Deployment (Automatic):**

The `deployspec.yml` already handles:
```yaml
# Decrypt SAML private key using terraform infrastructure
${CODEBUILD_SRC_DIR}/terraform-infrastructure/scripts/decrypt-key.ksh ${SAML_PRIVATE_KEY}.cpt ${SAML_KEY_NAME}

# Deploy SAML certificates automatically
./scripts/manage-saml-certificates-terraform.sh deploy $DEPLOYMENT_ENVIRONMENT
```

**What happens during deployment:**
1. AWS Secrets Manager provides passphrase
2. `decrypt-key.ksh` decrypts SAML private key
3. Private key + stored certificate = Ready for SimpleSAMLphp
4. Certificates deployed to container automatically

## 🔧 Management Commands

### **Bootstrap Secrets (One-time per environment):**
```bash
# Create AWS secrets for encryption passphrases
./scripts/manage-saml-certificates-terraform.sh bootstrap-secrets staging
./scripts/manage-saml-certificates-terraform.sh bootstrap-secrets production
```

### **Generate Keys (One-time per environment):**
```bash
# Generate encrypted SAML private keys
./scripts/manage-saml-certificates-terraform.sh generate-keys staging
./scripts/manage-saml-certificates-terraform.sh generate-keys production
```

### **Deploy (Automatic during CI/CD):**
```bash
# Deploy certificates using decrypted keys
./scripts/manage-saml-certificates-terraform.sh deploy staging
./scripts/manage-saml-certificates-terraform.sh deploy production
```

### **Certificate Information:**
```bash
# View certificate details
./scripts/manage-saml-certificates-terraform.sh info
./scripts/manage-saml-certificates-terraform.sh info staging
```

## 🔄 Certificate Renewal Process

### **Annual Certificate Renewal:**
1. **Reuse existing keys and secrets** (no regeneration needed)
2. **Generate new CSR** with existing private key
3. **Submit to UVA CA** for renewal
4. **Update certificate in git** repository
5. **Deploy automatically** via CI/CD

## 🔐 Security Model Summary

### **Three-Layer Security:**

1. **AWS Secrets Manager**: Stores encryption passphrases
   - Managed by `add-secret.ksh`
   - Secure random generation (32 characters)
   - AWS IAM access controls

2. **Terraform Infrastructure**: Stores encrypted private keys  
   - Encrypted using `crypt-key.ksh` with AWS secrets passphrases
   - Version controlled in secure terraform repository
   - Decrypted only during deployment using `decrypt-key.ksh`

3. **Application Repository**: Stores public certificates
   - Public certificates safe for version control
   - Environment-specific certificates
   - No sensitive data exposed

### **Security Benefits:**
✅ **Zero Plaintext Keys**: No unencrypted private keys anywhere  
✅ **AWS Secrets**: Passphrases managed by AWS Secrets Manager  
✅ **Existing Infrastructure**: Reuses your proven security model  
✅ **Environment Isolation**: Separate secrets and keys per environment  
✅ **Automated Deployment**: Secure key decryption during CI/CD only  

## 📋 Troubleshooting

### **AWS Secrets Issues:**
```bash
# Check if secret exists
aws secretsmanager describe-secret --secret-id dh-drupal-staging-saml-passphrase

# Verify secret value (be careful - sensitive!)
aws secretsmanager get-secret-value --secret-id dh-drupal-staging-saml-passphrase
```

### **Key Encryption Issues:**
```bash
# Verify encrypted key exists
ls -la terraform-infrastructure/dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem.cpt

# Test decryption (during troubleshooting)
cd terraform-infrastructure
./scripts/decrypt-key.ksh dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem.cpt
```

### **Certificate Deployment Issues:**
```bash
# Manual certificate deployment for testing
TERRAFORM_REPO_PATH=/path/to/terraform-infrastructure \
./scripts/manage-saml-certificates-terraform.sh deploy staging

# Check certificate/key pair validation
openssl x509 -noout -modulus -in certificate.crt | openssl md5
openssl rsa -noout -modulus -in private.key | openssl md5
```

## 🎯 Implementation Checklist

- [ ] **Bootstrap AWS secrets** for staging and production
- [ ] **Generate encrypted SAML private keys** using AWS secrets
- [ ] **Store encrypted keys** in terraform-infrastructure repository
- [ ] **Submit CSRs** to UVA Certificate Authority
- [ ] **Store signed certificates** in application repository
- [ ] **Test deployment** via CI/CD pipeline
- [ ] **Validate SAML authentication** in each environment
- [ ] **Document renewal procedures** for next year

**Status**: ✅ **Ready for complete implementation with AWS secrets integration**
