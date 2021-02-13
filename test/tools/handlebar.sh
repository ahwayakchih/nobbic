#!/bin/bash

# Temporary files used by tests
TEMPLATE="tmp.test.handlebarsh"
EXPECT="tmp.test.expected"
RESULT="tmp.test.result"

testHandlebarsh () {
	env ${__TOOLS}/handlebar.sh "$TEMPLATE" > "$RESULT"
	diff "$EXPECT" "$RESULT"
	result=$?
	test $result -eq 0 && echo "$(head -n 1 $TEMPLATE | xargs) works ok" || echo "$(head -n 1 $TEMPLATE | xargs) failed"
	return $result
}

# Simple copy, no tokens
tee "$TEMPLATE" <<'EOF' >/dev/null
	Simple copy

	Simple line 2
EOF
cp -a "$TEMPLATE" "$EXPECT"
testHandlebarsh || return 1

# Simple token injection
export TEST_TOKEN=">injected test content<"
tee "$TEMPLATE" <<'EOF' >/dev/null
	Simple token injection
	Line with {{TEST_TOKEN}}
	Simple line 2
EOF
tee "$EXPECT" <<EOF >/dev/null
	Simple token injection
	Line with ${TEST_TOKEN}
	Simple line 2
EOF
testHandlebarsh || return 1

# Required token injection
export TEST_TOKEN=">injected test content<"
tee "$TEMPLATE" <<'EOF' >/dev/null
	Required token injection
	Line with {{!TEST_TOKEN}}
	Simple line 2
EOF
tee "$EXPECT" <<EOF >/dev/null
	Required token injection
	Line with ${TEST_TOKEN}
	Simple line 2
EOF
testHandlebarsh || return 1

# Required missing token injection
unset TEST_TOKEN
tee "$TEMPLATE" <<'EOF' >/dev/null
	Required missing token injection
	Line with {{!TEST_TOKEN}}
	Simple line 2
EOF
tee "$EXPECT" <<EOF >/dev/null
	Required missing token injection
	Simple line 2
EOF
testHandlebarsh || return 1

# We're here, so nothing exited earlier and we can cleanup temporary files
rm -rf "$TEMPLATE" "$EXPECT" "$RESULT" &>/dev/null || true
