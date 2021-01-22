Cleaning up podman
==================

If `podman system prune -a` does not work for any reason, you may try to remove everything in small steps.

Remove containers first:

```sh
podman rm -a
```

Next go pods:

```sh
podman pod rm -a
```

Next go volumes:

```sh
podman volume prune
```

Finally, remove all images:

```sh
podman rmi -a
```

If any of the commands errors out and cannot remove stuff, try adding `--force`, e.g., `podman rm -a --force`.
