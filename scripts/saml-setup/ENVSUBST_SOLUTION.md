# envsubst Availability Solution

## Problem
The SAML setup scripts in `drupal-dhportal` require `envsubst` (from the `gettext-base` package) for template processing, but it was not available in both development (DDEV) and production (Docker) environments.

## Solution Implemented

### 1. Production Environment (Docker)
Updated `package/Dockerfile` to install `gettext-base`:

```dockerfile
# update the packages
RUN apt-get -y update && \
        apt-get -y upgrade && \
        apt-get install -y gettext-base
```

This ensures `envsubst` is available when running the production Docker container.

### 2. Development Environment (DDEV)
Created custom web-build configuration in `.ddev/web-build/Dockerfile`:

```dockerfile
# Custom web build for drupal-dhportal

# Install gettext-base for envsubst (required for SAML template processing)
ARG BASE_IMAGE
FROM $BASE_IMAGE
RUN apt-get update && apt-get install -y gettext-base && apt-get clean && rm -rf /var/lib/apt/lists/*
```

This ensures `envsubst` is available in the DDEV development environment.

### 3. Consistency Across Projects
Applied the same solution to `drupal-netbadge` for consistency and future-proofing, even though it doesn't currently use `envsubst`.

## Verification
Both environments now have `envsubst` available:

- **Production**: `docker run --rm <image> which envsubst` returns `/usr/bin/envsubst`
- **Development**: `ddev exec "which envsubst"` returns `/usr/bin/envsubst`

## Usage
The SAML setup scripts can now use `envsubst` for template processing in both environments:

```bash
envsubst < template_file > output_file
```

## Benefits
1. **Environment Parity**: Both development and production environments have the same tools available
2. **Template Processing**: SAML configuration templates can use environment variable substitution
3. **Future-Proof**: Both projects are prepared for any future template processing needs
4. **Minimal Impact**: Small package addition with no breaking changes

## Files Modified
- `/Users/ys2n/Code/ddev/drupal-dhportal/package/Dockerfile`
- `/Users/ys2n/Code/ddev/drupal-dhportal/.ddev/web-build/Dockerfile` (created)
- `/Users/ys2n/Code/ddev/drupal-netbadge/package/Dockerfile`
- `/Users/ys2n/Code/ddev/drupal-netbadge/.ddev/web-build/Dockerfile` (created)
