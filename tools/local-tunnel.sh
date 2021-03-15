#!/bin/sh

# WARNING: This script has to be run INSIDE container.
#          It's meant to start basic server that responds with the same content to every request.

set -e

FROM_PORT=${1:-80}
TO_PORT=${2:-8080}
TUNNEL_PID=
QUIT="0"

trap 'QUIT="1"; [ -n "$TUNNEL_PID" ] && kill -9 "$TUNNEL_PID"' INT TERM

debug() {
	test -n "$DEBUG" && echo "$*" || true
}

echo "Starting tunnel from port ${FROM_PORT} to port ${TO_PORT}"
while [ "$QUIT" = "0" ] ; do
	nc -l -p ${FROM_PORT} -e "/usr/bin/nc 127.0.0.1 ${TO_PORT}" &
	TUNNEL_PID=$!
	debug "tunnel PID: $TUNNEL_PID"
	wait $TUNNEL_PID
done
