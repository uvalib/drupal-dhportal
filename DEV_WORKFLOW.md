# Development Workflow for SAML Certificates

## 🔗 Complete SAML Testing Ecosystem (Recommended)

When working on SAML integration locally, the best approach is to set up a complete testing ecosystem with both Identity Provider (IDP) and Service Provider (SP) using coordinated certificates.

### Quick Start - Full Ecosystem

```bash
# Setup complete SAML ecosystem (IDP + SP with coordinated certificates)
# This automatically starts both DDEV containers if they're not running
./scripts/setup-dev-saml-ecosystem.sh ../drupal-netbadge

# ... do your development work with full SAML flow testing ...

# Clean up when done
./scripts/setup-dev-saml-ecosystem.sh cleanup
```

### What This Does

1. **🔍 Checks prerequisites** - Verifies both projects exist and tools are available
2. **🚀 Starts containers** - Automatically starts both DDEV containers if not running
3. **🏢 Generates IDP certificates** for drupal-netbadge (test NetBadge server)
4. **📋 Generates SP certificates** for drupal-dhportal 
5. **🔗 Cross-configures trust** - IDP trusts SP certificates, SP can trust IDP
6. **📝 Provides testing guide** with URLs and next steps
7. **🧹 Complete cleanup** removes all certificates from both projects

### Benefits

- ✅ **Automatic container startup** - No need to manually start DDEV containers
- ✅ **Complete SAML flow testing** with real redirects and assertions
- ✅ **Certificate trust validation** - test signature verification
- ✅ **Realistic development environment** - mirrors production SAML flow
- ✅ **Coordinated cleanup** - no orphaned certificates

## 📋 SP-Only Development (Alternative)

If you only need Service Provider certificates (e.g., testing against external IDP):

### Quick Start - SP Only

```bash
# Generate development certificates (30-day expiry)
./scripts/generate-saml-certificates.sh dev

# ... do your development work ...

# Clean up when done
./scripts/generate-saml-certificates.sh cleanup-dev
```

### What This Does

1. **Generates**: Self-signed certificates for local testing
2. **Places**: Certificates in `saml-config/dev/` (ignored by git)
3. **Expires**: Certificates automatically expire in 30 days
4. **Cleans**: Removes all development certificates and temp files

### Important Notes

- 🚮 **Disposable**: These certificates are temporary and local-only
- 🚫 **Never committed**: The `saml-config/dev/` directory is git-ignored
- 🔄 **Generate fresh**: Run the generation command whenever you need new certs
- 🧹 **Always cleanup**: Run cleanup when switching projects or when done

### SimpleSAMLphp Configuration

The development certificates will be automatically placed where SimpleSAMLphp expects them:

```
saml-config/dev/
├── saml-sp-dev.crt    # Public certificate
└── saml-sp-dev.key    # Private key
```

Your SimpleSAMLphp configuration should reference these files when in development mode.

### Security

- Development certificates include `localhost` and `127.0.0.1` as Subject Alternative Names
- Private keys are generated with proper permissions (`600`)
- All temporary files are cleaned up automatically
- No development certificates are ever committed to git

## 🏗️ Staging/Production

For staging and production, see `SAML_CERTIFICATE_LIFECYCLE.md` for the one-time certificate setup process using infrastructure keys.
