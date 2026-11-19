# JoomEngine

JoomEngine is a desktop development workspace for [JoomEngine Playground](https://playground.joomengine.org/). Launch Joomla Component Builder, edit a running site in JoomEngine Code, inspect its MariaDB database, and export your work from one app. The default site and available Joomla, PHP, and JCB versions come from Playground's current deployment.

The app opens Playground directly in a dedicated Chromium window. PHP and MariaDB run in Playground's browser workers. The desktop keeps its own persistent profile, lets the Code and database tools open detached windows, and uses the operating system's file dialogs for uploads and downloads. Opening the hosted workspace and fetching uncached assets requires a connection. See the [Playground guide](https://github.com/joomengine/playground#readme) for site persistence, backup and restoration.

## Run from source

Install Node.js 24 and npm, then run these commands from this repository on your desktop.

```sh
npm ci
npm run stage
npm start
```

Staging downloads the pinned Electron release for the current OS and architecture. Run `npm run stage` again after changing the desktop source to refresh the staged app. The first release targets a Linux x64 archive and Snap, a Windows x64 MSIX, and macOS disk images for Apple silicon and Intel.

## Credits and license

The [GetBible desktop app](https://github.com/getbible/desktop) inspired the focused desktop window and the multi-platform release approach. JoomEngine is an independent implementation built exclusively for [JoomEngine Playground](https://github.com/joomengine/playground). Its desktop source is licensed under [Apache-2.0](LICENSE). The Playground project supplied the pearl rocket artwork. Electron and Chromium retain their own distribution notices.
