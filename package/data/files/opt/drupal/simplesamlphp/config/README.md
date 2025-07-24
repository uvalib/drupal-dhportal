# SimpleSAMLphp Configuration for drupal-dhportal

## 🚨 Important: AWS Deployment Configuration

**The files in this directory are NOT used by AWS deployments!**

AWS uses Ansible templates located in:
- **Staging**: `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/staging/ansible/templates/simplesamlphp/authsources.php.j2`
- **Production**: `/Users/ys2n/Code/uvalib/terraform-infrastructure/dh.library.virginia.edu/production.new/ansible/templates/simplesamlphp/authsources.php.j2`

## 🚨 CRITICAL DEBUGGING REMINDER

When debugging SimpleSAMLphp 403 admin errors:

### AWS Environments (staging/production):
- Configuration is **GENERATED** from Ansible templates during deployment
- Files like `authsources.php` are created by Ansible, not stored in git
- **TO FIX**: Edit templates in `terraform-infrastructure` repository, then run deployment
- **DEPLOYMENT REQUIRED**: Changes don't take effect until `ansible-playbook deploy_backend_1.yml` (staging) or `deploy_backend.yml` (production) is executed

### DDEV Local Environment:
- Configuration files are in `.ddev/simplesamlphp/config/` directory  
- **TO FIX**: Edit files directly and restart DDEV

## 📁 File Usage

| File | Used By | Purpose |
|------|---------|---------|
| `authsources.php` | Documentation | Reference configuration |
| `config.php` | Documentation | Reference configuration |
| `acl.php` | Container Build | Basic access control configuration |
| ~~`authsources.production.php`~~ | ❌ Removed | Legacy - was unused |
| ~~`authsources.staging.php`~~ | ❌ Removed | Legacy - was unused |
| ~~`config.production.php`~~ | ❌ Removed | Legacy - was unused |
| ~~`config.staging.php`~~ | ❌ Removed | Legacy - was unused |

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
