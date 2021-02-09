#!/bin/sh

# WARNING: This script has to be sourced by os-install-service.sh script.
#          It should be run on a system that uses OpenRC init system.

serviceFile=$(mktemp -p ./)
env "${__DIRNAME}/handlebar.sh" "${__DIRNAME}/openrc.handlebarsh" > "$serviceFile"
chmod +x "$serviceFile"
unitFile="/etc/init.d/$APP_NAME"

echo "Service file for $APP_NAME was created as $serviceFile"

if command su --help &>/dev/null ; then
	echo "Trying to install it now as root user..."
	su -c "cp -aT '$serviceFile' '$unitFile' && (rc-service $APP_NAME restart || (rc-update add $APP_NAME && rc-service $APP_NAME start))"\
		&& rm $serviceFile\
		&& echo "Done"\
		&& exit 0
	echo "Failed"
fi

echo "Ask system administrator to copy it to $unitFile and let init system know about it"
echo "For example:"
echo "cp -aT '$serviceFile' '$unitFile'"
echo "  && rc-update add $APP_NAME"
echo "  && rc-service $APP_NAME start"
echo "Below is content of the file."
echo ""
cat $serviceFile
