NodeBB in a container
=====================

This project's goal is to make it easy to setup new NodeBB installation in a pod (a set of connected containers).

While it's quite easy to start the NodeBB docker container alone, things complicate quickly when one wants
to start also database container, NGINX proxy container, etc... It's not difficult, but it takes time
(and a lot of reading) if it's not something you everyday already.


## Requirements

All it requires to start is the `bash` shell and the `podman` installed. And a Linux operating system.

**Podman** should be at least **v2.2.1** and **[configured for running rootless](https://github.com/containers/podman/blob/master/docs/tutorials/rootless_tutorial.md)**.
Simplest way to test whole thing is to [install Alpine Linux (with podman)](./docs/SetupPodmanOnAlpineHost.markdown) in a virtual machine (like QEMU, VirtualBox or VMWare).

Project was tested ONLY in rootless mode, with configuration in `~/.config/containers/containers.conf`, changed from defaults to:

```
runtime = "crun"
```


## Compatibility

It was tested with various versions of NodeBB between (and including) v1.12.1 and v1.16.2.
Depending on NodeBB version, it was tested with Node.js versions 8, 10, 12, 13, 14 and 15,
and various versions and combinations of databases.

For a full list of software, read [docs/Compatibility.markdown](./docs/Compatibility.markdown).


## Installation

You can download ZIP archive with this project from [GitHub](https://github.com/ahwayakchih/containerized-nodebb)
and unzip it to selected directory, or git clone repository if you already have `git` installed:

```sh
git clone https://github.com/ahwayakchih/containerized-nodebb.git
```

Once you have directory with files in it, open command line and change to that directory, for example:

```sh
cd containerized-nodebb
```

Once it's "installed", you can use it from command line, for example:

```sh
./app help
```

## Usage

To quickly proceed to creating and starting NodeBB, try:

```sh
APP_USE_FQDN=localhost APP_ADD_REDIS=1 ./app start my-new-forum
```

That will install latest released NodeBB version, with latest version of Redis database, and make it accessible through
"http://localhost:8080" URL.

It will take some time to download and prepare all the stuff for the first time
(somewhere between 15-30 minutes, but it all depends on network, processors and available RAM).
Every next try that uses the same Node.js version, should be much faster.

Read [docs/Usage.markdown](./docs/Usage.markdown) for more info about all the possibilities.

## TODO

This is not a finished project yet (it may never will be).

Read [TODO.markdown](./TODO.markdown) to see a list of changes that are already planned.
