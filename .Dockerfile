FROM ubuntu:22.04

# Argumentos
ARG GIT_URL

# Variables de entorno
ENV API_URL=${GIT_URL}
ENV DEBIAN_FRONTEND noninteractive

# Establecer el idioma español
RUN apt-get update && apt-get install -y locales && \
    locale-gen es_ES.UTF-8 
	
RUN apt install -yq git

ENV LANG es_ES.UTF-8

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y software-properties-common

# Agregar el PPA de ondrej/php
RUN add-apt-repository ppa:ondrej/php && \
    apt-get update

# Instalar PHP 8.2 y las extensiones necesarias
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 \
    libapache2-mod-php8.1 \
    php8.2 \
    php8.2-common \
    php8.2-mysql \
    php8.2-mbstring \
    php8.2-xml \
    php8.2-zip \
    php8.2-gd \
    mariadb-server \
    && rm -rf /var/lib/apt/lists/*
	
	
#RUN mkdir /var/www/html/devlaravel

# Instalar Xdebug
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y php-xml
RUN apt-get install -y php-dev
RUN apt-get install -y php-pear
RUN apt-get install -y tar
RUN pecl install xdebug
RUN apt install php8.2-xdebug

# Agregar la configuracion de Xdebug
RUN echo "xdebug.mode=debug" >> /etc/php/8.2/mods-available/xdebug.ini
RUN echo "xdebug.start_with_request=yes" >> /etc/php/8.2/mods-available/xdebug.ini
RUN echo "xdebug.client_host=host.docker.internal" >> /etc/php/8.2/mods-available/xdebug.ini
RUN echo "xdebug.client_port=9003" >> /etc/php/8.2/mods-available/xdebug.ini

RUN echo "source /root/.bash_aliases" >> /root/.bashrc
# Set a cool prompt
RUN echo "PS1='\[\033[1;36m\][WebServer]\[\033[1;34m\] [\u] [\w]\n\\$ \[\033[0m\]'" >> /root/.bashrc


# Install oh my git! terminal bash bar
RUN git clone https://github.com/jenhsun/oh-my-git-patched.git ~/.oh-my-git && echo source ~/.oh-my-git/prompt.sh >> /root/.bashrc

# Enable git completion
RUN echo "source /usr/share/bash-completion/completions/git" >> ~/.bashrc

# clone github repositorio
RUN git clone ${API_URL} /var/www/html

# Instalar Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
RUN php composer-setup.php
RUN php -r "unlink('composer-setup.php');"
RUN mv composer.phar /usr/local/bin/composer

# Instalar Node.js y npm
RUN apt-get update && \
    apt-get install -y curl && \
    curl -sL https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get install -y nodejs


# Establecer el directorio de trabajo
WORKDIR /var/www/html/laravel-environment-for-docker


# Instalar Laravel
RUN composer create-project --prefer-dist laravel/laravel .

# Instalar breeze
RUN composer require laravel/breeze --dev
RUN php artisan breeze:install
RUN npm install && npm run dev
RUN php artisan migrate
# vue
#npm install vue@next

# Exponer el puerto 80 y 3306
EXPOSE 80 3306 443

# Agregar el archivo de configuración del virtual host
COPY ./conf/devlaravel.conf /etc/apache2/sites-available/

# RUN a2enmod ssl 

# Habilitar el virtual host y deshabilitar el sitio predeterminado
RUN a2ensite devlaravel.conf && a2dissite 000-default.conf

# Habilitar modulo rewrite
RUN a2enmod rewrite

RUN echo "ServerName localhost" >> /etc/apache2/httpd.conf

# Copiar el archivo de configuración de MySQL al contenedor
COPY my.cnf /etc/mysql/my.cnf

# Cambiar el usuario de MySQL al usuario "mysql" existente en el contenedor
RUN sed -i 's/user\s*=\s*mysql/user=mysql/g' /etc/mysql/my.cnf

# Reiniciar el servicio de MySQL para aplicar los cambios en la configuración
RUN service mysql restart

# colores git en la terminal
RUN git config --global color.ui true

RUN apt-get install nano

# Iniciar MySQL y Apache en primer plano
CMD service mysql start && apachectl -D FOREGROUND

RUN composer update

# docker run --privileged -p 80:80 -p 443:443 -p 3306:330 -p 9003:9003 dockerfile

