# SAML Certificate Strategy - Realistic Implementation Options

## 🎯 **The Challenge**

You're correct that terraform-based infrastructure scripts are **NOT available in local environments**. This means we need to choose a realistic approach for SAML certificate management.

## 🔧 **Three Realistic Options**

### **Option 1: Dedicated SAML Keys (RECOMMENDED)**

**Generate new private keys specifically for SAML certificates**

#### **Pros:**
- ✅ Clean separation between infrastructure and SAML keys
- ✅ Can generate locally with full security control
- ✅ Dedicated key lifecycle for SAML certificates
- ✅ No dependency on infrastructure key availability

#### **Process:**
```bash
# 1. Generate locally
./scripts/generate-saml-certificates.sh

# 2. Submit CSRs to UVA CA, get signed certificates

# 3. Encrypt private keys
ccrypt saml-config/temp/staging/saml-sp-staging.key
ccrypt saml-config/temp/production/saml-sp-production.key

# 4. Store encrypted keys in terraform-infrastructure repo:
# terraform-infrastructure/dh.library.virginia.edu/staging/keys/saml-sp-staging.pem.cpt
# terraform-infrastructure/dh.library.virginia.edu/production/keys/saml-sp-production.pem.cpt

# 5. Commit public certificates to git
git add saml-config/certificates/
git commit -m "Add SAML certificates"
```

#### **Deployment Integration:**
```yaml
# Add to deployspec.yml pre_build phase
- SAML_KEY_NAME=dh.library.virginia.edu/staging/keys/saml-sp-staging.pem  
- SAML_KEY=${CODEBUILD_SRC_DIR}/terraform-infrastructure/${SAML_KEY_NAME}
- ${CODEBUILD_SRC_DIR}/terraform-infrastructure/scripts/decrypt-key.ksh ${SAML_KEY}.cpt ${SAML_KEY_NAME}
```

---

### **Option 2: Reuse Infrastructure Keys (CURRENT IMPLEMENTATION)**

**Use existing SSH infrastructure keys for SAML certificates**

#### **Pros:**
- ✅ No new key management needed
- ✅ Leverages existing secure infrastructure
- ✅ Simpler deployment pipeline

#### **Cons:**
- ⚠️ Must generate certificates on staging/production servers
- ⚠️ Key coupling between infrastructure and SAML
- ⚠️ Cannot generate certificates locally

#### **Process:**
```bash
# 1. SSH to staging server
ssh staging-server
cd /path/to/drupal-dhportal

# 2. Generate using infrastructure keys
# (This would require modifying the script to use existing decrypted keys)

# 3. Submit CSRs, get certificates, commit to git
```

---

### **Option 3: Hybrid Approach**

**Generate locally but use infrastructure for production**

#### **For Development/Staging:**
- Generate locally with dedicated keys
- Use for development and staging testing

#### **For Production:**
- Generate on production server using infrastructure keys
- Use infrastructure keys only for production environment

---

## 🏆 **RECOMMENDATION: Option 1 (Dedicated SAML Keys)**

### **Why This Is Best:**

1. **Security Isolation**: SAML keys separate from infrastructure access
2. **Local Generation**: Full control over certificate generation process
3. **Operational Flexibility**: Can generate/renew certificates without server access
4. **NetBadge Integration**: Clean, dedicated certificates for IDP configuration

### **Implementation Steps:**

#### **1. Update deployspec.yml:**
```yaml
# Add SAML key decryption alongside existing infrastructure keys
- SAML_STAGING_KEY_NAME=dh.library.virginia.edu/staging/keys/saml-sp-staging.pem
- SAML_STAGING_KEY=${CODEBUILD_SRC_DIR}/terraform-infrastructure/${SAML_STAGING_KEY_NAME}
- ${CODEBUILD_SRC_DIR}/terraform-infrastructure/scripts/decrypt-key.ksh ${SAML_STAGING_KEY}.cpt ${SAML_STAGING_KEY_NAME}

- SAML_PRODUCTION_KEY_NAME=dh.library.virginia.edu/production/keys/saml-sp-production.pem  
- SAML_PRODUCTION_KEY=${CODEBUILD_SRC_DIR}/terraform-infrastructure/${SAML_PRODUCTION_KEY_NAME}
- ${CODEBUILD_SRC_DIR}/terraform-infrastructure/scripts/decrypt-key.ksh ${SAML_PRODUCTION_KEY}.cpt ${SAML_PRODUCTION_KEY_NAME}
```

#### **2. Generate certificates locally:**
```bash
./scripts/generate-saml-certificates.sh
# Submit CSRs to UVA CA
# Encrypt private keys with ccrypt
# Store encrypted keys in terraform repo
# Commit public certificates to git
```

#### **3. Enhanced script automatically detects:**
- Dedicated SAML keys (preferred)
- Infrastructure keys (fallback)
- Development self-signed (local)

## 🚀 **Next Steps**

1. **Choose your approach** (I recommend Option 1)
2. **Generate certificates** using chosen method
3. **Update deployment pipeline** if using dedicated keys
4. **Test certificate setup** in staging environment
5. **Send certificates to NetBadge admin** for IDP configuration

The dedicated SAML keys approach gives you the **best security, flexibility, and operational control** while maintaining compatibility with your existing infrastructure.
