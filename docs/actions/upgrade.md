Usage
=====

## `upgrade` APP_NAME

Upgrades NodeBB's version to the one specified in environment.

For example, if your forum was created with NodeBB v1.12.1, you can use command like:

```sh
NODEBB_VERSION=latest nobbic upgrade my-new-forum
```

It will create a backup, stop current pod, remove it, restore from backup but using new version of NodeBB,
and start it (including runnig NodeBB's upgrade procedure).

You can also override `NODE_VERSION`, `APP_USE_FQDN` (if you want to change also domain name), and other options.
See list of all options at [/docs/actions/start.markdown](./start.markdown).
