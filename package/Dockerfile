#
# build the target container
#
FROM public.ecr.aws/docker/library/drupal:10.4.4

# update the packages
RUN apt-get -y update && \
	apt-get -y upgrade && \
	apt-get -y install git less vim && \
	apt-get -y install default-mysql-client sqlite3 && \
	apt-get -y install rsync && \
	apt-get -y install gettext-base && \
	apt-get -y install openssl jq

# set the timezone appropriatly
ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Specify home
ENV APP_HOME=/drupal-dhportal
WORKDIR $APP_HOME

# Move in necessary assets
COPY package/data/container_bash_profile /root/.profile
COPY package/data/files/opt/drupal/web/sites/default/settings.php /opt/drupal/web/sites/default/settings.php
COPY package/data/files/usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

RUN mkdir -p /opt/drupal/dhportal && chown www-data:www-data /opt/drupal/dhportal

# github checkout drupal-dhportal dir and symlink appropriate directories
RUN 	mkdir /opt/drupal/util \
	&& git clone https://github.com/uvalib/drupal-dhportal /opt/drupal/util/drupal-dhportal \
	&& ln -sf util/drupal-dhportal/composer.lock /opt/drupal/composer.lock \
	&& ln -sf util/drupal-dhportal/composer.json /opt/drupal/composer.json \
	&& rm -rf /opt/drupal/web/modules/custom \
  	&& ln -sf /opt/drupal/util/drupal-dhportal/web/modules/custom /opt/drupal/web/modules/custom \
	&& rm -rf /opt/drupal/web/themes/custom \
        && ln -sf /opt/drupal/util/drupal-dhportal/web/themes/custom /opt/drupal/web/themes/custom \
	&& ln -sf /opt/drupal/util/drupal-dhportal/scripts /opt/drupal/scripts \
	&& ln -sf /opt/drupal/util/drupal-dhportal/simplesamlphp /opt/drupal/simplesamlphp

# Copy SimpleSAMLphp production configuration files (overrides development config)
COPY package/data/files/opt/drupal/simplesamlphp/ /opt/drupal/simplesamlphp/
COPY package/data/files/opt/drupal/entrypoint-saml.sh /opt/drupal/entrypoint-saml.sh

# Make entrypoint executable
RUN chmod +x /opt/drupal/entrypoint-saml.sh

# install other dependancies
RUN pecl install apcu-5.1.22 && docker-php-ext-enable apcu

# Enable Apache mod_headers module for SimpleSAMLphp security headers
RUN a2enmod headers

# Enable Apache error logging for debugging 403 issues
RUN echo "LogLevel debug" >> /etc/apache2/apache2.conf \
    && echo "ErrorLog /var/log/apache2/error.log" >> /etc/apache2/apache2.conf \
    && echo "CustomLog /var/log/apache2/access.log combined" >> /etc/apache2/apache2.conf

# Update Apache DocumentRoot and enable symlink following for SimpleSAMLphp
RUN sed -i 's|DocumentRoot /var/www/html|DocumentRoot /opt/drupal/web|g' /etc/apache2/sites-enabled/000-default.conf \
    && sed -i '/<VirtualHost \*:80>/a\\t<Directory /opt/drupal/web>\n\t\tOptions FollowSymLinks\n\t\tAllowOverride All\n\t\tRequire all granted\n\t</Directory>' /etc/apache2/sites-enabled/000-default.conf

# need to mount volume in /opt/drupal/web/sites (is that done here?)
# need to run composer install here
# Note: themes will be deployed via composer
# Need to flush and rebuild caches here

WORKDIR /opt/drupal
RUN mkdir -p /opt/drupal/web/modules/contrib && chmod 755 /opt/drupal/web/modules/contrib
RUN mkdir -p /opt/drupal/config/sync && chown www-data:www-data /opt/drupal/config/sync && chmod 2775 /opt/drupal/config/sync

# Set up SimpleSAMLphp configuration directory structure (initial setup only)
RUN mkdir -p /opt/drupal/simplesamlphp/config \
    && mkdir -p /opt/drupal/simplesamlphp/metadata \
    && mkdir -p /opt/drupal/simplesamlphp/cert

RUN composer install

# Ensure vendor directory permissions are correct for copying
RUN chmod -R 755 /opt/drupal/vendor/simplesamlphp/simplesamlphp/public

# Create symlink to SimpleSAMLphp vendor public directory instead of copying
RUN rm -rf /opt/drupal/web/simplesaml \
    && echo "=== DEBUGGING SIMPLESAMLPHP SETUP ===" \
    && echo "Checking vendor directory structure:" \
    && ls -la /opt/drupal/vendor/simplesamlphp/ || echo "simplesamlphp vendor dir not found" \
    && ls -la /opt/drupal/vendor/simplesamlphp/simplesamlphp/ || echo "simplesamlphp/simplesamlphp dir not found" \
    && ls -la /opt/drupal/vendor/simplesamlphp/simplesamlphp/public/ || echo "public dir not found" \
    && echo "Creating symlink from web/simplesaml to vendor public directory:" \
    && ln -sf /opt/drupal/vendor/simplesamlphp/simplesamlphp/public /opt/drupal/web/simplesaml \
    && echo "Verifying symlink creation:" \
    && ls -la /opt/drupal/web/simplesaml \
    && echo "Checking symlink target permissions:" \
    && ls -la /opt/drupal/vendor/simplesamlphp/simplesamlphp/public/ \
    && echo "Looking for assets in target:" \
    && find /opt/drupal/vendor/simplesamlphp/simplesamlphp/public -name "*.css" -o -name "*.js" | head -5 || echo "No CSS/JS assets found" \
    && echo "Testing symlink access:" \
    && ls -la /opt/drupal/web/simplesaml/ || echo "Cannot access via symlink" \
    && echo "=== END DEBUGGING ==="

# Note: Custom SimpleSAMLphp configuration is handled via config directory, not web directory overlays
# The symlink points directly to vendor public files, preserving all assets and default functionality

# Ensure proper permissions for all SimpleSAMLphp files including assets
RUN chown -R www-data:www-data /opt/drupal/web/simplesaml \
    && chmod -R 755 /opt/drupal/web/simplesaml

# Fix permissions for SimpleSAMLphp directories after all files are in place
RUN mkdir -p /opt/drupal/simplesamlphp/log \
    && mkdir -p /opt/drupal/simplesamlphp/tmp \
    && mkdir -p /opt/drupal/simplesamlphp/cache \
    && mkdir -p /opt/drupal/simplesamlphp/data \
    && chown -R 33:33 /opt/drupal/simplesamlphp \
    && chown -R 33:33 /opt/drupal/web/simplesaml \
    && chmod -R 755 /opt/drupal/simplesamlphp \
    && chmod -R 755 /opt/drupal/web/simplesaml \
    && chmod -R 777 /opt/drupal/simplesamlphp/log \
    && chmod -R 777 /opt/drupal/simplesamlphp/tmp \
    && chmod -R 777 /opt/drupal/simplesamlphp/cache \
    && chmod -R 777 /opt/drupal/simplesamlphp/data

# Copy scripts directory for local build
COPY scripts /opt/drupal/scripts

# Make remaining scripts executable
RUN find /opt/drupal/scripts -name "*.sh" -type f -exec chmod +x {} \;

# Final permissions fix to ensure SimpleSAMLphp can write logs at runtime
RUN chown -R 33:33 /opt/drupal/simplesamlphp/log \
    && chown -R 33:33 /opt/drupal/simplesamlphp/tmp \
    && chown -R 33:33 /opt/drupal/simplesamlphp/cache \
    && chown -R 33:33 /opt/drupal/simplesamlphp/data \
    && chmod -R 777 /opt/drupal/simplesamlphp/log \
    && chmod -R 777 /opt/drupal/simplesamlphp/tmp \
    && chmod -R 777 /opt/drupal/simplesamlphp/cache \
    && chmod -R 777 /opt/drupal/simplesamlphp/data

# Make remaining scripts executable
RUN find /opt/drupal/scripts -name "*.sh" -type f -exec chmod +x {} \;

# Final verification of SimpleSAMLphp symlink setup
RUN echo "=== FINAL SIMPLESAMLPHP VERIFICATION ===" \
    && echo "Web directory structure:" \
    && ls -la /opt/drupal/web/ | grep simplesaml \
    && echo "Symlink target verification:" \
    && file /opt/drupal/web/simplesaml \
    && echo "Can we access index.php via symlink?" \
    && ls -la /opt/drupal/web/simplesaml/index.php || echo "index.php not accessible" \
    && echo "=== END VERIFICATION ==="

RUN mkdir /var/run/sqlite && chown www-data:www-data /var/run/sqlite 
# Add the build tag
ARG BUILD_TAG
RUN test -n "$BUILD_TAG" && touch $APP_HOME/buildtag.build-$BUILD_TAG || touch $APP_HOME/buildtag.build-0
#
# end of file

