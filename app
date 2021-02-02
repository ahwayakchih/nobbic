#!/bin/bash

action=$1
__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/tools/common.sh

export CONTAINERIZED_NODEBB_VERSION=0.5.0
export CONTAINERIZED_NODEBB_LABEL=containerized.nodebb

export PODMAN_ARG_LABEL="--label ${CONTAINERIZED_NODEBB_LABEL}=${CONTAINERIZED_NODEBB_VERSION}"
export PODMAN_CREATE_ARGS="$PODMAN_ARG_LABEL $PODMAN_CREATE_ARGS"

#
# @param {string} appName
#
function sanitizeAppName () {
	local appName=$1

	if [ -z "$appName" ] ; then
		echo "WARNING: No application name was specified, using 'nodebb' as default" >&2
		appName="nodebb"
	fi

	echo "${appName}" | tr "[:blank:]" "_"
}

function showHelp () {
	echo "Usage: app [action]"
	echo ""
	echo "Supported actions are:"
	echo "help - show this info"
	echo "build APP_NAME  - build pod with specified name"
	echo "info APP_NAME   - get information about application's setup"
	echo "start APP_NAME  - start pod (build it if none exists) with specified name"
	echo "bash APP_NAME   - enter bash command line inside NodeBB container"
	echo "exec APP_NAME COMMAND [ARG...]  - run command inside NodeBB container"
	echo "backup APP_NAME [BACKUPS_DIR] [BACKUP_NAME] - create a backup containing data and setup info"
	echo "upgrade APP_NAME - upgrade NodeBB version"
	echo "restore APP_NAME [BACKUPS_DIR] [BACKUP_NAME] - restore from a previously created backup"
	echo "stop APP_NAME   - stop pod"
	echo "remove APP_NAME - stop pod, remove its containers and their data, remove the pod itself"
	echo "cleanup [nodebb|node|repo] - remove all pods, containers and images built for NodeBB containers, removing 'node' images, will also remove all nodebb images. 'repo' removes only the image used for downloading repo"
	echo ""
	echo "When building, you can specify database images to use for pod containers by setting environment variables:"
	echo "APP_ADD_MONGODB  - set it to 1 to use default 'bionic' image, or set image name, e.g., docker.io/mongo:4.4.2-bionic"
	echo "APP_ADD_POSTGRES - set it to 1 to use default 'alpine' image, or set image name, e.g., docker.io/postgres:13.1-alpine"
	echo "APP_ADD_REDIS    - set it to 1 to use default 'alpine3.12' image, or set image name, e.g., docker.io/redis:6.0.9-alpine"
	echo "You can specify two: one of MongoDB or PostgreSQL and Redis, to make NodeBB use Redis for session storage only."
	echo "Keep in mind that support for PostgreSQL was added in v1.10.x."
	echo ""
	echo "Similarly you can add local NPM mirror, which may be helpful when you're testing various configurations, or simply running more than one forum:"
	echo "APP_ADD_NPM      - set it to 1 to use default 'verdaccio/verdaccio:latest' image, or set image name, e.g., docker.io/verdaccio/verdaccio:5.x"
	echo ""
	echo "By default, official 'docker.io/node:NODE_VERSION-alpine' image will be used for NodeBB."
	echo "You can change that by specifying APP_ADD_NODEBB environment variable with value like 'some.repo/image:%NODE_VERSION%'."
	echo "'%%' placeholder will be replaced by NODE_VERSION value (either specified, or detected for selected NodeBB version)."
	echo ""
	echo "If placeholder is missing from image name, nothing ill be replaced, so better make sure that image contains Node.js version that will work with NodeBB".
	echo "You can set NODEBB_VERSION to select which version of the forum to run. By default, latest release will be used."
	echo "By default, 'nodebb-repo' name will be used for volume containing clone of NodeBB git repository. It will be shared by all apps (DO NOT create/restore/upgrade them concurrently!)."
	echo "You can create separate volume for application by setting NODEBB_REPO_VOLUME environment variable with some unique name as its value."
	echo ""
	echo "Set NODEBB_GIT to URL of git repository of NodeBB forum."
	echo "Official repo will be used by default, but you can specify other, e.g., with your custom modifications."
	echo "It just has to follow example of official repo and create tag per released version."
	echo ""
	echo "By default, forum will be run with Node.js version specified in the 'package.json' file."
	echo "You can enforce different version by setting NODE_VERSION environment variable."
	echo ""
	echo "You can set also APP_USE_PORT (http/https, defaults to 4567) value to port numbers you want the pod to listen to."
	echo ""
	echo "For example: APP_USE_FQDN=localhost APP_ADD_MONGODB=1 ./app start my-forum"
	echo "It will create pod that includes MongoDB based on Ubuntu bionic (default) and NodeBB latest (default), and then run it with minimum required Node.js version for that NodeBB."
	echo ""
	echo "Another example: NODEBB_VERSION=1.12.1 APP_USE_FQDN=localhost APP_ADD_POSTGRES=1 ./app start my-forum"
	echo "It will create pod with NodeBB v1.12.1 that uses PostgreSQL as database engine and sets its URL to localhost:4567 (default port) and websockets to localhost:4567 (default)"
	echo ""
	echo "Before container is created, specified (or default) images are pulled from repository (check: podman pull --help). You can pass additional arguments to pull command through environment variables:"
	echo "PODMAN_PULL_ARGS_MONGODB variable is used when pulling image for MongoDB database container,"
	echo "PODMAN_PULL_ARGS_POSTGRES variable is used when pulling image for PostgreSQL database container,"
	echo "PODMAN_PULL_ARGS_REDIS variable is used when pulling image for Redis database container."
	echo "PODMAN_PULL_ARGS_NPM variable is used when pulling image for NPM mirror container."
	echo ""
	echo "You can set any additional environment variables for specific containers using CONTAINER_ENV_ prefix."
	echo "CONTAINER_ENV_NODE_* variables will be set as NODE_* in nodebb container."
	echo "CONTAINER_ENV_NODEBB_* variables will be set as * in nodebb container."
	echo "CONTAINER_ENV_MONGODB_* variables will be set as * in mongodb container."
	echo "CONTAINER_ENV_POSTGRES_* variables will be set as POSTGRES_* in postgres container."
	echo "CONTAINER_ENV_PG_* variables will be set as PG* in postgres container."
	echo "CONTAINER_ENV_REDIS_* variables will be set as * in redis container."
	echo "CONTAINER_ENV_NPM_* variables will be set as * in npm container."
	echo ""
	echo "You can pass additional arguments to podman commands used for creation of containers (check: podman create --help) through separate environment variables:"
	echo "PODMAN_CREATE_ARGS_NODEBB variable for NodeBB container,"
	echo "PODMAN_CREATE_ARGS_MONGODB variable for MongoDB database container,"
	echo "PODMAN_CREATE_ARGS_POSTGRES variable for PostgreSQL database container,"
	echo "PODMAN_CREATE_ARGS_REDIS variable for Redis database container."
	echo "PODMAN_CREATE_ARGS_NPM variable for NPM mirror container."
	echo "You can also set PODMAN_CREATE_ARGS environment variable, to pass the same additional arguments to all podman create commands."
	echo ""
	echo "When container is created, its port number is automaticaly read from image. In case of more than one port being exposed by that image, you can override its value through environment variable:"
	echo "CONTAINER_MONGODB_PORT for MongoDB container,"
	echo "CONTAINER_POSTGRES_PORT for PostgreSQL container,"
	echo "CONTAINER_REDIS_PORT for Redis container."
	echo "CONTAINER_NPM_PORT for NPM container."
	echo ""
}

#
# @param {string} podName
# @param {string} fromName   full script path or repo/image name
# @param {string} toolPath   path to default script to use, if image is not a script path
#
addToPod() {
	local podName=$1
	local fromName=$2
	local toolPath=$3

	local options="POD=$podName"
	if [ ! -z "$RESTORE_FROM" ] && [ -d "$RESTORE_FROM" ]; then
		options="$options RESTORE_FROM=${RESTORE_FROM}"
	fi

	case "$fromName" in
		1) env $(echo "$options" | xargs) "$toolPath";;
		./*|/*) if [ -f "$fromName" ] ; then env $(echo "$options" | xargs) "$fromName"; else echo "'$fromName' script not found">&2; fi ;;
		*) env $(echo "$options FROM_IMAGE=$fromName" | xargs) "$toolPath";;
	esac
}

#
# @param {string} podName
#
function infoPod () {
	local podName=$1

	if [ -z "$podName" ] ; then
		echo "ERROR: missing pod name" >&2
		return 1
	fi

	APP_NAME="$podName" "${__DIRNAME}/tools/podman-info.sh" || return 1
}

#
# @param {string} podName
#
function buildPod () {
	local podName=$1
	local nodebbOptions=""

	if [ -z "$podName" ] ; then
		echo "ERROR: missing pod name" >&2
		return 1
	fi

	if [ -z "$APP_ADD_MONGODB" ] && [ -z "$APP_ADD_REDIS" ] && [ -z "$APP_ADD_POSTGRES" ] ; then
		echo "WARNING: building without database container" >&2
		echo "         Set APP_ADD_MONGODB, APP_ADD_REDIS and/or APP_ADD_POSTGRES in environment" >&2
		# echo "         or specify database access info when running the pod" >&2
	fi

	echo "Building '$podName' pod..."

	local podOptions=""

	local port=${APP_USE_PORT:-8080}
	local nodebbPort=4567
	if [ -n "$NODEBB_CLUSTER" ] && [ "$NODEBB_CLUSTER" -gt 1 ] ; then
		local nodebbEnvPort=""
		for ((n=0;n<$NODEBB_CLUSTER;n++)); do
			podOptions="$podOptions -p $port:$nodebbPort"
			if [ -z "$nodebbEnvPort" ] ; then
				nodebbEnvPort="$nodebbPort"
			else
				nodebbEnvPort="${nodebbEnvPort},${nodebbPort}"
			fi
			port=$(($port + 1))
			nodebbPort=$(($nodebbPort + 1))
		done
		export CONTAINER_ENV_NODEBB_PORT=${CONTAINER_ENV_NODEBB_PORT:-"[${nodebbEnvPort}]"}
		export CONTAINER_ENV_NODEBB_APP_USE_PORT=${CONTAINER_ENV_NODEBB_APP_USE_PORT:-${APP_USE_PORT:-8080}}
	else
		podOptions="$podOptions -p $port:$nodebbPort"
		export CONTAINER_ENV_NODEBB_PORT=${CONTAINER_ENV_NODEBB_PORT:-$nodebbPort}
		export CONTAINER_ENV_NODEBB_APP_USE_PORT=${CONTAINER_ENV_NODEBB_APP_USE_PORT:-${APP_USE_PORT:-8080}}
	fi

	podman pod create -n "$podName" $podOptions \
		$PODMAN_ARG_LABEL \
		--add-host=localhost:127.0.0.1 --hostname="$podName" || return 1

	# Add "data" container, to be shared by database, nodebb, etc...
	# podman create --pod "$podName" --name "${podName}-data" -v /data docker.io/busybox:musl || return 1

	if [ ! -z "$APP_ADD_MONGODB" ] ; then
		addNodeBBOptions=$(addToPod "$podName" $APP_ADD_MONGODB "${__DIRNAME}/tools/podman-add-mongodb.sh")
		if [ -z "$addNodeBBOptions" ] ; then
			return 1
		fi
		nodebbOptions="$nodebbOptions $addNodeBBOptions"
	fi

	if [ ! -z "$APP_ADD_REDIS" ] ; then
		addNodeBBOptions=$(addToPod "$podName" $APP_ADD_REDIS "${__DIRNAME}/tools/podman-add-redis.sh")
		if [ -z "$addNodeBBOptions" ] ; then
			return 1
		fi
		nodebbOptions="$nodebbOptions $addNodeBBOptions"
	fi

	if [ ! -z "$APP_ADD_POSTGRES" ] ; then
		addNodeBBOptions=$(addToPod "$podName" $APP_ADD_POSTGRES "${__DIRNAME}/tools/podman-add-postgres.sh")
		if [ -z "$addNodeBBOptions" ] ; then
			return 1
		fi
		nodebbOptions="$nodebbOptions $addNodeBBOptions"
	fi

	if [ ! -z "$APP_ADD_NPM" ] ; then
		addNodeBBOptions=$(addToPod "$podName" $APP_ADD_NPM "${__DIRNAME}/tools/podman-add-npm.sh")
		if [ -z "$addNodeBBOptions" ] ; then
			return 1
		fi
		nodebbOptions="$nodebbOptions $addNodeBBOptions"
	fi

	export PODMAN_CREATE_ARGS_NODEBB="$PODMAN_CREATE_ARGS_NODEBB $nodebbOptions"
	addToPod "$podName" ${APP_ADD_NODEBB:-1} "${__DIRNAME}/tools/podman-add-nodebb.sh" || return 1
}

#
# @param {string} podName
#
function startPod () {
	local podName=$1

	if [ -z "$podName" ] ; then
		echo "ERROR: missing pod name" >&2
		return 1
	fi

	local existed=$(podman pod exists "$podName" && echo exists);
	test "$existed" || buildPod "$podName" || return 1

	if test "$existed" ; then
		echo "Restarting '$podName' pod..."
		podman pod start "$podName" || return 1
		# Use `restart` right after `start` because of ports not being accessible from outside after stop+start.
		# See: https://github.com/containers/podman/issues/7103 - issue is closed, but on Arch with podman v2.2.1
		# and cgroups v1 problem seems to still exist. With cgroups v2 it works ok.
		# podman pod restart "$podName" || return 1
		(
			WAIT_FOR_PORT=$(podman container inspect "${podName}-nodebb" --format="{{range .Config.Env}}{{.}}\n{{end}}" | grep -E '^PORT=' | cut -d= -f2)
			echo "Waiting for $podName port $WAIT_FOR_PORT to be ready inside container"
			podman exec "${podName}-nodebb" /app/.container/tools/wait-for.sh 127.0.0.1:$WAIT_FOR_PORT -t 120 -l || exit 1
			sleep 1
			WAIT_FOR_PORT=$(podman container inspect "${podName}-nodebb" --format="{{range .Config.Env}}{{.}}\n{{end}}" | grep -E '^APP_USE_PORT=' | cut -d= -f2)
			echo "Waiting for $podName port $WAIT_FOR_PORT to be accessible from outside of container"
			${__DIRNAME}/.container/tools/wait-for.sh localhost:${WAIT_FOR_PORT} -t 20 -l && echo "NodeBB should be accessible now" && exit 0
			echo "WARNING: Looks like podman on this system is buggy and needs restart, not just start. Restarting..."
			podman pod restart "$podName"
			# TODO: reattach to nodebb stdout?
		)&
	else
		echo "Starting '$podName' pod..."
		podman pod start "$podName" || return 1
	fi

	podman attach --no-stdin --sig-proxy=false "${podName}-nodebb" || return 0
}

#
# @param {string} podName
#
function enterBash () {
	local podName=$1

	if [ -z "$podName" ] ; then
		echo "ERROR: missing pod name" >&2
		return 1
	fi

	if ! podman pod exists "$podName" ; then
		echo "ERROR: could not find pod '$podName'" >&2
		return 1
	fi

	podman exec -it ${podName}-nodebb /bin/bash || return $?
}

#
# @param {string} podName
# @param {string} command
# @param {string} arg...
#
function runCommand () {
	local podName=$1

	if [ -z "$podName" ] ; then
		echo "ERROR: missing pod name" >&2
		return 1
	fi

	if ! podman pod exists "$podName" ; then
		echo "ERROR: could not find pod '$podName'" >&2
		return 1
	fi

	podman exec ${podName}-nodebb /bin/bash -c "source .container/lib/onbb_utils.sh; $(shift 1; echo $@)" || return $?
}

#
# @param {string} podName
# @param {string} backupsDir
# @param {string} backupName
#
function backupPod () {
	local podName=$1
	local backupDir=$2
	local backupName=$3

	if [ -z "$podName" ] ; then
		echo "ERROR: missing pod name" >&2
		return 1
	fi

	APP_NAME="$podName" BACKUPS_DIR="$backupDir" BACKUP_NAME="$backupName" "${__DIRNAME}/tools/podman-backup.sh" || return 1
}

#
# @param {string} podName
#
function upgradePod () {
	local podName=$1

	if [ -z "$podName" ] ; then
		echo "ERROR: missing pod name" >&2
		return 1
	fi

	APP_NAME="$podName" "${__DIRNAME}/tools/podman-upgrade.sh" || return 1
}

#
# @param {string} podName
# @param {string} backupsDir
# @param {string} backupName
#
function restorePod () {
	local podName=$1
	local backupDir=$2
	local backupName=$3

	if [ -z "$podName" ] ; then
		echo "ERROR: missing pod name" >&2
		return 1
	fi

	APP_NAME="$podName" BACKUPS_DIR="$backupDir" BACKUP_NAME="$backupName" "${__DIRNAME}/tools/podman-restore.sh" || return 1
}

#
# @param {string} podName
#
function stopPod () {
	local podName=$1

	if [ -z "$podName" ] ; then
		echo "ERROR: missing pod name" >&2
		return 1
	fi

	local isRunning=$(podman ps --filter status=running --filter name='^'$podName'-nodebb$' -q)
	if [ ! -z "$isRunning" ] ; then
		# Try to prevent possible errors, by stopping NodeBB first
		echo -n "Stopping NodeBB of '$podName' pod... "
		(podman stop -t 10 ${podName}-nodebb >/dev/null && echo "OK") || echo "Failed"
	fi

	echo "Stopping '$podName' pod..."
	podman pod stop -t 10 "$podName" || return 1
}

#
# @param {string} podName
#
function removePod () {
	local podName=$1

	if [ -z "$podName" ] ; then
		echo "ERROR: missing pod name" >&2
		return 1
	fi

	stopPod $podName || return 1

	echo "Removing '$podName' pod..."
	podman pod rm "$podName" || return 1
}

#
# @param {string} imageType
#
function cleanupImages () {
	local imageType=$1

	if [ -z "$imageType" ] ; then
		echo "ERROR: missing which images to remove" >&2
		return 1
	fi

	# Remove all pods first
	for pod in $(podman pod ls --filter label="$CONTAINERIZED_NODEBB_LABEL" --format '{{.Name}}') ; do
		removePod "$pod"
	done

	if [ "$imageType" = "repo" ] ; then
		# Select only repo downloader image and repo volume
		podman images --format "{{.Repository}}:{{.Tag}}" | grep localhost/nodebb-repo | xargs podman rmi -f
		podman volume rm nodebb-repo
		return 0
	fi

	if [ "$imageType" = "nodebb" ] ; then
		# Select only nodebb images, not nodebb-node
		podman images --format "{{.Repository}}:{{.Tag}}" | grep localhost/nodebb | grep -v localhost/nodebb- | xargs podman rmi -f
		return 0
	fi

	# Both `nodebb` and `node` remove NodeBB images
	podman images --format "{{.Repository}}:{{.Tag}}" | grep localhost/nodebb | xargs podman rmi -f
	return 0
}


if [ -z "$action" ] || [ "$action" = "help" ] ; then
	showHelp
	exit 0
fi

if [ "$action" = "build" ] ; then
	buildPod $(sanitizeAppName $2) || exit 1
	exit 0
fi

if [ "$action" = "info" ] ; then
	infoPod $(sanitizeAppName $2) || exit 1
	exit 0
fi

if [ "$action" = "start" ] ; then
	startPod $(sanitizeAppName $2) || exit 1
	exit 0
fi

if [ "$action" = "bash" ] ; then
	enterBash $(sanitizeAppName $2) || exit $?
	exit 0
fi

if [ "$action" = "exec" ] ; then
	runCommand $(sanitizeAppName $2) $(shift 2; echo $@) || exit $?
	exit 0
fi

if [ "$action" = "backup" ] ; then
	backupPod $(sanitizeAppName $2) "$3" "$4" || exit 1
	exit 0
fi

if [ "$action" = "upgrade" ] ; then
	upgradePod $(sanitizeAppName $2) || exit 1
	exit 0
fi

if [ "$action" = "restore" ] ; then
	restorePod $(sanitizeAppName $2) "$3" "$4" || exit 1
	exit 0
fi

if [ "$action" = "stop" ] ; then
	stopPod $(sanitizeAppName $2) || exit 1
	exit 0
fi

if [ "$action" = "remove" ] ; then
	removePod $(sanitizeAppName $2) || exit 1
	exit 0
fi

if [ "$action" = "cleanup" ] ; then
	cleanupImages $2 || exit 1
	exit 0
fi

echo "ERROR: unrecognized action '$action'" >&2
showHelp
exit 1
