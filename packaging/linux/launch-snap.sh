#!/bin/sh
# The KDE launcher sets these variables to a file absent from its content snap.
export FONTCONFIG_PATH=/etc/fonts
export FONTCONFIG_FILE=/etc/fonts/fonts.conf
exec "$SNAP/usr/bin/joomengine" "$@"
