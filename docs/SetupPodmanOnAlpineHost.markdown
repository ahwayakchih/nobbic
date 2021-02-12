How to set up Alpine Linux for running rootless podman
======================================================

This tutorial is mainly a compilation of 3 other documents:

1. https://wiki.alpinelinux.org/wiki/Installation
2. https://wiki.alpinelinux.org/wiki/Podman
3. https://github.com/containers/podman/blob/master/docs/tutorials/rootless_tutorial.md

It was written when [**Alpine Linux**](https://alpinelinux.org/) did not have `podman` in the **v3.13** repository, only in the "edge" repository. Hopefully with next version it will be available in default repositories.
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
http://dl-4.alpinelinux.org/alpine/v3.13/main
#http://dl-4.alpinelinux.org/alpine/v3.13/community
#http://dl-4.alpinelinux.org/alpine/edge/main
#http://dl-4.alpinelinux.org/alpine/edge/community
#http://dl-4.alpinelinux.org/alpine/edge/testing
```

Comment out lines with "v3.13" and uncomment "edge" lines, so it looks more like this:

```txt
#/media/cdrom/apks
#http://dl-4.alpinelinux.org/alpine/v3.13/main
#http://dl-4.alpinelinux.org/alpine/v3.13/community
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

The only "required" packages to run rootless podman are `podman` (of course) and `shadow`.
`crun` helps running containers faster with less memory use.
`curl` is needed later in this tutorial.
Rest of them are simply useful for running other scripts (`bash`), getting some code (`git`), parsing container info (`jq`) and help with rendering text in CLI (`ncurses`).

```sh
apk add git jq podman crun shadow bash curl ncurses
```


### Prepare UID and GID mapping

UID and GID mapping should be set for every new user. Edit defaults:

```sh
nano /etc/login.defs
```

Make sure it contains:

```txt
SUB_UID_COUNT 10000
SUB_GID_COUNT 10000
```

You can set numbers bigger than 1000, if there will be many containers (and user accounts created inside them) run by users.
Save changes and exit editor.

This will allocate pool of "virtual" ids for every user. You can read more about this in tutorial found in [`podman`'s repository](https://github.com/containers/podman/blob/master/docs/tutorials/rootless_tutorial.md#etcsubuid-and-etcsubgid-configuration) and deep-dive into why this is needed at [Red Hat's blog](https://www.redhat.com/en/blog/understanding-root-inside-and-outside-container).

If you do not want to allocate pool of ids for every user, only for specific ones, you can skip editing `/etc/login.defs`. Instead, use the command `usermod` the way it's described in podman's repository.


### Enable pinging from containers

Make sure that pinging from rootless container is enabled:

```sh
sysctl -w "net.ipv4.ping_group_range=0 2000000"
echo 'net.ipv4.ping_group_range=0 2000000' > /etc/sysctl.d/podman.conf
```

You can read more about why this is needed in tutorial found in [`podman`'s repository](https://github.com/containers/podman/blob/master/docs/tutorials/rootless_tutorial.md#enable-unprivileged-ping).


### Add a new regular user

Execute following commands to create a new user account named "username" belonging to their own "username" group.
You can change "username" something else, of course; replacing it in all commands from this tutorial.

```sh
useradd -m -U -s /bin/bash username
passwd username
```

*NOTICE:* use `useradd` instead of `adduser`, to make sure "virtual" ids will be properly allocated for created user account.


### Enable podman "service"

At the moment of writing this, podman info on Alpine's wiki mentions adding and enabling "cgroups" service.
Unfortunately that's not enough. Rootless `podman` needs also two kernel modules to be loaded: `tun` and `fuse`.
That's why it's simpler to enable "podman" service instead: it loads modules and enables "cgroups" through its dependancy.

Edit config file for podman "service":

```sh
nano /etc/conf.d/podman
```

Change `podman_user` value to a regular user name, like this:

```txt
podman_user = "username"
```

Save changes and exit editor.

Enable the service.

```sh
rc-update add podman
rc-service podman start
```


## Configure Podman for user

Switch to the new user account:

```sh
su -l username
```

That's all! Well... almost.


## Test if it works OK.

While still being logged as regular user (`whoami` command shows "username"), check if podman can run and uses your config:

```sh
podman info | grep crun
```

You should see something like this:

```txt
	name: crun
	path: /usr/bin/crun
	  crun version 0.16
```

Finally test if podman can run containers properly. You can do that by either executing following "one-liner" command:

```sh
([ $(id -u) != "0" ] && [ $(podman run --rm -v $HOME:/host docker.io/alpine /bin/sh -c '[ "$container" = "podman" ] && (id -u | tee /host/test.log) && (chmod 0700 /host/test.log)') = "0" ] && [ $(cat $HOME/test.log) = "0" ] && [ $(stat -c "%U:%G" $HOME/test.log) = $(id -nu)":"$(id -ng) ] && (rm $HOME/test.log) && echo "That's all, it works :)") || echo "It failed for some reason :("
```

or by downloading and running [podman-test.sh](https://github.com/ahwayakchih/nobbic/blob/main/tools/podman-test.sh) script from [nobbic](https://github.com/ahwayakchih/nobbic) project (be sure to check its source - never run anything directly from web, if you do not know what it's going to do to your system!):

```sh
curl -sL https://raw.githubusercontent.com/ahwayakchih/nobbic/main/tools/podman-test.sh | bash -s --
```

If it did not work, report any errors - maybe we can fix it. Otherwise...

Have fun running containers rootlessly!
