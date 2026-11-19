#include "desktop.hpp"
#ifdef JOOMENGINE_NATIVE_QA
#include "native_qa.hpp"
#endif

#include <QAction>
#include <QApplication>
#include <QCloseEvent>
#include <QCryptographicHash>
#include <QDesktopServices>
#include <QDir>
#include <QEventLoopLocker>
#include <QFileDialog>
#include <QFileInfo>
#include <QKeySequence>
#include <QLocalServer>
#include <QLocalSocket>
#include <QLockFile>
#include <QLayout>
#include <QMainWindow>
#include <QMenu>
#include <QMenuBar>
#include <QMessageBox>
#include <QStandardPaths>
#include <QStatusBar>
#include <QWebEngineDownloadRequest>
#include <QWebEngineFileSystemAccessRequest>
#include <QWebEngineLoadingInfo>
#include <QWebEngineNavigationRequest>
#include <QWebEngineNewWindowRequest>
#include <QWebEnginePage>
#include <QWebEngineProfile>
#include <QWebEngineScript>
#include <QWebEngineScriptCollection>
#include <QWebEngineSettings>
#include <QWebEngineView>

#include <memory>

namespace {

void openExternal(const QUrl& url) {
    if (joomengine::isExternalWebURL(url.toEncoded().toStdString()))
        QDesktopServices::openUrl(url);
}

class WorkspaceWindow final : public QMainWindow {
public:
    explicit WorkspaceWindow(QWebEngineProfile& profile, WorkspaceWindow* opener = nullptr)
        : QMainWindow(opener, Qt::Window), owner(opener ? opener->owner : this), browser(new QWebEngineView(this)),
          page(new QWebEnginePage(&profile, browser)) {
        setWindowTitle(opener ? QStringLiteral("JoomEngine Tool") : QStringLiteral("JoomEngine"));
        resize(opener ? 1100 : 1400, opener ? 760 : 900);
        if (opener) {
            setAttribute(Qt::WA_DeleteOnClose);
            setAttribute(Qt::WA_QuitOnClose, false);
        }
        setCentralWidget(browser);
        // A QMainWindow status bar consumes a row even when its message is empty.
        // Give errors a place to appear without reserving space on a healthy page.
        auto* errors = new QStatusBar(this);
        errors->setSizeGripEnabled(false);
        setStatusBar(errors);
        errors->hide();
        browser->setPage(page);

#ifndef Q_OS_MACOS
        menuBar()->setNativeMenuBar(false);
#endif
        auto* file = menuBar()->addMenu(tr("&File"));
        auto* closeWindow = file->addAction(tr("Close Window"));
        closeWindow->setShortcuts(QKeySequence::Close);
        addAction(closeWindow);
        connect(closeWindow, &QAction::triggered, this, &QWidget::close);
        auto* quit = file->addAction(tr("Quit JoomEngine"));
        quit->setMenuRole(QAction::QuitRole);
        quit->setShortcuts(QKeySequence::Quit);
        addAction(quit);
        connect(quit, &QAction::triggered, owner, &QWidget::close);

        auto* edit = menuBar()->addMenu(tr("&Edit"));
        auto addEdit = [this, edit](QWebEnginePage::WebAction action, QKeySequence::StandardKey shortcut) {
            auto* item = page->action(action);
            item->setShortcuts(shortcut);
            edit->addAction(item);
            addAction(item);
        };
        addEdit(QWebEnginePage::Undo, QKeySequence::Undo);
        addEdit(QWebEnginePage::Redo, QKeySequence::Redo);
        edit->addSeparator();
        addEdit(QWebEnginePage::Cut, QKeySequence::Cut);
        addEdit(QWebEnginePage::Copy, QKeySequence::Copy);
        addEdit(QWebEnginePage::Paste, QKeySequence::Paste);
        addEdit(QWebEnginePage::SelectAll, QKeySequence::SelectAll);

        auto* view = menuBar()->addMenu(tr("&View"));
        auto* reload = view->addAction(tr("&Reload"));
        addAction(reload);
        reload->setShortcuts(QKeySequence::Refresh);
        // Qt's Refresh binding on some Linux desktops only includes F5.
        auto shortcuts = reload->shortcuts();
        const QKeySequence controlR(Qt::CTRL | Qt::Key_R);
        if (!shortcuts.contains(controlR)) shortcuts.append(controlR);
        reload->setShortcuts(shortcuts);
        connect(reload, &QAction::triggered, browser, &QWebEngineView::reload);

#ifndef Q_OS_MACOS
        toggleMenu = view->addAction(tr("Show Menu Bar"));
        toggleMenu->setCheckable(true);
        toggleMenu->setShortcut(QKeySequence(Qt::CTRL | Qt::SHIFT | Qt::Key_M));
        addAction(toggleMenu);
        connect(toggleMenu, &QAction::toggled, menuBar(), &QWidget::setVisible);
        menuBar()->hide();
        browser->setContextMenuPolicy(Qt::CustomContextMenu);
        connect(browser, &QWidget::customContextMenuRequested, this, [this](const QPoint& at) {
            auto* context = browser->createStandardContextMenu();
            context->setAttribute(Qt::WA_DeleteOnClose);
            context->addSeparator();
            context->addAction(toggleMenu);
            context->popup(browser->mapToGlobal(at));
        });
#endif

        connect(page, &QWebEnginePage::navigationRequested, this, [](QWebEngineNavigationRequest& request) {
            if (!request.isMainFrame() || joomengine::isWorkspaceURL(request.url().toEncoded().toStdString())) return;
            request.reject();
            openExternal(request.url());
        });
        connect(page, &QWebEnginePage::newWindowRequested, this, [this](QWebEngineNewWindowRequest& request) {
            const QUrl url = request.requestedUrl();
            if (!url.isEmpty() && !joomengine::isWorkspaceURL(url.toEncoded().toStdString())) {
                openExternal(url);
                return;
            }
            auto* child = new WorkspaceWindow(*page->profile(), this);
            // Attach WebEngine's pending browsing context. Loading its URL in
            // a new view separately would break the tools' window.opener.
            request.openIn(child->page);
            child->show();
        });
        connect(page, &QWebEnginePage::windowCloseRequested, this, [this] {
            closeApproved = true;
            close();
        });
        connect(page, &QWebEnginePage::loadingChanged, this, [this, errors](const QWebEngineLoadingInfo& info) {
            if (info.status() == QWebEngineLoadingInfo::LoadStartedStatus) {
                errors->hide();
                errors->clearMessage();
                rendererStopped = false;
            } else if (info.status() == QWebEngineLoadingInfo::LoadFailedStatus) {
                errors->showMessage(tr("The page could not load. Press %1 to try again.").arg(reloadShortcut()));
                errors->show();
            }
        });
        connect(page, &QWebEnginePage::renderProcessTerminated, this, [this, errors] {
            rendererStopped = true;
            errors->showMessage(tr("The browser process stopped. Press %1 to reopen the workspace.").arg(reloadShortcut()));
            errors->show();
        });
        connect(page, &QWebEnginePage::fileSystemAccessRequested, this, [this](QWebEngineFileSystemAccessRequest request) {
            const bool writing = request.accessFlags().testFlag(QWebEngineFileSystemAccessRequest::Write);
            const QString question = writing ? tr("Allow %1 to change %2?") : tr("Allow %1 to read %2?");
            if (QMessageBox::question(this, tr("File access"),
                    question.arg(request.origin().toDisplayString(), request.filePath().toLocalFile()),
                    QMessageBox::Yes | QMessageBox::No, QMessageBox::No) == QMessageBox::Yes)
                request.accept();
            else
                request.reject();
        });
#ifdef JOOMENGINE_NATIVE_QA
        if (!opener) {
            QWebEngineScript script;
            script.setName(QStringLiteral("JoomEngine native QA"));
            script.setSourceCode(QString::fromStdString(qa::script()));
            script.setInjectionPoint(QWebEngineScript::DocumentCreation);
            script.setWorldId(QWebEngineScript::MainWorld);
            script.setRunsOnSubFrames(false);
            page->scripts().insert(script);
            connect(page, &QWebEnginePage::titleChanged, this, [this, reload](const QString& title) {
                qa::onTitle(title.toStdString(), [reload] { reload->trigger(); }, [this] { close(); },
                    [this] { page->action(QWebEnginePage::SelectAll)->trigger(); });
            });
        }
#endif
        if (!opener) page->load(QUrl(QString::fromLatin1(joomengine::url)));
    }

    void bringToFront() {
        if (isMinimized()) setWindowState(windowState() & ~Qt::WindowMinimized);
        show();
        raise();
        activateWindow();
    }

#ifdef JOOMENGINE_NATIVE_QA
    bool verifyCompactLayout() {
        layout()->activate();
        if (browser->geometry() != contentsRect()) return false;
#ifndef Q_OS_MACOS
        if (toggleMenu->isChecked() || menuBar()->isVisible()) return false;
        toggleMenu->trigger();
        layout()->activate();
        const QRect expanded = browser->geometry();
        const bool barOpened = menuBar()->isVisible() && expanded.top() > contentsRect().top()
                            && expanded.bottom() == contentsRect().bottom();
        toggleMenu->trigger();
        layout()->activate();
        return barOpened && menuBar()->isHidden() && browser->geometry() == contentsRect();
#else
        return menuBar()->isNativeMenuBar();
#endif
    }
#endif

private:
    static QString reloadShortcut() {
        return QKeySequence(Qt::CTRL | Qt::Key_R).toString(QKeySequence::NativeText);
    }

    void closeEvent(QCloseEvent* event) override {
        if (closeApproved || rendererStopped) {
            // Once the owner has passed Chromium's beforeunload check, end all
            // its related tool windows too, including tools launched by a tool.
            for (auto* child : children()) {
                if (auto* tool = dynamic_cast<WorkspaceWindow*>(child)) {
                    tool->closeApproved = true;
                    tool->close();
                }
            }
            event->accept();
            return;
        }
        event->ignore();
        // Chromium delivers beforeunload and reports an accepted close via
        // windowCloseRequested. This path is shared by the desktop and QA.
        page->triggerAction(QWebEnginePage::RequestClose);
    }

#ifndef Q_OS_MACOS
    QAction* toggleMenu = nullptr;
#endif
    WorkspaceWindow* owner;
    QWebEngineView* browser;
    QWebEnginePage* page;
    bool closeApproved = false;
    bool rendererStopped = false;
};

void saveDownload(QWebEngineDownloadRequest* request) {
    QString name = QFileInfo(request->downloadFileName()).fileName();
    if (name.isEmpty() || name == "." || name == "..") name = QStringLiteral("download");
    QString destination;
#ifdef JOOMENGINE_NATIVE_QA
    destination = QString::fromStdString(qa::downloadPath(name.toStdString()));
#endif
    if (destination.isEmpty()) {
        destination = QFileDialog::getSaveFileName(QApplication::activeWindow(), QObject::tr("Save Download"),
            QDir(QStandardPaths::writableLocation(QStandardPaths::DownloadLocation)).filePath(name));
    }
    if (destination.isEmpty()) {
        request->cancel();
        return;
    }
    const QFileInfo file(destination);
    request->setDownloadDirectory(file.absolutePath());
    request->setDownloadFileName(file.fileName());
    // Closing the source window must not interrupt a transfer already accepted.
    auto keepRunning = std::make_shared<QEventLoopLocker>();
    QObject::connect(request, &QWebEngineDownloadRequest::isFinishedChanged, request, [request, keepRunning] {
        if (!request->isFinished()) return;
        if (request->state() == QWebEngineDownloadRequest::DownloadInterrupted)
            QMessageBox::warning(QApplication::activeWindow(), QObject::tr("Download failed"), request->interruptReasonString());
        request->deleteLater();
    });
    request->accept();
}

} // namespace

int main(int argc, char** argv) {
    QApplication app(argc, argv);
    QApplication::setApplicationName(QString::fromLatin1(joomengine::name));
    QApplication::setOrganizationDomain(QStringLiteral("joomengine.org"));
    QApplication::setDesktopFileName(QString::fromLatin1(joomengine::id));
    QApplication::setWindowIcon(QIcon::fromTheme(QString::fromLatin1(joomengine::id), QIcon::fromTheme(QStringLiteral("joomengine"))));
#ifdef JOOMENGINE_NATIVE_QA
    const QString data = QString::fromStdString(qa::profilePath());
    const QString cache = QDir(data).filePath(QStringLiteral("cache"));
#else
    const QString data = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    const QString cache = QStandardPaths::writableLocation(QStandardPaths::CacheLocation);
#endif
    if (data.isEmpty() || !QDir().mkpath(data)) {
        QMessageBox::critical(nullptr, QObject::tr("JoomEngine"), QObject::tr("The browser profile directory could not be created."));
        return 1;
    }

    const QString serverName = QStringLiteral("joomengine-") +
        QString::fromLatin1(QCryptographicHash::hash(data.toUtf8(), QCryptographicHash::Sha256).toHex().left(32));
    QLockFile lock(QDir(data).filePath(QStringLiteral("desktop.lock")));
    lock.setStaleLockTime(0);
    if (!lock.tryLock()) {
        QLocalSocket activation;
        activation.connectToServer(serverName);
        if (activation.waitForConnected(1500)) return 0;
        QMessageBox::warning(nullptr, QObject::tr("JoomEngine"),
            QObject::tr("The browser profile is in use or could not be locked. Please reopen the running JoomEngine window."));
        return 1;
    }
    // Only the holder of the profile lock may remove a stale activation socket.
    QLocalServer::removeServer(serverName);
    QLocalServer server;
    server.setSocketOptions(QLocalServer::UserAccessOption);
    if (!server.listen(serverName)) {
        QMessageBox::critical(nullptr, QObject::tr("JoomEngine"), server.errorString());
        return 1;
    }

#ifdef JOOMENGINE_NATIVE_QA
    // Qt initializes a named profile before applying a custom storage path.
    // Keep that initial name separate from the real user's profile as well.
    QWebEngineProfile profile(QStringLiteral("QA-") + serverName);
#else
    QWebEngineProfile profile(QStringLiteral("Playground"));
#endif
    profile.setPersistentStoragePath(QDir(data).filePath(QStringLiteral("browser")));
    profile.setCachePath(QDir(cache).filePath(QStringLiteral("browser")));
    profile.setHttpCacheType(QWebEngineProfile::DiskHttpCache);
    profile.settings()->setAttribute(QWebEngineSettings::JavascriptCanOpenWindows, true);
    // Playground's Copy share URL calls writeText() from a user click.
    // JavascriptCanPaste stays off so scripted clipboard reads require permission.
    profile.settings()->setAttribute(QWebEngineSettings::JavascriptCanAccessClipboard, true);
    QObject::connect(&profile, &QWebEngineProfile::downloadRequested, &profile, saveDownload);

    // All pages are destroyed before their disk-backed browser profile.
    WorkspaceWindow owner(profile);
    QObject::connect(&server, &QLocalServer::newConnection, &owner, [&] {
        while (auto* client = server.nextPendingConnection()) client->deleteLater();
        owner.bringToFront();
    });
    owner.show();
#ifdef JOOMENGINE_NATIVE_QA
    if (!owner.verifyCompactLayout()) {
        qCritical("The embedded browser failed the native window layout check.");
        return 1;
    }
#endif
    const int status = app.exec();
#ifdef JOOMENGINE_NATIVE_QA
    return status ? status : qa::exitCode();
#else
    return status;
#endif
}
