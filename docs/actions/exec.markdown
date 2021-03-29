[Usage](../Usage.markdown)
==========================

## `exec` APP_NAME COMMAND [ARG...]

Runs a single command inside NodeBB's container. For example:

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

There's an additional `onbb_exec_command` command available there, which allows to call special functions inside NodeBB's process:

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


If you want to run multiple commands or whole scripts inside NodeBB's container, check [`bash`](./bash.markdown) action.
