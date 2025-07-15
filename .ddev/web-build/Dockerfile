# Custom DDEV web container build
# Ensures SAML setup dependencies are available

# Install gettext-base for envsubst (required for SAML template processing)
RUN apt-get update && apt-get install -y gettext-base && apt-get clean && rm -rf /var/lib/apt/lists/*
