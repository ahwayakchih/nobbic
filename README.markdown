Nobbic
======

Nobbic helps you nicely fit [NodeBB](https://nodebb.org/), database and other stuff into a single pod with containers.

While it's quite easy to start the NodeBB docker container alone, things complicate quickly when one wants to start also database container, [NGINX](https://www.nginx.com/) proxy container, etc... all the while trying out different versions of software. It's not difficult, but it takes time (and a lot of reading) if it's not something you do everyday already.

Best of all is that after NodeBB is installed and running, it can be controlled with usual `podman` commands.
Nobbic does not usurp ownership of anything. It just helps to set thing up and running, and then may help with backing them up and restoring, but it's all optional.


## Requirements

All it requires to start is the [`bash`](https://www.gnu.org/software/bash/) shell and the [`podman`](https://podman.io/) installed. And a [Linux](https://www.linux.org/) operating system.

**Podman** should be at least **v2.2.1** and **[configured for running rootless](https://github.com/containers/podman/blob/master/docs/tutorials/rootless_tutorial.md)**.
Simplest way to test whole thing is to [install Alpine Linux (with podman)](./docs/SetupPodmanOnAlpineHost.markdown) in a virtual machine (like [QEMU](https://www.qemu.org/)).


## Compatibility

It was tested with various versions of NodeBB between (and including) v1.12.1 and v1.16.2.
Depending on NodeBB version, it was tested with [Node.js](https://nodejs.org/) versions 8, 10, 12, 13, 14 and 15, and various versions and combinations of databases supported by NodeBB ([MongoDB](https://www.mongodb.com/), [PostgreSQL](https://www.postgresql.org/) and [Redis](https://redis.io/)).

For a full list of software, read [docs/Compatibility.markdown](./docs/Compatibility.markdown).


## Installation

You can download ZIP archive with this project from [GitHub](https://github.com/ahwayakchih/nobbic)
and unzip it to selected directory, or git clone repository if you already have `git` installed:

```sh
git clone https://github.com/ahwayakchih/nobbic.git
```

Once you have directory with files in it, open command line and change to that directory, for example:

```sh
cd nobbic
```

Once it's "installed", you can use it from command line, for example:

```sh
./nobbic help
```

You can add nobic's path to the `PATH` environment variable, or keep prefixing commands with path to the script, e.g., `./nobbic` or `~/nobbic/nobic`, etc...
For clarity, example commands following in this and other documents found in [docs](./docs) subdirectory will not be prefixed.


## Usage

To quickly proceed to creating and starting NodeBB, try:

```sh
APP_USE_FQDN=localhost APP_ADD_REDIS=1 nobbic start my-new-forum
```

That will install latest released NodeBB version, with latest version of Redis database, and make it accessible through "http://localhost:8080" URL.

It will take some time to download and prepare all the stuff for the first time (somewhere between 15-30 minutes, but it all depends on network, processors and available RAM).
Every next try that uses the same Node.js version, should be much faster.

Read [docs/Usage.markdown](./docs/Usage.markdown) to see full list of supported actions.


## TODO

This is not a finished project yet (it may never will be).

Read [TODO.markdown](./TODO.markdown) to see a list of changes that are already planned.


## Why "Nobbic"?

Because it's a **No**de**BB** **I**n a **C**ontainer ;).
