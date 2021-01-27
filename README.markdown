NodeBB in the container
=======================

This document needs A LOT of work, but for now:

```sh
./app help
```

## Requirements

All it requires to start is a `bash` shell and `podman`.

**Podman** should be at least **v2.2.1** and **[configured for running rootless](https://github.com/containers/podman/blob/master/docs/tutorials/rootless_tutorial.md)**.
Simplest way to test whole thing is to [install Alpine Linux (with podman)](./docs/SetupPodmanOnAlpineHost.markdown) in a virtual machine (like QEMU, VirtualBox or VMWare).

Project was tested ONLY in rootless mode, with configuration in `~/.config/containers/containers.conf`, changed from defaults to:

```
runtime = "crun"
```

## Compatibility

It was tested with various versions of NodeBB between (and including) v1.12.1 and v1.16.2.
Depending on NodeBB version, it was tested with Node.js versions 8, 10 and 15.

It was tested and is known to work with following database images from docker.io:

### postgres (PostgreSQL)

- 9.6.20-alpine
- 10.15-alpine
- 11.10-alpine
- 12.5-alpine
- 13.1-alpine

### mongo (MongoDB)

- 3.6.21-xenial
- 4.4.3-bionic

### redis (Redis)

- 5.0.10-alpine
- 6.0.10-alpine
- 6.2-rc2-alpine

## Cleanup

To remove everything from podman, simply run:

```sh
podman system prune -a
podman volume prune
```

Sometimes it may not work, for whatever reason, in which case read [docs/PodmanCleanup](./docs/PodmanCleanup.markdown).

## TODO

- option for NodeBB to keep building assets in "series" mode
- option to specify additional plugins when creating instance, so they are installed and
  activated from the start.
- support installations with Redis as the only database (enable data persistence in Redis, backup & restore)
- clear situation with NodeBB /data - package.json is not link, but a copy, others are linked, etc...
- add musl-locales to Postgres (and other?) images: https://github.com/docker-library/postgres/issues/501
- optional, mini-test (puppeteer-based?) to run after start
- write proper README content
- show README content in `./app help`?
- add nginx container
