# SimpleSAMLphp Configuration for drupal-dhportal

## 🚨 Important: AWS Deployment Configuration

**The files in this directory are NOT used by AWS deployments!**

AWS uses Ansible templates located in:
- **Staging**: `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/staging/ansible/templates/simplesamlphp/authsources.php.j2`
- **Production**: `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/production.new/ansible/templates/simplesamlphp/authsources.php.j2`

## 📁 File Usage

| File | Used By | Purpose |
|------|---------|---------|
| `authsources.php` | Documentation | Reference configuration |
| `config.php` | Documentation | Reference configuration |
| `authsources.production.php` | ❌ Not Used | Legacy - can be removed |
| `authsources.staging.php` | ❌ Not Used | Legacy - can be removed |

## 🔧 Making Configuration Changes

### For AWS Environments:
1. Edit the Ansible templates in `terraform-infrastructure` repository
2. Deploy via Terraform/Ansible

### For Local DDEV:
1. Edit files in `.ddev/simplesamlphp/config/`

## ✅ Required Configuration

All authsources configurations must include:

```php
$config = [
    // Admin authentication source - required for SimpleSAMLphp administration
    'admin' => [
        'core:AdminPassword',
    ],
    
    // Your SP configuration...
    'default-sp' => [
        // ...
    ],
];
```
