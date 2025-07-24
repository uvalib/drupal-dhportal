# Environment Configuration

This container supports different PHP configurations for staging and production environments through runtime environment variables.

## PHP Configuration

### Environment Variable: `PHP_MODE`

**Default**: `development` (if not set)

**Available Options**:
- `development`: Uses `php.ini-development` with `display_errors = On` (good for staging/debugging)
- `production`: Uses `php.ini-production` with `display_errors = Off` (secure for production)

### Usage Examples

#### Staging/Development Environment
```bash
# Default behavior - uses development configuration
docker run drupal-dhportal

# Explicitly set development mode
docker run -e PHP_MODE=development drupal-dhportal
```

#### Production Environment
```bash
# Use production PHP configuration
docker run -e PHP_MODE=production drupal-dhportal
```

### Terraform/Ansible Deployment

In your deployment configuration, set the environment variable:

```yaml
# Ansible example
- name: Deploy container with production PHP config
  docker_container:
    name: drupal-dhportal
    image: "{{ container_image }}"
    env:
      PHP_MODE: production

# Or for staging
- name: Deploy container with development PHP config
  docker_container:
    name: drupal-dhportal
    image: "{{ container_image }}"
    env:
      PHP_MODE: development
```

### Configuration Details

**Development Mode (`PHP_MODE=development`)**:
- `display_errors = On` - PHP errors visible in output (helpful for debugging)
- `error_reporting = E_ALL` - All errors reported
- `log_errors = On` - Errors also logged to stderr
- Better for staging environments where debugging is needed

**Production Mode (`PHP_MODE=production`)**:
- `display_errors = Off` - PHP errors not displayed (security)
- `error_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT` - Reduced error reporting
- `log_errors = On` - Errors logged to stderr only
- Secure configuration for production environments

Both modes always log errors to `/dev/stderr` for container log visibility.

## Current Implementation

For the 403 SimpleSAMLphp debugging, **staging environments should use development mode** to get `display_errors = On`, which will show any PHP errors that might be causing the 403 issues.
