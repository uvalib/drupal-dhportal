# SAML Certificate Management - Coordinated Development Strategy

## 🔐 Certificate Lifecycle Overview

### **Development vs Production Strategy:**

#### **🏠 Development**: Disposable, coordinated IDP+SP testing
#### **🏗️ Staging/Production**: Static, CA-signed certificates

## 🔗 **Complete Development Ecosystem (Recommended)**

### **Coordinated IDP + SP Setup:**

### **One-Time Setup Process:**

1. **Generate static certificates** for each environment
2. **Send public certificates to NetBadge admin** for IDP configuration
3. **Store certificates in git repository** for consistent deployment
4. **Use same certificates** for all future deployments

### **Why Static Certificates:**

- **IDP Integration**: NetBadge admin configures their IDP with your public certificate
- **Trust Relationship**: Changing certificates breaks the SAML trust relationship
- **Deployment Consistency**: Same certificate across all deployments ensures reliability
- **Operational Simplicity**: No certificate rotation during normal deployments

## 🏗️ **Updated Implementation Strategy**

### **Development Environment (Local/DDEV) - Coordinated Ecosystem:**

#### **🔗 Complete SAML Testing Setup (IDP + SP):**

```bash
# RECOMMENDED: Setup complete SAML ecosystem with test IDP
# This coordinates certificates between drupal-dhportal (SP) and drupal-netbadge (test IDP)

# From drupal-dhportal project root:
./scripts/setup-dev-saml-ecosystem.sh ../drupal-netbadge

# This creates:
# 1. 🏢 IDP certificates for drupal-netbadge (test Identity Provider)
# 2. 📋 SP certificates for drupal-dhportal (Service Provider) 
# 3. 🔗 Cross-configures trust relationships
# 4. 📝 Provides complete testing instructions
```

#### **📋 SP-Only Development (Alternative):**

```bash
# ALTERNATIVE: Generate only SP certificates for external IDP testing
# Use this if you're testing against UVA NetBadge or another external IDP

./scripts/generate-saml-certificates.sh dev

# This creates:
# - Temporary SP private key (local only)
# - Self-signed SP certificate (local only)
# - Stores in saml-config/dev/ directory

# When done developing, clean up all local certificates
./scripts/generate-saml-certificates.sh cleanup-dev
```

**Development Key Points:**
- 🚮 **Disposable**: Generated fresh for each development session
- 🏠 **Local only**: Never committed to git or shared
- 🔄 **Self-signed**: No CA involvement needed
- 🧹 **Cleanup**: Removed when done developing
- 🔗 **Coordinated**: IDP and SP certificates work together seamlessly

### **Staging/Production (One-Time Setup):**

```bash
# APPROACH: Generate certificates on staging/production using existing infrastructure keys
# This is simpler and reuses the security infrastructure you already have

# STEP 1: Generate certificates on staging server
ssh staging-server
cd /path/to/drupal-dhportal
./scripts/generate-saml-certificates.sh staging

# STEP 2: Generate certificates on production server
ssh production-server
cd /path/to/drupal-dhportal
./scripts/generate-saml-certificates.sh production

# This creates CSRs using the existing infrastructure private keys
# Submit CSRs to UVA Certificate Authority
# (CSRs are in saml-config/temp/staging/ and saml-config/temp/production/)

# STEP 3: Receive signed certificates from CA

# STEP 4: Store signed certificates permanently in git
cp signed-staging-cert.crt saml-config/certificates/staging/saml-sp.crt
cp signed-production-cert.crt saml-config/certificates/production/saml-sp.crt

# STEP 5: Clean up temporary files (CSRs, etc.)
./scripts/generate-saml-certificates.sh cleanup

# STEP 6: Commit certificates to git repository
git add saml-config/certificates/
git commit -m "Add SAML certificates for staging and production"
git push

# STEP 7: Send certificate data to NetBadge admin for IDP configuration
```

### **Deployment Process (Every Deploy):**

```bash
# Certificate setup uses existing stored certificates
# No generation, just pairing with infrastructure private key
./scripts/manage-saml-certificates-enhanced.sh staging  # or production
```

### **Certificate Renewal (Annually/Before Expiration):**

```bash
# Generate new CSR using existing private key
# Get new certificate from CA
# Update certificate in git repository
# Notify NetBadge admin of certificate change
# Coordinate IDP reconfiguration
```

## 📁 **Git Repository Structure (Final):**

```
saml-config/
├── certificates/
│   ├── staging/
│   │   └── saml-sp.crt              # Static staging certificate (in git)
│   └── production/
│       └── saml-sp.crt              # Static production certificate (in git)
└── README.md                        # Documentation
```

## 🚫 **What NOT to Store in Git:**

- Private keys (always encrypted in terraform-infrastructure)
- CSR files (temporary, generated as needed)
- Self-signed certificates (development only)
- Certificate temporary files

## ✅ **What IS Safe in Git:**

- ✅ **Public certificates** (staging and production)
- ✅ **Certificate chains** (if needed)
- ✅ **Configuration documentation**
- ✅ **Certificate metadata** (expiration dates, etc.)

## 🔄 **NetBadge Admin Integration:**

### **Initial Setup:**
1. Send staging certificate to NetBadge admin for test IDP setup
2. Send production certificate to NetBadge admin for production IDP setup
3. NetBadge admin configures IDP trust relationship

### **Certificate Renewal:**
1. Generate new certificate using same private key
2. Notify NetBadge admin of upcoming certificate change
3. Coordinate IDP reconfiguration timing
4. Update certificate in git repository
5. Deploy updated certificate

## 🛡️ **Security Benefits:**

- **Static trust relationship** with NetBadge IDP
- **No certificate surprises** during deployments
- **Predictable SAML authentication** behavior
- **Clear certificate lifecycle** management
