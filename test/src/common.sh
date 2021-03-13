#!/bin/bash

source ${__SRC}/common.sh

# Temporary files used by tests
INPUT="tmp.test.input"

runTest () {
	local failed=0
	$@ || failed=$?
	if [ $failed -ne 0 ] ; then
		echo "$* failed"
		return $failed
	fi
	echo "$* works ok"
	return 0
}

testImport () {
	unset TEST
	echo "TEST=one" | tee $INPUT
	runTest import $INPUT || return $?
	runTest test "$TEST" = "" || return $?

	runTest import $INPUT TEST || return $?
	runTest test "$TEST" = "one" || return $?

	echo "TEST=two" | tee $INPUT
	runTest import $INPUT TEST || return $?
	runTest test "$TEST" = "one" || return $?

	unset TEST
	runTest import $INPUT TEST || return $?
	runTest test "$TEST" = "two" || return $?

	unset TEST
	echo "# comment before" | tee $INPUT
	echo "TEST=three# inline commented" | tee -a $INPUT
	echo "# comment after" | tee -a $INPUT
	runTest import $INPUT TEST || return $?
	runTest test "$TEST" = "three" || return $?

	unset TEST
	echo "# TEST=four" | tee $INPUT
	runTest import $INPUT TEST || return $?
	runTest test "$TEST" = "" || return $?


	return 0
}

testImport

# We're here, so nothing exited earlier and we can cleanup temporary files
rm -rf "$INPUT" &>/dev/null || true
