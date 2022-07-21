#!/bin/bash

nano version.txt
version=$(cat version.txt | head -n 1)
sed -i '/# Version/c\# Version: '"${version}" spacewarner.sh
source /usr/local/hachre/aliases/source/aliases.sh || source ~/.local/hachre/aliases/source/aliases.sh
gitit
git push
