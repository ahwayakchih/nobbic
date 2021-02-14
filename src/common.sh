# This is meant to be used by any of the tools, to setup helpful error handling
# simply by calling `source ./common.sh`

# From: https://stackoverflow.com/a/11564455/6352710
set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
on_error() {
    JOB="$0"              # job name
    LASTLINE="$1"         # line of error occurrence
    LASTERR="$2"          # error code
    echo "ERROR: ${JOB}, on line #${LASTLINE}, exited with code ${LASTERR}" >&2
    exit $LASTERR
}
trap 'on_error ${LINENO} ${?}' ERR

# @param {string}    error message
# @param [number=$?] code  exit code
fail() {
	LASTERR=${2:-$?}
	echo ${1:-Failed} >&2
	exit $LASTERR
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
get_image_name_from_json () {
	cat "$1" 2>/dev/null | grep ImageName | sed 's/^.*ImageName.*:\s*"//' | sed 's/".*$//' || echo "1"
}

# @param {string} envFilePath
# @param {string} regex
function import() {
	test -f "$1" || return 1

	local regex=${2:-^(PORT|(NODE(BB)?|CONTAINER|APP|PODMAN)_)}
	local name
 	while read -r line ; do
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