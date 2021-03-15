#!/bin/sh

# WARNING: This script has to be run INSIDE container.
#          It's meant to be run by netcat, to handle requests.
#          RESPONSE_CONTENT has to be set to ACCOUNT_THUMBPRINT in environment for script to work as acme-challenge responder.

IFS= read -r -s -n 256 REQUEST

ACTION=${REQUEST%% *}
if [[ "$ACTION" = "GET" ]] ; then
	PATHNAME="${REQUEST#* }"
	PATHNAME="${PATHNAME%% *}"
else
	printf "HTTP/1.1 405 Method Not Allowed\r\nConnection: close\r\n\r\n"
	exit 0
fi

DIR=$(dirname "$PATHNAME")
if [ "$DIR" = '/.well-known/acme-challenge' ] ; then
	NAME=$(basename "$PATHNAME")
	BODY="${NAME}.${RESPONSE_CONTENT:-$ACCOUNT_THUMBPRINT}"
else
	BODY="${RESPONSE_CONTENT:-}"
fi

# Respond with prepared content
printf "HTTP/1.1 200 OK\r\nContent-type: text/plain\r\nConnection: close\r\nContent-Length:${#BODY}\r\n\r\n${BODY}"

# Consume rest of the request, so we do not close connection too early.
while true ; do
	IFS= read -r -s -t 1 REQUEST || exit 0
done
