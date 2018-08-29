################################################################################
# Base image
################################################################################

FROM debian:stretch-slim

LABEL maintainer="Pathompong Pechkongtong <boynoiz [at] gmail.com>"

ARG PROJECT_NAME
ARG PROJECT_URL
ARG PROJECT_NGINX_SERVER_NAME
ARG SSH_USER_NAME
ARG SSH_USER_PASSWORD
ARG TZ

ENV PROJECT_NAME ${PROJECT_NAME}
ENV PROJECT_URL ${PROJECT_URL}
ENV PROJECT_NGINX_SERVER_NAME ${PROJECT_NGINX_SERVER_NAME}
ENV SSH_USER_NAME ${SSH_USER_NAME}
ENV SSH_USER_PASSWORD ${SSH_USER_PASSWORD}
ENV TZ ${TZ}

################################################################################
# Build instructions
################################################################################
SHELL ["/bin/bash", "-c"]
# Add custom repository

RUN echo ${PROJECT_NAME}

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
  openssh-server \
  git \
  git-core \
  nano \
  supervisor \
  automake \
  libtool \
  libssl-dev \
  libgss3 \
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
RUN mkdir -p /usr/share/nginx/cache

ADD conf/nginx/sites-available/default.conf /etc/nginx/sites-available/default.conf
RUN ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf

##WORKSPACE PROJECT
ADD conf/nginx/sites-available/PROJECT_NAME.conf /etc/nginx/sites-available/${PROJECT_NAME}.conf
RUN sed -i \
        -e "s/#{PROJECT_NAME}/${PROJECT_NAME}/g" \
        -e "s/#{PROJECT_URL}/${PROJECT_URL}/g" \
        -e "s/#{PROJECT_NGINX_SERVER_NAME}/${PROJECT_NGINX_SERVER_NAME}/g" \
        /etc/nginx/sites-available/${PROJECT_NAME}.conf

RUN ln -s /etc/nginx/sites-available/${PROJECT_NAME}.conf /etc/nginx/sites-enabled/${PROJECT_NAME}.conf

# Prepare
RUN mkdir -p /etc/nginx/ssl && \
rm -Rf /var/www/* && \
mkdir -p /var/www/html/ && \
mkdir -p /var/www/tmp && \
chown -R www-data:www-data /var/www/ && \
chmod a+x /var/www/

# Add SSL Self-Host for nginx
RUN /usr/bin/openssl dhparam -out /etc/nginx/ssl/dhparam.pem 2048

# Create Root CA Cert and Key
RUN /usr/bin/openssl genrsa -out /etc/nginx/ssl/rootCA.key 2048

RUN /usr/bin/openssl req \
  -newkey rsa:2048 \
  -x509 \
  -nodes \
  -keyout /etc/nginx/ssl/${PROJECT_URL}.key \
  -new \
  -out /etc/nginx/ssl/${PROJECT_URL}.crt \
  -subj "/C=US/ST=Distributed/L=Cloud/O=Cluster/CN=\*.${PROJECT_URL}" \
  -reqexts SAN \
  -extensions SAN \
  -config  \
  <(cat /etc/ssl/openssl.cnf <(printf "[SAN]\nsubjectAltName=DNS.1:${PROJECT_URL},DNS.2:\*.${PROJECT_URL}")) \
  -sha256 \
  -days 3650

# Config timezone, Localization
RUN echo ${TZ} >> /etc/timezone && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -yqq tzdata && \
    rm /etc/localtime && \
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    dpkg-reconfigure -f noninteractive tzdata && \
    apt-get clean

RUN echo -e "en_US ISO-8859-1\nen_US.UTF-8 UTF-8\nth_TH.UTF-8 UTF-8\n" >> /etc/locale.gen &&  \
    /usr/sbin/locale-gen

# Installation nodejs
RUN DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends --no-install-suggests -yqq nodejs
RUN npm install -g pm2

# Add supervisor configuration files
ADD conf/supervisor/conf.d/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
ADD entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

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

VOLUME ["/var/www", "/opt/certs"]

################################################################################
# Entrypoint
################################################################################
CMD []
ENTRYPOINT ["/opt/entrypoint.sh"]
