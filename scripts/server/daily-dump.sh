#!/usr/bin/bash
ENV=dhportal-dev
DAYOFWEEK=`date +%w-%A`
MONTHLY=`date +%m-%B`
BACKUP_DIR=/opt/drupal/dhportal/backups/daily/$DAYOFWEEK
MONTHLY_DIR=/opt/drupal/dhportal/backups/monthly/$MONTHLY
TSTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP="${BACKUP_DIR}/dh-backup-$ENV-$TSTAMP.sql.gz"
MONTHLY="${MONTHLY_DIR}/dh-backup-$ENV-$MONTHLY.sql.gz"
mkdir -p ${BACKUP_DIR}
mkdir -p ${MONTHLY_DIR}

drush sql-dump --extra-dump=--no-tablespaces | gzip > "$BACKUP"
cp "$BACKUP" "$MONTHLY"

#Clean up old backups

find "$BACKUP_DIR" -type f -mtime +32 -delete
find "$MONTHLY_DIR" -type f -mtime +365 -delete
