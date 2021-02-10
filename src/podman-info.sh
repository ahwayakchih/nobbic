#!/bin/bash

if ! podman pod exists ${APP_NAME} &>/dev/null ; then
	echo "ERROR: pod '${APP_NAME}' does not exist" >&2
	return 1
fi

NODEBB_ENV=$(podman container inspect "${APP_NAME}-nodebb" --format='{{range .Config.Env}}{{.}}\n{{end}}' | grep -E "^(NODE(BB)?|APP_USE)_")
NODE_VERSION=$(echo "$NODEBB_ENV" | grep NODE_VERSION | cut -d= -f2 || echo "")
NODEBB_VERSION=$(echo "$NODEBB_ENV" | grep NODEBB_VERSION | cut -d= -f2 || echo "")
NODEBB_PORT=$(echo "$NODEBB_ENV" | grep -E "^APP_USE_PORT=" | cut -d= -f2 || echo "")
NODEBB_FQDN=$(echo "$NODEBB_ENV" | grep -E "^APP_USE_FQDN=" | cut -d= -f2 || echo "")
NODEBB_GIT_SHA=$(podman run --rm --volumes-from "${APP_NAME}-nodebb:ro" "nodebb-node:${NODE_VERSION}" /bin/sh -c 'cd /app/nodebb && git rev-parse HEAD')

echo "Hosted on "$(source /etc/os-release && echo $PRETTY_NAME)" using Podman v"$(podman version | head -n 1 | tr -d '[:blank:]' | cut -d : -f2)
echo "NodeBB v${NODEBB_VERSION} is run with Node.js v${NODE_VERSION}"
echo "NodeBB SHA:${NODEBB_GIT_SHA}"
echo "Built with Containerized-NodeBB v"$(podman pod inspect "$APP_NAME" --format='{{range $key,$value := .Labels}}{{$key}}={{$value}}\n{{end}}' | grep "$__LABEL" | cut -d= -f2 || echo "unknown")
echo "It uses:"

for container in $(podman pod inspect "$APP_NAME" --format='{{range .Containers}}{{.Name}}\n{{end}}' | grep "^${APP_NAME}-") ; do
	name=${container/$APP_NAME-/}
	image=$(podman container inspect "$container" --format='{{.ImageName}}' || echo "")

	echo "- $name ($image)"
	echo "  with "$(podman container inspect "$container" --format='{{range .Config.Env}}{{.}}\n{{end}}' | grep '_VERSION' | xargs echo)
done

isRunning=$(podman pod ps --filter status=running --filter name="$APP_NAME" -q)
if test $isRunning ; then
	echo -n "Awaits "
else
	echo -n "When started, it will await "
fi
# TODO: check if gateway uses SSL or not
echo "connections at https://${NODEBB_FQDN}:${NODEBB_PORT}"
