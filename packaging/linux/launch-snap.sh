#!/bin/sh
# The KDE launcher sets these variables to a file absent from its content snap.
export FONTCONFIG_PATH=/etc/fonts
export FONTCONFIG_FILE=/etc/fonts/fonts.conf
# GTK reads the file chooser's settings when an upload opens the native dialog.
export GSETTINGS_SCHEMA_DIR="$SNAP/usr/share/glib-2.0/schemas${GSETTINGS_SCHEMA_DIR:+:$GSETTINGS_SCHEMA_DIR}"
exec "$SNAP/usr/bin/joomengine" "$@"
