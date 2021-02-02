#!/bin/bash

# WARNING: This script has to be run OUTSIDE of container.
#          It's meant to get info about Node.js and NodeBB version, what is used, etc...

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh
__APP=$(dirname "$__DIRNAME")"/app"

if [ -z "$APP_NAME" ] ; then
    echo "ERROR: APP_NAME must be specified" >&2
    exit 1
fi

if ! podman pod exists ${APP_NAME} ; then
	echo "ERROR: pod '${APP_NAME}' does not exist" >&2
	exit 1
fi

NODEBB_ENV=$(podman inspect "${APP_NAME}-nodebb" --format='{{range .Config.Env}}{{.}}\n{{end}}' | grep -E "(NODE(BB)?_)")
NODE_VERSION=$(echo "$NODEBB_ENV" | grep NODE_VERSION | cut -d= -f2 || echo "")
NODEBB_VERSION=$(echo "$NODEBB_ENV" | grep NODEBB_VERSION | cut -d= -f2 || echo "")

echo "NodeBB v${NODEBB_VERSION} is run with Node.js v${NODE_VERSION}"
echo "Built with Containerized-NodeBB v"$(podman pod inspect "$APP_NAME" --format='{{range $key,$value := .Labels}}{{$key}}={{$value}}\n{{end}}' | grep "$CONTAINERIZED_NODEBB_LABEL" | cut -d= -f2 || echo "unknown")
echo "It uses:"

for container in $(podman pod inspect "$APP_NAME" --format='{{range .Containers}}{{.Name}}\n{{end}}' | grep "^${APP_NAME}-") ; do
	name=${container/$APP_NAME-/}
	image=$(podman container inspect "$container" --format='{{.ImageName}}' || echo "")

	echo "- $name ($image)"
done

# isRunning=$(podman pod ps --filter status=running --filter name="$APP_NAME" -q)

