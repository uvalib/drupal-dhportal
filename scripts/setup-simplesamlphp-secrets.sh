#!/usr/bin/env bash
#
# Setup SimpleSAMLphp secrets in AWS Secrets Manager
# This script helps create and manage SimpleSAMLphp secrets for different environments
#

set -e

function help_and_exit() {
    echo "Usage: $(basename $0) <command> <environment> [options]"
    echo ""
    echo "Commands:"
    echo "  create-all    Create all required secrets for an environment"
    echo "  create        Create a specific secret"
    echo "  update        Update a specific secret"
    echo "  list          List all secrets for an environment"
    echo "  delete        Delete a specific secret"
    echo ""
    echo "Environment: staging | production"
    echo ""
    echo "Examples:"
    echo "  $(basename $0) create-all staging"
    echo "  $(basename $0) create production admin-password"
    echo "  $(basename $0) update staging secret-salt"
    echo "  $(basename $0) list production"
    exit 1
}

function generate_password() {
    # Generate a strong 32-character password
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

function generate_salt() {
    # Generate a cryptographic salt
    openssl rand -base64 48 | tr -d "=+/"
}

function create_secret() {
    local environment=$1
    local secret_type=$2
    local secret_value=$3
    
    local secret_name="dhportal/${environment}/simplesamlphp/${secret_type}"
    local description="SimpleSAMLphp ${secret_type} for ${environment} environment"
    
    echo "🔐 Creating secret: ${secret_name}"
    
    aws secretsmanager create-secret \
        --name "${secret_name}" \
        --description "${description}" \
        --secret-string "${secret_value}"
    
    if [ $? -eq 0 ]; then
        echo "✅ Secret created successfully"
    else
        echo "❌ Failed to create secret"
        return 1
    fi
}

function update_secret() {
    local environment=$1
    local secret_type=$2
    local secret_value=$3
    
    local secret_name="dhportal/${environment}/simplesamlphp/${secret_type}"
    
    echo "🔄 Updating secret: ${secret_name}"
    
    aws secretsmanager update-secret \
        --secret-id "${secret_name}" \
        --secret-string "${secret_value}"
    
    if [ $? -eq 0 ]; then
        echo "✅ Secret updated successfully"
    else
        echo "❌ Failed to update secret"
        return 1
    fi
}

function list_secrets() {
    local environment=$1
    
    echo "📋 Listing SimpleSAMLphp secrets for ${environment}:"
    echo ""
    
    aws secretsmanager list-secrets \
        --query "SecretList[?starts_with(Name, 'dhportal/${environment}/simplesamlphp/')].{Name:Name,Description:Description,LastChangedDate:LastChangedDate}" \
        --output table
}

function delete_secret() {
    local environment=$1
    local secret_type=$2
    
    local secret_name="dhportal/${environment}/simplesamlphp/${secret_type}"
    
    echo "🗑️  Deleting secret: ${secret_name}"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        aws secretsmanager delete-secret \
            --secret-id "${secret_name}" \
            --force-delete-without-recovery
        
        if [ $? -eq 0 ]; then
            echo "✅ Secret deleted successfully"
        else
            echo "❌ Failed to delete secret"
            return 1
        fi
    else
        echo "❌ Deletion cancelled"
    fi
}

function create_all_secrets() {
    local environment=$1
    
    echo "🚀 Creating all SimpleSAMLphp secrets for ${environment} environment..."
    echo ""
    
    # Generate values
    echo "🎲 Generating secure values..."
    local admin_password=$(generate_password)
    local secret_salt=$(generate_salt)
    
    echo "✅ Generated admin password (32 chars)"
    echo "✅ Generated secret salt (64+ chars)"
    echo ""
    
    # Create secrets
    echo "📝 Admin Password: ${admin_password}"
    create_secret "${environment}" "admin-password" "${admin_password}"
    echo ""
    
    echo "📝 Secret Salt: ${secret_salt}"
    create_secret "${environment}" "secret-salt" "${secret_salt}"
    echo ""
    
    echo "📋 Certificate placeholders (you'll need to update these with real certificates):"
    create_secret "${environment}" "private-key" "-----BEGIN PRIVATE KEY-----\n(paste your private key here)\n-----END PRIVATE KEY-----"
    echo ""
    
    create_secret "${environment}" "certificate" "-----BEGIN CERTIFICATE-----\n(paste your certificate here)\n-----END CERTIFICATE-----"
    echo ""
    
    echo "🎯 All secrets created! Next steps:"
    echo "1. Update the private-key and certificate secrets with real values"
    echo "2. Test retrieval with: ./get-simplesamlphp-secret.sh ${environment} admin-password /tmp/test"
    echo "3. Update your Ansible templates to use these secrets"
}

# Validate input
if [ $# -lt 2 ]; then
    help_and_exit
fi

COMMAND=$1
ENVIRONMENT=$2

# Validate environment
case "${ENVIRONMENT}" in
    staging|production)
        ;;
    *)
        echo "Error: Environment must be 'staging' or 'production'"
        help_and_exit
        ;;
esac

# Ensure AWS CLI is available
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is required but not installed"
    exit 1
fi

# Execute commands
case "${COMMAND}" in
    create-all)
        create_all_secrets "${ENVIRONMENT}"
        ;;
    create)
        if [ $# -ne 3 ]; then
            echo "Error: create command requires secret type"
            echo "Usage: $(basename $0) create <environment> <secret-type>"
            exit 1
        fi
        SECRET_TYPE=$3
        echo "Enter secret value:"
        read -s SECRET_VALUE
        create_secret "${ENVIRONMENT}" "${SECRET_TYPE}" "${SECRET_VALUE}"
        ;;
    update)
        if [ $# -ne 3 ]; then
            echo "Error: update command requires secret type"
            echo "Usage: $(basename $0) update <environment> <secret-type>"
            exit 1
        fi
        SECRET_TYPE=$3
        echo "Enter new secret value:"
        read -s SECRET_VALUE
        update_secret "${ENVIRONMENT}" "${SECRET_TYPE}" "${SECRET_VALUE}"
        ;;
    list)
        list_secrets "${ENVIRONMENT}"
        ;;
    delete)
        if [ $# -ne 3 ]; then
            echo "Error: delete command requires secret type"
            echo "Usage: $(basename $0) delete <environment> <secret-type>"
            exit 1
        fi
        SECRET_TYPE=$3
        delete_secret "${ENVIRONMENT}" "${SECRET_TYPE}"
        ;;
    *)
        echo "Error: Unknown command: ${COMMAND}"
        help_and_exit
        ;;
esac
