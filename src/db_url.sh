#!/bin/bash

# WARNING: This script has to be sourced by main script.
#          It depends on bash syntax.

# It's inspired by code by pjz: https://stackoverflow.com/a/17287984/6352710
# It's inspired by code by maersu: https://gist.github.com/maersu/2e050f6399e11348804bf162a301fb82

# @param {string} url
# @param {string} envPrefix   used for variable names, e.g., "DB_"
set_db_envs_from_url () {
	local url="$1"
	local db_="$2"

	local protocol=${url%%://*}
	if [ -n "$protocol" ] && [ "$protocol" != "$url" ] ; then
		export "${db_}PROTOCOL=${protocol}"
		url=${url/${protocol}:\/\//}
	else
		unset "${db_}PROTOCOL"
	fi

	local credentials=${url%%@*}
	local user
	local pass
	if [ "$credentials" != "$url" ] ; then
		user=${credentials%%:*}
		pass=${credentials#*:}
		if [ -n "$pass" ] && [ "$pass" != "$credentials" ] ; then
			export "${db_}PASSWORD=${pass}"
		else
			unset "${db_}PASSWORD"
		fi

		if [ -n "$user" ] ; then
			export "${db_}USER=${user}"
		else
			unset "${db_}USER"
		fi

		url=${url/${credentials}@/}
	else
		unset "${db_}USER"
		unset "${db_}PASSWORD"
	fi

	local params=${url#*\?}
	if [ "$params" != "$url" ] ; then
		export "${db_}PARAMS=${params}"
		url=${url/\?$params/}
	else
		unset "${db_}PARAMS"
	fi

	local path=${url#*/}
	if [ "$path" != "$url" ] ; then
		export "${db_}NAME=${path}"
		url=${url/\/$path/}
	else
		unset "${db_}NAME"
	fi

	local host=${url%%:*}
	if [ -n "$host" ] ; then
		export "${db_}HOST=${host}"
		url=${url/${host}/}
		url=${url#:}
	else
		unset "${db_}HOST"
	fi

	local port=$url
	if [ -n "$port" ] ; then
		export "${db_}PORT=${port}"
		url=${url/$port/}
	else
		unset "${db_}PORT"
	fi
}

# @param {string} envPrefix
get_url_from_db_envs () {
	local db_="$1"
	local URL=
	local name

	name="${db_}PROTOCOL"
	test -n "${!name}" && URL="${URL}${!name}://" || (echo -n "" && exit 1) || return 1

	name="${db_}USER"
	test -n "${!name}" && URL="${URL}${!name}"

	name="${db_}PASSWORD"
	test -n "${!name}" && URL="${URL}:${!name}"

	# If there was a user
	name="${db_}USER"
	(test -n "${!name}" || (name="${db_}PASSWORD"; test -n "${!name}")) && URL="${URL}@"

	name="${db_}HOST"
	test -n "${!name}" && URL="${URL}${!name}" || (echo -n "" && exit 1) || return 1

	name="${db_}PORT"
	test -n "${!name}" && URL="${URL}:${!name}"

	name="${db_}NAME"
	test -n "${!name}" && URL="${URL}/${!name}"

	name="${db_}PARAMS"
	test -n "${!name}" && URL="${URL}?${!name}"

	echo -n "$URL"
}