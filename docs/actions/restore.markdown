[Usage](../Usage.markdown)
==========================

## `restore` APP_NAME [BACKUPS_DIR] [BACKUP_NAME]

Restores pod from specified backup, or latest backup available.

Just like with [`backup`](./backup.markdown), both `BACKUPS_DIR` and `BACKUP_NAME` arguments are optional.

Same as with [`upgrade`](./upgrade.markdown) action, you can override options used to create the pod before, e.g., to restore data, but change software versions, URL and/or any other supported options.
