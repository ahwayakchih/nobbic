#!/bin/bash

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to test which ports we can use and if there already is SSL at the gateway.

local FQDN="${APP_USE_FQDN:-localhost}"
local IP

# Try to autodetect FQDN only when asked to.
if [ "$FQDN" = "1" ] ; then
	echo "Calling OpenDNS service to get public IP..."

	# Alternative: dig @ns1.google.com TXT o-o.myaddr.l.google.com +short
	IP=$(podman run --rm "localhost/${NODEBB_TOOLBOX_IMAGE}" dig +short myip.opendns.com @resolver1.opendns.com || echo '')
	if [ -z "$IP" ] ; then
		echo "ERROR: could not determine public IP, cannot run without APP_USE_FQDN specified" >&2
		return 1
	else
		echo "Got IP '$IP'."
	fi

	echo "Trying to find FQDN for IP '$IP'..."
	FQDN=$(podman run --rm "localhost/${NODEBB_TOOLBOX_IMAGE}" dig +short -x "$IP" || echo '')
	if [ -n "$FQDN" ] ; then
		echo "Got '$FQDN' fully qualified domain name."
		export APP_USE_FQDN="$FQDN"
	else
		FQDN="$IP"
		echo "WARNING: no domain name found, using ${FQDN}."
	fi
fi

# Trim dot from the end
FQDN=${FQDN/%./}

echo "Using '${FQDN}' as domain name."

if [ -n "$APP_ADD_SSL" ] && [ "$FQDN" = "$IP" -o "$FQDN" = "localhost" ] ; then
	unset APP_ADD_SSL
	echo "WARNING: cannot create SSL certificate for IP or 'localhost'" >&2
	echo "         Ignoring APP_ADD_SSL." >&2
fi

local PORT=${APP_USE_PORT:-80}
local LOWEST_AVAILABLE_PORT=$(sysctl -n net.ipv4.ip_unprivileged_port_start)

if [ $LOWEST_AVAILABLE_PORT -gt $PORT ] ; then
	PORT=8080

	if [ $LOWEST_AVAILABLE_PORT -gt $PORT ] ; then
		echo "ERROR: Minimum port number available to unprivilaged user is ${LOWEST_AVAILABLE_PORT}." >&2
		echo "       Specify APP_USE_PORT equal or higger than that, or contact your administrator." >&2
		return 1
	fi

	if [ -n "$APP_USE_PORT" ] ; then
		echo "WARNING: port ${APP_USE_PORT} is not available for unprivilaged user." >&2
		echo "         Minimum port number is ${LOWEST_AVAILABLE_PORT}, port ${PORT} will be used instead." >&2
	fi
fi
export APP_USE_PORT=$PORT

local REQUEST="$(pwd)/tmp.nobbic.network.test.request"
local RESULT="$(pwd)/tmp.nobbic.network.test.result"
local EXPECTED="$(pwd)/tmp.nobbic.network.test.expected"
on_return carelessly rm "$REQUEST" "$RESULT" "$EXPECTED"

local SECRET=$(tr -cd '[:alnum:]' < /dev/urandom | fold -w32 | head -n1 | fold -w8 | paste -sd\- -)
echo "GET / HTTP/1.1\nHost:${FQDN}\n\n" > $REQUEST
echo -n "" > $RESULT
echo -n "$SECRET" > $EXPECTED

echo "Starting test server..."
podman run -d --replace --name nodebb-network-test -p "${PORT}:80" "localhost/${NODEBB_TOOLBOX_IMAGE}" alpine-run-acme-server.sh "$SECRET" &>/dev/null
if [ $? -ne 0 ] ; then
	echo "ERROR: failed to start test server: $?" >&2
	if podman container exists nodebb-network-test ; then
		podman rm -f nodebb-network-test
	fi
	return 1
fi
on_return carelessly async podman rm -f nodebb-network-test

echo -n "Waiting for test server to be ready"
while true ; do
	echo -n "."
	nc -z localhost "$PORT" && break;
	sleep 1
done
echo " done"

if [ "$FQDN" != "localhost" ] ; then
	local TEST_THROUGH_PORT=${APP_ROUTED_THROUGH_PORT:-443}
	if [ "$TEST_THROUGH_PORT" != "80" ] ; then
		echo "Testing access through ${FQDN}:${TEST_THROUGH_PORT}, assuming SSL termination exists"
		podman run --rm "localhost/${NODEBB_TOOLBOX_IMAGE}" curl --connect-timeout 5 --no-progress-meter "https://${FQDN}:${TEST_THROUGH_PORT}" 2>/dev/null | tail -n 1 >"$RESULT"
		if [ $? -eq 0 ] ; then
			if diff -Nawr "$EXPECTED" "$RESULT" ; then
				# Done!
				if [ -n "$APP_ADD_SSL" ] ; then
					unset APP_ADD_SSL
					echo "WARNING: SSL seems to be terminated on the way to server." >&2
					echo "         No point in adding SSL, ignoring APP_ADD_SSL." >&2
				fi
				export APP_ROUTED_THROUGH_PORT=$TEST_THROUGH_PORT
				export APP_USE_FQDN=$FQDN
				return 0
			elif [ -n "$APP_ROUTED_THROUGH_PORT" ] ; then
				echo "ERROR: something else is listening on port ${APP_ROUTED_THROUGH_PORT}" >&2
				return 1
			fi
		fi

		echo "Testing access through ${FQDN}:${TEST_THROUGH_PORT}, assuming passthrough"
		(cat "$REQUEST" | timeout -s KILL 5 nc "$FQDN" "$TEST_THROUGH_PORT" | tail -n 1 >"$RESULT")&>/dev/null
		if [ $? -eq 0 ] && diff -Nawr "$EXPECTED" "$RESULT" ; then
			if [ -n "$APP_USE_FQDN" ] ; then
				export APP_ADD_SSL=${APP_ADD_SSL:-1}
			fi
			export APP_ROUTED_THROUGH_PORT=$TEST_THROUGH_PORT
			echo "Port ${TEST_THROUGH_PORT} is passed through" >&2
		elif [ -n "$APP_ROUTED_THROUGH_PORT" ] ; then
			echo "ERROR: cannot access web server through port ${APP_ROUTED_THROUGH_PORT}" >&2
			return 1
		fi
	else
		unset APP_ADD_SSL
	fi

	if [ "$TEST_THROUGH_PORT" = "80" ] || [ -n "$APP_ADD_SSL" ] ; then
		echo "Testing access through ${FQDN}:80"
		(cat "$REQUEST" | timeout -s KILL 5 nc "$FQDN" "80" | tail -n 1 >"$RESULT")&>/dev/null
		if [ $? -eq 0 ] && diff -Nawr "$EXPECTED" "$RESULT" ; then
			# Done!
			if [ "$APP_ROUTED_THROUGH_PORT" = "80" ] ; then
				unset APP_ADD_SSL
				echo "WARNING: there is no point in adding SSL for port 80, ignoring APP_ADD_SSL" >&2
			fi
			export APP_ROUTED_THROUGH_PORT=${APP_ROUTED_THROUGH_PORT:-80}
			export APP_USE_FQDN=$FQDN
			return 0
		fi

		if [ "$APP_ROUTED_THROUGH_PORT" = "80" ] ; then
			echo "ERROR: cannot access web server through port 80" >&2
			return 1
		fi

		if [ -n "$APP_ADD_SSL" ] ; then
			unset APP_ADD_SSL
			echo "WARNING: cannot add SSL, that requires port 80 to be routed to web server" >&2
			echo "         Ask administrator to route port 80 to port ${PORT}." >&2
		fi
	fi
fi

unset APP_ROUTED_THROUGH_PORT
echo "Testing access through ${FQDN}:${PORT}"
(cat "$REQUEST" | timeout -s KILL 5 nc "$FQDN" "$PORT" | tail -n 1 >"$RESULT")&>/dev/null
if [ $? -eq 0 ] && diff -Nawr "$EXPECTED" "$RESULT" ; then
	# Done!
	export APP_USE_FQDN=$FQDN
	return 0
elif [ "$FQDN" = "localhost" ] ; then
	echo "ERROR: ${FQDN}:${PORT} is not accessible!" >&2
	echo "       Something is blocking selected port." >&2
	return 1
else
	echo "ERROR: ${FQDN}:${PORT} is not accessible!" >&2
	echo "       Check if ${FQDN} is correct." >&2
	echo "       Ask administrator to route port 80 to port ${PORT}." >&2
	echo "       Or read about 'nobbic install' command to install system service." >&2
	return 1
fi
