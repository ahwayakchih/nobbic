#!/bin/sh

# WARNING: This script has to be sourced by os-install-service.sh script.
#          It should be run on a system that uses SystemD init system.

serviceFile="${APP_NAME}.service"
generate openrc.handlebarsh $serviceFile || return 1
chmod +x "$serviceFile"
unitFile="/etc/systemd/system/${APP_NAME}.service"

echo "Service file for $APP_NAME was created as $serviceFile"

if command su --help &>/dev/null ; then
	echo "Trying to install it now as root user..."
	su -c "cp -aT '$serviceFile' '$unitFile' && systemctl daemon-reload && (systemctl restart ${APP_NAME}.service || (systemctl start ${APP_NAME}.service && systemctl enable ${APP_NAME}.service))"\
		&& rm $serviceFile\
		&& echo "Done"\
		&& exit 0
	echo "Failed"
fi

echo "Ask system administrator to copy it to $unitFile and let init system know about it"
echo "For example:"
echo "cp -aT '$serviceFile' '$unitFile'"
echo "  && systemctl start ${APP_NAME}.service"
echo "  && systemctl enable ${APP_NAME}.service"
echo "To check its logs:"
echo "journalctl -u ${APP_NAME}.service -b -f"
echo "Below is content of the file."
echo ""
cat $serviceFile
