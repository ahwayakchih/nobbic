[Usage](../Usage.markdown)
==========================

## `tunnel` APP_NAME

Creates a tunnel from local port (defaults to "80") to port used by specified APP_NAME.

**WARNING:** This tunnel was implemented for SSL certification process only. It is not suited for running in production environment!

You can set TUNNEL_PORT environment variable to custom port number, if you do not want to tunnel from default port 80.

To access NodeBB through default HTTP(S) port(s) (80 and 443), read about configuring firewall (or `iptables`) on your system of choice.

This is one of the only two actions (the other one being [`install`](./install.markdown)) that will ask for `root` privilages. If allowed, only this `nc`-based tunnel will be run as privilaged user. No other software will run with higher privilages.
