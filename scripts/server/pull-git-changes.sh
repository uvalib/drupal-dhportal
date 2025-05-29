#!/bin/sh
cd /opt/drupal/util/drupal-dhportal
git fetch -o StrictHostKeyChecking=accept-new
changes=`git diff --name-only origin/main| wc -l`

if [ $changes -gt 0 ]; then
        echo $changes changes detected.
        git pull && \
		( cd /opt/drupal ; composer install ) && \
        drush cr
fi
