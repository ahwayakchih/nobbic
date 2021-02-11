[Usage](../Usage.markdown)
==========================

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