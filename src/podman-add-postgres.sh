#!/bin/bash

if ! podman pod exists ${APP_NAME} &>/dev/null ; then
	echo "ERROR: could not find pod '${APP_NAME}'" >&2
	return 1
fi

DEFAULT_POSTGRES_PORT=5432

if [[ "$APP_ADD_POSTGRES" =~ ^postgre(s|sql)?:\/\/ ]] ; then
	inline db_url.sh
	set_db_envs_from_url "$APP_ADD_POSTGRES" POSTGRES_
	if [ -n "$POSTGRES_HOST" ] ; then
		# Output result
		export PODMAN_CREATE_ARGS_NODEBB="-e CONTAINER_POSTGRES_HOST=${POSTGRES_HOST}\
			-e CONTAINER_POSTGRES_PORT=${POSTGRES_PORT:-$DEFAULT_POSTGRES_PORT}\
			-e CONTAINER_POSTGRES_DB=${POSTGRES_NAME}\
			-e CONTAINER_POSTGRES_USER=${POSTGRES_USER}\
			-e CONTAINER_POSTGRES_PASSWORD=${POSTGRES_PASSWORD}\
			${PODMAN_CREATE_ARGS_NODEBB}"
		# TODO: support restoring from backup?
		# Return early
		return
	fi
fi

POSTGRES_CONTAINER=${CONTAINER:-"${APP_NAME}-postgres"}

POSTGRES_IMAGE=${FROM_IMAGE:-docker.io/postgres:alpine}
# Make sure image is available before we inspect it
if ! podman image exists "$POSTGRES_IMAGE" &>/dev/null ; then
	if ! podman pull $PODMAN_PULL_ARGS_POSTGRES "$POSTGRES_IMAGE" >/dev/null ; then
		echo "ERROR: could not find '$POSTGRES_IMAGE'" >&2
		return 1
	fi
fi

# Get postgres port
POSTGRES_PORT=${CONTAINER_POSTGRES_PORT:-$(podman image inspect $POSTGRES_IMAGE --format=$'{{range $key,$value := .Config.ExposedPorts}}{{$key}}\n{{end}}' | grep -m 1 -E '^[[:digit:]]*' | cut -d/ -f1 || test $? -eq 141)}
if [ -z "$POSTGRES_PORT" ] ; then
	POSTGRES_PORT=$DEFAULT_POSTGRES_PORT
	echo "WARNING: could not find port number exposed by ${POSTGRES_IMAGE}, defaulting to ${POSTGRES_PORT}" >&2
fi

POSTGRES_ENV=$(get_env_values_for CONTAINER_ENV_POSTGRES_ POSTGRES_)' '$(get_env_values_for CONTAINER_ENV_PG_ PG)

POSTGRES_DB=$CONTAINER_ENV_POSTGRES_DB
if [ -z "$POSTGRES_DB" ] ; then
	POSTGRES_DB="$APP_NAME"
	POSTGRES_ENV="-e POSTGRES_DB=${POSTGRES_DB} ${POSTGRES_ENV}"
fi

POSTGRES_PASSWORD=$CONTAINER_ENV_POSTGRES_PASSWORD
if [ -z "$POSTGRES_PASSWORD" ] ; then
	# Generate random password for database access
	# Ignore exit code 141 which hapens in case of writing to pipe that was closed, which is our case (read urandom until enough data is gathered),
	# by using trick from https://stackoverflow.com/a/33026977/6352710, i.e., `|| test $? -eq 141` part.
	POSTGRES_PASSWORD=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w16 | head -n1 | fold -w4 | paste -sd\- - || test $? -eq 141)
	POSTGRES_ENV="-e POSTGRES_PASSWORD=${POSTGRES_PASSWORD} ${POSTGRES_ENV}"
else
	echo "WARNING: using pre-specified password for PostgreSQL database" >&2
fi

ALPINE_LOCALE=''
# Prepare locale, if none is found
if ! podman run --rm -it "$POSTGRES_IMAGE" /bin/sh -c 'locale -a' &>/dev/null ; then
	# Make sure PostgreSQL's image is Alpine based, otherwise there's no point to run our script
	if podman run --rm -it "$POSTGRES_IMAGE" /bin/sh -c 'source /etc/os-release && test "$ID" = "alpine"' ; then
		ALPINE_LOCALE='nodebb-alpine-locale'
		# Create temporary container && install musl-locale there
		podman run --replace --name "$ALPINE_LOCALE" -v ${__TOOLS}/alpine-install-locale.sh:/usr/local/bin/alpine-install-locale.sh "$POSTGRES_IMAGE" alpine-install-locale.sh
		POSTGRES_ENV="-e MUSL_LOCPATH=/usr/share/i18n/locales/musl $POSTGRES_ENV"
	fi
fi

POSTGRES_CREATE_ARGS="${PODMAN_CREATE_ARGS} ${PODMAN_CREATE_ARGS_POSTGRES}"

	# Specyfing custom user name seem to prevent us from accessing db:
	# "NodeBB could not connect to your PostgreSQL database. PostgreSQL returned the following error: role "custom_user" does not exist"
	# -e POSTGRES_USER="$APP_NAME"\
podman create --pod "$APP_NAME" --name "$POSTGRES_CONTAINER" $POSTGRES_CREATE_ARGS \
	$POSTGRES_ENV "$POSTGRES_IMAGE" $CONTAINER_CMD_POSTGRES >/dev/null || exit 1

# Import from backup, if specified
if [ ! -z "$RESTORE_FROM" ] && [ -f "${RESTORE_FROM}/postgres.txt" ] ; then
	podman cp "${RESTORE_FROM}/postgres.txt" ${POSTGRES_CONTAINER}:/docker-entrypoint-initdb.d/restore-${APP_NAME}.sql >/dev/null || exit 1
fi

# Install locale, if none is found
if [ -n "$ALPINE_LOCALE" ] ; then
	tempdir=$(mktemp -d)

	podman cp "${ALPINE_LOCALE}:/usr/bin/locale" "${tempdir}/locale"
	podman cp "${tempdir}/locale" "${POSTGRES_CONTAINER}:/usr/bin/locale"

	podman cp "${ALPINE_LOCALE}:/usr/share/i18n" "${tempdir}/i18n"
	podman cp "${tempdir}/i18n" "${POSTGRES_CONTAINER}:/usr/share/i18n"

	rm -rf "$tempdir"
	podman rm "$ALPINE_LOCALE"
fi

# Output result
export PODMAN_CREATE_ARGS_NODEBB="-e CONTAINER_POSTGRES_HOST=localhost\
	-e CONTAINER_POSTGRES_PORT=${POSTGRES_PORT}\
	-e CONTAINER_POSTGRES_PASSWORD=${POSTGRES_PASSWORD}\
	-e CONTAINER_POSTGRES_USER=postgres\
	-e CONTAINER_POSTGRES_DB=${POSTGRES_DB}\
	${PODMAN_CREATE_ARGS_NODEBB}"
