#!/bin/bash
set -e

pushd . > /dev/null
cd /src
. jmvenv/bin/activate
popd > /dev/null

exec "$@"



