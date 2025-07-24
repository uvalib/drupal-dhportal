# SimpleSAMLphp Troubleshooting Quick Reference

## 🚨 FIRST: Identify Your Environment

### Environment Detection
- **DDEV Local**: URL contains `*.ddev.site`
- **AWS Staging**: URL is `dhportal-dev.internal.lib.virginia.edu`  
- **AWS Production**: URL is `dh.library.virginia.edu`

### Configuration Sources
- **DDEV**: Files are in THIS repository (`.ddev/simplesamlphp/config/`)
- **AWS**: Generated from `terraform-infrastructure` Ansible templates

## 403 Admin Access Errors

### DDEV Environment
1. Check `.ddev/simplesamlphp/config/authsources.php` has admin source:
   ```php
   'admin' => ['core:AdminPassword'],
   ```
2. Restart: `ddev restart`

### AWS Environments
1. Check templates in `terraform-infrastructure`:
   - Staging: `dh.library.virginia.edu/staging/ansible/templates/simplesamlphp/authsources.php.j2`
   - Production: `dh.library.virginia.edu/production.new/ansible/templates/simplesamlphp/authsources.php.j2`
2. Verify templates contain admin source
3. **DEPLOY TO APPLY CHANGES**:
   ```bash
   # Staging
   cd terraform-infrastructure/dh.library.virginia.edu/staging/ansible
   ansible-playbook deploy_backend_1.yml
   
   # Production
   cd terraform-infrastructure/dh.library.virginia.edu/production.new/ansible
   ansible-playbook deploy_backend.yml
   ```

## Remember

- **AWS configurations are GENERATED, not static files**
- **Templates must be deployed to take effect**
- **DDEV uses direct file editing**
- **Always verify which environment you're debugging**

## Common Mistakes

❌ Editing `drupal-dhportal/simplesamlphp/config/authsources.php` when debugging AWS environments  
✅ Edit `terraform-infrastructure` templates and deploy for AWS environments

❌ Expecting AWS changes to take effect immediately  
✅ Run deployment after template changes

❌ Confusing local DDEV config with AWS staging config  
✅ Check URL to identify environment first
