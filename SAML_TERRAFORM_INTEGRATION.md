# SAML Certificate Management with Terraform Infrastructure

This document outlines how to manage SAML certificates using your existing terraform infrastructure encryption/decryption system.

## 🏗️ Architecture Overview

Your existing infrastructure already handles encrypted private keys securely:

```
terraform-infrastructure/
├── scripts/
│   ├── crypt-key.ksh           # Encrypts private keys
│   └── decrypt-key.ksh         # Decrypts keys during deployment
└── dh.library.virginia.edu/
    ├── staging/keys/
    │   ├── dh-drupal-staging.pem.cpt      # SSH key (existing)
    │   └── dh-drupal-staging-saml.pem.cpt # SAML key (new)
    └── production/keys/
        ├── dh-drupal-production.pem.cpt      # SSH key (existing)
        └── dh-drupal-production-saml.pem.cpt # SAML key (new)
```

**Key Benefits:**
- ✅ Reuses your existing secure key management infrastructure
- ✅ Private keys never stored unencrypted in any git repository
- ✅ Public certificates safely stored in application git repository
- ✅ Environment-specific key/certificate pairs
- ✅ Integrates seamlessly with existing deployment pipeline

## 🔧 Setup Process

### 1. Generate SAML Private Keys for Each Environment

```bash
# Generate staging SAML private key and CSR
./scripts/manage-saml-certificates-terraform.sh generate-keys staging dh-staging.library.virginia.edu

# Generate production SAML private key and CSR
./scripts/manage-saml-certificates-terraform.sh generate-keys production dh.library.virginia.edu
```

**This will:**
- Generate a new RSA private key
- Create a Certificate Signing Request (CSR)
- Encrypt the private key using `terraform-infrastructure/scripts/crypt-key.ksh`
- Store encrypted key in terraform repository path
- Save CSR in `saml-config/csr/` for CA submission

### 2. Store Encrypted Keys in Terraform Repository

```bash
# In your terraform-infrastructure repository
git add dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem.cpt
git add dh.library.virginia.edu/production/keys/dh-drupal-production-saml.pem.cpt
git commit -m "Add encrypted SAML private keys for staging and production"
```

### 3. Submit CSRs to UVA Certificate Authority

Submit the generated CSR files to UVA CA:
- `saml-config/csr/staging-saml-sp.csr`
- `saml-config/csr/production-saml-sp.csr`

### 4. Store Signed Certificates in Application Repository

Once you receive the signed certificates from UVA CA:

```bash
# Store staging certificate
cp staging-signed-cert.crt saml-config/certificates/staging/saml-sp.crt

# Store production certificate  
cp production-signed-cert.crt saml-config/certificates/production/saml-sp.crt

# Commit to application repository (safe - public certificates only)
git add saml-config/certificates/
git commit -m "Add signed SAML certificates from UVA CA"
```

## 🚀 Deployment Integration

The deployment pipeline (`pipeline/deployspec.yml`) now automatically:

### Pre-Build Phase:
1. **Decrypts SSH private key** (existing functionality)
2. **Decrypts SAML private key** (new functionality)
   ```yaml
   # Environment-specific SAML key decryption
   - SAML_PRIVATE_KEY=${CODEBUILD_SRC_DIR}/terraform-infrastructure/${SAML_KEY_NAME}
   - ${CODEBUILD_SRC_DIR}/terraform-infrastructure/scripts/decrypt-key.ksh ${SAML_PRIVATE_KEY}.cpt
   ```

### Build Phase:
3. **Deploys SAML certificates** if available
   ```bash
   ./scripts/manage-saml-certificates-terraform.sh deploy $DEPLOYMENT_ENVIRONMENT
   ```

### Result:
- Decrypted private key + stored public certificate = Ready for SAML authentication
- Keys are automatically placed in `simplesamlphp/cert/` directory
- Proper file permissions set (600 for keys, 644 for certificates)

## 📋 Management Commands

### View Certificate Information
```bash
# Show all environments
./scripts/manage-saml-certificates-terraform.sh info

# Show specific environment
./scripts/manage-saml-certificates-terraform.sh info staging
```

### Deploy Certificates (Manual)
```bash
# Deploy staging certificates (during staging deployment)
TERRAFORM_REPO_PATH=/path/to/terraform-infrastructure \
./scripts/manage-saml-certificates-terraform.sh deploy staging

# Deploy production certificates (during production deployment)
TERRAFORM_REPO_PATH=/path/to/terraform-infrastructure \
./scripts/manage-saml-certificates-terraform.sh deploy production
```

### Encrypt Existing Keys
If you already have SAML private keys that need to be encrypted:

```bash
# Encrypt existing staging key
./scripts/manage-saml-certificates-terraform.sh encrypt-existing staging /path/to/existing-staging.key

# Encrypt existing production key
./scripts/manage-saml-certificates-terraform.sh encrypt-existing production /path/to/existing-production.key
```

## 🔄 Certificate Renewal Process

When certificates need renewal (typically annually):

### 1. Generate New CSR (Reusing Existing Private Key)
```bash
# The encrypted private key stays the same, just generate new CSR
./scripts/manage-saml-certificates-terraform.sh generate-keys staging
# Choose to reuse existing key when prompted
```

### 2. Submit New CSR to UVA CA
Submit the new CSR for the same private key.

### 3. Update Certificate in Git
Replace the old certificate with the new signed certificate:
```bash
cp new-staging-cert.crt saml-config/certificates/staging/saml-sp.crt
git commit -m "Renew staging SAML certificate"
```

### 4. Deploy Updated Certificate
Next deployment will automatically use the new certificate with the existing private key.

## 🔒 Security Model

### Private Keys (Never in Git)
- **Location:** `terraform-infrastructure` repository (encrypted)
- **Encryption:** Using existing `crypt-key.ksh` script
- **Decryption:** During deployment only using `decrypt-key.ksh`
- **Access:** Same security model as SSH keys

### Public Certificates (Safe in Git)
- **Location:** `drupal-dhportal` repository (unencrypted)
- **Purpose:** Public certificates are safe to store openly
- **Environment:** Separate certificates for staging/production
- **Renewal:** Updated in place when renewed

### Development Environment
- **Approach:** Self-signed certificates generated locally
- **Storage:** `saml-config/dev/` (excluded from git)
- **Regeneration:** Automatic on each setup

## 🚨 Security Considerations

### ✅ Secure Practices
- Private keys encrypted with same method as infrastructure keys
- Environment-specific key/certificate pairs
- Automatic cleanup of decrypted keys after deployment
- Public certificates safely version-controlled
- Development certificates excluded from production systems

### ⚠️ Important Notes
- Never commit unencrypted private keys to any repository
- Always verify certificate/key pairs match before deployment
- Monitor certificate expiration dates for timely renewal
- Keep terraform infrastructure repository access restricted

## 🔍 Troubleshooting

### Certificate/Key Mismatch
```bash
# Validate certificate and key match
openssl x509 -noout -modulus -in certificate.crt | openssl md5
openssl rsa -noout -modulus -in private.key | openssl md5
# These should produce identical output
```

### Missing Encrypted Key
```bash
# Check if encrypted key exists in terraform repo
ls -la terraform-infrastructure/dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem.cpt
```

### Deployment Issues
```bash
# Check deployment logs for SAML key availability
grep "SAML_KEY_AVAILABLE" deployment-logs.txt

# Manual certificate deployment for testing
TERRAFORM_REPO_PATH=/path/to/terraform-infrastructure \
./scripts/manage-saml-certificates-terraform.sh deploy staging
```

## 📞 Support

For issues with:
- **Certificate Authority:** Contact UVA CA administrator
- **NetBadge Integration:** Contact NetBadge administrator  
- **Encryption/Decryption:** Reference existing terraform infrastructure documentation
- **SAML Configuration:** Use `web/saml-debug.php` diagnostic tool
