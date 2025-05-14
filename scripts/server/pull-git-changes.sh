#!/bin/sh
cd /opt/drupal/util/drupal-dhportal
git fetch
changes=`git diff --name-only origin/main| wc -l`

if [ $changes -gt 0 ]; then
        echo $changes changes detected.
        git pull && \
		( cd /opt/drupal ; composer install ) && \
        drush cr
fi
