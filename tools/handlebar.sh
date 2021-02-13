#!/bin/bash

# A very simple template handling for bash
# Supports very short list of replacement tokens.
#
# {{VARIABLE_NAME}}
# Simply replaces with value of VARIABLE_NAME found in environment.
# For example:
# ```
# Value of HOSTNAME is {{HOSTNAME}}
# ```
# run with HOSTNAME set to "example.com" in environment, will output:
# ```
# Value of HOSTNAME is example.com
# ```
# 
# {{...VARIABLE_NAME}}
# Gets the value of VARIABLE_NAME, splits it by comma, and outputs whole line
# for each of the resulting values.
# For example:
# ```
# {{...NUMBERS}} repeated line
# ```
# run with NUMBERS set to "1,2,3" in environment, will output:
# ```
# 1 repeated line
# 2 repeated line
# 3 repeated line
# ```
#
# Every token can use "!" to mark that the value is required, and if not found,
# line should be removed.
# For example:
# ```
# This line will not exist in output if {{!VARIABLE_NAME}} is not found or empty.
# ```
# run without VARIABLE_NAME, or empty VARIABLE_NAME, will output:
# ```
# ```
# run with VARIABLE_NAME set to non-empty value, e.g., "myValue", will output:
# ```
# This line will not exist in output if myValue is not found or empty.
# ```

injectValue () {
	local line=$1
	local name=$2
	local required=$3
	local expand=$4

	local token="{{${required}${expand}${name}}}"

	if [ -z "$name" ] ; then
		return 0
	fi

	if [ -n "$required" ] && [ -z "${!name}" ] ; then
		return 0
	fi

	if [ -z "$expand" ] ; then
		echo -n "${line/$token/${!name}}"
		return 0
	fi

	IFS=, read -ra values <<< "${!name}"
	for value in "${values[@]}" ; do
		injectLine "${line/$token/$value}"
	done
}

injectLine () {
	local line=$1
	local nl=$2

	# Just copy empty lines
	if [ -z "$line" ] ; then
		printf '%s\n' "$line"
		return
	fi

	# Inject values as long as there are any tokens left
	while [[ $line =~ \{\{(\!|)(\.\.\.|)([^{}]+)\}\} ]] ; do
		line=$(injectValue "$line" "${BASH_REMATCH[3]}" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}")
	done

	# Output modified line only if it's not empty
	if [ -n "$line" ] ; then
		printf '%s\n' "$line"
	fi
}

template () {
	while IFS= read -r line ; do
		injectLine "$line"
	done <"${1:-}"
}

if [ -n "$1" ] && [ -f "$1" ] ; then
	template "$1"
	exit 0
fi

echo "USAGE: handlebarsh /path/to/template/filename" >&2
