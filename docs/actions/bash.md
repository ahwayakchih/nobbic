Usage
=====

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
