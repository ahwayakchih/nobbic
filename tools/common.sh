# This is meant to be used by any of the tools, to setup helpful error handling
# simply by calling `source ./common.sh`

# From: https://stackoverflow.com/a/11564455/6352710
set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
on_error() {
    JOB="$0"              # job name
    LASTLINE="$1"         # line of error occurrence
    LASTERR="$2"          # error code
    echo "ERROR: ${JOB}, on line #${LASTLINE}, exited with code ${LASTERR}"
    exit $LASTERR
}
trap 'on_error ${LINENO} ${?}' ERR