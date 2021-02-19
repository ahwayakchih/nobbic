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
		if [ "$pass" != "$user" ] ; then
			export "${db_}PASSWORD=${pass}"
		else
			unset "${db_}PASSWORD"
		fi
		export "${db_}USER=${user}"
		url=${url/${credentials}@/}
	else
		unset "${db_}USER"
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
