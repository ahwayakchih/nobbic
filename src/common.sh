# This is meant to be used by any of the tools, to setup helpful error handling
# simply by calling `source ./common.sh`

# From: https://stackoverflow.com/a/11564455/6352710
set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
on_error() {
    readonly JOB="$0"              # job name
    readonly LASTLINE="$1"         # line of error occurrence
    readonly LASTERR="$2"          # error code
    echo "ERROR: ${TASKED_FROM_FILE:-$JOB}, on line #${TASKED_FROM_LINE:-$LASTLINE}, exited with code ${LASTERR}" >&2
    exit $LASTERR
}
trap 'on_error ${LINENO} ${?}' ERR

# When called with arguments, add them as a command to run at script's exit.
# When called without arguments, run all commands added so far.
#
# Commands are NOT evaluated intentionally! So no & or > or && or || will work!
# Use `async` to run task asynchronously, `carelessly` to ingnore all the output.
# Write proper functions to run multiple commands conditionally.
declare -a __ON_EXIT_QUEUE
on_exit() {
	if test ${#@} -gt 0 ; then
		__ON_EXIT_QUEUE+=( "__tasked_by $(caller) $*" )
	else
		readonly EXIT_STATUS=$?
		local cmd
		for (( i=0; i<${#__ON_EXIT_QUEUE[@]}; i++ )) ; do
			${__ON_EXIT_QUEUE[$i]}
		done
	fi
}
trap 'on_exit' EXIT

# @param {string}    error message
# @param [number=$?] code  exit code
abort() {
	readonly LASTERR=${2:-$?}
	echo ${1:-Failed} >&2
	exit $LASTERR
}

# Run command ignoring any output (both stdout and stderr)
carelessly() {
	$@ &>/dev/null
}

# Run command in background, output it's PID
async() {
	$@ &
	echo $!
}

# @private
# @param {number} line
# @param {string} filePath
__tasked_by() {
	TASKED_FROM_LINE=$1
	TASKED_FROM_FILE=$2
	shift 2
	$@
	TASKED_FROM_LINE=
	TASKED_FROM_FILE=
}

# @param {string} from  e.g., CONTAINER_ENV_MONGODB_
# @param {string} to  e.g., MONGO_, or empty string to remove whole prefix
get_env_values_for() {
	# Ignore errors
	values=$(env | grep "$1" || echo "")
	if [ -z "$values" ] ; then
		# Return early without error
		return
	fi

	for v in $values; do
		echo -n "-e "$(echo "$v" | cut -d= -f1 | sed "s/^${1}/${2}/")'='$(echo "$v" | cut -d= -f2)' '
	done
}

# @param {string} jsonFilePath
get_image_name_from_json() {
	cat "$1" 2>/dev/null | grep ImageName | sed 's/^.*ImageName.*:\s*"//' | sed 's/".*$//' || echo "1"
}

#
# @param {string} scriptPath
#
inline() {
	local __INLINED=$1

	if [ -z "$__INLINED" ] ; then
		echo "WARNING: No script path was specified to inline, ignoring" >&2
		return 0
	fi

	if test $(basename "$__INLINED") = "$__INLINED" ; then
		__INLINED="${__SRC}/${__INLINED}"
	fi

	source $__INLINED
	return $?
}

# @param {string} envFilePath
# @param {string} regex
import() {
	test -f "$1" || return 1

	local regex=${2:-^(PORT|(NODE(BB)?|CONTAINER|APP|PODMAN)_)}
	local name
 	while read -r line ; do
 		line=${line%%\#*}
 		[[ -n "$line" ]] || continue
 		name=${line%%=*}
 		[[ "$name" =~ $regex ]] || continue
 		test -z "${!name}" || continue
 		declare -x -g "${name}"="${line#*=}" || echo "failed to export '${name}'"
	done <"${1:-}"
}

# @param {string} templateName
# @param {string} [outputFile]
generate() {
	outputFile=${2:-$(mktemp -p ./)}
	env "${__TOOLS}/handlebar.sh" "${__TEMPLATES}/$1" > "$outputFile" || return 1
	echo $outputFile
}