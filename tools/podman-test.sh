#!/bin/sh

# WARNING: This script has to be run OUTSIDE container.
#          It's meant to test if podman can run rootless.

abort() {
	msg=$1
	if [ -z "$msg" ] ; then
		echo "That's all, it works :)"
		exit 0
	else
		echo $msg >&2
		echo "It failed for some reason :("
		exit 1
	fi
}

if [ $(id -u) = "0" ] ; then
	abort "ERROR: this test must be run by a regular user, not root"
fi

wasRunAs=$(podman run --rm -v $HOME:/host docker.io/alpine /bin/sh -c '[ "$container" = "podman" ] && (id -u | tee /host/test.log) && (chmod 0700 /host/test.log)')

if [ "$wasRunAs" != "0" ] ; then
	abort "ERROR: looks like default user inside container was not root"
fi

if [ $(cat $HOME/test.log) != "0" ] ; then
	abort "ERROR: looks like root did not write to test file"
fi

if [ $(stat -c "%U:%G" $HOME/test.log) != $(id -nu)":"$(id -ng) ] ; then
	abort "ERROR: owner and/or group of created test file is different than current user/group"
fi

if ! rm $HOME/test.log ; then
	abort "ERROR: could not remove test file"
fi

echo "That's all, it works :)"
