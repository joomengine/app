# JoomEngine for Linux

## Portable archive

Extract the archive and run `app/joomengine` on a Linux x86-64 desktop with working unprivileged user namespaces. To install an application-menu entry, or to run on Ubuntu with restricted user namespaces, run the following commands from the extracted directory.

```sh
sudo ./install.sh
joomengine
```

The installer places the application in `/opt/joomengine`. On Ubuntu it installs an AppArmor rule scoped to the root-owned JoomEngine executable so Chromium can use its namespace sandbox. To update, close JoomEngine and run `sudo ./install.sh` from the new archive. The installer retains the two most recent installations. User projects live separately in the application profile.

These commands remove the system installation and retain your projects.

```sh
if [ -f /etc/apparmor.d/joomengine ]; then
    sudo apparmor_parser -R /etc/apparmor.d/joomengine
    sudo rm -f /etc/apparmor.d/joomengine
fi
sudo rm -f /usr/local/bin/joomengine /usr/local/share/applications/joomengine.desktop \
    /usr/local/share/icons/hicolor/512x512/apps/joomengine.png
sudo rm -rf /opt/joomengine
```

## Snap

Download the release Snap into its own directory. Install it, connect the browser sandbox and start JoomEngine.

```sh
sudo snap install --dangerous ./joomengine_*_amd64.snap
sudo snap connect joomengine:browser-sandbox :browser-support
snap run joomengine
```

The local-file flag allows Snap to install an artifact distributed outside its store. The browser connection lets Chromium sandbox its processes inside strict Snap confinement. JoomEngine stores its desktop profile in the Snap's per-user common directory across package revisions. You can remove the installed Snap with `sudo snap remove joomengine`.
