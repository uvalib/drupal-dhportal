#
# build the target container
#
FROM public.ecr.aws/docker/library/drupal:10.4.4

# Update packages and install dependencies
RUN apt-get -y update && \
	apt-get -y upgrade && \
	apt-get -y install \
		git less vim \
		default-mysql-client sqlite3 \
		rsync gettext-base \
		openssl jq && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Set timezone
ENV TZ=America/New_York
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Specify home
ENV APP_HOME=/drupal-dhportal
WORKDIR $APP_HOME

# Move in necessary assets
COPY package/data/container_bash_profile /root/.profile
COPY package/data/files/opt/drupal/web/sites/default/settings.php /opt/drupal/web/sites/default/settings.php
# Copy both PHP configurations for runtime switching
COPY package/data/files/usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini-development
COPY package/data/files/usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini-production
# Default to development configuration (staging/dev friendly)
COPY package/data/files/usr/local/etc/php/php.ini-development /usr/local/etc/php/php.ini
RUN echo "PHP configuration: Default development mode (will be switched at runtime via PHP_MODE env var)" && \
    echo "PHP display_errors setting: $(grep '^display_errors' /usr/local/etc/php/php.ini || echo 'not set')"

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

# Install PHP dependencies
RUN pecl install apcu-5.1.22 && docker-php-ext-enable apcu

# Configure Apache for Drupal and SimpleSAMLphp
RUN a2enmod headers && \
    echo "LogLevel info" >> /etc/apache2/apache2.conf && \
    sed -i 's|DocumentRoot /var/www/html|DocumentRoot /opt/drupal/web|g' /etc/apache2/sites-enabled/000-default.conf && \
    sed -i '/<VirtualHost \*:80>/a\\t<Directory /opt/drupal/web>\n\t\tOptions FollowSymLinks\n\t\tAllowOverride All\n\t\tRequire all granted\n\t</Directory>' /etc/apache2/sites-enabled/000-default.conf && \
    echo "Apache config verification:" && \
    grep -A 10 -B 2 "DocumentRoot\|FollowSymLinks" /etc/apache2/sites-enabled/000-default.conf && \
    echo "Apache log configuration (should be symlinks to stdout/stderr):" && \
    ls -la /var/log/apache2/

# Set up Drupal working environment
WORKDIR /opt/drupal

# Create required directories with proper permissions
RUN mkdir -p /opt/drupal/web/modules/contrib && chmod 755 /opt/drupal/web/modules/contrib && \
    mkdir -p /opt/drupal/config/sync && chown www-data:www-data /opt/drupal/config/sync && chmod 2775 /opt/drupal/config/sync && \
    mkdir -p /opt/drupal/simplesamlphp/{config,metadata,cert}

RUN composer install

# Ensure vendor directory permissions are correct for copying
RUN chmod -R 755 /opt/drupal/vendor/simplesamlphp/simplesamlphp/public

# Create symlink to SimpleSAMLphp vendor public directory
RUN rm -rf /opt/drupal/web/simplesaml \
    && ln -sf /opt/drupal/vendor/simplesamlphp/simplesamlphp/public /opt/drupal/web/simplesaml \
    && echo "SimpleSAMLphp symlink created successfully" \
    && echo "Build-time verification:" \
    && ls -la /opt/drupal/web/simplesaml/index.php \
    && echo "Symlink target readable: $(cat /opt/drupal/web/simplesaml/index.php | head -1)"

# Note: Custom SimpleSAMLphp configuration is handled via config directory, not web directory overlays
# The symlink points directly to vendor public files, preserving all assets and default functionality

# Copy scripts directory for local build (do this early to avoid permission conflicts)
COPY scripts /opt/drupal/scripts

# Set up SimpleSAMLphp directories and permissions in one consolidated step
RUN mkdir -p /opt/drupal/simplesamlphp/{log,tmp,cache,data} \
    && chown -R www-data:www-data /opt/drupal/web/simplesaml \
    && chown -R www-data:www-data /opt/drupal/simplesamlphp \
    && chmod -R 755 /opt/drupal/simplesamlphp \
    && chmod -R 755 /opt/drupal/web/simplesaml \
    && chmod -R 777 /opt/drupal/simplesamlphp/{log,tmp,cache,data} \
    && find /opt/drupal/scripts -name "*.sh" -type f -exec chmod +x {} \;

RUN mkdir /var/run/sqlite && chown www-data:www-data /var/run/sqlite 
# Add the build tag
ARG BUILD_TAG
RUN test -n "$BUILD_TAG" && touch $APP_HOME/buildtag.build-$BUILD_TAG || touch $APP_HOME/buildtag.build-0
#
# end of file

