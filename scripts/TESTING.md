# Production Container Path Testing

## Overview

This test script validates that the production container path configuration works correctly, ensuring SAML setup scripts can find their templates and dependencies.

## Problem Statement

In the production container environment:
- Scripts are mounted at: `/opt/drupal/util/drupal-dhportal/scripts`
- Scripts expect to find themselves at: `/opt/drupal/scripts`

This path mismatch could cause SAML setup and other scripts to fail when looking for their templates.

## Solution

The production `Dockerfile` creates a symlink to bridge this gap:

```dockerfile
ln -sf /opt/drupal/util/drupal-dhportal/scripts /opt/drupal/scripts
```

## Test Script Usage

### Running the Test

```bash
# Run from the project root directory
./scripts/test-production-paths.sh
```

### What It Tests

The script performs comprehensive validation:

1. **Docker Build** - Ensures the production container builds successfully
2. **Symlink Creation** - Verifies the symlink exists and points correctly
3. **Directory Access** - Tests that script directories are accessible through symlink
4. **Template Files** - Confirms all SAML template files exist and have content
5. **Path Resolution** - Validates `${DRUPAL_ROOT}/scripts/saml-setup/templates/` resolves correctly
6. **Script Permissions** - Ensures scripts have proper execute permissions
7. **Script Syntax** - Confirms scripts have no syntax errors
8. **Cleanup** - Removes test artifacts

### Expected Output

When all tests pass:

```
🎉 All tests passed! Production container path configuration is working correctly.

Summary:
  • Scripts are mounted at: /opt/drupal/util/drupal-dhportal/scripts
  • Scripts expect to find themselves at: /opt/drupal/scripts
  • Symlink successfully bridges the gap: /opt/drupal/scripts → /opt/drupal/util/drupal-dhportal/scripts
  • SAML templates are accessible at: ${DRUPAL_ROOT}/scripts/saml-setup/templates/
  • All SAML setup functionality should work correctly in production
```

## Test Details

| Test | Validates | Failure Indicates |
|------|-----------|-------------------|
| Docker build | Container builds without errors | Dockerfile syntax issues |
| Symlink creation | `/opt/drupal/scripts` → `/opt/drupal/util/drupal-dhportal/scripts` | Missing symlink command in Dockerfile |
| Directory access | Scripts accessible through symlink | Repository not cloned correctly |
| Template files | All required `.template` files present | Missing template files in repository |
| DRUPAL_ROOT resolution | Environment variable resolves correctly | Script configuration issues |
| Script permissions | Scripts have execute permissions | File permission problems |
| Script syntax | No syntax errors in shell scripts | Shell scripting syntax errors |
| Template content | Template files are not empty | Empty or corrupted template files |
| Path resolution | Exact logic used by scripts works | Script path resolution logic broken |
| Cleanup | No artifacts left behind | Docker cleanup issues |

## Troubleshooting

### Common Issues

**Docker build fails**
- Check `package/Dockerfile` for syntax errors
- Ensure base image is accessible
- Verify all COPY commands reference existing files

**Symlink tests fail**
- Verify the symlink creation line exists in `package/Dockerfile`
- Check that the symlink command syntax is correct

**Directory access fails**
- Ensure the repository is cloned correctly in the container
- Verify git clone command in Dockerfile works

**Template tests fail**
- Check that template files exist in `scripts/saml-setup/templates/`
- Verify file permissions allow reading

**Path resolution fails**
- Check that `DRUPAL_ROOT` is set correctly in scripts
- Verify script logic for finding templates

## Integration with CI/CD

This test should be run after changes to:

- `package/Dockerfile`
- Script directory structure  
- SAML setup scripts
- Template files
- Production deployment configuration

Example GitHub Actions integration:

```yaml
- name: Test Production Paths
  run: ./scripts/test-production-paths.sh
```

## Related Files

- `package/Dockerfile` - Production container definition with symlink creation
- `scripts/saml-setup/setup-saml-integration-container.sh` - Main SAML setup script
- `scripts/saml-setup/templates/` - Template files accessed through symlink
