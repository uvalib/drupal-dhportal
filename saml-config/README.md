# SAML Certificate Management Strategy

This directory contains the SAML certificates and encrypted private keys for environment-specific deployments.

## 🏗️ Architecture

We leverage the existing encrypted private key infrastructure from the Terraform deployment pipeline and pair it with environment-specific certificates stored in the git repository.

### **Directory Structure:**
```
saml-config/
├── certificates/           # Public certificates (safe to store in git)
│   ├── staging/
│   │   ├── saml-sp.crt         # Staging environment certificate
│   │   └── saml-sp-chain.crt   # CA chain certificate (if needed)
│   └── production/
│       ├── saml-sp.crt         # Production environment certificate  
│       └── saml-sp-chain.crt   # CA chain certificate (if needed)
└── keys/                   # Encrypted private keys (safe to store in git)
    ├── staging/
    │   └── saml-sp-staging.pem.cpt    # Encrypted staging private key
    └── production/
        └── saml-sp-production.pem.cpt # Encrypted production private key
```

## 🔐 Security Model

### **Private Keys:**
- **Development**: Generated locally, self-signed
- **Staging/Production**: Use existing encrypted infrastructure keys
- **Storage**: Encrypted with `ccrypt` (same as existing deployment keys)
- **Decryption**: During deployment pipeline using existing decrypt scripts

### **Certificates:**
- **Public certificates**: Safe to store in git repository
- **Environment-specific**: Each environment has its own signed certificate
- **CA-signed**: Proper certificates signed by University of Virginia CA
- **Chain support**: Full certificate chain if intermediate CAs are used

## 🚀 Deployment Integration

### **Current Pipeline Integration:**

The `deployspec.yml` already decrypts private keys:
```yaml
# decrypt the instance private key
- PRIVATE_KEY_NAME=dh.library.virginia.edu/staging/keys/dh-drupal-staging.pem
- PRIVATE_KEY=${CODEBUILD_SRC_DIR}/terraform-infrastructure/${PRIVATE_KEY_NAME}
- ${CODEBUILD_SRC_DIR}/terraform-infrastructure/scripts/decrypt-key.ksh ${PRIVATE_KEY}.cpt ${PRIVATE_KEY_NAME}
```

### **Enhanced Certificate Setup:**

The enhanced script will:
1. Use the already-decrypted private key from deployment
2. Pair it with the environment-specific certificate from git repo
3. Create the proper SAML certificate files for SimpleSAMLphp

## 📋 Setup Process

### **For Staging Environment:**

1. **Get the staging private key** (from existing infrastructure):
   ```bash
   # This key already exists in terraform-infrastructure repo
   dh.library.virginia.edu/staging/keys/dh-drupal-staging.pem.cpt
   ```

2. **Generate CSR** using enhanced script:
   ```bash
   ./scripts/manage-saml-certificates-enhanced.sh staging dh-staging.library.virginia.edu
   ```

3. **Get certificate signed** by UVA Certificate Authority

4. **Store certificate** in git repo:
   ```bash
   # Store the signed certificate
   cp signed-certificate.crt saml-config/certificates/staging/saml-sp.crt
   
   # Store CA chain if provided
   cp ca-chain.crt saml-config/certificates/staging/saml-sp-chain.crt
   ```

### **For Production Environment:**

Same process but using production paths:
- Key: `dh.library.virginia.edu/production/keys/dh-drupal-production.pem.cpt`
- Certificate: `saml-config/certificates/production/saml-sp.crt`
- Domain: `dh.library.virginia.edu`

## 🔧 Usage

### **During Deployment:**
```bash
# In container during deployment
/opt/drupal/scripts/manage-saml-certificates-enhanced.sh staging
# or
/opt/drupal/scripts/manage-saml-certificates-enhanced.sh production
```

### **Local Development:**
```bash
# Generate self-signed certificate for development
./scripts/manage-saml-certificates-enhanced.sh dev
```

### **Certificate Information:**
```bash
# View certificate details
./scripts/manage-saml-certificates-enhanced.sh info
```

## ✅ Benefits

1. **Reuses existing infrastructure**: Leverages current encrypted key management
2. **Environment isolation**: Each environment has its own certificate  
3. **Proper CA signing**: Uses legitimate certificates from UVA CA
4. **Git-friendly**: Public certificates safe to store in repository
5. **Deployment integration**: Works with existing pipeline automation
6. **Security**: Private keys remain encrypted and are never stored in git

## 🔄 Certificate Renewal Process

1. **Generate new CSR** using the same private key
2. **Get new certificate** signed by CA
3. **Update certificate** in git repository
4. **Deploy** - next deployment will use new certificate automatically

The private keys can remain the same, only certificates need renewal.
