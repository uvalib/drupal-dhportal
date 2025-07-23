#!/usr/bin/env bash
#
# SimpleSAMLphp AWS Secrets Manager Integration
# Retrieves SimpleSAMLphp credentials from AWS Secrets Manager
# Usage: get-simplesamlphp-secret.sh <environment> <secret-type> <output-file>
#

set -e

function help_and_exit() {
    echo "Usage: $(basename $0) <environment> <secret-type> <output-file>"
    echo ""
    echo "Environment: staging | production"
    echo "Secret Type: admin-password | secret-salt | private-key | certificate"
    echo ""
    echo "Examples:"
    echo "  $(basename $0) staging admin-password /tmp/admin-password.txt"
    echo "  $(basename $0) production private-key /tmp/saml-private.pem"
    echo "  $(basename $0) production certificate /tmp/saml-cert.crt"
    exit 1
}

# Validate input parameters
if [ $# -ne 3 ]; then
    help_and_exit
fi

ENVIRONMENT=${1}
SECRET_TYPE=${2}
OUTPUT_FILE=${3}

# Validate environment
case "${ENVIRONMENT}" in
    staging|production)
        ;;
    *)
        echo "Error: Environment must be 'staging' or 'production'"
        help_and_exit
        ;;
esac

# Validate secret type
case "${SECRET_TYPE}" in
    admin-password|secret-salt|private-key|certificate)
        ;;
    *)
        echo "Error: Invalid secret type: ${SECRET_TYPE}"
        help_and_exit
        ;;
esac

# Check if output file already exists
if [ -f "${OUTPUT_FILE}" ]; then
    echo "Secret file already exists: ${OUTPUT_FILE}"
    exit 0
fi

# Ensure we have AWS CLI available
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is required but not installed"
    exit 1
fi

# Map secret types to AWS Secret Manager secret names
case "${SECRET_TYPE}" in
    admin-password)
        SECRET_NAME="dhportal/${ENVIRONMENT}/simplesamlphp/admin-password"
        ;;
    secret-salt)
        SECRET_NAME="dhportal/${ENVIRONMENT}/simplesamlphp/secret-salt"
        ;;
    private-key)
        SECRET_NAME="dhportal/${ENVIRONMENT}/simplesamlphp/private-key"
        ;;
    certificate)
        SECRET_NAME="dhportal/${ENVIRONMENT}/simplesamlphp/certificate"
        ;;
esac

echo "🔐 Retrieving ${SECRET_TYPE} for ${ENVIRONMENT} environment..."
echo "   Secret: ${SECRET_NAME}"

# Retrieve secret from AWS Secrets Manager
SECRET_VALUE=$(aws secretsmanager get-secret-value \
    --secret-id "${SECRET_NAME}" \
    --query 'SecretString' \
    --output text 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ Failed to retrieve secret: ${SECRET_NAME}"
    echo ""
    echo "💡 To create this secret, run:"
    echo "   aws secretsmanager create-secret \\"
    echo "       --name '${SECRET_NAME}' \\"
    echo "       --description 'SimpleSAMLphp ${SECRET_TYPE} for ${ENVIRONMENT}' \\"
    echo "       --secret-string 'your-secret-value-here'"
    exit 1
fi

# Create output directory if it doesn't exist
OUTPUT_DIR=$(dirname "${OUTPUT_FILE}")
mkdir -p "${OUTPUT_DIR}"

# Write secret to output file with appropriate permissions
echo "${SECRET_VALUE}" > "${OUTPUT_FILE}"

# Set appropriate permissions based on secret type
case "${SECRET_TYPE}" in
    private-key)
        chmod 600 "${OUTPUT_FILE}"  # Private key - very restrictive
        ;;
    admin-password|secret-salt)
        chmod 600 "${OUTPUT_FILE}"  # Passwords - very restrictive
        ;;
    certificate)
        chmod 644 "${OUTPUT_FILE}"  # Certificate - readable
        ;;
esac

echo "✅ Secret written to: ${OUTPUT_FILE}"
echo "   Permissions: $(stat -c '%a' "${OUTPUT_FILE}" 2>/dev/null || stat -f '%A' "${OUTPUT_FILE}")"

exit 0
