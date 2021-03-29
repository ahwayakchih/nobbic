[Usage](../Usage.markdown)
==========================

## `bash` APP_NAME

Switches your current CLI to bash command line inside the NodeBB's running container.
This can be useful, if you need to run more than one command in that container (for running a single command, check [`exec`](./exec.markdown) action).

Use `exit` command, to exit from container shell back to your previous shell.

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

This can be useful for troubleshooting, e.g., disabling problematic plugin (as mentioned in [NodeBB's FAQ](https://docs.nodebb.org/faq/#i-installed-an-incompatible-plugin-and-now-my-forum-wont-start)):

```sh
nobbic bash my-new-forum
```

and then:

```sh
cd nodebb
./nodebb reset -p nodebb-plugin-pluginName
./nodebb build
```

or disable all plugins:

```sh
cd nodebb
./nodebb reset -p
./nodebb build
```
