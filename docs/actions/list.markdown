[Usage](../Usage.markdown)
==========================

## `list` APP_NAME

This action simply passes output of `podman pod ps` filtered for pods created with nobbic.

```sh
nobbic list
```

It should output something like this:

```txt
POD ID        NAME    STATUS  CREATED       INFRA ID      # OF CONTAINERS
34e98ed6fd45  one     Exited  42 hours ago  50ae843b5b8d  5
```

Since it just passes arguments, you can pass whatever `podman` supports. For example:

```sh
nobbic list --format '{{.Name}}'
```

It should output something like this:

```txt
one
```