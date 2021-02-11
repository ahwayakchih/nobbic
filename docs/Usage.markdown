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

Runs command inside NodeBB's container. For example:

```sh
nobbic exec my-new-forum ls -la
```

should output something like:

```txt
total 48
drwxr-xr-x    8 node     node          4096 Feb 11 15:11 .
dr-xr-xr-x   21 root     root          4096 Feb 11 15:09 ..
drwxr-xr-x    7 node     node          4096 Feb  2 15:00 .container
-rw-r--r--    1 node     node            37 Feb 11 15:11 NODEBB_GIT
-rw-r--r--    1 node     node             7 Feb 11 15:11 NODEBB_VERSION
-rw-r--r--    1 node     node             1 Feb 11 15:11 NODE_VERSION
-rw-------    1 node     node           404 Feb 11 15:08 POD_BUILD_ENV
drwxr-xr-x    2 node     node          4096 Feb 11 15:11 logs
drwxr-xr-t    2 root     root          4096 Feb 10 18:39 node
drwxr-xr-x    2 node     node          4096 Feb 10 18:38 node_modules
drwxr-xr-x   12 node     node          4096 Feb 11 15:12 nodebb
drwxr-xr-x    2 node     node          4096 Dec  9 13:14 patches
```


There's an additional `onbb_exec_command` command available there,
which allows to call special functions inside NodeBB's process:

```sh
nobbic exec my-new-forum onbb_exec_command help
```

should output something like:

```txt
Following commands are available:

   config
   resetPassword email
   help
```

So, to reset default NodeBB's administrator's password, use command like:

```sh
nobbic exec my-new-forum onbb_exec_command resetPassword my-new-forum@127.0.0.1
```

It should output an URL to "change password" page.


## `backup` APP_NAME [BACKUPS_DIR] [BACKUP_NAME]

Creates a backup directory containing data from database(s), archive with files uploaded by users to NodeBB, etc...
All the information needed to rebuild the pod whenever it's needed.

`BACKUPS_DIR` and `BACKUP_NAME` arguments are optional.

If `BACKUPS_DIR` is not provided, default `backups` sub-directory will be created in your current directory.

If `BACKUP_NAME` is not provided, default `[APP_NAME]_[CURRENT_DATE_TIME]` will be used for sub-directory
containing backup data. For example:

```sh
nobbic backup my-new-forum
```

will create directory like `/home/username/backups/my-new-forum_2021-02-10T19-04-06`
(assuming your current direcotry is `/home/username`).


## `restore` APP_NAME [BACKUPS_DIR] [BACKUP_NAME]

Restores pod from specified backup, or latest backup created.

Just like wth `backup`, both `BACKUPS_DIR` and `BACKUP_NAME` arguments are optional.

Same as with `upgrade` action, you can override options to restore data, but change software versions or some options.


## `upgrade` APP_NAME

Upgrades NodeBB's version to the one specified in environment.

For example, if your forum was created with NodeBB v1.12.1, you can use command like:

```sh
NODEBB_VERSION=latest nobbic upgrade my-new-forum
```

It will create a backup, stop current pod, remove it, restore from backup but using new version of NodeBB,
and start it (including runnig NodeBB's upgrade procedure).

You can also override `NODE_VERSION`, `APP_USE_FQDN` (if you want to change also domain name), etc...


## `install` APP_NAME

Generates a system service file and tries to install it.

Service file simply makes sure that pod will be started after operating system reboots.

This is the only action that needs `root` permissions, but only if service file has to be installed.
Without permissions, it will show instructions on how to enable service in the system.


## `stop` APP_NAME

Stops the pod. After this action finishes, NodeBB and other containers in the pod will not be running.
They'll still be available to start again.


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
