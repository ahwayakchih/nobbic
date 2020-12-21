How to set up Alpine Linux for running rootless podman
======================================================

This document is mainly a compilation of 3 other documents:

1. https://wiki.alpinelinux.org/wiki/Installation
2. https://wiki.alpinelinux.org/wiki/Podman
3. https://github.com/containers/podman/blob/master/docs/tutorials/rootless_tutorial.md

It was written when Alpine Linux did not have podman in v3.12 repository, only in "edge" repository.
Hopefully with next version it will be available in default repositories and with fixed configuration.
In the meantime, keep reading this "tutorial".

## Install Alpine Linux from ISO

After booting virtual machine or a computer from ISO/CD/USB/etc..., login as "root" and execute following sequence of commands:

```sh
setup-alpine
reboot
```

## Switch to "edge" version

After logging in as root user, change repositories:

```sh
apk add nano
nano /etc/apk/repositories
```

You should see something like this (URLs may differ, but last two parts should be version number/name and category):

```txt
#/media/cdrom/apks
http://dl-4.alpinelinux.org/alpine/v3.12/main
#http://dl-4.alpinelinux.org/alpine/v3.12/community
#http://dl-4.alpinelinux.org/alpine/edge/main
#http://dl-4.alpinelinux.org/alpine/edge/community
#http://dl-4.alpinelinux.org/alpine/edge/testing
```

Comment out lines with "v3.12" and uncomment "edge" lines, so it looks more like this:

```txt
#/media/cdrom/apks
#http://dl-4.alpinelinux.org/alpine/v3.12/main
#http://dl-4.alpinelinux.org/alpine/v3.12/community
http://dl-4.alpinelinux.org/alpine/edge/main
http://dl-4.alpinelinux.org/alpine/edge/community
http://dl-4.alpinelinux.org/alpine/edge/testing
```

Save changes and exit editor (CTRL+x, confirm write with "y" and ENTER).

Now update system and its packages from edge repositories:

```sh
apk upgrade --update-cache --available
sync
reboot
```

## Configuring Podman

After logging in as a root user, it's time to install and configure podman.

### Install various dependencies and helpful tools

apk add git jq podman crun shadow bash curl

### Add regular user and group

Execute following commands to create user named "username" belonging to "groupname" group.
You can change "username" and "groupname" to something else, of course; replacing them in all commands from this tutorial.

```sh
addgroup -g 1000 -S groupname
adduser -u 1000 -S -D -G groupname -s /bin/bash username
passwd username
```

### Prepare system for running rootless podman

```sh
usermod --add-subuids 200000-201000 --add-subgids 200000-201000 username
sysctl -w "net.ipv4.ping_group_range=0 2000000"
echo 'net.ipv4.ping_group_range=0 2000000' > /etc/sysctl.d/podman.conf
```

### Fix podman's init script

Edit init script:

```sh
nano /etc/init.d/podman
```

Make `start_pre()` function look like this (just add `modprobe fuse` line into the "else" part of original file):

```sh
	start_pre() {
		if [ "$podman_user" = "root" ] ; then
			einfo "Configured as rootful service"
			checkpath -d -m 755 /run/podman
		else
			einfo "Configured as rootless service"
			modprobe tun
			modprobe fuse
		fi
	}
```

Save changes and exit editor.

### Switch podman to run rootless

Edit config file for podman "service":

```sh
nano /etc/conf.d/podman
```

Change `podman_user` to regular user name, like this:

```txt
podman_user = "username"
```

Save changes and exit editor.

### Enable podman "service"

```sh
rc-update add podman
rc-service podman start
```

At the moment of writing this, podman info on Alpine's wiki mentions adding and enabling "cgroups" service instead.
But that is not enough (as both `tun` and `fuse` kernel modules need to be loaded too), and "podman" service enables "cgroups" as its dependency anyway.

## Configure Podman for user

Switch to regular user account and change its password:

```sh
su -l username
```

### Change default configuration

Podman uses "runc" runtime by default. "crun" is supoosed to be faster and use less memory, so let's switch to it.

First, prepare space for user-specific configuration:

```sh
mkdir -p $HOME/.config/containers
```

Next, download default configuration which containes a lot of helpful comments:

```sh
curl https://raw.githubusercontent.com/containers/common/master/pkg/config/containers.conf > $HOME/.config/containers/containers.conf
```

Finally, change some of the lines in containers configuration file:

```sh
nano $HOME/.config/containers/containers.conf
```

You can comment original lines and add new ones next under them, or replace originals with new ones.
To quickly find a line, use CTRL+w key combination and type in part of it, e.g., "runtime =" and hit ENTER.
If it finds similar line, just repeat searching (it will continue searching starting from current line).

```txt
runtime = "crun"
```

Save changes and exit editor.

If you want, you can change some other options through `HOME/.config/containers/storage.conf` file.
Default file can be downloaded from `https://raw.githubusercontent.com/containers/storage/master/storage.conf`.

That's all! Well... almost.

## Test if it works OK.

While still being logged as regular user (`whoami` returns "username"), check if podman runs and uses your config:

```sh
podman info | grep crun
```

You should see something like this:

```txt
	name: crun
	path: /usr/bin/crun
	  crun version 0.16
```

Finally test if podman can run containers properly by executing following command line:

```sh
([ $(id -u) != "0" ] && [ $(podman run --rm -v $HOME:/host docker.io/alpine /bin/sh -c '[ "$container" = "podman" ] && (id -u | tee /host/test.log) && (chmod 0700 /host/test.log)') = "0" ] && [ $(cat $HOME/test.log) = "0" ] && [ $(stat -c "%U:%G" $HOME/test.log) = $(id -nu)":"$(id -ng) ] && (rm $HOME/test.log) && echo "That's all, it works :)") || echo "It failed for some reason :("
```

If it did not work, report any errors - maybe we can fix it. Otherwise...

Have fun running containers rootlessly!