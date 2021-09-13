#!/bin/bash
set -e

cd ..
. jmvenv/bin/activate
cd scripts

exec "$@"
