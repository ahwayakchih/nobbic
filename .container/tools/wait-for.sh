#!/bin/sh

# From: https://github.com/Eficode/wait-for

TIMEOUT=15
QUIET=0
LOCAL=0

echoerr() {
  if [ "$QUIET" -ne 1 ]; then printf "%s\n" "$*" 1>&2; fi
}

usage() {
  exitcode="$1"
  cat << USAGE >&2
Usage:
  $cmdname host:port [-t timeout] [-- command args]
  -q | --quiet                        Do not output any status messages
  -t TIMEOUT | --timeout=timeout      Timeout in seconds, zero for no timeout
  -l | --local                        Allow using netstat to check too, just in case nc does not work
  -- COMMAND ARGS                     Execute command with args after the test finishes
USAGE
  exit "$exitcode"
}

wait_for() {
  if ! command -v nc >/dev/null; then
    echoerr 'nc command is missing!'
    exit 1
  fi

  if [ "$HOST" != "localhost" ] && [ "$HOST" != "127.0.0.1" ]; then
    LOCAL=0
  elif test $LOCAL -ne 0; then
    if ! command -v netstat >/dev/null; then
      LOCAL=0
    fi
  fi

  for i in `seq $TIMEOUT` ; do
    (nc -z "$HOST" "$PORT" > /dev/null 2>&1 || (test $LOCAL -ne 0 && netstat -tuln | tr -s ' ' ' ' | cut -d ' ' -f 4 | grep ":${PORT}\$" > /dev/null 2>&1))
    
    result=$?
    if [ $result -eq 0 ] ; then
      if [ $# -gt 0 ] ; then
        exec "$@"
      fi
      exit 0
    fi
    sleep 1
  done
  echo "Operation timed out" >&2
  exit 1
}

while [ $# -gt 0 ]
do
  case "$1" in
    *:* )
    HOST=$(printf "%s\n" "$1"| cut -d : -f 1)
    PORT=$(printf "%s\n" "$1"| cut -d : -f 2)
    shift 1
    ;;
    -q | --quiet)
    QUIET=1
    shift 1
    ;;
    -t)
    TIMEOUT="$2"
    if [ "$TIMEOUT" = "" ]; then break; fi
    shift 2
    ;;
    --timeout=*)
    TIMEOUT="${1#*=}"
    shift 1
    ;;
    -l | --local)
    LOCAL=1
    shift 1
    ;;
    --)
    shift
    break
    ;;
    --help)
    usage 0
    ;;
    *)
    echoerr "Unknown argument: $1"
    usage 1
    ;;
  esac
done

if [ "$HOST" = "" -o "$PORT" = "" ]; then
  echoerr "Error: you need to provide a host and port to test."
  usage 2
fi

wait_for "$@"