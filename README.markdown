NodeBB in the container
=======================

This document needs A LOT of work, but for now:

```sh
./app help
```

## Requirements

All it requires to start is a `bash` shell and `podman`.

**Podman** should be at least **v2.2.1** and **[configured for running rootless](https://github.com/containers/podman/blob/master/docs/tutorials/rootless_tutorial.md)**.

Project was tested ONLY in rootless mode, with following configuration options changed from defaults:

In `~/.config/containers/containers.conf`, changed:

```
cgroup_manager = "cgroupfs"
static_dir = "$HOME/.local/share/containers/storage/libpod"
volume_path = "$HOME/.local/share/containers/storage/volumes"
runtime = "crun"
```

In `~/.config/containers/storage.conf`,changed:

```
driver = "overlay"
# Here change numer "1000" to your user id, or output of `id -u` command
runroot = "/run/user/1000/containers"
graphroot = "$HOME/.local/share/containers/storage"
rootless_storage_path = "$HOME/.local/share/containers/storage"
mount_program = "/usr/bin/fuse-overlayfs"
mountopt = ""
```
