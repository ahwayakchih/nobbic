Usage
=====

```sh
nobbic ACTION [ARG...]
```

Nobbic offers an easy way to install and run NodeBB with one of PostgreSQL, MongoDB or Redis as a main database, or one of the first two as a main and Redis as a session database.

It also allows to create backups and restore from those backups.

Most of the actions require specifying APP_NAME as their first argument. APP_NAME is simply a name of your chosing for the NodeBB installation.

Following "actions" are implemented so far:

* `list`

  Lists pods created with nobbic.

  [Read more](./actions/list.markdown)

* `build` APP_NAME

  Builds pod with containers using options passes through environment variables.

  [Read more](./actions/start.markdown)

* `start` APP_NAME

  Starts pod with containers, building it first if it does not exist yet.

  [Read more](./actions/start.markdown)

* `info` APP_NAME

  Shows information about pod and its containers.

  [Read more](./actions/info.markdown)

* `bash` APP_NAME

  Switches to the bash shell inside NodeBB's container.

  [Read more](./actions/bash.markdown)

* `exec` APP_NAME COMMAND [ARG...]

  Executes single command inside NodeBB's container's shell.

  [Read more](./actions/exec.markdown)

* `backup` APP_NAME [BACKUPS_DIR] [BACKUP_NAME]

  Creates backup directory with data from pod's containers.

  [Read more](./actions/backup.markdown)

* `restore` APP_NAME [BACKUPS_DIR] [BACKUP_NAME]

  Restores pod and containers with data from backup.

  [Read more](./actions/restore.markdown)

* `upgrade` APP_NAME

  Creates backup, recreates pod using options from environment variables.

  [Read more](./actions/upgrade.markdown)

* `install` APP_NAME

  Creates system's (OpenRC or SystemD) service file and tries to install it.

  [Read more](./actions/install.markdown)

* `stop` APP_NAME

  Stops the pod and its containers.

  [Read more](./actions/stop.markdown)

* `remove` APP_NAME

  Removes pods, its containers and their data.

  [Read more](./actions/remove.markdown)

* `cleanup` ["nodebb"|"node"|"repo"]

  Removes pods (if any are still existing) and NodeBB or both NodeBB and Node.js images. Or volumes with NodeBB repository and shared data.

  [Read more](./actions/cleanup.markdown)
