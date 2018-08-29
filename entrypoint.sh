#!/bin/bash

#Copy cert file from container to host
cp /etc/nginx/ssl/* /opt/certs

#Start Supervisord
/usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
