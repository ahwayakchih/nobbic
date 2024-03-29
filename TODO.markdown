TODO
====

- Check if we can use `podman container checkpoint` and `podman container restore` commands for our backup/restore
  functionality. That would simplify our scripts a lot, but could be more resource consuming (larger backups).
- Make NGINX script add itself as `--required` to NodeBB container, so it will be started earlier
  (and be able to show some kind of a placeholder page while NodeBB and database are started).
  NodeBB can use `--required` to specify database(s) too.
  This requires changing the way scripts prepare containers - it needs two passes. First they prepare all info,
  then containers are created. Otherwise when nginx requires nodebb, it cannot be created, because nodebb
  container is created last.
- do not downgrade NODEBB_VERSION when restoring/upgrading without specifying version having NodeBB setup using
  next beta version (reported by @nhlpl).
- add support for Let's Encrypt when `APP_USE_FQDN` is specified and names existing domain name (not IP number).
- stop replacing app.js and src/cli/index.js, run config generator instead before calling nodebb in entrypoint.sh.
  we're not running in changing environment (old OpenShift v2) any more, environment variables in containers are
  immutable. To change them, one has to hack it, or simply re-create container. So there's no real need to override
  data in nconf dynamically.
  Also, it would help users to apply known solutions, if they could simply edit config.js.
  **update:** replacing may still be needed, or writing config AFTER install, because install parses url from config,
  and if there's a port specified, it overrides port setting with the one from url. Which breaks stuff if external port
  is defferent than the one NodeBB should listen on, e.g., example.com:8080 -> 4567.
- option for NodeBB to keep building assets in `series` mode
- option to specify additional plugins when creating instance, so they are installed and
  activated from the start.
- optional, mini-test (puppeteer-based?) to run after start
- add "recovery" mode: disable non-standard plugins, build assets and restart (suggested by @nhlpl)
- add support for specifying more than one app name at the same time for build, start, upgrade, backup, restore and stop?
- when no app/pod name is specified backup all of them?
- ask (or require "force" flag) before removing?
- add command to send online users a message, e.g., "forum will close in 2 minutes, we will be back in about 10 minutes"
- wait X time before closing forum, so users can save whatever they were working on
- optimize backups (use fastest formats for each database engine) and restore (add node_modules volume)
- add support for backing up and restoring external (those added as db url) databases?
- consider something like "continous backup", where data is stored in a "universal" format. that would not only speed up
  process of exporting backup, but also allow for such extravagant thing as jumping from one database engine to another,
  e.g., from MongoDB to PostgreSQL and/or vice versa.
- rewrite whole thing in Go :D
