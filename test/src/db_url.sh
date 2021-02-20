#!/bin/bash

source ${__SRC}/db_url.sh

# Temporary files used by tests
EXPECT="tmp.test.expected"
RESULT="tmp.test.result"

testURL () {
	local URL=$1
	echo "${2:-$1}" > "$EXPECT"
	set_db_envs_from_url ${URL:-""} TEST_
	echo -n "" > "$RESULT"
	test -n "${TEST_PROTOCOL}" && echo -n "${TEST_PROTOCOL}://" >> "$RESULT"
	test -n "${TEST_USER}" && echo -n "${TEST_USER}" >> "$RESULT"
	test -n "${TEST_PASSWORD}" && echo -n ":${TEST_PASSWORD}" >> "$RESULT"
	test -n "${TEST_USER}" && echo -n "@" >> "$RESULT"
	echo -n "${TEST_HOST}" >> "$RESULT"
	test -n "${TEST_PORT}" && echo -n ":${TEST_PORT}" >> "$RESULT"
	test -n "${TEST_NAME}" && echo -n "/${TEST_NAME}" >> "$RESULT"
	test -n "${TEST_PARAMS}" && echo -n "?${TEST_PARAMS}" >> "$RESULT"
	echo "" >> "$RESULT"
	diff "$EXPECT" "$RESULT"
	result=$?
	test $result -eq 0 && echo "${URL:-''} works ok" || echo "${URL:-''} failed"
	return $result
}

testURL "mongodb://localhost" || return 1
testURL "mongodb://example.com" || return 1
testURL "mongodb://example.com:1234" || return 1
testURL "mongodb://example.com:1234/" "mongodb://example.com:1234" || return 1
testURL "mongodb://example.com/" "mongodb://example.com" || return 1
testURL "mongodb://username@example.com" || return 1
testURL "mongodb://username:password@example.com" || return 1
testURL "mongodb://username:password@example.com:1234" || return 1
testURL "mongodb://username:password@example.com:1234/db_name" || return 1
testURL "mongodb://username:password@example.com:1234/db_name?param=value" || return 1
testURL "mongodb://username@example.com:1234/db_name?param=value" || return 1
testURL "mongodb://example.com:1234/db_name?param=value" || return 1
testURL "mongodb://example.com/db_name?param=value" || return 1
testURL "mongodb://example.com/?param=value" "mongodb://example.com?param=value" || return 1
testURL "mongodb://example.com?param=value" || return 1
testURL "" || return 1
