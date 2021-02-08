#!/bin/sh

# WARNING: This script has to be run as root INSIDE Alpine-based container.
#          It should be run only while preparing image for use in a container(s).

set -e

# Exit early, if locale works OK
locale -a 2>/dev/null && exit 0

# Try to install from repo first
apk add --no-cache musl-locales && locale -a && exit 0 || true

# Add dependencies
apk add --no-cache libintl

# Add tools needed to build musl-locale
apk add --no-cache --virtual .build-deps cmake make musl-dev gcc gettext-dev

# Download and build musl-locale
# Based on https://grrr.tech/posts/2020/add-locales-to-alpine-linux-docker-image/
# To have all locales working OK, be sure to set MUSL_LOCPATH to "/usr/share/i18n/locales/musl" in the environment!
wget https://gitlab.com/rilian-la-te/musl-locales/-/archive/master/musl-locales-master.zip\
    && unzip musl-locales-master\
    && cd musl-locales-master\
    && (cmake -DLOCALE_PROFILE=OFF -D CMAKE_INSTALL_PREFIX:PATH=/usr . && make && make install)\
    && cd .. && rm -r musl-locales-master && rm musl-locales-master.zip\
    && apk del --no-network .build-deps\
    && locale -a
