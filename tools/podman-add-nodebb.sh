#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to add Redis to the specified pod.

# Remember our stdout, so we can bring it back later
exec 4>&1

# Redirect stdout to stderr, just in case something slips through
# so it will not break our result.
exec 1>&2

__DIRNAME=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
source ${__DIRNAME}/common.sh

POD="$POD"
if [ -z "$POD" ] ; then
	echo "ERROR: POD name must be specified to add local NodeBB to it" >&2
	exit 1
fi

if [ -z "$CONTAINER" ] ; then
	CONTAINER="${POD}-nodebb"
fi

# Prepare NodeBB image
imageNameFile=$(mktemp)
env IMAGE_NAME_FILE="$imageNameFile" APP_NAME="$POD" tools/podman-create-nodebb.sh || exit 1
NODEBB_IMAGE=$(cat "$imageNameFile")
rm "$imageNameFile"
if [ -z "$NODEBB_IMAGE" ] ; then
	echo "ERROR: could not get NodeBB container image name" >&2
	exit 1
fi

NODEBB_ENV="-e APP_NAME=$POD "$(get_env_values_for CONTAINER_ENV_NODEBB_ "")' '$(get_env_values_for CONTAINER_ENV_NODE_ NODE_)

if ! echo $NODEBB_ENV | grep -q "APP_USE_FQDN=" ; then
	if [ -z "$APP_USE_FQDN" ] ; then
		echo "WARNING: no APP_USE_FQDN was specified" >&2
		echo "         OpenDNS service will be used to get public IP when running the pod" >&2

		APP_USE_FQDN=$(podman run --rm -t $PODMAN_CREATE_ARGS $PODMAN_CREATE_ARGS_NODEBB $NODEBB_ENV "$NODEBB_IMAGE" /bin/bash -c 'source .container/lib/onbb_utils.sh && onbb_setup_fqdn >/dev/null 2>&1 && echo -n "$NODEBB_FQDN" || echo -n ""')
		if [ -z "$APP_USE_FQDN" ] ; then
			APP_USE_FQDN=localhost
			echo "ERROR: could not determine URL to be used for NodeBB, defaulting to '$APP_USE_FQDN'" >&2
		else
			echo "         Forum will await connections through '$APP_USE_FQDN'" >&2
		fi
	fi
	# TODO: test if it's really accessible through that name/IP?
	NODEBB_ENV="$NODEBB_ENV -e APP_USE_FQDN=$APP_USE_FQDN"
fi

PODMAN_CREATE_ARGS="$PODMAN_CREATE_ARGS $PODMAN_CREATE_ARGS_NODEBB"

podman create --pod "$POD" --name "$CONTAINER" $PODMAN_CREATE_ARGS \
	$NODEBB_ENV "$NODEBB_IMAGE" >/dev/null || exit 1

# Import from backup, if specified
BACKUP_DATA="${RESTORE_FROM}/nodebb.tar"
if [ ! -z "$RESTORE_FROM" ] && [ -f "$BACKUP_DATA" ] ; then
	echo -n "Copying $BACKUP_DATA to NodeBB container... "
	podman cp "$BACKUP_DATA" ${CONTAINER}:/app/nodebb-$(basename "$RESTORE_FROM").tar || (echo "failed" && exit 1) || return 1
	echo "done"
fi

# Restore stdout and close 4 that was storing its file descriptor
exec 1>&4-

# Output result
echo ''
