#!/bin/bash

if [ -z "$APP_NAME" ] ; then
	echo "ERROR: APP_NAME name must be specified to add local NodeBB to it" >&2
	exit 1
fi

NODEBB_CONTAINER=${CONTAINER:-"${APP_NAME}-nodebb"}

# Prepare NodeBB image
inline podman-create-nodebb.sh || return $?
if [ -z "$NODEBB_IMAGE" ] ; then
	echo "ERROR: could not get NodeBB container image name" >&2
	exit 1
fi

NODEBB_ENV="$(get_env_values_for CONTAINER_ENV_NODEBB_ '') $(get_env_values_for CONTAINER_ENV_NODE_ NODE_) -e APP_NAME=${APP_NAME}"

# Detect FQDN if none was specified
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
	NODEBB_ENV="${NODEBB_ENV} -e APP_USE_FQDN=${APP_USE_FQDN}"
fi

NODEBB_CREATE_ARGS="${PODMAN_CREATE_ARGS} ${PODMAN_CREATE_ARGS_NODEBB}"

podman create --pod "$APP_NAME" --name "$NODEBB_CONTAINER" $NODEBB_CREATE_ARGS \
	$NODEBB_ENV "$NODEBB_IMAGE" $CONTAINER_CMD_NODEBB >/dev/null || exit 1

if [ -n "$APP_CREATE_ENV_FILE" ] ; then
	podman cp "$APP_CREATE_ENV_FILE" "${NODEBB_CONTAINER}:/app/POD_BUILD_ENV"
fi

# Import from backup, if specified
BACKUP_DATA="${RESTORE_FROM}/nodebb.tar"
if [ ! -z "$RESTORE_FROM" ] && [ -f "$BACKUP_DATA" ] ; then
	echo -n "Copying $BACKUP_DATA to NodeBB container... "
	podman cp "$BACKUP_DATA" ${NODEBB_CONTAINER}:/app/nodebb-$(basename "$RESTORE_FROM").tar || (echo "failed" && exit 1) || return 1
	echo "done"
fi
