Compatibility
=============

## Podman

Nobbic was created while **podman v2.2.1** was current. Now it's tested with podman **v3.1**.

It's tested ONLY in rootless mode.

If, for whatever reason, you use podman version older than v3.0, switch runtime to `crun`, by changing configuration in `~/.config/containers/containers.conf` from default to:

```
runtime = "crun"
```


## NodeBB

Project was tested with various versions of **NodeBB** between (and including) **v1.12.1** and **v1.16.2**.


## Node.js

Depending on NodeBB version, project was tested with **Node.js** versions **8**, **10**, **12**, **13**, **14** and **15** using Alpine Linux based images from docker.io.


## Databases

Project was tested and is known to work with following database images from docker.io (assume official repository, i.e., same as db's short-name, unless specified otherwise):


### postgres (PostgreSQL)

- 9.6.20-alpine
- 10.15-alpine
- 11.10-alpine
- 12.5-alpine
- 13.1-alpine
- *bitnami/postgresql:* 13.2.0


### mongo (MongoDB)

- 3.6.21-xenial
- 4.0.22-xenial
- 4.2.12-bionic
- 4.4.3-bionic
- *bitnami/mongodb:* 4.4.3-debian-10-r43
- *bitnami/mongodb:* 4.4.4

### redis (Redis)

- 5.0.10-alpine
- 6.0.10-alpine
- 6.2-rc2-alpine
- 6.2-rc3-alpine
- 6.2.1-alpine
- *bitnami/redis:* 6.0 ([build/start](./actions/start.markdown) with an additional `CONTAINER_ENV_REDIS_ALLOW_EMPTY_PASSWORD=yes` environment variable)

## HTTP(S) servers

Project was tested with **NGINX v1.19-alpine** and **v1.18.0-alpine** images from docker.io.
