FROM docker.io/ahwayakchih/nodeapp:312.1415

ARG NODE_ENV
ARG NODEBB_GIT
ARG NODEBB_VERSION
ARG CONTAINER_APP_NAME

ENV NODE_ENV=${NODE_ENV:-production}
ENV NODEBB_GIT ${NODEBB_GIT:-https://github.com/NodeBB/NodeBB.git}
ENV NODEBB_VERSION ${NODEBB_VERSION:-1.15.5}
ENV CONTAINER_APP_NAME ${CONTAINER_APP_NAME:-nodebb}

# Pass following environment variables when running this container.
# WARNING: DO NOT SET THEM WHEN BUILDING THE CONTAINER (they will be kept with it, i.e., password will be shared)!
# Optional, for example: admin@example.com
# ENV CONTAINER_LOGIN
# Optional, defaults to CONTAINER_LOGIN, or CONTAINER_APP_NAME@NODEBB_FQDN, for example: nodebb@example.com
# ENV NODEBB_ADMIN_EMAIL
# Optional, defaults to null
# ENV CONTAINER_NODEJS_IP
# Optional, defaults to 8080
# ENV CONTAINER_NODEJS_PORT
# Optional, defaults to either 8000 (ws) or 8443 (wss)
# ENV CONTAINER_WEBSOCKET_PORT
# Optional, domain name, for example "nodebb.example.com"
# ENV CONTAINER_APP_DNS_ALIAS
# Optional, IP number or domain name, for example: 192.168.100.100
# ENV CONTAINER_APP_DNS
# Optional, defaults to "nodebb"
# ENV CONTAINER_MONGODB_DB_NAME
# Required when using MongoDB
# ENV CONTAINER_MONGODB_DB_HOST
# Required when using MongoDB
# ENV CONTAINER_MONGODB_IP
# Required when using MongoDB
# ENV CONTAINER_MONGODB_DB_PASSWORD
# Required when using MongoDB
# ENV CONTAINER_MONGODB_DB_PORT
# Required when using MongoDB
# ENV CONTAINER_MONGODB_DB_USERNAME
# Required when using Mongolab
# ENV MONGOLAB_URI
# Required when using Redis
# ENV CONTAINER_REDIS_HOST
# Required when using Redis
# ENV CONTAINER_REDIS_PORT
# Required when using Redis
# ENV REDIS_PASSWORD

ENV CONTAINER_REPO_DIR /app/
ENV CONTAINER_DATA_DIR /data/
VOLUME /data

USER root
# bash for our scripts, patch for applying patches, jq for parsing package.js, bind-tools for dig (to check public IP)
RUN apk add --no-cache bash patch jq bind-tools

COPY .container /app/.container
COPY logs /app/logs
COPY patches /app/patches
RUN chown -R node:node /app/* /app/.container

USER node:node

WORKDIR /app

CMD ["/bin/bash", "-l", "./.container/entrypoint.sh"]