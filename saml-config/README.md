# SAML Configuration Files

This directory contains all SimpleSAMLphp configuration files for the SAML Service Provider (SP) setup.

## Files

- `simplesaml-*.php` - Various SimpleSAMLphp configuration files
- `simplesamlphp/` - SimpleSAMLphp configuration directory with metadata and certificates
- `*-idp-remote.php` - Identity Provider metadata files

## Usage

These files are referenced by the SimpleSAMLphp installation and copied to the appropriate locations during DDEV container startup.

## Important Notes

- Configuration files contain sensitive information like certificates and secret keys
- The `simplesamlphp/` directory contains the main configuration files used by SimpleSAMLphp
- Files are automatically copied to the vendor SimpleSAMLphp directory during container initialization
