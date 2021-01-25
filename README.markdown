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

## Cleanup

To remove everything from podman, simply run:

```sh
podman system prune -a
podman volume prune
```

Sometimes it may not work, for whatever reason, in which case read [docs/PodmanCleanup](./docs/PodmanCleanup.markdown).

## TODO

- option to specify additional plugins when creating instance, so they are installed and
  activated from the start.
- support installations with Redis as the only database (enable data persistence in Redis)
- clear situation with logs (some are not written, they are in 3 different places, etc...),
  maybe drop creating log files and simply depend on `podman logs`?
- clear situation with NodeBB /data - package.json is not link, but a copy, others are linked, etc...
- add musl-locales to Postgres (and other?) images: https://github.com/docker-library/postgres/issues/501
- optional, mini-test (puppeteer-based?) to run after start
- support for podman options like cpu and ram limits
- setting up restart options (unless-stopped by default?)
- setup healthcheck commands
- write proper README content
- show README content in `./app help`?
- maybe support auto-update configuration?
- add nginx container
