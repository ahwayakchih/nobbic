[Usage](../Usage.markdown)
==========================

## `install` APP_NAME

Generates a system service file and tries to install it (will ask for root password, just hit enter if you don't want to give it permissions to install anything).

Service file simply makes sure that pod will be started after operating system reboots.

This is one of the only two actions (the other one being [`tunnel`](./tunnel.markdown)) that asks for `root` privilages. Enter valid password only if service file has to be installed.
Without permissions, it will show instructions on how to enable service in the system.