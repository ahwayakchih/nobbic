#!/bin/bash

action=$1
__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/tools/common.sh

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
	echo "start APP_NAME  - start pod (build it if none exists) with specified name"
	echo "backup APP_NAME [BACKUPS_DIR] [BACKUP_NAME] - create a backup containing data and setup info"
	echo "upgrade APP_NAME - upgrade NodeBB version"
	echo "restore APP_NAME [BACKUPS_DIR] [BACKUP_NAME] - restore from a previously created backup"
	echo "stop APP_NAME   - stop pod"
	echo "remove APP_NAME - stop pod, remove its containers and their data, remove the pod itself"
	echo ""
	echo "When building, you can specify database images to use for pod containers by setting environment variables:"
	echo "APP_ADD_MONGODB  - set it to 1 to use default 'bionic' image, or set image name, e.g., docker.io/mongo:4.4.2-bionic"
	echo "APP_ADD_POSTGRES - set it to 1 to use default 'alpine' image, or set image name, e.g., docker.io/postgres:13.1-alpine"
	echo "APP_ADD_REDIS    - set it to 1 to use default 'alpine3.12' image, or set image name, e.g., docker.io/redis:6.0.9-alpine"
	echo "You can specify two: one of MongoDB or PostgreSQL and Redis, to make NodeBB use Redis for session storage only."
	echo "Keep in mind that support for PostgreSQL was added in v1.10.x."
	echo ""
	echo "You can set NODEBB_VERSION to select which version of the forum to run. By default, latest release will be used."
	echo ""
	echo "Set NODEBB_GIT to URL of git repository of NodeBB forum."
	echo "Official repo will be used by default, but you can specify other, e.g., with your custom modifications."
	echo "It just has to follow example of official repo and create tag per released version."
	echo ""
	echo "By default, forum will be run with Node.js version specified in the 'package.json' file."
	echo "You can enforce different version by setting NODE_VERSION environment variable."
	echo ""
	echo "You can set also CONTAINER_NODEJS_PORT and CONTAINER_WEBSOCKET_PORT values to port numbers you want pod to listen to."
	echo "They both default to 8080."
	echo ""
	echo "For example: CONTAINER_APP_DNS_ALIAS=localhost APP_ADD_MONGODB=1 ./app start my-forum"
	echo "It will create pod that includes MongoDB based on Ubuntu bionic (default) and NodeBB v1.15.5 (default), and then run it with Node.js v10 container (minimum required by NodeBB v1.15.5)."
	echo ""
	echo "Another example: NODEBB_VERSION=1.12.1 CONTAINER_APP_DNS_ALIAS=localhost APP_ADD_POSTGRES=1 ./app start my-forum"
	echo "It will create pod with NodeBB v1.12.1 that uses PostgreSQL as database engine and sets its URL to localhost:8080 (default port) and websockets to localhost:8000 (default)"
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
		echo "         or specify database access info when running the pod" >&2
	fi

	# Prepare NodeBB image
	local imageNameFile=$(mktemp)
	IMAGE_NAME_FILE="$imageNameFile" APP_NAME="$podName" NODE_VERSION="$NODE_VERSION" NODEBB_VERSION="$NODEBB_VERSION" NODEBB_GIT="$NODEBB_GIT" tools/podman-create-nodebb.sh || return 1
	local NODEBB_IMAGE=$(cat "$imageNameFile")
	rm "$imageNameFile"
	if [ -z "$NODEBB_IMAGE" ] ; then
		echo "ERROR: could not get NodeBB container image name" >&2
		return 1
	fi

	if [ -z "$CONTAINER_APP_DNS_ALIAS" -a -z "$CONTAINER_APP_DNS" ] ; then
		echo "WARNING: no CONTAINER_APP_DNS_ALIAS nor CONTAINER_APP_DNS was specified" >&2
		echo "         OpenDNS service will be used to get public IP when running the pod" >&2
		# TODO: set to "localhost" by default?
	elif [ -z "$CONTAINER_APP_DNS_ALIAS" ] ; then
		nodebbOptions="$nodebbOptions -e CONTAINER_APP_DNS=$CONTAINER_APP_DNS"
	else
		nodebbOptions="$nodebbOptions -e CONTAINER_APP_DNS_ALIAS=$CONTAINER_APP_DNS_ALIAS"
	fi

	echo "Building '$podName' pod..."

	local webPort=${CONTAINER_NODEJS_PORT:-8080}
	local wsPort=${CONTAINER_WEBSOCKET_PORT:-$webPort}

	local podOptions="-p $webPort:$webPort"
	if [ "$webPort" != "$wsPort" ] ; then
		podOptions="$podOptions -p $wsPort:$wsPort"
	fi

	podman pod create -n "$podName" $podOptions --add-host=localhost:127.0.0.1 --hostname="$podName" || return 1

	# Add "data" container, to be shared by database, nodebb, etc...
	# podman create --pod "$podName" --name "${podName}-data" -v /data docker.io/busybox:musl || return 1

	local addNodeBBOptions=""
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

	if [ "$CONTAINER_NODEJS_IP" ] ; then
		nodebbOptions="$nodebbOptions -e CONTAINER_NODEJS_IP=${CONTAINER_NODEJS_IP}"
	fi

	# Add NodeBB container
	podman create --pod "$podName" --name "${podName}-nodebb"\
		-e CONTAINER_NODEJS_PORT=$webPort\
		-e CONTAINER_WEBSOCKET_PORT=$wsPort\
		$nodebbOptions $NODEBB_IMAGE || return 1

	local BACKUP_DATA="${RESTORE_FROM}/nodebb.tar"
	if [ ! -z "$RESTORE_FROM" ] && [ -f "$BACKUP_DATA" ] ; then
		echo -n "Copying $BACKUP_DATA to NodeBB container... "
		podman cp "$BACKUP_DATA" ${podName}-nodebb:/app/nodebb.tar || (echo "failed" && exit 1) || return 1
		echo "done"
	fi
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
		WAIT_FOR_PORT=$(podman inspect "${podName}-nodebb" --format="{{range .Config.Env}}{{.}}\n{{end}}" | grep CONTAINER_NODEJS_PORT | cut -d= -f2)

		echo "Restarting '$podName' pod..."
		podman pod start "$podName" || return 1
		# Use `restart` right after `start` because of ports not being accessible from outside after stop+start.
		# See: https://github.com/containers/podman/issues/7103 - issue is closed, but on Arch with podman v2.2.1
		# problem seems to still exist.
		# podman pod restart "$podName" || return 1
		(
			echo "Waiting for $podName port $WAIT_FOR_PORT to be ready inside container"
			podman exec nhl-nodebb /app/.container/tools/wait-for.sh 127.0.0.1:$WAIT_FOR_PORT -t 120 || exit 1
			sleep 1
			echo "Waiting for $podName port $WAIT_FOR_PORT to be accessible from outside of container"
			${__DIRNAME}/.container/tools/wait-for.sh localhost:${WAIT_FOR_PORT} -t 20 && echo "NodeBB should be accessible now" && exit 0
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

	echo "Stopping '$podName' pod..."
	podman pod stop "$podName" || return 1
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

if [ -z "$action" ] || [ "$action" = "help" ] ; then
	showHelp
	exit 0
fi

if [ "$action" = "build" ] ; then
	buildPod $(sanitizeAppName $2) || exit 1
	exit 0
fi

if [ "$action" = "start" ] ; then
	startPod $(sanitizeAppName $2) || exit 1
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

echo "ERROR: unrecognized action '$action'" >&2
showHelp
exit 1
