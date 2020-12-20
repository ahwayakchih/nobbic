#!/bin/bash

action=$1

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
	echo "start [APP_NAME]  - start pod (build it if none exists) with specified name"
	echo "build [APP_NAME]  - build pod with specified name"
	echo "stop [APP_NAME]   - stop pod"
	echo "remove [APP_NAME] - stop pod, remove all its data and containers it used"
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
	echo "They default to 8080 and 8000 respectively."
	echo ""
	echo "For example: CONTAINER_APP_DNS_ALIAS=localhost APP_ADD_MONGODB=1 ./app start my-forum"
	echo "It will create pod that includes MongoDB based on Ubuntu bionic (default) and NodeBB v1.15.5 (default), and then run it with Node.js v10 container (minimum required by NodeBB v1.15.5)."
	echo ""
	echo "Another example: NODEBB_VERSION=1.12.1 CONTAINER_APP_DNS_ALIAS=localhost APP_ADD_POSTGRES=1 ./app start my-forum"
	echo "It will create pod with NodeBB v1.12.1 that uses PostgreSQL as database engine and sets its URL to localhost:8080 (default port) and websockets to localhost:8000 (default)"
}

#
# @param {string} podName
# @param {string} mongoImage   1 to use default ("docker.io/mongo:bionic") or specify
#
function podAddMongoDB () {
	local podName=$1
	local mongoImage=$2
	local containerName="${podName}-mongodb"

	if [ -z "$podName" ] ; then
		return 1
	fi

	if [ "$mongoImage" = "1" ] ; then
		mongoImage="docker.io/mongo:bionic"
	fi

	# if [ -z "$APP_SET_MONGODB_ENV_USER" ] ; then
	# 	echo "APP_SET_MONGODB_ENV_USER was not set in environment, defaulting to 'MONGO_INITDB_ROOT_USERNAME'" >&2
	# 	APP_SET_MONGODB_ENV_USER=MONGO_INITDB_ROOT_USERNAME
	# fi

	# if [ -z "$APP_SET_MONGODB_ENV_PASSWORD" ] ; then
	# 	echo "APP_SET_MONGODB_ENV_PASSWORD was not set in environment, defaulting to 'MONGO_INITDB_ROOT_PASSWORD'" >&2
	# 	APP_SET_MONGODB_ENV_PASSWORD=MONGO_INITDB_ROOT_PASSWORD
	# fi

	if [ -z "$APP_SET_MONGODB_ENV_DBNAME" ] ; then
		echo "APP_SET_MONGODB_ENV_DBNAME was not set in environment, defaulting to 'MONGO_INITDB_DATABASE'" >&2
		APP_SET_MONGODB_ENV_DBNAME=MONGO_INITDB_DATABASE
	fi

	# if [ -z "$APP_ADD_MONGODB_DATA_DIR" ] ; then
	# 	echo "APP_ADD_MONGODB_DATA_DIR was not specified in environment, using default '/data/db'" >&2
	# 	APP_ADD_MONGODB_DATA_DIR="/data/db"
	# fi

	# Make sure pod exists
	local exists=$(podman pod ls | grep "$podName")
	if [ -z "$exists" ] ; then
		return 1
	fi

	# local password=`tr -cd '[:alnum:]' < /dev/urandom | fold -w16 | head -n1 | fold -w4 | paste -sd\- -`

		# -e ${APP_SET_MONGODB_ENV_USER}="$podName" \
		# -e ${APP_SET_MONGODB_ENV_PASSWORD}="$password" \
	podman run -d --pod "$podName" --name "$containerName" \
		-e ${APP_SET_MONGODB_ENV_DBNAME}="$podName" \
        -e CONTAINER_DATA_DIR="/data/"\
		"$mongoImage" >/dev/null || return 1

		# '-e CONTAINER_MONGODB_DB_USERNAME=nodebb -e CONTAINER_MONGODB_DB_PASSWORD='$password
	echo '-e CONTAINER_MONGODB_DB_HOST=localhost -e CONTAINER_MONGODB_DB_PORT=27017 -e CONTAINER_MONGODB_DB_NAME='$podName
}


#
# @param {string} podName
# @param {string} redisImage   1 to use default ("docker.io/redis:alpine3.12") or specify
#
function podAddRedis () {
	local podName=$1
	local redisImage=$2
	local containerName="${podName}-redis"

	if [ -z "$podName" ] ; then
		return 1
	fi

	if [ "$redisImage" = "1" ] ; then
		redisImage="docker.io/redis:alpine3.12"
	fi

	# Make sure pod exists
	local exists=$(podman pod ls | grep "$podName")
	if [ -z "$exists" ] ; then
		return 1
	fi

	# We do not set CONTAINER_DATA_DIR, because, for now, Redis is used only for temporary data
	# and does not persist data between restarts.

	podman run -d --pod "$podName" --name "$containerName" \
		"$redisImage" >/dev/null || return 1

	echo '-e CONTAINER_REDIS_HOST=localhost -e CONTAINER_REDIS_PORT=27017'
}

#
# @param {string} podName
# @param {string} postgreImage   1 to use default ("docker.io/postgres:alpine") or specify
#
function podAddPostgres () {
	local podName=$1
	local postgreImage=$2
	local containerName="${podName}-postgres"

	if [ -z "$podName" ] ; then
		return 1
	fi

	if [ "$postgreImage" = "1" ] ; then
		postgreImage="docker.io/postgres:alpine"
	fi

	# Make sure pod exists
	local exists=$(podman pod ls | grep "$podName")
	if [ -z "$exists" ] ; then
		return 1
	fi

	local password=`tr -cd '[:alnum:]' < /dev/urandom | fold -w16 | head -n1 | fold -w4 | paste -sd\- -`

	# Get PGDATA from env used by default by official PostgreSQL images.
	# We'll set CONTAINER_DATA_DIR to the same value, so backups know what to archive.
	local dataDir=$(podman inspect "$postgreImage" --format='{{range .Config.Env}}{{.}}\n{{end}}'| grep PGDATA | cut -d= -f2)

		# Specyfing custom user name seem to prevent us from accessing db:
		# "NodeBB could not connect to your PostgreSQL database. PostgreSQL returned the following error: role "custom_user" does not exist"
		# -e POSTGRES_USER="$podName"\
	podman run -d --pod "$podName" --name "$containerName" \
		-e POSTGRES_PASSWORD="$password"\
		-e POSTGRES_DB="$podName"\
		-e CONTAINER_DATA_DIR="$dataDir"\
		"$postgreImage" >/dev/null || return 1

	echo '-e CONTAINER_POSTGRES_HOST=localhost -e CONTAINER_POSTGRES_PORT=5432 -e CONTAINER_POSTGRES_PASSWORD='$password\
		'-e CONTAINER_POSTGRES_USER=postgres -e CONTAINER_POSTGRES_DB='$podName
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

	if [ "$APP_ADD_MONGODB" ] ; then
		addNodeBBOptions=$(podAddMongoDB "$podName" "$APP_ADD_MONGODB")
		if [ -z "$addNodeBBOptions" ] ; then
			return 1
		fi
		nodebbOptions="$nodebbOptions $addNodeBBOptions"
	fi

	if [ "$APP_ADD_REDIS" ] ; then
		addNodeBBOptions=$(podAddRedis "$podName" "$APP_ADD_REDIS")
		if [ -z "$addNodeBBOptions" ] ; then
			return 1
		fi
		nodebbOptions="$nodebbOptions $addNodeBBOptions"
	fi

	if [ "$APP_ADD_POSTGRES" ] ; then
		addNodeBBOptions=$(podAddPostgres "$podName" "$APP_ADD_POSTGRES")
		if [ -z "$addNodeBBOptions" ] ; then
			return 1
		fi
		nodebbOptions="$nodebbOptions $addNodeBBOptions"
	fi

	if [ "$CONTAINER_NODEJS_IP" ] ; then
		nodebbOptions="$nodebbOptions -e CONTAINER_NODEJS_IP=${CONTAINER_NODEJS_IP}"
	fi

	# Add NodeBB container
	podman run -d --pod "$podName" --name "${podName}-nodebb"\
		-e CONTAINER_NODEJS_PORT=$webPort\
		-e CONTAINER_WEBSOCKET_PORT=$wsPort\
		$nodebbOptions $NODEBB_IMAGE || return 1
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

	podman pod exists "$podName" || buildPod "$podName" || return 1

	echo "Starting '$podName' pod..."
	# Use `restart` instead of `start` because of https://github.com/containers/podman/issues/7103
	# Issue is closed, but on podman v2.2.1 problem seems to exist
	podman pod restart "$podName" || return 1

	podman attach --no-stdin --sig-proxy=false "${podName}-nodebb"
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

	echo "Removing '$podName' pod..."
	podman pod stop "$podName" && podman pod rm "$podName" && return 0

	return 1
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
