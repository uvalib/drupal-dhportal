#!/bin/bash

# Configuration
HOSTS="dev:dh-drupal-dev-1.internal.lib.virginia.edu"
DEFAULT_ENV="dev"
LOCAL_DIR="../web/sites/default/files"
REMOTE_PATH="/mnt/data/drupal-0/sites/default/files/"

show_help() {
    echo "Usage: $0 [env]"
    echo "Environments:"
    for pair in $HOSTS; do
        env=${pair%%:*}
        host=${pair#*:}
        [[ "$env" == "$DEFAULT_ENV" ]] && default=" (default)" || default=""
        echo "  $env: $host$default"
    done
    exit 1
}

[[ "$1" == "-h" || "$1" == "--help" ]] && show_help
ENV="${1:-$DEFAULT_ENV}"

HOST=""
for pair in $HOSTS; do
    if [[ "${pair%%:*}" == "$ENV" ]]; then
        HOST="${pair#*:}"
        break
    fi
done

[[ -z "$HOST" ]] && echo "Error: Unknown environment '$ENV'" && show_help

echo "Syncing from ${HOST} to ${LOCAL_DIR}"

rsync -avz -e ssh "${HOST}:$REMOTE_PATH" "$LOCAL_DIR" \
    && echo "Rsync download from $HOST completed successfully."
