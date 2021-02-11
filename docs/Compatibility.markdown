Compatibility
=============

## NodeBB

Project was tested with various versions of NodeBB between (and including) v1.12.1 and v1.16.2.

## Node.js

Depending on NodeBB version, project was tested with Node.js versions 8, 10, 12, 13, 14 and 15 images from docker.io, all of them using Alpine Linux as a base.

## Databases

Project was tested and is known to work with following database images from docker.io:

### postgres (PostgreSQL)

- 9.6.20-alpine
- 10.15-alpine
- 11.10-alpine
- 12.5-alpine
- 13.1-alpine

### mongo (MongoDB)

- 3.6.21-xenial
- 4.0.22-xenial
- 4.2.12-bionic
- 4.4.3-bionic

#### Also from 3rd party:

- bitnami/mongodb:latest (4.4.3-debian-10-r43 at the time of writing this)

### redis (Redis)

- 5.0.10-alpine
- 6.0.10-alpine
- 6.2-rc2-alpine
- 6.2-rc3-alpine

## HTTP(S) servers

Project was tested with NGINX v1.19.6-alpine and v1.18.0-alpine images from docker.io.
