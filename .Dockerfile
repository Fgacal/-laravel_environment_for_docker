# Use la imagen base de Ubuntu 22.04
FROM ubuntu:22.04

# Argumentos
ARG ENV_FILE=./.env
RUN if [ -f $ENV_FILE ]; then export $(grep -v '^#' $ENV_FILE | xargs -0); fi

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

# Instalar PHP 8.3 y las extensiones necesarias
# Actualizar el sistema e instalar los paquetes necesarios
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apache2 \
    libapache2-mod-php8.3 \
    php8.3 \
    php8.3-curl \
    php8.3-common \
    php8.3-mysql \
    php8.3-mbstring \
    php8.3-xml \
    php8.3-zip \
    php8.3-gd \
    php-pear \
    mysql-server \
    zip \
    unzip \
    php8.3-dev \
    && rm -rf /var/lib/apt/lists/*

# Actualizar el índice de paquetes e instalar cURL
RUN apt-get update && apt-get install -y curl

# Instalar Xdebug
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y php-xml php-dev php-pear tar && \
    pecl install xdebug && \
    apt install -y php8.3-xdebug

# Agregar la configuracion de Xdebug
RUN echo "xdebug.mode=debug" >> /etc/php/8.3/mods-available/xdebug.ini
RUN echo "xdebug.start_with_request=yes" >> /etc/php/8.3/mods-available/xdebug.ini
RUN echo "xdebug.client_host=host.docker.internal" >> /etc/php/8.3/mods-available/xdebug.ini
RUN echo "xdebug.client_port=9003" >> /etc/php/8.3/mods-available/xdebug.ini

# Clonar el repositorio desde la variable de entorno
# RUN git clone $GIT_URL /var/www/html || true
# Establecer el directorio de trabajo

WORKDIR /var/www/html

# Actualizar los repositorios e instalar las dependencias necesarias
RUN apt-get update \
    && apt-get install -y curl git nano

# Descargar e instalar la versión más reciente de Node.js y npm
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest

RUN apt-get install -y php8.3-curl

# Instalar Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
# Eliminar contenido existente en /var/www/html
RUN rm -rf /var/www/html/*
# Instalar Laravel en el directorio /var/www/html
RUN composer create-project --prefer-dist laravel/laravel /var/www/html --ignore-platform-reqs


# Instalar breeze
#RUN composer require laravel/breeze --dev
#RUN php artisan cache:clear
#RUN php artisan breeze:install
#RUN npm install && npm run dev
#RUN php artisan migrate


# Exponer los puertos
EXPOSE 80 3306 443

# Agregar el archivo de configuración del virtual host
COPY ./conf/devlaravel.conf /etc/apache2/sites-available/

# Habilitar el virtual host y deshabilitar el sitio predeterminado
RUN a2ensite devlaravel.conf && a2dissite 000-default.conf

# Habilitar el módulo rewrite
RUN a2enmod rewrite

RUN echo "ServerName localhost" >> /etc/apache2/httpd.conf

# Agregar el archivo de configuración de MySQL al contenedor
COPY ./conf/my.cnf /etc/mysql/my.cnf

# Cambiar el usuario de MySQL al usuario "mysql" existente en el contenedor
RUN sed -i 's/user\s*=\s*mysql/user=mysql/g' /etc/mysql/my.cnf

# Reiniciar el servicio de MySQL para aplicar los cambios en la configuración
RUN service mysql restart

# Configurar los colores de git en la terminal
RUN git config --global color.ui true

# Configurar el prompt de la terminal
RUN echo "PS1='\[\033[1;36m\][WebServer]\[\033[1;34m\] [\u] [\w]\n\\$ \[\033[0m\]'" >> /root/.bashrc

# Instalar oh my git! para la terminal bash
RUN git clone https://github.com/jenhsun/oh-my-git-patched.git ~/.oh-my-git && echo source ~/.oh-my-git/prompt.sh >> /root/.bashrc

# Habilitar la autocompletación de git
RUN echo "source /usr/share/bash-completion/completions/git" >> ~/.bashrc

# Ejecutar composer update
RUN composer update

# Iniciar MySQL y Apache en primer plano
CMD service mysql start && apachectl -D FOREGROUND

# docker run --privileged -p 80:80 -p 443:443 -p 3306:330 -p 9003:9003 -d --name laravel laravel:10
# docker build -t laravel:10 -f .Dockerfile .
