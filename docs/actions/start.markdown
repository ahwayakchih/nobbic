[Usage](../Usage.markdown)
==========================

## `build` APP_NAME
## `start` APP_NAME

The only difference between `build` and `start` is that `start` will automatically call `build`, if specified NodeBB pod was not built yet, and then it will start pod and its containers (`build` does not start anything).

Both support the same set of options passed through environment variables. You can either set them up beforehand or use one-liners like it was shown in a [README.markdown](../README.markdown):

```sh
APP_ADD_REDIS=1 nobbic start my-new-forum
```

This will create and start pod named "my-new-forum", that will use latest Redis database and serve NodeBB at http://localhost:8080.

To use MongoDB instead of Redis database, try:

```sh
APP_ADD_MONGODB=1 nobbic start my-forum
```

It will create pod that includes MongoDB based on Ubuntu bionic (default) and NodeBB latest (default), and then run it with minimum required Node.js version for that NodeBB.

You can use specific database image(s) with the created pod by setting one or two of:

- `APP_ADD_MONGODB` can be set to 1, to use default 'bionic' image, or to specific image name, e.g., docker.io/mongo:4.4.2-bionic
- `APP_ADD_POSTGRES` can be set to 1, to use default 'alpine' image, or to specific image name, e.g., docker.io/postgres:13.1-alpine
- `APP_ADD_REDIS` can be set to 1, to use default 'alpine3.12' image, or to specific image name, e.g., docker.io/redis:6.0.9-alpine

You can specify two of them as long as one of them is Redis. That will make NodeBB use Redis for session storage only.
*Keep in mind that support for PostgreSQL was added in NodeBB v1.10.x.*

You can also set any of those three to "db url", e.g., "mongodb://username:password@hostname:port/db_name", "postgresql://username:password@hostname:port/db_name" or "redis://:password@hostname:port/db_name". If you do so, database container will not be created and NodeBB will try to connect to specified "external" database. There's no support for [`backup`](./backup.markdown) or [`restore`](./restore.markdown) in case of external databases.


You can specify domain name by setting `APP_USE_FQDN` environment variable. Set its value to "1" to autodetect it, or custom value (as long as the domain you specify does actually point to IP number of machine you are using to run NodeBB). For example:

```sh
APP_USE_FQDN=1 APP_ADD_REDIS=1 nobbic start my-new-forum
```

or

```sh
APP_USE_FQDN=example.com APP_ADD_REDIS=1 nobbic start my-new-forum
```


Similarly to databases, you can add local NPM mirror container to the pod, which may be helpful when you're testing various configurations, or simply running more than one forum.
Just set `APP_ADD_NPM` to 1, to use default 'verdaccio/verdaccio:latest' image, or to specific image name, e.g., docker.io/verdaccio/verdaccio:5.x.


You can also add NGINX container to serve static assets and load balance connections between multiple instances of NodeBB (see also `APP_USE_CLUSTER`):
Just set `APP_ADD_NGINX` to 1, to use default 'docker.io/nginx:alpine' image, or to specific image name, e.g., docker.io/nginx:stable-alpine


By default, forum will be run with Node.js version specified in the 'package.json' file.
You can enforce different version by setting `NODE_VERSION` environment variable.


By default, official 'docker.io/node:%NODE_VERSION%-alpine' image will be used for NodeBB.
You can change that by setting `APP_ADD_NODEBB` environment variable to some specific image name, e.g., 'some.repo/image:%NODE_VERSION%'.
'%NODE_VERSION%' placeholder will be replaced by `NODE_VERSION` value (either specified, or detected for selected NodeBB version).
If placeholder is missing from the image name, nothing will be replaced, so better make sure that image contains Node.js version that will work with selected NodeBB version.


You can set `NODEBB_VERSION` to select which version of the NodeBB forum to run. By default, latest release will be used.

For example:

```sh
NODEBB_VERSION=1.12.1 APP_ADD_POSTGRES=1 nobbic start my-forum
```

It will create pod with NodeBB v1.12.1 that uses PostgreSQL as database engine and sets its URL to http://localhost:8080.


By default, 'nodebb-repo' name will be used for volume containing clone of NodeBB git repository. It will be shared by all pods (**WARNING:** DO NOT create/restore/upgrade them concurrently!).
You can create separate volume for application by setting `NODEBB_REPO_VOLUME` environment variable with some unique name as its value.


Set `NODEBB_GIT` to the URL of git repository of NodeBB forum.
Official repository will be used by default, but you can specify different one, e.g., with your custom modifications.
It just has to follow example set by the official repository and create a tag per released version.


You can set `APP_USE_PORT` variable (http/https, defaults to 8080) to the port number you want the pod to listen on.


Set `APP_USE_CLUSTER` to a number higher than 1, to make NodeBB spin more than one process for handling connections (and NGINX will load balance between them, after it's also added to the pod).


Before container is created, specified (or default) images are pulled from repository (check: `podman pull --help`). You can pass additional arguments to pull command through environment variables:

- `PODMAN_PULL_ARGS_MONGODB` variable is used when pulling image for MongoDB database container,
- `PODMAN_PULL_ARGS_POSTGRES` variable is used when pulling image for PostgreSQL database container,
- `PODMAN_PULL_ARGS_REDIS` variable is used when pulling image for Redis database container,
- `PODMAN_PULL_ARGS_NPM` variable is used when pulling image for NPM mirror container,
- `PODMAN_PULL_ARGS_NGINX` variable is used when pulling image for NGINX server container.

You can set any additional environment variables for specific containers using CONTAINER_ENV_ prefix.

- `CONTAINER_ENV_NODE_*` variables will be set as NODE_* in nodebb container.
- `CONTAINER_ENV_NODEBB_*` variables will be set as * in nodebb container.
- `CONTAINER_ENV_MONGODB_*` variables will be set as * in mongodb container.
- `CONTAINER_ENV_POSTGRES_*` variables will be set as POSTGRES_* in postgres container.
- `CONTAINER_ENV_PG_*` variables will be set as PG* in postgres container.
- `CONTAINER_ENV_REDIS_*` variables will be set as * in redis container.
- `CONTAINER_ENV_NPM_*` variables will be set as * in npm container.
- `CONTAINER_ENV_NGINX_*` variables will be set as * in nginx server container.

You can replace command executed by container by setting environment variable for specific container.

- `CONTAINER_CMD_MONGODB` variable is used as a custom command passed to MongoDB database container,
- `CONTAINER_CMD_POSTGRES` variable is used as a custom command passed to PostgreSQL database container,
- `CONTAINER_CMD_REDIS` variable is used as a custom command passed to Redis database container,
- `CONTAINER_CMD_NPM` variable is used as a custom command passed to NPM mirror container,
- `CONTAINER_CMD_NGINX` variable is used as a custom command passed to NGINX server container.

You can pass additional arguments to podman commands used for creation of containers (check: `podman create --help`) through separate environment variables:

- `PODMAN_CREATE_ARGS_NODEBB` variable for NodeBB container,
- `PODMAN_CREATE_ARGS_MONGODB` variable for MongoDB database container,
- `PODMAN_CREATE_ARGS_POSTGRES` variable for PostgreSQL database container,
- `PODMAN_CREATE_ARGS_REDIS` variable for Redis database container,
- `PODMAN_CREATE_ARGS_NPM` variable for NPM mirror container,
- `PODMAN_CREATE_ARGS_NGINX` variable for NGINX server container.

You can also set `PODMAN_CREATE_ARGS` environment variable, to pass the same additional arguments to all `podman create` commands.

When container is created, its port number is automaticaly read from image. In case of more than one port being exposed by the image, you can specify its value through environment variable:

- `CONTAINER_MONGODB_PORT` for MongoDB container,
- `CONTAINER_POSTGRES_PORT` for PostgreSQL container,
- `CONTAINER_REDIS_PORT` for Redis container,
- `CONTAINER_NPM_PORT` for NPM container,
- `CONTAINER_NGINX_PORT` for NGINX container.
