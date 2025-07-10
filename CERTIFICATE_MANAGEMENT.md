# SAML Certificate Management Strategy

This document outlines how SAML certificates are managed across different deployment environments for the drupal-dhportal project.

## 🏗️ Certificate Requirements

SAML requires X.509 certificates for:
1. **Signing SAML assertions** - Ensures integrity and authenticity
2. **SSL/TLS encryption** - Secures SAML communications
3. **Metadata validation** - Validates IdP and SP metadata

## 🌍 Environment-Specific Certificate Strategies

### 1. DDEV Development Environment (`/var/www/html`)

**Strategy**: Self-signed certificates for local development

**Certificate Locations**:
```
/var/www/html/simplesamlphp/cert/
├── server.crt     # Self-signed certificate
├── server.key     # Private key
└── server.pem     # Combined cert+key for some SAML libraries
```

**Generation Method**:
- Generated automatically by `setup-saml-integration-container.sh`
- Uses `manage-saml-certificates.sh` script with `-e dev` flag
- Domain: `localhost` or `drupal-dhportal.ddev.site`
- Validity: 365 days

**Characteristics**:
- ✅ Quick setup for development
- ✅ No external dependencies
- ⚠️ Browser warnings (expected for self-signed)
- ❌ Not suitable for production

### 2. Container Environment (`/var/www/html`)

**Strategy**: Self-signed certificates (same as DDEV)

**Use Case**: Testing container builds locally or in CI/CD

**Certificate Management**:
- Same as DDEV environment
- Can be overridden with mounted certificates via Docker volumes
- Environment variables: `SAML_CERT_PATH`, `SAML_KEY_PATH`

### 3. Server Production Environment (`/opt/drupal`)

**Strategy**: Production-grade certificates from trusted CA

**Certificate Sources** (in order of preference):
1. **AWS Certificate Manager** - For ECS/ELB termination
2. **Let's Encrypt** - Free automated certificates
3. **UVA IT certificates** - Institution-provided certificates
4. **Self-signed fallback** - Emergency fallback only

**Certificate Locations**:
```
/opt/drupal/simplesamlphp/cert/
├── server.crt     # Production certificate
├── server.key     # Private key (secure permissions)
└── server.pem     # Combined format if needed
```

**Environment Variables**:
```bash
SAML_CERT_PATH=/path/to/production.crt
SAML_KEY_PATH=/path/to/production.key
SAML_DOMAIN=dhportal.library.virginia.edu
SSL_CERT_PATH=/etc/ssl/certs/dhportal.crt
SSL_KEY_PATH=/etc/ssl/private/dhportal.key
```

## 🔧 Certificate Management Script

The `scripts/manage-saml-certificates.sh` script provides unified certificate management:

### Usage Examples

```bash
# Generate development certificates
./scripts/manage-saml-certificates.sh setup -e dev -d localhost

# Setup production certificates
./scripts/manage-saml-certificates.sh setup -e prod -d dhportal.library.virginia.edu

# Validate existing certificates
./scripts/manage-saml-certificates.sh validate

# Display certificate information
./scripts/manage-saml-certificates.sh info
```

### Script Capabilities

1. **Environment Detection**: Automatically detects `/opt/drupal` vs `/var/www/html`
2. **Certificate Generation**: Creates self-signed certificates with proper SANs
3. **Production Integration**: Copies certificates from standard locations
4. **Validation**: Checks certificate validity and key matching
5. **Information Display**: Shows certificate details and expiration

## 🔄 Certificate Lifecycle

### Development Workflow

1. **Initial Setup**: `setup-saml-integration-container.sh` calls certificate management
2. **Local Testing**: Self-signed certificates work for SAML testing
3. **Container Builds**: Certificates regenerated in each container build
4. **DDEV Refresh**: Certificates persist across DDEV restarts

### Production Workflow

1. **Infrastructure Setup**: Certificates provisioned via Terraform/CloudFormation
2. **Container Deployment**: Certificates mounted as volumes or copied during build
3. **Certificate Renewal**: Automated via Let's Encrypt or manual via UVA IT
4. **Health Monitoring**: Automated checks for certificate expiration

## 🛡️ Security Considerations

### Development Security
- Self-signed certificates are acceptable for development
- Private keys have restricted permissions (600)
- Certificates not committed to version control

### Production Security
- **Never commit production private keys to git**
- Use AWS Secrets Manager or similar for key storage
- Implement certificate rotation procedures
- Monitor certificate expiration dates

### File Permissions
```bash
# Certificate files (public)
chmod 644 *.crt *.pem

# Private key files (restricted)
chmod 600 *.key

# Certificate directory
chmod 755 /path/to/cert/directory
```

## 🔗 Integration Points

### SimpleSAMLphp Configuration

Certificates are referenced in SimpleSAMLphp configuration:

```php
// simplesamlphp/config/config.php
'certdir' => '/opt/drupal/simplesamlphp/cert/',

// simplesamlphp/config/authsources.php
'default-sp' => [
    'saml:SP',
    'privatekey' => 'server.key',
    'certificate' => 'server.crt',
    // ...
],
```

### SAML Metadata

Certificates are embedded in SAML metadata for trust verification:

```xml
<KeyDescriptor use="signing">
    <ds:KeyInfo>
        <ds:X509Data>
            <ds:X509Certificate>MIIDXTCCAkWgAwIBAgIJAL...</ds:X509Certificate>
        </ds:X509Data>
    </ds:KeyInfo>
</KeyDescriptor>
```

## 🚀 Deployment Integration

### Docker Builds

```dockerfile
# Production Dockerfile can copy certificates
COPY cert/production.crt /opt/drupal/simplesamlphp/cert/server.crt
COPY cert/production.key /opt/drupal/simplesamlphp/cert/server.key
RUN chmod 600 /opt/drupal/simplesamlphp/cert/server.key
```

### AWS ECS Task Definition

```json
{
  "volumes": [
    {
      "name": "saml-certs",
      "host": {
        "sourcePath": "/opt/ssl/saml"
      }
    }
  ],
  "mountPoints": [
    {
      "sourceVolume": "saml-certs",
      "containerPath": "/opt/drupal/simplesamlphp/cert",
      "readOnly": true
    }
  ]
}
```

### AWS Secrets Manager Integration

```bash
# Retrieve certificates from AWS Secrets Manager
aws secretsmanager get-secret-value \
    --secret-id "dhportal/saml/certificate" \
    --query 'SecretString' --output text > /opt/drupal/simplesamlphp/cert/server.crt

aws secretsmanager get-secret-value \
    --secret-id "dhportal/saml/private-key" \
    --query 'SecretString' --output text > /opt/drupal/simplesamlphp/cert/server.key
```

## 🧪 Testing Certificate Setup

### Development Testing
```bash
# Test certificate generation
./scripts/manage-saml-certificates.sh setup -e dev -d localhost

# Validate generated certificates
./scripts/manage-saml-certificates.sh validate

# Check SAML metadata includes certificate
curl -k https://localhost/simplesaml/module.php/saml/sp/metadata.php/default-sp
```

### Production Testing
```bash
# Validate production certificates
openssl x509 -in /opt/drupal/simplesamlphp/cert/server.crt -text -noout

# Check certificate chain
openssl verify -CApath /etc/ssl/certs /opt/drupal/simplesamlphp/cert/server.crt

# Test SAML metadata accessibility
curl https://dhportal.library.virginia.edu/simplesaml/module.php/saml/sp/metadata.php/default-sp
```

## 📋 Troubleshooting

### Common Issues

1. **Certificate/Key Mismatch**
   ```bash
   # Compare modulus to verify they match
   openssl x509 -noout -modulus -in server.crt | openssl md5
   openssl rsa -noout -modulus -in server.key | openssl md5
   ```

2. **Permission Errors**
   ```bash
   # Fix certificate permissions
   chmod 644 /opt/drupal/simplesamlphp/cert/server.crt
   chmod 600 /opt/drupal/simplesamlphp/cert/server.key
   ```

3. **Expired Certificates**
   ```bash
   # Check expiration
   openssl x509 -in server.crt -noout -dates
   
   # Regenerate if expired
   ./scripts/manage-saml-certificates.sh setup -e dev -d localhost
   ```

4. **SAML Signature Verification Failures**
   - Ensure certificate in metadata matches actual signing certificate
   - Verify certificate is properly formatted (no extra whitespace)
   - Check that private key corresponds to public certificate

This certificate management strategy ensures secure, maintainable SAML authentication across all deployment environments while providing appropriate security levels for each use case.
