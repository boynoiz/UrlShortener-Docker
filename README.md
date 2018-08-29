
# UrlShortener-Docker

  

This repository is Docker for development [UrlShortener](https://github.com/boynoiz/UrlShortener) Support Nodejs 10.x and MongoDB

  

## Usage

  

### Build Container

  

First clone this repository anywhere on your machine

  

```sh

$ git clone https://github.com/boynoiz/UrlShortener-Docker

$ cd UrlShortener-Docker

$ copy .env-example .env

```

Change variable in .env

  

```

APP_PROJECT_NAME=localhost

APP_PROJECT_URL=local.host // Only domain without www or http://

APP_PROJECT_NGINX_SERVER_NAME=local.host www.local.host api.local.host // Add many as you want, separate with space

APP_SSH_USER_NAME=username

APP_SSH_USER_PASSWORD=password  

APP_TZ=Asia/Bangkok

APP_DB_USER=root

APP_DB_PASSWORD=secret

```

  

Then build up a container

  

```sh

$ docker-compose build

```

  

Wait for a few minute util docker-compose finished then

  

```sh

$ docker-compose up

```

Edit your ```hosts``` file like this
```
10.0.75.1 local.host www.local.host api.local.host
```  

Your workspace is inside of  ```webroot``` directory 

  

### SSL

  

There are also generating self-signed ssl certificate and copy .crt file to ```certs``` directory so you can import .crt file in the browser for trust the certificate

License

----

  

MIT
