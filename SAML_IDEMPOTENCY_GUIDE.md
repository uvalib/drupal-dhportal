# SAML Certificate Management - Idempotency and Safety Guide

## 🛡️ **Idempotent Operations Overview**

All SAML certificate management scripts are designed to be **fully idempotent** and safe to run multiple times without causing issues or overwriting critical infrastructure.

## 🔄 **Idempotency by Command**

### **1. `bootstrap-secrets` - AWS Secrets Management**

**What it does:** Creates AWS Secrets Manager secrets for SAML private key encryption passphrases.

**Idempotency behavior:**
- ✅ **Safe to run multiple times**
- ✅ **Will not overwrite existing secrets**
- ✅ **Validates existing secret accessibility**
- ✅ **Confirms secret format (32-character passphrase)**

**Example:**
```bash
# First run - creates new secret
./scripts/manage-saml-certificates-terraform.sh bootstrap-secrets staging
# → Creates: dh.library.virginia.edu/staging/keys/dh-drupal-staging-saml.pem

# Second run - detects existing secret
./scripts/manage-saml-certificates-terraform.sh bootstrap-secrets staging
# → Output: "IDEMPOTENCY: AWS secret bootstrap complete (using existing secret)"
```

### **2. `generate-keys` - SAML Certificate and Key Generation**

**What it does:** Generates SAML private keys, encrypts them, and creates self-signed certificates.

**Idempotency behavior:**
- ✅ **Safe to run multiple times**
- ✅ **Will not overwrite existing keys/certificates by default**
- ✅ **Validates existing assets (encrypted keys, certificates)**
- ✅ **Checks AWS secret accessibility before proceeding**
- ⚠️ **Requires `--force` flag to regenerate existing assets**

**Example:**
```bash
# First run - generates new assets
./scripts/manage-saml-certificates-terraform.sh generate-keys staging
# → Creates encrypted key and certificate

# Second run - detects existing assets
./scripts/manage-saml-certificates-terraform.sh generate-keys staging
# → Output: "IDEMPOTENCY: SAML key and certificate already exist for staging"

# Force regeneration (DESTRUCTIVE)
./scripts/manage-saml-certificates-terraform.sh generate-keys staging --force
# → Regenerates everything (requires NetBadge admin coordination)
```

### **3. `deploy` - Certificate Deployment**

**What it does:** Deploys SAML certificates to SimpleSAMLphp directories during application deployment.

**Idempotency behavior:**
- ✅ **Safe to run multiple times**
- ✅ **Validates existing deployments**
- ✅ **Checks certificate and key matching**
- ✅ **Only redeploys if validation fails**
- ✅ **Performs comprehensive pre-deployment validation**

**Example:**
```bash
# First run - deploys certificates
./scripts/manage-saml-certificates-terraform.sh deploy staging
# → Copies certificates to SimpleSAMLphp directory

# Second run - validates existing deployment
./scripts/manage-saml-certificates-terraform.sh deploy staging
# → Output: "SAML certificate deployment complete (idempotent)"
```

## 🔒 **Safety Features**

### **Comprehensive Validation**
- **AWS secret accessibility** - Verifies secrets exist and are readable
- **Encrypted key integrity** - Checks file size and format
- **Certificate validity** - Validates X.509 certificate structure
- **Key-certificate matching** - Ensures public keys match
- **File permissions** - Sets secure permissions on private keys

### **Partial State Detection**
The scripts detect and handle partial states gracefully:

```bash
# If only encrypted key exists (missing certificate)
./scripts/manage-saml-certificates-terraform.sh generate-keys staging
# → Output: "PARTIAL STATE DETECTED" with instructions

# If only certificate exists (missing encrypted key)
./scripts/manage-saml-certificates-terraform.sh generate-keys staging
# → Output: "PARTIAL STATE DETECTED" with instructions
```

### **Force Mode Protection**
- Regeneration requires explicit `--force` flag
- Clear warnings about NetBadge coordination requirements
- Destructive operations are never the default

## 🚨 **Important Safety Guidelines**

### **1. NetBadge Coordination Required**
⚠️ **CRITICAL:** Certificate regeneration invalidates existing NetBadge registrations.

**Before using `--force`:**
1. Coordinate with NetBadge administrator
2. Plan for SP metadata update
3. Expect temporary authentication downtime
4. Have rollback plan ready

### **2. Production Environment Protection**
- Always test changes in staging first
- Use `info` command to verify current state
- Review certificate expiration dates regularly
- Monitor AWS secret accessibility

### **3. Terraform Infrastructure Dependencies**
- Ensure terraform-infrastructure repository is available
- Verify encryption/decryption scripts are accessible
- Confirm AWS credentials have proper permissions
- Test secret retrieval before key operations

## 🧪 **Testing Idempotency**

### **Staging Validation Script**
```bash
# Comprehensive staging environment test
./scripts/test-staging-saml-validation.sh

# Includes idempotency tests:
# - bootstrap-secrets multiple runs
# - generate-keys multiple runs  
# - deploy multiple runs
```

### **Manual Verification**
```bash
# Check current state
./scripts/manage-saml-certificates-terraform.sh info staging

# Test bootstrap idempotency
./scripts/manage-saml-certificates-terraform.sh bootstrap-secrets staging
./scripts/manage-saml-certificates-terraform.sh bootstrap-secrets staging  # Should be idempotent

# Test generate-keys idempotency  
./scripts/manage-saml-certificates-terraform.sh generate-keys staging
./scripts/manage-saml-certificates-terraform.sh generate-keys staging  # Should be idempotent

# Test deploy idempotency
./scripts/manage-saml-certificates-terraform.sh deploy staging
./scripts/manage-saml-certificates-terraform.sh deploy staging  # Should be idempotent
```

## 📋 **Idempotency Checklist**

Before production deployment, verify:

- [ ] Bootstrap secrets is idempotent ✅
- [ ] Generate keys is idempotent ✅  
- [ ] Deploy is idempotent ✅
- [ ] Force mode requires explicit flag ✅
- [ ] Partial state detection works ✅
- [ ] Certificate validation passes ✅
- [ ] Key-certificate matching verified ✅
- [ ] AWS secret accessibility confirmed ✅
- [ ] File permissions are secure ✅
- [ ] All test scripts pass ✅

## 🎯 **Best Practices**

1. **Always use staging first** - Test all operations in staging before production
2. **Run tests regularly** - Use automated test scripts to verify idempotency
3. **Monitor expiration** - Set calendar reminders for certificate renewal
4. **Document changes** - Keep records of when certificates are regenerated
5. **Coordinate renewals** - Work with NetBadge admin for smooth transitions

## 🔄 **Typical Workflow (Idempotent)**

```bash
# Setup (safe to run multiple times)
./scripts/manage-saml-certificates-terraform.sh bootstrap-secrets staging
./scripts/manage-saml-certificates-terraform.sh generate-keys staging

# Deployment (safe to run multiple times)  
./scripts/manage-saml-certificates-terraform.sh deploy staging

# Validation (always safe)
./scripts/manage-saml-certificates-terraform.sh info staging
./scripts/test-staging-saml-validation.sh

# Production (only after staging validation)
./scripts/manage-saml-certificates-terraform.sh bootstrap-secrets production
./scripts/manage-saml-certificates-terraform.sh generate-keys production  
# → Register new certificate with NetBadge admin
./scripts/manage-saml-certificates-terraform.sh deploy production
```

This idempotent design ensures that SAML certificate management is safe, predictable, and suitable for automation in CI/CD pipelines.
