Usage
=====

Project offers an easy way to instal and run NodeBB with one of PostgreSQL, MongoDB or Redis as a main database,
or one fo the first two as main and Redis as a session database.

It also allows to create backups and restore from those backups.

Most of the actions require specifying APP_NAME as their first argument. APP_NAME is simply a name of your chosing for the NodeBB installation.

Following "actions" are implemented so far:

## `build` APP_NAME
## `start` APP_NAME

The only difference between `build` and `start` is that `start` will automatically `build` if specified forum was not built yet and then it will start pod and containers (`build` does not start anything).

Both support various options passed through environment variables. You can either set them up beforehand or use one liners,
like it was shown in a [README.markdown](../README.markdown):

```sh
APP_USE_FQDN=localhost APP_ADD_REDIS=1 ./nobbic start my-new-forum
```

This will create and start pod named "my-new-forum", that will use latest Redis database and serve NodeBB at http://localhost:8080.

For a full list of available options, read [BuildAndStart.markdown](./BuildAndStart.markdown).

## `info` APP_NAME

This action simply outputs information about selected pod. It can be used as soon as one is built:

```sh
nobbic info my-new-forum
```

It should output something like this (everyting depends on options you used to build the pod):

```txt
Hosted on Arch Linux using Podman v2.2.1
NodeBB v1.12.1 is run with Node.js v8.17.0
NodeBB SHA:041cde4dbce64c8f748c81800fac8f6738bf0005
Built with Nobbic v0.5.0
It uses:
- mongodb (docker.io/mongo:bionic)
  with MONGO_VERSION=4.4.3 GOSU_VERSION=1.12 JSYAML_VERSION=3.13.1
- nodebb (localhost/nodebb:8.17.0-1.12.1)
  with YARN_VERSION=1.21.1 NODEBB_VERSION=1.12.1 NODE_VERSION=8.17.0
When started, it will await connections at https://localhost:8080
```

## `bash` APP_NAME

Switches your current CLI to bash command line inside the NodeBB's container.
Use `exit` command, to exit from container back into your previous shell.

For example, if you run following commands, line-by-line separately:

```sh
pwd
nobbic bash my-new-forum
pwd
exit
```

they should output something like:

```txt
/home/username
/app
```


## `exec` APP_NAME COMMAND [ARG...]

...

## `backup` APP_NAME [BACKUPS_DIR] [BACKUP_NAME]

...

## `upgrade` APP_NAME

...

## `restore` APP_NAME [BACKUPS_DIR] [BACKUP_NAME]

...

## `install` APP_NAME

...

## `stop` APP_NAME

...

## `remove` APP_NAME

To just remove single installation of NodeBB, use following command line:

```sh
nobbic remove my-new-forum
```

Of course, replace `my-new-forum` with whatever name you used to create it in the first place.


## `cleanup` ["nodebb"|"node"|"repo"]

To remove all installations:

```sh
nobbic cleanup nodebb
```

To remove all installations and cached images:

```sh
nobbic cleanup node && nobbic cleanup repo
```

To remove everything from podman, simply run:

```sh
podman system prune -a
podman volume prune
```

Sometimes it may not work, for whatever reason, in which case read [docs/PodmanCleanup](./docs/PodmanCleanup.markdown).
