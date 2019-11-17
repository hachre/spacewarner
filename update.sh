#!/bin/bash

set -e

cd $(dirname $0)
git reset --hard
git pull
chmod a+x *.sh