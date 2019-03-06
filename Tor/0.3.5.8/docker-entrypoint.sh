#!/bin/sh
set -e

exec gosu tor "$@"
