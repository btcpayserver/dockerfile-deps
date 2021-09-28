#!/bin/bash

touch /tmp/stop
pkill python
while ! [ -f "/tmp/stopped" ]; do
    sleep 1
done