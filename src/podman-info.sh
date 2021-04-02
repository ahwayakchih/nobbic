#!/bin/bash

if ! podman pod exists ${APP_NAME} &>/dev/null ; then
	echo "ERROR: pod '${APP_NAME}' does not exist" >&2
	return 1
fi

# Prepare toolbox, if it's not ready yet
inline podman-create-nodebb-toolbox.sh || return $?

NODEBB_ENV=$(podman container inspect "${APP_NAME}-nodebb" --format=$'{{range .Config.Env}}{{.}}\n{{end}}' | grep -E "^((NODE(BB)?|APP_USE)_|PORT=)")
PORT=$(echo "$NODEBB_ENV" | grep '^PORT=' | cut -d= -f2 || echo "")
NODE_VERSION=$(echo "$NODEBB_ENV" | grep NODE_VERSION | cut -d= -f2 || echo "")
NODEBB_VERSION=$(echo "$NODEBB_ENV" | grep NODEBB_VERSION | cut -d= -f2 || echo "")
NODEBB_GIT_SHA=$(podman run --rm --volumes-from "${APP_NAME}-nodebb:ro" "localhost/${NODEBB_TOOLBOX_IMAGE}" /bin/sh -c 'cd /app/nodebb && git rev-parse HEAD')
APP_URL=$(podman run --rm --volumes-from "${APP_NAME}-nodebb:ro" "localhost/${NODEBB_TOOLBOX_IMAGE}" jq -r '.url' 'nodebb/config.json' 2>/dev/null || echo "")

APP_USE_CLUSTER=$(printf "${PORT//,/"\n"}\n" | wc -l)

echo "Hosted on "$(source /etc/os-release && echo $PRETTY_NAME)" using Podman v"$(podman version | head -n 1 | tr -d '[:blank:]' | cut -d : -f2)
echo "Available CPU(s): "$(getconf _NPROCESSORS_ONLN || echo 'N/A')
echo -n "NodeBB v${NODEBB_VERSION} is run with Node.js v${NODE_VERSION}"
if [ $APP_USE_CLUSTER -gt 1 ] ; then
	echo " on ${APP_USE_CLUSTER} processes (ports: ${PORT})"
else
	echo " on a single process (port ${PORT})"
fi
echo "NodeBB SHA:${NODEBB_GIT_SHA}"
echo "Built with Nobbic v"$(podman pod inspect "$APP_NAME" --format=$'{{range $key,$value := .Labels}}{{$key}}={{$value}}\n{{end}}' | grep "$__LABEL" | cut -d= -f2 || echo "unknown")
echo "It uses:"

for container in $(podman pod inspect "$APP_NAME" --format=$'{{range .Containers}}{{.Name}}\n{{end}}' | grep "^${APP_NAME}-") ; do
	name=${container/$APP_NAME-/}
	image=$(podman container inspect "$container" --format='{{.ImageName}}' || echo "")

	echo "- $name ($image)"
	echo "  with "$(podman container inspect "$container" --format=$'{{range .Config.Env}}{{.}}\n{{end}}' | grep '_VERSION' | xargs echo || echo "")
done

if [ -n "$APP_URL" ] ; then
	isRunning=$(podman pod ps --filter status=running --filter name="$APP_NAME" -q)
	if test $isRunning ; then
		echo -n "Awaits "
	else
		echo -n "When started, it will await "
	fi
	echo "connections at ${APP_URL}"
else
	echo "When NodeBB setup succeeds, call info again to see URL at which it awaits for connections."
fi