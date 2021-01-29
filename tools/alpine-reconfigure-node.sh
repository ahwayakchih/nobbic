#!/bin/sh

# WARNING: This script has to be run as root INSIDE Alpine-based container.
#          It should be run only while preparing image for use in a container(s).
#          It's meant to be run with official Node.js image, and assumes `node` and `npm` are already installed.

set -e

# Update Alpine to latest available for the release
apk update && apk upgrade --available

# Add tools needed to build compiled node modules
apk add --no-cache \
    libstdc++ \
    curl \
    make \
    g++ \
    python2 \
    git

# `bash` for our scripts, `patch` for applying patches, `bind-tools` for dig (to check public IP)
# `jq`  and `git` should already be installed by alpine-get-nodebb-repo.sh script
apk add --no-cache \
    bash \
    patch \
    bind-tools

# Prepare "local" node_modules with proper ownership
mkdir -p /app/node_modules \
    && chmod -R 755 /app \
    && chown -R node:node /app

# Setup global node_modules so `npm -g example-module` works OK
# npm config set prefix '/home/node/.npm-global'\
mkdir /home/node/.npm-global\
    && echo "prefix=/home/node/.npm-global" > /home/node/.npmrc\
    && echo "export PATH=/home/node/.npm-global/bin:\$PATH" > /home/node/.profile

# No need to fight with locks in container
# npm config set package-lock false
echo "package-lock=false" >> /home/node/.npmrc

# Fix ownership
chown node:node /home/node/.npm-global /home/node/.npmrc /home/node/.profile
