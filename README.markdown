Nobbic
======

Nobbic helps you nicely fit [NodeBB](https://nodebb.org/), database and other stuff into a single pod with containers controlled by [`podman`](https://podman.io/).

While it's quite easy to start the NodeBB docker container alone, things complicate quickly when one wants to start also database container, [NGINX](https://www.nginx.com/) proxy container, etc... all the while trying out different versions of software. It's not difficult, but it takes time (and a lot of reading) if it's not something you do everyday already.

Best of all is that after NodeBB is installed and running, it can be controlled with usual `podman` commands.
Nobbic does not usurp ownership of anything. It just helps to [set things up and running](./docs/actions/start.markdown), and then may help with [backing them up](./docs/actions/backup.markdown), [upgrading](./docs/actions/upgrade.markdown) and [restoring](./docs/actions/restore.markdown), but only if you want to - it's all optional.


## Requirements

All it requires to start is the [`bash`](https://www.gnu.org/software/bash/) shell and the `podman` installed and running on a [Linux](https://www.linux.org/) operating system.

**Podman** should be at least **v2.2.1** and **[configured for running rootless](https://github.com/containers/podman/blob/master/docs/tutorials/rootless_tutorial.md)**.

If you're not running Linux at the moment, or just do not want to change anything in how it's set up, simplest way to test whole thing is to [install Alpine Linux (with podman)](./docs/SetupPodmanOnAlpineHost.markdown) in a virtual machine (like [QEMU](https://www.qemu.org/)).


## Compatibility

It was tested with various versions of NodeBB between (and including) v1.12.1 and v1.16.2.
Depending on NodeBB version, it was tested with [Node.js](https://nodejs.org/) versions from 8 to 15, and various versions and combinations of databases supported by NodeBB ([MongoDB](https://www.mongodb.com/), [PostgreSQL](https://www.postgresql.org/) and [Redis](https://redis.io/)).

For a full list of software, read [docs/Compatibility.markdown](./docs/Compatibility.markdown).


## Installation

You can download ZIP archive with this project from [GitHub](https://github.com/ahwayakchih/nobbic/archive/main.zip)
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

You can add nobbic's path to the `PATH` environment variable, or keep prefixing commands with path to its location, e.g., `./nobbic` or `~/nobbic/nobic`, etc...
For clarity, example commands following in this and other documents found in [docs](./docs) subdirectory will not be prefixed.


## Usage

To quickly proceed to creating and starting NodeBB, try:

```sh
APP_ADD_REDIS=1 nobbic start my-new-forum
```

That will start latest released NodeBB version, with latest version of Redis database, and make it accessible through "http://localhost:8080" URL.

It will take some time to download and prepare all the stuff for the first time (somewhere between 15-30 minutes, but it all depends on network, available processor(s) and RAM).
Every next try that uses the same Node.js version, should build much faster. Simply starting the same pod, once it was created, will be nearly as fast as if NodeBB was started directly, without any containers.

Read [docs/Usage.markdown](./docs/Usage.markdown) to see full list of supported actions.


## TODO

This is not a finished project yet (it may never be, since it depends on other projects that are being worked on also).

Read [TODO.markdown](./TODO.markdown) to see a list of changes that are already planned.


## Why "Nobbic"?

Because it's a **No**de**BB** **I**n a **C**ontainer ;).
