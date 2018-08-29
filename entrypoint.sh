#!/bin/bash

#Copy cert file to host
cp /etc/nginx/ssl/* /opt/certs

#Star Supervisord
/usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
