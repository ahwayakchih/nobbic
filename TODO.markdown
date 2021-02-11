TODO
====

- write proper README and docs content
- add support for Let's Encrypt when `APP_USE_FQDN` is specified and names existing domain name (not IP number).
- stop replacing app.js and src/cli/index.js, run config generator instead before calling nodebb in entrypoint.sh.
  we're not running in changing environment (old OpenShift v2) any more, environment variables in containers are
  immutable. To change them, one has to hack it, or simply re-create container. So there's no real need to override
  data in nconf dynamically.
  Also, it would help users to apply known solutions, if they could simply edit config.js.
  **update:** replacing may still be needed, or writing config AFTER install, because install parses url from config,
  and if there's a port specified, it overrides port setting with the one from url. Which breaks stuff if external port
  is defferent than the one NodeBB should listen on, e.g., example.com:8080 -> 4567.
- add support for something like `APP_ADD_POSTGRES=postgres://user@hostname:port/dbname` for all databases,
  so it will be easier to backup and restore access to external databases, and define by user when first start/build is done.
- option for NodeBB to keep building assets in `series` mode
- option to specify additional plugins when creating instance, so they are installed and
  activated from the start.
- optional, mini-test (puppeteer-based?) to run after start
- show README content in `./app help`?
- add support for specifying more than one app name at the same time for build, start, upgrade and stop?
- add command to send online users a message, e.g., "forum will close in 2 minutes, we will be back in about 10 minutes"
- wait X time before closing forum, so users can save whatever they were working on
- rewrite whole thing in Go :D
