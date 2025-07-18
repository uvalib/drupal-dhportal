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
COPY package/data/files/opt/drupal/web/simplesaml/ /opt/drupal/web/simplesaml/
COPY package/data/files/opt/drupal/entrypoint-saml.sh /opt/drupal/entrypoint-saml.sh

# Make entrypoint executable
RUN chmod +x /opt/drupal/entrypoint-saml.sh

# install other dependancies
RUN pecl install apcu-5.1.22 && docker-php-ext-enable apcu

# Enable Apache mod_headers module for SimpleSAMLphp security headers
RUN a2enmod headers

# need to mount volume in /opt/drupal/web/sites (is that done here?)
# need to run composer install here
# Note: themes will be deployed via composer
# Need to flush and rebuild caches here

WORKDIR /opt/drupal
RUN mkdir -p /opt/drupal/web/modules/contrib && chmod 755 /opt/drupal/web/modules/contrib
RUN mkdir -p /opt/drupal/config/sync && chown www-data:www-data /opt/drupal/config/sync && chmod 2775 /opt/drupal/config/sync

# Set up SimpleSAMLphp configuration directory structure and permissions
RUN mkdir -p /opt/drupal/simplesamlphp/config \
    && mkdir -p /opt/drupal/simplesamlphp/metadata \
    && mkdir -p /opt/drupal/simplesamlphp/cert \
    && mkdir -p /opt/drupal/simplesamlphp/log \
    && mkdir -p /opt/drupal/simplesamlphp/tmp \
    && mkdir -p /opt/drupal/simplesamlphp/cache \
    && mkdir -p /opt/drupal/simplesamlphp/data \
    && mkdir -p /opt/drupal/web/simplesaml \
    && chown -R www-data:www-data /opt/drupal/simplesamlphp \
    && chown -R www-data:www-data /opt/drupal/web/simplesaml \
    && chmod -R 755 /opt/drupal/simplesamlphp \
    && chmod -R 755 /opt/drupal/web/simplesaml \
    && chmod -R 775 /opt/drupal/simplesamlphp/log \
    && chmod -R 775 /opt/drupal/simplesamlphp/tmp \
    && chmod -R 775 /opt/drupal/simplesamlphp/cache \
    && chmod -R 775 /opt/drupal/simplesamlphp/data

RUN composer install

# Copy scripts directory for local build
COPY scripts /opt/drupal/scripts

# Copy SAML configuration and certificates from git repo
COPY saml-config /opt/drupal/saml-config

# Make SAML certificate management scripts executable (setup happens during deployment)
RUN chmod +x /opt/drupal/scripts/manage-saml-certificates*.sh

RUN mkdir /var/run/sqlite && chown www-data:www-data /var/run/sqlite 
# Add the build tag
ARG BUILD_TAG
RUN test -n "$BUILD_TAG" && touch $APP_HOME/buildtag.build-$BUILD_TAG || touch $APP_HOME/buildtag.build-0
#
# end of file

