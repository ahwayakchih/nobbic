[Usage](../Usage.markdown)
==========================

## `cleanup` ["nodebb"|"node"|"repo"]

To remove all installations:

```sh
nobbic cleanup nodebb
```

To remove all installations and cached images:

```sh
nobbic cleanup node && nobbic cleanup repo
```

### Cleaning up everything

**WARNING:** this will remove ALL the containers, images and volumes, not just the ones created with the help of `nobbic`!

To remove everything from podman, simply run:

```sh
podman system prune -a
podman volume prune
```

Sometimes it may not work, for whatever reason, in which case try to remove everything in small steps, one-by-one.

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
