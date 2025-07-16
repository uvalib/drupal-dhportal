# SAML Certificate AWS Secrets Bootstrap Guide

This guide covers the complete bootstrapping process for SAML certificate management using AWS Secrets Manager integration with your existing terraform infrastructure.

## 🎯 Overview

The bootstrap process creates the complete infrastructure needed for secure SAML certificate lifecycle management:

1. **Encrypted Private Keys** → Stored in terraform-infrastructure repository
2. **AWS Secrets** → Passphrases for private key encryption
3. **Certificate Storage** → Public certificates in application repository
4. **CSR Generation** → Ready for UVA CA submission

## 🏗️ Infrastructure Components

### **AWS Secrets Manager Integration**

Your existing `terraform-infrastructure/scripts/` tools are used:

```bash
add-secret.ksh       # Creates new AWS secrets
get-secret.ksh       # Retrieves secrets during deployment
crypt-key.ksh        # Encrypts private keys
decrypt-key.ksh      # Decrypts keys during deployment
```

### **Secret Names Created**
- `dh-drupal-staging-saml-passphrase` → Staging private key encryption
- `dh-drupal-production-saml-passphrase` → Production private key encryption

### **File Structure Created**

```
terraform-infrastructure/
└── dh.library.virginia.edu/
    ├── staging/keys/
    │   └── dh-drupal-staging-saml.pem.cpt     # Encrypted SAML private key
    └── production/keys/
        └── dh-drupal-production-saml.pem.cpt  # Encrypted SAML private key

drupal-dhportal/
└── saml-config/
    ├── csr/
    │   ├── staging-saml-sp.csr                # For UVA CA submission
    │   └── production-saml-sp.csr             # For UVA CA submission
    └── certificates/
        ├── staging/
        │   └── README.md                      # Instructions for certificate storage
        └── production/
            └── README.md                      # Instructions for certificate storage
```

## 🚀 Bootstrap Process

### **Prerequisites**

1. **Repository Access**:
   ```bash
   # Ensure you have both repositories cloned
   git clone https://gitlab.com/uvalib/terraform-infrastructure.git
   git clone https://github.com/uvalib/drupal-dhportal.git
   ```

2. **AWS CLI Configuration**:
   ```bash
   aws configure list  # Verify AWS credentials
   aws secretsmanager list-secrets  # Test access
   ```

3. **Required Tools**:
   ```bash
   # Verify tools are installed
   which openssl aws jq pwgen
   ```

### **Run Bootstrap**

```bash
cd drupal-dhportal

# Set paths if repositories are in non-standard locations
export TERRAFORM_REPO_PATH=/path/to/terraform-infrastructure
export DRUPAL_DHPORTAL_PATH=/path/to/drupal-dhportal

# Bootstrap both environments
./scripts/bootstrap-saml-certificates.sh both

# Or bootstrap individually
./scripts/bootstrap-saml-certificates.sh staging
./scripts/bootstrap-saml-certificates.sh production
```

### **Bootstrap Output**

The script will:

1. ✅ **Generate RSA private keys** (2048-bit) for each environment
2. ✅ **Create AWS secrets** for encryption passphrases using `add-secret.ksh`
3. ✅ **Encrypt private keys** using `crypt-key.ksh` with generated passphrases
4. ✅ **Generate CSRs** for UVA Certificate Authority submission
5. ✅ **Create certificate directories** with instructions
6. ✅ **Validate** all components were created successfully

## 📋 Post-Bootstrap Steps

### **1. Commit Infrastructure Changes**

```bash
cd terraform-infrastructure

# Review what was created
git status
git diff

# Commit encrypted private keys
git add dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem.cpt
git add dh.library.virginia.edu/production/keys/dh-drupal-production-saml.pem.cpt
git commit -m "Add encrypted SAML private keys for drupal-dhportal

- Staging: dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem.cpt
- Production: dh.library.virginia.edu/production/keys/dh-drupal-production-saml.pem.cpt
- AWS secrets created for encryption passphrases
- Ready for UVA CA certificate signing"
```

### **2. Submit CSRs to UVA Certificate Authority**

```bash
cd drupal-dhportal

# Submit these files to UVA CA:
cat saml-config/csr/staging-saml-sp.csr     # Staging CSR
cat saml-config/csr/production-saml-sp.csr  # Production CSR
```

**Email to UVA CA should include:**
- CSR files (staging and production)
- Purpose: SAML authentication for Digital Humanities Portal
- Domains: `dh-staging.library.virginia.edu` and `dh.library.virginia.edu`
- Contact information for certificate delivery

### **3. Store Signed Certificates**

Once you receive signed certificates from UVA CA:

```bash
cd drupal-dhportal

# Store staging certificate
cp staging-signed-certificate.crt saml-config/certificates/staging/saml-sp.crt

# Store production certificate
cp production-signed-certificate.crt saml-config/certificates/production/saml-sp.crt

# Store CA chain if provided
cp ca-chain.crt saml-config/certificates/staging/saml-sp-chain.crt
cp ca-chain.crt saml-config/certificates/production/saml-sp-chain.crt

# Commit certificates (safe for git - public certificates)
git add saml-config/certificates/
git commit -m "Add UVA CA signed SAML certificates

- Staging certificate for dh-staging.library.virginia.edu
- Production certificate for dh.library.virginia.edu
- Ready for deployment and SAML authentication"
```

## 🔄 Deployment Integration

### **Enhanced Pipeline Process**

Your `pipeline/deployspec.yml` now includes:

1. **AWS Secret Retrieval**:
   ```yaml
   SAML_PASSPHRASE=$(cd terraform-infrastructure && ./scripts/get-secret.ksh ${SAML_SECRET_NAME})
   ```

2. **Private Key Decryption**:
   ```yaml
   terraform-infrastructure/scripts/decrypt-key.ksh ${SAML_PRIVATE_KEY}.cpt ${SAML_KEY_NAME}
   ```

3. **Certificate Deployment**:
   ```bash
   ./scripts/manage-saml-certificates-terraform.sh deploy $DEPLOYMENT_ENVIRONMENT
   ```

### **Automatic Process During Deployment**

1. **Pre-Build**: Decrypt SAML private key using AWS secret passphrase
2. **Build**: Deploy certificates to SimpleSAMLphp using decrypted key + stored certificate
3. **Result**: SAML authentication ready

## 🔍 Validation and Monitoring

### **Check Bootstrap Status**

```bash
./scripts/bootstrap-saml-certificates.sh status
```

**Expected Output:**
```
📋 staging Environment:
  Domain: dh-staging.library.virginia.edu
  Private Key: ✅ Encrypted and stored
  AWS Secret:  ✅ Available
  CSR:         ✅ Ready for CA submission
  Certificate: ⏳ Pending CA signing

📋 production Environment:
  Domain: dh.library.virginia.edu
  Private Key: ✅ Encrypted and stored
  AWS Secret:  ✅ Available
  CSR:         ✅ Ready for CA submission
  Certificate: ⏳ Pending CA signing
```

### **Validate Bootstrap**

```bash
# Validate both environments
./scripts/bootstrap-saml-certificates.sh validate

# Validate specific environment
./scripts/bootstrap-saml-certificates.sh validate staging
```

### **Monitor AWS Secrets**

```bash
cd terraform-infrastructure

# Check staging secret
./scripts/get-secret.ksh dh-drupal-staging-saml-passphrase

# Check production secret
./scripts/get-secret.ksh dh-drupal-production-saml-passphrase
```

## 🔐 Security Model

### **Multi-Layer Security**
1. **Private Keys**: Never stored unencrypted anywhere
2. **Encryption Passphrases**: Stored in AWS Secrets Manager
3. **Public Certificates**: Safe for git storage
4. **Environment Isolation**: Separate keys/secrets for staging and production

### **Access Control**
- **Terraform Infrastructure**: Restricted repository access
- **AWS Secrets Manager**: IAM-controlled access
- **Deployment Pipeline**: CodeBuild service role permissions

### **Rotation Process**
```bash
# When certificates need renewal:
# 1. Keys stay the same (no need to regenerate AWS secrets)
# 2. Generate new CSR using existing key
# 3. Submit to UVA CA
# 4. Replace certificate in git repository
```

## 🚨 Troubleshooting

### **Bootstrap Failures**

```bash
# Check prerequisites
./scripts/bootstrap-saml-certificates.sh
# Follow prerequisite checklist

# Verify AWS access
aws secretsmanager list-secrets

# Check terraform infrastructure
ls -la terraform-infrastructure/scripts/
```

### **Deployment Issues**

```bash
# Check secret availability
cd terraform-infrastructure
./scripts/get-secret.ksh dh-drupal-staging-saml-passphrase

# Verify encrypted key exists
ls -la dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem.cpt
```

### **Certificate Issues**

```bash
# Validate certificate and key match (after CA signing)
openssl x509 -noout -modulus -in saml-config/certificates/staging/saml-sp.crt | openssl md5
# Compare with decrypted key modulus
```

## 📞 Support Contacts

- **UVA Certificate Authority**: Contact for CSR submission and certificate signing
- **AWS Secrets Manager**: IT support for access issues
- **NetBadge Integration**: NetBadge administrator for SP metadata configuration
