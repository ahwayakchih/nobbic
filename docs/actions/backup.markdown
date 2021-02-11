Usage
=====

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
