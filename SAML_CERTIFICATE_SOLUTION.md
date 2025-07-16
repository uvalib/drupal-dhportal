# SAML Certificate Management Solution

## 🎯 Solution Overview

Perfect! We can leverage your existing encrypted private key infrastructure and store the public certificates in the git repository. This approach provides:

- **Reuses existing infrastructure**: Same encrypted keys used for SSH access via `terraform-infrastructure/scripts/decrypt-key.ksh` and `crypt-key.ksh`
- **Git-friendly**: Public certificates are safe to store in repository  
- **Environment-specific**: Each environment gets its own signed certificate
- **Secure**: Private keys remain encrypted in terraform-infrastructure, never stored in application git
- **Seamless Integration**: Uses your existing deployment pipeline decrypt process

## 🏗️ Enhanced Implementation with Terraform Integration

### **1. Terraform Infrastructure Key Storage:**

```
terraform-infrastructure/
├── scripts/
│   ├── crypt-key.ksh           # Your existing encryption script
│   └── decrypt-key.ksh         # Your existing decryption script  
└── dh.library.virginia.edu/
    ├── staging/keys/
    │   ├── dh-drupal-staging.pem.cpt      # SSH key (existing)
    │   └── dh-drupal-staging-saml.pem.cpt # SAML key (new)
    └── production/keys/
        ├── dh-drupal-production.pem.cpt      # SSH key (existing)  
        └── dh-drupal-production-saml.pem.cpt # SAML key (new)
```

### **2. Application Repository Certificate Storage:**

```
saml-config/
├── certificates/           # Public certificates (safe in git)
│   ├── staging/
│   │   ├── saml-sp.crt         # Staging certificate (CA-signed)
│   │   └── saml-sp-chain.crt   # CA chain if needed
│   └── production/
│       ├── saml-sp.crt         # Production certificate (CA-signed)
│       └── saml-sp-chain.crt   # CA chain if needed
├── csr/                    # Certificate Signing Requests
│   ├── staging-saml-sp.csr     # For CA submission
│   └── production-saml-sp.csr  # For CA submission
└── dev/                    # Development certificates (excluded from git)
    ├── saml-sp.crt             # Self-signed dev cert
    └── saml-sp.key             # Dev private key
```

### **3. Enhanced Certificate Management Script:**

Created: `scripts/manage-saml-certificates-terraform.sh`

**Key Features:**
- Integrates with your existing `terraform-infrastructure/scripts/crypt-key.ksh` and `decrypt-key.ksh`
- Generates encrypted SAML private keys for terraform storage
- Uses terraform-decrypted keys during deployment
- Pairs decrypted keys with stored certificates from git repo
- Generates CSRs for certificate authority signing
- Falls back to self-signed for development

### **4. Integration with Your Deployment Pipeline:**

Your `deployspec.yml` already decrypts private keys:
```yaml
# decrypt the instance private key  
- PRIVATE_KEY_NAME=dh.library.virginia.edu/staging/keys/dh-drupal-staging.pem
- PRIVATE_KEY=${CODEBUILD_SRC_DIR}/terraform-infrastructure/${PRIVATE_KEY_NAME}
- ${CODEBUILD_SRC_DIR}/terraform-infrastructure/scripts/decrypt-key.ksh ${PRIVATE_KEY}.cpt ${PRIVATE_KEY_NAME}
```

**Enhanced SAML key decryption (NEW):**
```yaml
# decrypt the SAML private key (environment-specific)
- |
  if [ "$DEPLOYMENT_ENVIRONMENT" = "production" ]; then
    SAML_KEY_NAME=dh.library.virginia.edu/production/keys/dh-drupal-production-saml.pem
  else
    SAML_KEY_NAME=dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem
  fi
- SAML_PRIVATE_KEY=${CODEBUILD_SRC_DIR}/terraform-infrastructure/${SAML_KEY_NAME}
- ${CODEBUILD_SRC_DIR}/terraform-infrastructure/scripts/decrypt-key.ksh ${SAML_PRIVATE_KEY}.cpt ${SAML_KEY_NAME}
- chmod 600 ${SAML_PRIVATE_KEY}
```

**Enhanced script integration (NEW):**
```bash
# Deploy SAML certificates using terraform-decrypted keys
./scripts/manage-saml-certificates-terraform.sh deploy $DEPLOYMENT_ENVIRONMENT
```

## 🔧 Setup Process

### **For Each Environment (Staging & Production):**

1. **Generate encrypted private key and CSR:**
   ```bash
   # Generate staging SAML key (encrypted for terraform)
   ./scripts/manage-saml-certificates-terraform.sh generate-keys staging dh-staging.library.virginia.edu
   
   # Generate production SAML key (encrypted for terraform) 
   ./scripts/manage-saml-certificates-terraform.sh generate-keys production dh.library.virginia.edu
   ```

2. **Store encrypted keys in terraform repository:**
   ```bash
   # In terraform-infrastructure repository
   git add dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem.cpt
   git add dh.library.virginia.edu/production/keys/dh-drupal-production-saml.pem.cpt
   git commit -m "Add encrypted SAML private keys"
   ```

3. **Get certificate signed by UVA Certificate Authority**
   - Submit generated CSRs: `saml-config/csr/staging-saml-sp.csr` and `saml-config/csr/production-saml-sp.csr`

4. **Store signed certificate in application git repo:**
   ```bash
   # Store staging certificate (public - safe in git)
   cp signed-staging-cert.crt saml-config/certificates/staging/saml-sp.crt
   
   # Store production certificate (public - safe in git)
   cp signed-production-cert.crt saml-config/certificates/production/saml-sp.crt
   
   # Commit certificates to application repository
   git add saml-config/certificates/
   git commit -m "Add signed SAML certificates from UVA CA"
   ```

5. **Next deployment automatically uses proper certificates and terraform-decrypted keys**

## 🚀 Deployment Flow

### **Current Deployment:**
1. Decrypt SSH infrastructure private key ✅ (already working)
2. Clone drupal-dhportal repo ✅ (already working)
3. Build Docker container ✅ (already working)

### **Enhanced SAML Certificate Setup:**
4. **Decrypt SAML private key** using existing terraform infrastructure
5. **Deploy certificates** using terraform-decrypted key + stored certificate
6. **Creates SAML certificate files** for SimpleSAMLphp
7. **Ready for SAML authentication!**

## 🔄 Certificate Management Commands

### **Generate Keys (One-time Setup):**
```bash
# Generate encrypted SAML keys for terraform storage
./scripts/manage-saml-certificates-terraform.sh generate-keys staging dh-staging.library.virginia.edu
./scripts/manage-saml-certificates-terraform.sh generate-keys production dh.library.virginia.edu
```

### **Deploy (Automatic during deployment):**
```bash  
# Deploy certificates using terraform-decrypted keys
TERRAFORM_REPO_PATH=/path/to/terraform-infrastructure \
./scripts/manage-saml-certificates-terraform.sh deploy staging

TERRAFORM_REPO_PATH=/path/to/terraform-infrastructure \
./scripts/manage-saml-certificates-terraform.sh deploy production
```

### **Development (Local):**
```bash
# Generate self-signed certificate for local development
./scripts/manage-saml-certificates-terraform.sh deploy dev
```

### **Certificate Info:**
```bash
# View current certificate details
./scripts/manage-saml-certificates-terraform.sh info
```

## ✅ Next Steps

1. **Generate encrypted SAML private keys** for staging and production environments
2. **Store encrypted keys** in terraform-infrastructure repository  
3. **Submit CSRs** to UVA Certificate Authority for signing
4. **Store signed certificates** in application git repository:
   - `saml-config/certificates/staging/saml-sp.crt`
   - `saml-config/certificates/production/saml-sp.crt`
5. **Test deployment** with new terraform-integrated certificate management

## 🔐 Security Benefits

- **Private keys**: Encrypted using your existing terraform infrastructure, never in application git
- **Public certificates**: Safe to store in application git, environment-specific  
- **Reuses existing security model**: Same encryption/decryption as SSH keys via `crypt-key.ksh` and `decrypt-key.ksh`
- **Proper CA signing**: Legitimate certificates from UVA Certificate Authority
- **Environment isolation**: Each environment has its own encrypted key/certificate pair
- **Deployment integration**: Seamless integration with existing deployment pipeline

This approach perfectly aligns with your existing terraform infrastructure security practices and leverages the same battle-tested encryption/decryption system you already use for SSH keys!
