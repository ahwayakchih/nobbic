#!/bin/bash

#
#
#
function client_result () {
	echo $@
}

#
# Echo full path to specified logfile name or logs directory
#
# @param {string} [logfileName]
#
function onbb_get_logfile () {
	local logfileName=$1

	readlink -f "${CONTAINER_REPO_DIR}logs/${logfileName}"
}

#
# Echo NodeBB version number from package.json file
#
function onbb_get_nodebb_version () {
	jq -je '.version' "${CONTAINER_REPO_DIR}nodebb/install/package.json" || return 1
}

#
# Echo URL found in config.json
#
function onbb_get_url_from_config () {
	jq -je '.url' "${CONTAINER_REPO_DIR}nodebb/config.json" || return 1
}

#
# Test if NodeBB version is equal or higher than the one specified
#
# @param {string} minVersion
#
function onbb_test_nodebb_version () {
	local minVersion=$1
	local currentVersion=$(onbb_get_nodebb_version || echo "")

	if [ "$minVersion" = "$currentVersion" ] ; then
		echo equal
		return 0
	fi

	local higherVersion=$(echo -e "$minVersion\n$currentVersion" | sort -V | tail -n 1)
	if [ "$higherVersion" != "$minVersion" ] ; then
		return 0
	fi

	return 1
}

#
# Print information about failed NodeBB setup.
#
# @param {string} [logfile=logs/container-nodebb-setup.log]   Path to NodeBB logfile
# @param {string} [reason]                                    Possible reason as a short one-liner, defaults to "unknown"
#
function onbb_echo_result_of_setup_failed () {
	local logfile=$1
	local reason=$2
	local message="Setup failed."

	if [ "$logfile" = "" ] ; then
		logfile=$(onbb_get_logfile "container-nodebb-setup.log")
	fi

	if [ "$reason" = "" ] ; then
		message="Setup possibly failed - unknown result."
		reason="There was a problem completing NodeBB setup."
	fi

	client_result ""
	client_result ".-============================================-."
	client_result ".  Setup failed."
	client_result "."
	client_result ".  $reason"
	client_result "."
	client_result ".  Check logfile for more information:"
	client_result ".  $logfile"
	client_result "^-============================================-^"
	client_result ""
}

#
# Print information about successfull NodeBB setup.
#
# @param {string} [name]       Only if new admin account was created
# @param {string} [password]   Only if new admin account was created
# @param {string} [email]      Only if new admin account was created
#
function onbb_echo_result_of_setup_success () {
	local name=$1
	local pass=$2
	local email=$3

	if [ "$name" = "" -o "$pass" = "" -o "$email" = "" ] ; then
		client_result ""
		client_result ".-============================================-."
		client_result ".  Setup finished."
		client_result "."
		client_result ".  Please wait for NodeBB to start."
		client_result "^-============================================-^"
		client_result ""
	else
		client_result ""
		client_result ".-============================================-."
		client_result ".  Setup finished."
		client_result "."
		client_result ".  New administrator user has been created:"
		client_result "."
		client_result ".    email   : $email"
		client_result ".    login   : $name"
		client_result ".    password: $pass"
		client_result "."
		client_result ".  Please wait for NodeBB to start."
		client_result "."
		client_result ".  WARNING: Be sure to change admin password"
		client_result ".           after first log in!"
		client_result "^-============================================-^"
		client_result ""
	fi
}

#
# Print information about failed start of NodeBB.
#
# @param {string} [logfile=log/output.log]   Path to NodeBB logfile
#
function onbb_echo_result_of_start_failed () {
	local logfile=$1

	if [ "$logfile" = "" ] ; then
		logfile=$(onbb_get_logfile "output.log")
	fi

	client_result ""
	client_result ".-============================================-."
	client_result ".  NodeBB failed to start for some reason."
	client_result "."
	client_result ".  Check logfile for more information:"
	client_result ".  $logfile"
	client_result "^-============================================-^"
	client_result ""
}

#
# Print information about NodeBB started and ready.
#
# @param {string} [url]   URL of NodeBB instance, defaults to the one found in config.json
#
function onbb_echo_result_of_start_success () {
	local url=$1

	if [ "$url" = "" ] ; then
		url=$(onbb_get_url_from_config)
	fi

	client_result ""
	client_result ".-============================================-."
	client_result ".  NodeBB is ready."
	client_result "."
	client_result ".  You can visit it at:"
	client_result ".  $url"
	client_result "."
	client_result ".  You can log in to it at:"
	client_result ".  $url/login"
	client_result "^-============================================-^"
	client_result ""
}

#
# Setup NODEBB_FQDN from APP_USE_FQDN, or dig OpenDNS, or fail (empty string).
# Echo result to stdout.
#
function onbb_setup_fqdn () {
	local FQDN="$APP_USE_FQDN"

	if [ -z "$FQDN" ] ; then
		echo "WARNING: No APP_USE_FQDN was specified" >&2
		echo "         Calling OpenDNS service to get public IP..." >&2
		FQDN=$(dig +short myip.opendns.com @resolver1.opendns.com)
		echo "         Got '$FQDN'." >&2
	fi

	export NODEBB_FQDN="$FQDN"
	echo "$FQDN"
}

#
# Setup NODEBB_ADMIN_EMAIL from NODEBB_ADMIN_EMAIL, or from CONTAINER_LOGIN, or as APP_NAME@NODEBB_FQDN, or fail.
#
function onbb_setup_email () {
	local email="$NODEBB_ADMIN_EMAIL"

	if [ -z "$email" ] ; then
		email="$CONTAINER_LOGIN"
	fi

	if [ -z "$email" -a "$NODEBB_FQDN" != "" ] ; then
		email="$APP_NAME@$NODEBB_FQDN"
	fi

	if [ -z "$email" ] ; then
		email="${APP_NAME}@127.0.0.1"
	fi

	export NODEBB_ADMIN_EMAIL="$email"
	echo "$email"
}

#
# Find and apply all patches matching NodeBB version number.
#
# @param [version] defaults to $(onbb_get_nodebb_version)
#
function onbb_setup_sourcecode () {
	local version=$1

	if [ "$version" = "" ] ; then
		version=$(onbb_get_nodebb_version)
	fi

	if [ "$version" = "" ] ; then
		echo "Could not find NodeBB version number in source code"
		return 1
	fi

	local d=`pwd`
	cd "${CONTAINER_REPO_DIR}"

	# TODO: fix paths, since we now have soruce code in `nodebb` subdir

	local patches=`ls patches/container-$version*.diff 2>/dev/null`
	if [ "$patches" != "" ] ; then
		# Apply patches for selected version
		for changeset in $patches ; do
			echo "Applying changeset "$changeset
			local rejected=$changeset".rejected"
			patch -N --no-backup-if-mismatch -s -r $rejected -p1 < $changeset || return 1
			if [ -f "$rejected" ] ; then
				echo "Changeset $changeset was rejected. Check $rejected to see what parts of it could not be applied"
			fi
		done
	fi

	cd "$d"
}

#
# Setup directories and ensure everything is set up ok
#
function onbb_setup_environment () {
	local d=`pwd`
	cd "$CONTAINER_REPO_DIR"

	# Make sure NODEBB_FQDN is set
	local fqdn=$(onbb_setup_fqdn)
	if [ -z "$fqdn" ] ; then
		echo "Could not find FQDN"
		return 1
	fi
	export NODEBB_FQDN="$fqdn"

	# Make sure NODEBB_ADMIN_EMAIL is set
	local email=$(onbb_setup_email)
	if [ -z "$email" ] ; then
		echo "Could not find email"
		return 1
	fi
	export NODEBB_ADMIN_EMAIL="$email"

	# Make sure, that our `onbb` module is installed and has all dependencies met
	# cd .container/lib/onbb || echo "Could not find onbb module"
	# npm prune --production
	# npm install --production || echo "Could not install onbb module"
	# cd ../../../

	# Make sure package.json is there and installed, so our custom app.js can work ok before NodeBB is installed
	if [ -f nodebb/package.json ] ; then
		# Use default package.json, but merge dependencies from existing one
		mv nodebb/package.json nodebb/package.old.json
		jq -s --indent 4 '.[1] * {"dependencies": (.[0].dependencies * .[1].dependencies)}' nodebb/package.old.json nodebb/install/package.json > nodebb/package.json
		# rm nodebb/package.old.json
	else
		cp -a nodebb/install/package.json nodebb/package.json
	fi

	if [ ! -d nodebb/node_modules/nconf ] ; then
		echo "Installing dependencies"
		cd nodebb
		if [ "$NODE_ENV" != "development" ] ; then
			npm install --production
		else
			npm install
		fi
		cd ../
	fi

	for plugin in ${CONTAINER_REPO_DIR}.container/plugins/nodebb-plugin-*; do
		if [ -d "$plugin" ] ; then
			cd "$plugin"
			npm link
			cd "${CONTAINER_REPO_DIR}/nodebb"
			npm link $(basename "$plugin")
		fi
	done
	cd "$CONTAINER_REPO_DIR"

	# Override app.js
	# We have to move original and replace it with our "wrapper"
	# because NodeBB calls hardcoded "app.js" in some cases
	# and we do not want to modify code in too many places.
	local containerApp="${CONTAINER_REPO_DIR}.container/onbb-app.js"
	if [ -f "$containerApp" ] ; then
		echo "Overriding app.js"
		local needUpdate=$(diff "$containerApp" "nodebb/app.js" || false)
		if [ "$needUpdate" ] ; then
			if [ ! -f nodebb/_app.js ] ; then
				mv nodebb/app.js nodebb/_app.js
			fi
			cp -a "$containerApp" nodebb/app.js
		fi
		
		echo "Overriding src/cli/index.js"
		local needUpdate=$(diff "$containerApp" "nodebb/src/cli/index.js" || false)
		if [ "$needUpdate" ] ; then
			if [ ! -f nodebb/src/cli/_index.js ] ; then
				mv nodebb/src/cli/index.js nodebb/src/cli/_index.js
			fi
			cp -a "$containerApp" nodebb/src/cli/index.js
		fi
	fi

	cd "$d"
}

#
# Ensure that NodeBB is stopped. Wait until it is or time runs up
#
# @param {number} [timeout=2]      In seconds
# @param {number} [graceful=yes]   "no" to just kill node processes
#
function onbb_wait_until_stopped () {
	local seconds=$1
	local graceful=$2

	if [ -z "$seconds" ] ; then
		seconds=2
	fi

	if [ -z "$graceful" ] ; then
		graceful="yes"
	fi

	# Find first PID of node process, since we know there should be no other node processes running in "this" container
	local PID=`pgrep -x node -o`

	# Return early if it stopped already
	if [ -z "$PID" ] ; then
		return 0
	fi

	# Return error if there is no time left
	if [ "$seconds" -le "0" ] ; then
		return 1
	fi 

	# Stop it gracefully if we have more than a second of time left
	if [ "$seconds" -gt "1" -a "$graceful" = "yes" ] ; then
		local d=`pwd`
		cd "${CONTAINER_REPO_DIR}nodebb"
		./nodebb stop 2>/dev/null
		cd "$d"

		sleep 1

		onbb_wait_until_stopped $(echo "$seconds - 1" | bc) "no" || return 1
		return 0
	fi

	# KILL!
	kill "$PID" || return 1
	onbb_wait_until_stopped $(echo "$seconds - 1" | bc) "no" || return 1

	return 0
}

#
# Try NodeBB's port until it is listening for connections.
#
# @param {number} [timeout=120]   In seconds
#
function onbb_wait_until_ready () {
	local seconds=$1

	if [ -z "$seconds" ] ; then
		# 2 minutes
		seconds=120
	fi

	"${CONTAINER_REPO_DIR}.container/tools/wait-for.sh" 127.0.0.1:4567 -t $seconds -l || return 1
}

#
# Try databases' port until it is listening for connections.
#
# @param {number} [timeout=120]   In seconds
#
function onbb_wait_until_db_ready () {
	local seconds=$1

	if [ "$seconds" = "" ] ; then
		# 2 minutes
		seconds=120
	fi

	local port=
	local target=""

	if [ "${CONTAINER_MONGODB_HOST}${CONTAINER_MONGODB_IP}" ] ; then
		port=${CONTAINER_MONGODB_PORT:-27017}
		target="${CONTAINER_MONGODB_HOST:-$CONTAINER_MONGODB_IP}:${port}"
	elif [ "${MONGOLAB_URI}" ] ; then
		target=$(URL="${MONGOLAB_URI}" node -e 'const url=require("url");const u=url.parse(process.env.URL);const r=u.hostname+(u.port?":"+u.port:"");console.log(r);')
		port=$(echo "$target" | cut -s -d: -f2)
		if [ -z "$port" ] ; then
			port=27017
			target="${target}:${port}"
		fi
	elif [ "${CONTAINER_POSTGRES_HOST}${CONTAINER_POSTGRES_PASSWORD}" ] ; then
		port=${CONTAINER_POSTGRES_PORT:-5432}
		target="${CONTAINER_POSTGRES_HOST:-127.0.0.1}:${port}"
	elif [ "${CONTAINER_REDIS_HOST}${REDIS_PASSWORD}" ] ; then
		port=${CONTAINER_REDIS_PORT:-6379}
		target="${CONTAINER_REDIS_HOST:-127.0.0.1}:${port}"
	else
		echo "ERROR: no database connection specified" >&2
		return 1
	fi

	echo "Waiting for DB at ${target} to be ready" >&2
	"${CONTAINER_REPO_DIR}.container/tools/wait-for.sh" ${target} -t $seconds -l || return 1
}

#
# Execute command on NodeBB server.
#
function onbb_exec_command () {
	local server=`ls "${CONTAINER_REPO_DIR}nodebb" | grep -m 1 'nbb-cmd-[0-9]*.sock'`

	if [ -z $server ] ; then
		>&2 echo "No server found"
		return 1
	fi

	echo $@ | "${CONTAINER_REPO_DIR}.container/tools/run-command.js" "${CONTAINER_REPO_DIR}nodebb/${server}" || return 1
}