#!/bin/sh

# WARNING: This script has to be sourced by host-install-service.sh script.
#          It should be run on a system that uses OpenRC init system.

serviceFile="${APP_NAME}.service"
generate openrc.handlebarsh $serviceFile || return 1
chmod +x "$serviceFile"
unitFile="/etc/init.d/$APP_NAME"

echo "Service file for $APP_NAME was created as $serviceFile"

if command su --help &>/dev/null ; then
	echo "Trying to install it now as root user..."
	([ ! -f "$unitFile" ] && exit 0 || (read -r -p "'$unitFile' exists. Overwrite? [n/Y] " confirmation && [ "$confirmation" = 'Y' ] || exit 1))\
		&& (su -c "cp -aT '$serviceFile' '$unitFile' && ((rc-service -e $APP_NAME || rc-update add $APP_NAME) && rc-service $APP_NAME restart)"\
			&& rm $serviceFile\
			&& echo "Done"\
			|| echo "Failed" && exit 1)\
		&& exit 0\
		|| echo "Cancelled"
	echo ""
fi

fullPath=$(readlink -f "$serviceFile")

echo "Ask system administrator to copy file from"
echo "$fullPath"
echo "to"
echo "$unitFile"
echo "and make OpenRC add & start the service."
echo "For example:"
echo ""
echo "#==========================================."
echo ""
echo "  cp -aT '$fullPath' '$unitFile'\\"
echo "    && rc-update add $APP_NAME\\"
echo "    && rc-service $APP_NAME start"
echo ""
echo "#==========================================^"
