# DDEV & AWS Deployment Architecture

This document explains the development and deployment architecture for the two interconnected Drupal projects: `drupal-dhportal` (Service Provider) and `drupal-netbadge` (Identity Provider).

## 🏗️ Overall Architecture

```
┌─────────────────────┐    SAML Auth    ┌─────────────────────┐
│  drupal-dhportal    │ ───────────────▶│  drupal-netbadge    │
│  (Service Provider) │                 │  (Identity Provider)│
│  - Drupal 10        │                 │  - SimpleSAMLphp    │
│  - Dual Login       │                 │  - NetBadge IdP     │
│  - SAML + Local     │                 │  - PHP 8.2          │
└─────────────────────┘                 └─────────────────────┘
```

## 🔧 DDEV Development Configuration

### drupal-dhportal (Service Provider)
```yaml
# .ddev/config.yaml
name: drupal-dhportal
type: drupal10
docroot: web
php_version: "8.3"
webserver_type: apache-fpm
database:
  type: mariadb
  version: "10.11"
web_environment:
  - SIMPLESAMLPHP_CONFIG_DIR=/var/www/html/simplesamlphp/config
```

**Key Features:**
- **Dual Authentication**: SAML (NetBadge) + Local Drupal accounts
- **Custom Account Menu**: Prevents conflicts between auth systems
- **SimpleSAMLphp Integration**: Service Provider configuration
- **Apache Configuration**: Custom `.ddev/apache/simplesamlphp.conf` for alias setup

### drupal-netbadge (Identity Provider - TEST ONLY)
```yaml
# .ddev/config.yaml
name: drupal-netbadge
type: php
docroot: web
php_version: "8.2"
webserver_type: apache-fpm
database:
  type: mariadb
  version: "10.11"
web_environment:
  - SIMPLESAMLPHP_CONFIG_DIR=/var/simplesamlphp/config
```

**⚠️ TESTING ONLY - NOT FOR PRODUCTION**
- **SimpleSAMLphp IdP**: Test SAML 2.0 Identity Provider for development
- **Local NetBadge Simulation**: Simulates university authentication for testing
- **Volume Mounts**: Config, metadata, certs, logs, and temp directories
- **Environment Variables**: For container deployment flexibility
- **Production Note**: In production, drupal-dhportal connects to real NetBadge IdP

## 🐳 Container Strategy

### Unified Development/Production Containers

Both projects use a **container-first approach** where DDEV and AWS use the same base containers:

#### drupal-dhportal Container

```dockerfile
FROM public.ecr.aws/docker/library/drupal:10.4.4
# Features:
# - Drupal 10.4.4 base
# - Git clone from GitHub repo
# - Composer dependencies
# - Symlinked custom modules/themes
# - APCu extension for performance
# - Production PHP configuration
```

#### drupal-netbadge Container (TEST ONLY)

```dockerfile
FROM cirrusid/simplesamlphp:latest
# Features:
# - SimpleSAMLphp pre-configured
# - PHP extensions (gd, zip, mysqli, etc.)
# - Composer installed
# - Environment-driven configuration
# - Production-ready security settings
# ⚠️ FOR TESTING ONLY - NOT DEPLOYED TO PRODUCTION
```

## 🚀 AWS CodePipeline Deployment

### drupal-dhportal Pipeline (`pipeline/buildspec.yml`)

```yaml
phases:
  pre_build:
    - AWS ECR login
    - SSH key decryption (ccrypt)
    - Infrastructure repo cloning
  
  build:
    - Quick theme update via SSH
    - Docker build with timestamp tag
    - Multi-tag strategy (latest, build-VERSION, git-COMMIT)
    - ECR push
    - SSM parameter update
```

**Deployment Strategy:**
- **Remote Theme Updates**: SSH into existing containers for quick changes
- **Full Container Rebuilds**: For structural changes
- **Multi-Environment**: Dev, staging, production via different hosts
- **Encrypted Keys**: ccrypt-encrypted SSH keys from GitLab
- **Build Versioning**: Timestamp-based build tags

### drupal-netbadge Pipeline (`pipeline/buildspec.yml`)

```yaml
phases:
  pre_build:
    - AWS ECR login
    - Build versioning
  
  build:
    - Container build with build tags
    - Multi-tag strategy (latest, build-VERSION, git-COMMIT)
    - ECR push
    - SSM parameter update for deployment tracking
```

**Deployment Strategy:**
- **Simpler Pipeline**: Focus on container builds
- **Version Tracking**: SSM parameters for deployment coordination
- **Tag Strategy**: Latest, timestamped builds, and git commits

## 📦 Package Configurations

### drupal-dhportal Package Structure
```
package/
├── Dockerfile                     # Production container definition
└── data/
    ├── container_bash_profile     # Container shell configuration
    └── files/
        ├── opt/drupal/web/sites/default/settings.php
        ├── opt/drupal/web/drush/drush.yml
        └── usr/local/etc/php/php.ini-production
```

### drupal-netbadge Package Structure
```
package/
├── Dockerfile                     # Production container definition
├── config/
│   ├── .env.production.example    # Environment variables template
│   ├── .env.development.example   # Development environment template
│   ├── authsources.production.php # SAML auth sources
│   └── config.production.php      # SimpleSAMLphp config
└── deployment/
    ├── docker-compose.production.yml  # Docker Compose example
    ├── ecs-task-definition.json       # AWS ECS deployment
    └── kubernetes.yml                 # Kubernetes deployment
```

## 🔄 Development Workflow

### NPM Scripts Integration

Both projects use **npm scripts** for cross-platform development:

#### drupal-dhportal
```json
{
  "setup": "Setup SAML + menu integration",
  "test:menu": "Validate custom account menu",
  "config:export/import": "Drupal configuration management",
  "module:enable/disable": "Module management utilities"
}
```

#### drupal-netbadge  
```json
{
  "sync": "Sync DDEV with production container",
  "deploy:check": "Validate deployment readiness",
  "aws:login/push": "AWS ECR operations",
  "saml:test/admin": "SAML testing utilities"
}
```

### Container Synchronization

**drupal-netbadge** has advanced container sync capabilities:

```bash
npm run sync    # Build production container and test locally
npm run build   # Build using production Dockerfile
npm run test    # Validate container functionality
```

This ensures **development-production parity** by using the same container in both environments.

### SAML Integration Scripts

**drupal-dhportal** provides two SAML setup scripts for different environments:

#### DDEV Environment
```bash
./scripts/setup-saml-integration.sh
```

#### Container Environment (Production/AWS)
```bash
./scripts/setup-saml-integration-container.sh
```

**Key Differences:**
- **DDEV script**: Uses `ddev drush` and `ddev exec` commands
- **Container script**: Uses direct `drush` commands and filesystem access
- **Environment detection**: Container script checks for Drupal installation and Drush availability
- **URL determination**: Container script uses environment variables or Drupal config for base URL

## 🔐 Security & Configuration

### Environment-Driven Configuration

**drupal-netbadge** uses environment variables for secure deployment:

```bash
# Security
SIMPLESAML_SECRET_SALT=your-secret-salt
SIMPLESAML_ADMIN_PASSWORD=secure-password

# SAML Configuration  
SIMPLESAML_SP_ENTITY_ID=https://your-domain.com
SIMPLESAML_IDP_ENTITY_ID=https://idp.university.edu/...

# Deployment Mode
SIMPLESAML_DEBUG=false
SIMPLESAML_PROTECT_METADATA=true
```

### Secrets Management

- **AWS SSM Parameters**: For sensitive configuration
- **EFS Volumes**: For persistent data and certificates
- **Encrypted SSH Keys**: Using ccrypt for infrastructure access
- **IAM Roles**: Separate execution and task roles for containers

## 📊 Monitoring & Health Checks

### Container Health Checks
```bash
# Built into npm scripts
npm run container:health    # Test container responsiveness
npm run security:scan       # Security vulnerability scanning
npm run lint:dockerfile     # Dockerfile best practices
```

### Deployment Tracking
- **SSM Parameters**: Track latest build versions
- **Multi-tag Strategy**: latest, timestamped, git commit
- **Build Metadata**: Containers tagged with build information

## 🎯 Key Design Decisions

### 1. **Dual Project Structure**
- **Separation of Concerns**: IdP vs SP functionality
- **Independent Deployment**: Each can be deployed separately
- **SAML Communication**: Standard SAML 2.0 between projects

### 2. **Container-First Development**
- **Production Parity**: Same containers in dev and production
- **Environment Variables**: Runtime configuration flexibility
- **Volume Mounts**: Development configuration overrides

### 3. **Automated Deployment**
- **Infrastructure as Code**: Terraform integration
- **Secret Management**: Encrypted keys and SSM parameters  
- **Multi-Environment**: Dev, staging, production workflows

### 4. **Developer Experience**
- **NPM Scripts**: Unified command interface
- **Cross-Platform**: Works on macOS, Linux, Windows
- **Rich Feedback**: Emoji-rich console output
- **Testing Integration**: Automated validation

This architecture provides a robust foundation for both local development and AWS production deployment, with strong separation between the SAML Identity Provider and Service Provider components.
