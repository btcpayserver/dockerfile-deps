#!/bin/bash

echo "$(/sbin/ip route|awk '/default/ { print $3 }')  host.docker.internal" >> /etc/hosts

exec cloudflared --no-autoupdate "$@"
