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

# Prepare "local" node_modules with proper ownership
mkdir -p /app/node_modules \
    && chmod -R 755 /app \
    && chown -R node:node /app

# Switch to `node` user
su node

# No need to fight with locks in container
npm config set package-lock false

# Setup global node_modules so `npm -g example-module` works OK
mkdir ~/.npm-global\
	&& npm config set prefix '~/.npm-global'\
	&& echo "export PATH=~/.npm-global/bin:\$PATH" > ~/.profile
