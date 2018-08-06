################################################################################
# Base image
################################################################################

FROM debian:stretch-slim

LABEL maintainer="Pathompong Pechkongtong <boynoiz [at] gmail.com>"

ARG PROJECT_NAME
ARG SSH_USER_NAME
ARG SSH_USER_PASSWORD
ARG TZ

ENV PROJECT_NAME ${PROJECT_NAME}
ENV SSH_USER_NAME ${SSH_USER_NAME}
ENV SSH_USER_PASSWORD ${SSH_USER_PASSWORD}
ENV TZ ${TZ}

################################################################################
# Build instructions
################################################################################

# Add custom repository

RUN rm /etc/apt/sources.list
ADD conf/apt/sources.list /etc/apt/sources.list

RUN echo 'Acquire::Queue-Mode "host";' > /etc/apt/apt.conf

RUN apt-get update && \
  apt-get clean && apt-get autoclean && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -yqq \
  build-essential \
  python-dev \
  sudo \
  curl \
  wget \
  apt-transport-https \
  lsb-release \
  ca-certificates \
  dialog \
  apt-utils \
  locales \
  gnupg2 \
  dirmngr \
  zsh

# Add all dependencies's repository

RUN wget -O- https://packages.sury.org/nginx-mainline/apt.gpg | apt-key add - && \
    echo "deb https://packages.sury.org/nginx-mainline/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/nginx.list

RUN curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add - && \
echo 'deb https://deb.nodesource.com/node_10.x stretch main' > /etc/apt/sources.list.d/nodesource.list

# Start build

RUN apt-get clean && apt-get autoclean && \
  apt-get update && \
  DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -yqq \
  htop \
  python-pip \
  openssh-server \
  git \
  git-core \
  nano \
  vim \
  supervisor \
  automake \
  libtool \
  libssl-dev \
  libgss3 \
  libmagickwand-dev \
  openssl \
  nasm

RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -yqq \
  nginx-full

RUN usermod -u 1000 www-data

# Copy our nginx config

RUN rm /etc/nginx/nginx.conf
ADD conf/nginx/nginx.conf /etc/nginx/nginx.conf
RUN rm -rf /etc/nginx/sites-*/
RUN mkdir /etc/nginx/sites-available/ && mkdir /etc/nginx/sites-enabled/

# Create directory for fastCgi caching
RUN mkdir -p /usr/share/nginx/cache/shurl

ADD conf/nginx/sites-available/default.conf /etc/nginx/sites-available/default.conf
RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

##WORKSPACE PROJECT
ADD conf/nginx/sites-available/shurl.conf /etc/nginx/sites-available/shurl.conf

RUN ln -s /etc/nginx/sites-available/shurl.conf /etc/nginx/sites-enabled/shurl.conf


# Nginx site conf
RUN mkdir -p /etc/nginx/ssl/CA/ && \
mkdir -p /etc/nginx/ssl/certs/ && \
mkdir -p /etc/nginx/ssl/config/ && \
rm -Rf /var/www/* && \
mkdir -p /var/www/html/ && \
mkdir -p /var/www/tmp && \
chown -R www-data:www-data /var/www/ && \
chmod a+x /var/www/

# Add SSL Self-Host for nginx
RUN /usr/bin/openssl dhparam -out /etc/nginx/ssl/certs/dhparam.pem 2048

ADD conf/nginx/ssl/config/rootCA.cnf /etc/nginx/ssl/config/rootCA.cnf
ADD conf/nginx/ssl/config/v3.ext /etc/nginx/ssl/config/v3.ext

# Create Root CA Cert and Key for server-side
RUN mkdir -p /etc/nginx/ssl/CA
RUN /usr/bin/openssl genrsa -out /etc/nginx/ssl/CA/rootCA.key 2048
RUN /usr/bin/openssl req -x509 -new -nodes \
    -subj "/C=TH/ST=Somewhere/L=Somehow/O=NoOneLTD/OU=IT Department/CN=NoOneLTD" \
    -key /etc/nginx/ssl/CA/rootCA.key \
    -sha256 -days 3650 -out /etc/nginx/ssl/CA/rootCA.pem

# Create Cert and Key for web server and client side
RUN /usr/bin/openssl req -new -sha256 -nodes \
    -out /etc/nginx/ssl/certs/nginx-selfsigned.csr \
    -newkey rsa:2048 -keyout /etc/nginx/ssl/certs/nginx-selfsigned.key \
    -config /etc/nginx/ssl/config/rootCA.cnf

RUN /usr/bin/openssl x509 -req -in /etc/nginx/ssl/certs/nginx-selfsigned.csr \
    -CA /etc/nginx/ssl/CA/rootCA.pem \
    -CAkey /etc/nginx/ssl/CA/rootCA.key \
    -CAcreateserial -out /etc/nginx/ssl/certs/nginx-selfsigned.crt \
    -days 3650 -sha256 -extfile /etc/nginx/ssl/config/v3.ext


RUN chown www-data:www-data /etc/nginx/ssl/certs/nginx-selfsigned.key && \
    chown www-data:www-data /etc/nginx/ssl/certs/nginx-selfsigned.crt

RUN cp /etc/nginx/ssl/CA/rootCA.pem /usr/local/share/ca-certificates/ && \
    update-ca-certificates

# Config timezone, Localization
RUN echo ${TZ} >> /etc/timezone && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -yqq tzdata && \
    rm /etc/localtime && \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get clean

RUN echo 'en_US ISO-8859-1\nen_US.UTF-8 UTF-8\nth_TH.UTF-8 UTF-8\n' >> /etc/locale.gen &&  \
    /usr/sbin/locale-gen

# Installation nodejs
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -yqq nodejs
RUN npm install -g pm2

# Add supervisor configuration files
ADD conf/supervisor/conf.d/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Add user for ssh
RUN adduser --quiet --disabled-password --shell /bin/bash --home /home/${SSH_USER_NAME} --gecos "Docker ToolBox" ${SSH_USER_NAME} && \
    echo "${SSH_USER_NAME}:${SSH_USER_PASSWORD}" | chpasswd &&\
    echo "${SSH_USER_NAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Allow root login
RUN sed -i \
    -e "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" \
    -e "s/#PasswordAuthentication yes/PasswordAuthentication yes/g" \
    -e "s/#PermitEmptyPasswords no/PermitEmptyPasswords no/g" \
    /etc/ssh/sshd_config

# Config openssd-server
RUN mkdir -p /var/run/sshd

# Oh-My-Zsh
RUN wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O - | zsh || true && chsh -s `which zsh`
RUN sed -i -e "s/ZSH_THEME=\"robbyrussell\"/ZSH_THEME=\"agnoster\"/g"  ~/.zshrc
RUN echo "export PATH=$HOME/bin:/usr/local/bin:$PATH:$HOME/.composer/vendor/bin" >> ~/.zshrc

################################################################################
# Volumes
################################################################################

VOLUME ["/var/www"]

################################################################################
# Entrypoint
################################################################################
CMD []
ENTRYPOINT ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
