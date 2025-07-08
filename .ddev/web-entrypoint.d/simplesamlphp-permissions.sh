#!/bin/bash

# SimpleSAMLphp Permissions Fix
# This script ensures SimpleSAMLphp vendor files have correct permissions
# for web server access. Runs automatically on container start.

SIMPLESAML_PUBLIC_DIR="/var/www/html/vendor/simplesamlphp/simplesamlphp/public"
SIMPLESAML_WEB_DIR="/var/www/html/web/simplesaml"

# Only run if SimpleSAMLphp is installed
if [ -d "$SIMPLESAML_PUBLIC_DIR" ]; then
    echo "🔧 Fixing SimpleSAMLphp permissions..."
    
    # Ensure the public directory is readable by web server
    chmod -R 755 "$SIMPLESAML_PUBLIC_DIR"
    
    # Ensure specific files are executable
    find "$SIMPLESAML_PUBLIC_DIR" -name "*.php" -exec chmod 755 {} \;
    
    # If symlink exists, ensure it's accessible
    if [ -L "$SIMPLESAML_WEB_DIR" ]; then
        # Symlink permissions are determined by target, but ensure the link itself is valid
        if [ ! -e "$SIMPLESAML_WEB_DIR" ]; then
            echo "⚠️  SimpleSAMLphp symlink is broken, attempting to recreate..."
            rm -f "$SIMPLESAML_WEB_DIR"
            ln -sf "../vendor/simplesamlphp/simplesamlphp/public" "$SIMPLESAML_WEB_DIR"
        fi
    else
        echo "ℹ️  Creating SimpleSAMLphp symlink..."
        ln -sf "../vendor/simplesamlphp/simplesamlphp/public" "$SIMPLESAML_WEB_DIR"
    fi
    
    echo "✅ SimpleSAMLphp permissions and symlink configured"
else
    echo "ℹ️  SimpleSAMLphp not found, skipping permission fix"
fi
