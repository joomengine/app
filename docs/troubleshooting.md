# Troubleshoot desktop display issues

## A blank strip or a flickering page

First note whether the space is inside the Joomla page, at the bottom of the desktop window, or at the top where **File**, **Edit** and **View** appear. On Linux and Windows, **Ctrl+Shift+M** toggles that window's menu bar. In the Qt host the bottom status bar appears when the page fails to load or the browser process stops. If it shows a message, include its text in the report.

Try the same page and action in an ordinary browser at [JoomEngine Playground](https://playground.joomengine.org/). It has its own saved workspace. A reproduction in both environments helps identify which layout the maintainer should inspect. Note which section was open (JCB dashboard, code editor, Adminer or another Joomla view), whether the tool was detached, and whether you were scrolling, resizing or toggling a menu.

## Repeated messages in the Linux terminal

`ResizeObserver loop completed with undelivered notifications` means the web engine deferred some resize notifications to another rendering update. It can occur when page layout changes during a resize observation. Playground sizes the Joomla frame to the full document height to support scrolling the outer window. The editor and loaded Joomla extensions may also observe size changes. The message alone does not identify the responsible element. [Resize Observer specification](https://www.w3.org/TR/resize-observer/) · [Playground frame sizing](https://github.com/joomengine/playground/blob/main/src/frame-view.mjs)

`Attempt to read from an uninitialized SharedImage` is emitted by Chromium's graphics code when the compositor tries to read an image whose backing region has not been marked as initialized. The logged size is in image pixels and can exceed the visible window. A useful report says whether there was visible corruption, blank content, a crash, or only terminal output. These messages alone do not establish whether the two events share a cause. [Chromium's SharedImage read check](https://chromium.googlesource.com/chromium/src/+/5a6785d5aa40d7d332ef016f2007930cb448f91f/gpu/command_buffer/service/shared_image/shared_image_representation.cc)

## Gather a Linux report

1. Record the JoomEngine package format, version and release or preview tag. Note your distribution, screen resolution, display scaling, and whether the issue changes on another monitor. A screenshot of the whole desktop **window**, including the edges, can locate a blank strip. Remove private site content before sharing.
2. On the affected desktop, record the operating system and session.

   ```sh
   cat /etc/os-release
   uname -srmo
   printf 'Desktop session: %s\n' "$XDG_SESSION_TYPE"
   ```

   For Snap, also include the package and runtime revisions and the warning text.

   ```sh
   snap list joomengine kde-qt6-core24
   snap connections joomengine
   snap warnings
   ```

3. Fully quit JoomEngine so the new process captures its own log. For Snap, use the following command and reproduce the issue once. For a native distribution package, replace `snap run joomengine` with `joomengine`. Both commands preserve the usual renderer configuration.

   ```sh
   QT_LOGGING_RULES='qt.webenginecontext=true;qt.webengine.compositor=true' \
       snap run joomengine 2>&1 | tee joomengine-display.log
   ```

4. Include the Qt and Chromium graphics device/renderer lines, the first occurrence of the warning and the actions immediately preceding it. Review the excerpt for local paths, project names and private URLs. [Qt WebEngine graphics diagnostics](https://doc.qt.io/qt-6/qtwebengine-features.html#hardware-acceleration) · [Open a JoomEngine issue](https://github.com/joomengine/joomengine/issues)
