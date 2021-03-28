[Usage](../Usage.markdown)
==========================

## `install` APP_NAME

Generates a system service file and tries to install it.
Once installed, service file simply makes sure that your NodeBB pod will be started along with the operating system next time it is rebooted.

This is one of the only two actions (the other one being [`tunnel`](./tunnel.markdown)) that asks for `root` privilages.

Enter valid password only if you want generated service file to be installed in host operating system.
Otherwise just press ENTER key. It will omit installation and show instructions on how to enable service in the system manually.
