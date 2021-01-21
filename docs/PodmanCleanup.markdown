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
podman rm -a
```
