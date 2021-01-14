FROM php:7.4-fpm-alpine3.12

WORKDIR /src

# Install sys deps
RUN echo "deb http://deb.debian.org/debian stretch main multiverse non-free"  > /etc/apt/sources.list && \
echo "deb http://security.debian.org/debian-security stretch/updates main non-free" >> /etc/apt/sources.list && \
echo "deb http://deb.debian.org/debian stretch-updates main non-free " >> /etc/apt/sources.list && \
echo "deb http://deb.debian.org/debian stretch-backports main non-free" >> /etc/apt/sources.list && \
echo "deb http://http.us.debian.org/debian stable main contrib non-free" >> /etc/apt/sources.list

# Install node and npm (v8.x Specific)
# RUN apt-get update && apt-get install -my wget gnupg
# RUN curl -sL https://deb.nodesource.com/setup_8.x | bash -
# RUN apt-get install -y nodejs
# RUN npm i -g webpack && npm i -g typescript && npm i -g yarn

# Install specific version of Node (8.11.3)
# ENV NVM_DIR /usr/local/nvm
# RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.1/install.sh | bash
# ENV NODE_VERSION v8.11.3 
# RUN /bin/bash -c "source $NVM_DIR/nvm.sh && nvm install $NODE_VERSION && nvm use --delete-prefix $NODE_VERSION"
# ENV NODE_PATH $NVM_DIR/versions/node/$NODE_VERSION/lib/node_modules
# ENV PATH      $NVM_DIR/versions/node/$NODE_VERSION/bin:$PATH

# Install node and npm (v12.x Specific)
RUN apt-get update && apt-get install -my wget gnupg
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN apt-get install -y nodejs
RUN npm i -g webpack && npm i -g typescript && npm i -g yarn

# PDFTK
RUN mkdir /usr/share/man/man1 
COPY pdftk/pdftk-all.jar /pdftk.jar
COPY pdftk/pdftk.sh /usr/bin/pdftk
RUN chmod +x /usr/bin/pdftk

# Install dependencies
RUN apt-get update && apt-get install -y \
        git \
        vim \
        htop \
        libmcrypt-dev \
        libxml2-dev \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libpng-dev \
        nginx-light \
        ssh-client \
        supervisor \
        wget \
        zip \
        zlib1g-dev \
        libzip-dev \
        libicu-dev \
        g++ \
        poppler-utils \
        openjdk-8-jdk \
        libgd3 \
        libgd-dev \
        libc-client-dev \
        libkrb5-dev

# Install + Configure PHP libraries
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl
RUN docker-php-ext-configure intl

# mailparse
RUN pecl install mailparse
RUN docker-php-ext-enable opcache mailparse

RUN docker-php-ext-install -j$(nproc) \
        bcmath \
        mysqli \
        pcntl \
        pdo \
        pdo_mysql \
        zip \
        gd \
        soap \
        intl \
        imap

# MongoDb (required by: composer require doctrine/mongodb-odm-bundle)
RUN docker-php-ext-install -j$(nproc) sockets
RUN apt-get install -y libssl-dev
RUN yes '' | pecl install -f pcov
RUN yes '' | pecl install -f mongodb 
RUN docker-php-ext-enable pcov mongodb

# MCrypt extension
RUN yes '' | pecl install -f mcrypt
RUN echo "extension=mcrypt.so" > /usr/local/etc/php/conf.d/mcrypt.ini
RUN apt-get clean -y

# Setup PHP ini configs
RUN echo "date.timezone=Europe/London" > /usr/local/etc/php/conf.d/signature.ini && \
echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/signature.ini && \
echo "opcache.max_accelerated_files=32531" >> /usr/local/etc/php/conf.d/signature.ini && \
echo "opcache.memory_consumption=512" >> /usr/local/etc/php/conf.d/signature.ini && \
echo "upload_max_filesize = 10M" >>  /usr/local/etc/php/conf.d/signature.ini && \
echo "post_max_size = 11M" >> /usr/local/etc/php/conf.d/signature.ini && \
echo "memory_limit = 512M" >> /usr/local/etc/php/conf.d/signature.ini

# Install APCu
RUN pecl install apcu
RUN echo "extension=apcu.so" > /usr/local/etc/php/conf.d/apcu.ini

# Install composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && php composer-setup.php --install-dir=/usr/local/bin --filename=composer
RUN chmod +x /usr/local/bin/composer
RUN composer global require hirak/prestissimo

# Configure sudoers for better dev experience ;-)
RUN echo "Defaults umask=0002" >> /etc/sudoers \
    && echo "Defaults umask_override" >> /etc/sudoers

VOLUME /src
VOLUME /var/lib/nginx
VOLUME /tmp
VOLUME /tmp/nginx
VOLUME /tmp/nginx/cache
VOLUME /tmp/nginx/fcgicache

# Remove apt cache to make the image smaller
RUN apt-get clean -y
RUN rm -rf /var/lib/apt/lists/*
RUN apt-get purge -y --auto-remove

# These two commands are SUPER important!
EXPOSE 80
CMD ["/usr/bin/bash”]