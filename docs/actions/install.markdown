Usage
=====

## `install` APP_NAME

Generates a system service file and tries to install it.

Service file simply makes sure that pod will be started after operating system reboots.

This is the only action that needs `root` permissions, but only if service file has to be installed.
Without permissions, it will show instructions on how to enable service in the system.