// JoomEngine's Win32 host. WebView2 supplies the system browser, native
// download UI, file pickers, service workers and persistent website storage.
#include <windows.h>
#include <shlobj.h>
#include <shellapi.h>
#include <wrl.h>
#include <WebView2.h>
#include <choc/gui/choc_MessageLoop.h>
#include "desktop.hpp"

#include <filesystem>
#include <memory>
#include <string>
#include <string_view>

#ifdef JOOMENGINE_NATIVE_QA
#include "native_qa.hpp"
#endif

using Microsoft::WRL::Callback;
using Microsoft::WRL::ComPtr;

namespace {
constexpr wchar_t windowClass[] = L"JoomEngine.Workspace";
constexpr UINT reloadCommand = 101;
constexpr UINT closeCommand = 102;
constexpr UINT toggleMenuCommand = 103;
constexpr UINT selectAllCommand = 109;
constexpr UINT systemToggleMenuCommand = 0x1FA0; // System-menu commands reserve their low four bits.
struct EditCommand { UINT id; const wchar_t* label; const wchar_t* browserCommand; };
constexpr EditCommand editCommands[] = {
    {104, L"&Undo\tCtrl+Z", L"Undo"}, {105, L"&Redo\tCtrl+Y", L"Redo"},
    {106, L"Cu&t\tCtrl+X", L"Cut"}, {107, L"&Copy\tCtrl+C", L"Copy"},
    {108, L"&Paste\tCtrl+V", L"Paste"}, {selectAllCommand, L"Select &All\tCtrl+A", L"SelectAll"}
};
ComPtr<ICoreWebView2Environment> environment;

std::wstring wide(std::string_view source) {
    int size = MultiByteToWideChar(CP_UTF8, 0, source.data(), static_cast<int>(source.size()), nullptr, 0);
    std::wstring result(size, L'\0');
    if (size) MultiByteToWideChar(CP_UTF8, 0, source.data(), static_cast<int>(source.size()), result.data(), size);
    return result;
}

// WebView2 and SHGetKnownFolderPath return CoTaskMem-allocated strings.
struct Text {
    PWSTR data = nullptr;
    ~Text() { CoTaskMemFree(data); }
    std::string utf8() const {
        if (!data || !*data) return {};
        const int length = lstrlenW(data);
        int size = WideCharToMultiByte(CP_UTF8, 0, data, length, nullptr, 0, nullptr, nullptr);
        std::string result(size, '\0');
        WideCharToMultiByte(CP_UTF8, 0, data, length, result.data(), size, nullptr, nullptr);
        return result;
    }
};

struct Popup {
    ComPtr<ICoreWebView2NewWindowRequestedEventArgs> request;
    ComPtr<ICoreWebView2Deferral> deferral;
    ~Popup() { if (deferral) deferral->Complete(); }
};

struct Window;
using WindowPtr = std::shared_ptr<Window>;
LRESULT CALLBACK dispatch(HWND, UINT, WPARAM, LPARAM);

struct Window : std::enable_shared_from_this<Window> {
    HWND hwnd = nullptr;
    bool owner = false;
    bool failedNavigation = false;
    ComPtr<ICoreWebView2Controller> controller;
    ComPtr<ICoreWebView2> web;

    static WindowPtr create(HWND opener) {
        auto self = std::make_shared<Window>();
        self->owner = !opener;
        HWND window = CreateWindowExW(0, windowClass, opener ? L"JoomEngine tool" : L"JoomEngine",
            WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, opener ? 1024 : 1320, 860,
            opener, nullptr, GetModuleHandleW(nullptr), &self);
        if (!window) return {};
        HMENU system = GetSystemMenu(window, FALSE);
        AppendMenuW(system, MF_SEPARATOR, 0, nullptr);
        AppendMenuW(system, MF_STRING, systemToggleMenuCommand, L"Show Menu Bar\tCtrl+Shift+M");
        ShowWindow(window, SW_SHOWNORMAL);
        return self;
    }

    void toggleMenu() {
        if (HMENU oldMenu = GetMenu(hwnd)) {
            if (!SetMenu(hwnd, nullptr)) return;
            DestroyMenu(oldMenu);
        } else {
            HMENU menu = CreateMenu(), file = CreatePopupMenu(), edit = CreatePopupMenu(), view = CreatePopupMenu();
            AppendMenuW(file, MF_STRING, closeCommand, L"&Close");
            for (const auto& command : editCommands)
                AppendMenuW(edit, MF_STRING, command.id, command.label);
            AppendMenuW(view, MF_STRING, reloadCommand, L"&Reload\tCtrl+R");
            AppendMenuW(view, MF_CHECKED, toggleMenuCommand, L"Show &Menu Bar\tCtrl+Shift+M");
            AppendMenuW(menu, MF_POPUP, reinterpret_cast<UINT_PTR>(file), L"&File");
            AppendMenuW(menu, MF_POPUP, reinterpret_cast<UINT_PTR>(edit), L"&Edit");
            AppendMenuW(menu, MF_POPUP, reinterpret_cast<UINT_PTR>(view), L"&View");
            if (!SetMenu(hwnd, menu)) { DestroyMenu(menu); return; }
        }
        CheckMenuItem(GetSystemMenu(hwnd, FALSE), systemToggleMenuCommand,
                      MF_BYCOMMAND | (GetMenu(hwnd) ? MF_CHECKED : MF_UNCHECKED));
        DrawMenuBar(hwnd);
        resize();
    }

    void edit(const wchar_t* browserCommand) {
        if (!web || !controller) return;
        controller->MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC);
        // Dispatch inside the focused browser frame, including detached tools
        // and cross-origin frames, without injecting script into page content.
        const std::wstring args = std::wstring(LR"({"type":"rawKeyDown","commands":[")") + browserCommand + LR"("]})";
        web->CallDevToolsProtocolMethod(L"Input.dispatchKeyEvent", args.c_str(),
            Callback<ICoreWebView2CallDevToolsProtocolMethodCompletedHandler>([](HRESULT result, LPCWSTR) -> HRESULT {
                if (FAILED(result)) OutputDebugStringW(L"JoomEngine: the WebView2 edit command failed.\n");
                return S_OK;
            }).Get());
    }

    void addContextMenuToggle() {
        ComPtr<ICoreWebView2_11> menus;
        ComPtr<ICoreWebView2Environment9> factory;
        ComPtr<ICoreWebView2ContextMenuItem> toggle;
        if (FAILED(web.As(&menus)) || FAILED(environment.As(&factory)) ||
            FAILED(factory->CreateContextMenuItem(L"Show Menu Bar", nullptr, COREWEBVIEW2_CONTEXT_MENU_ITEM_KIND_CHECK_BOX, &toggle)))
            return; // The title-bar system menu is available on every runtime.
        std::weak_ptr<Window> weak = shared_from_this();
        EventRegistrationToken token{};
        toggle->add_CustomItemSelected(Callback<ICoreWebView2CustomItemSelectedEventHandler>(
            [weak](ICoreWebView2ContextMenuItem*, IUnknown*) -> HRESULT {
                if (auto self = weak.lock(); self && self->hwnd)
                    PostMessageW(self->hwnd, WM_COMMAND, toggleMenuCommand, 0);
                return S_OK;
            }).Get(), &token);
        menus->add_ContextMenuRequested(Callback<ICoreWebView2ContextMenuRequestedEventHandler>(
            [weak, toggle](ICoreWebView2*, ICoreWebView2ContextMenuRequestedEventArgs* args) -> HRESULT {
                auto self = weak.lock();
                ComPtr<ICoreWebView2ContextMenuItemCollection> items;
                UINT32 count = 0;
                if (!self || !self->hwnd || FAILED(args->get_MenuItems(&items)) || FAILED(items->get_Count(&count)))
                    return S_OK;
                toggle->put_IsChecked(GetMenu(self->hwnd) != nullptr);
                return items->InsertValueAtIndex(count, toggle.Get());
            }).Get(), &token);
    }

    void resize() {
        if (controller && hwnd) {
            RECT bounds{};
            GetClientRect(hwnd, &bounds);
            controller->put_Bounds(bounds);
        }
    }

#ifdef JOOMENGINE_NATIVE_QA
    bool savedReloadConfirmation = false;

    void qaFailure(const std::string& detail) {
        qa::result = 1;
        qa::logEvent("fail", detail);
        PostMessageW(hwnd, WM_CLOSE, 0, 0);
    }

    HRESULT configureQaDialogs() {
        ComPtr<ICoreWebView2Settings> settings;
        HRESULT hr = web->get_Settings(&settings);
        if (FAILED(hr)) return hr;
        std::weak_ptr<Window> weak = shared_from_this();
        EventRegistrationToken token{};
        hr = web->add_ScriptDialogOpening(Callback<ICoreWebView2ScriptDialogOpeningEventHandler>(
            [weak](ICoreWebView2*, ICoreWebView2ScriptDialogOpeningEventArgs* e) -> HRESULT {
                auto self = weak.lock();
                if (!self || !self->hwnd) return S_OK;
                COREWEBVIEW2_SCRIPT_DIALOG_KIND kind{};
                Text uri;
                if (FAILED(e->get_Kind(&kind)) || FAILED(e->get_Uri(&uri.data)) ||
                    !qa::takeSavedReloadConfirmation(self->savedReloadConfirmation,
                        kind == COREWEBVIEW2_SCRIPT_DIALOG_KIND_BEFOREUNLOAD, uri.utf8())) {
                    self->qaFailure("Unexpected WebView2 script dialog (kind " + std::to_string(kind) + ").");
                } else if (FAILED(e->Accept())) {
                    self->qaFailure("WebView2 rejected the saved workspace Reload confirmation.");
                } else {
                    qa::logEvent("native", "Confirmed the saved workspace's beforeunload dialog.");
                }
                return S_OK;
            }).Get(), &token);
        if (FAILED(hr)) return hr;
        // Only the instrumented owner uses this handler. Production keeps the
        // standard WebView2 dialogs, so the person using it can cancel a Reload.
        return settings->put_AreDefaultScriptDialogsEnabled(FALSE);
    }

    bool verifyCompactLayout() {
        const auto fillsClient = [this] {
            RECT native{}, browser{};
            return GetClientRect(hwnd, &native) && SUCCEEDED(controller->get_Bounds(&browser)) && EqualRect(&native, &browser);
        };
        if (GetMenu(hwnd) || !fillsClient()) return false;
        toggleMenu();
        const bool expanded = GetMenu(hwnd) && fillsClient();
        toggleMenu();
        return expanded && !GetMenu(hwnd) && fillsClient();
    }
#endif

    void reload() {
        if (!web) return;
        HRESULT hr = failedNavigation && owner ? web->Navigate(wide(joomengine::url).c_str()) : web->Reload();
#ifdef JOOMENGINE_NATIVE_QA
        if (FAILED(hr)) qaFailure("WebView2 could not dispatch native Reload, HRESULT " + std::to_string(hr));
        else qa::logEvent("native", "Dispatched native Reload.");
#else
        if (FAILED(hr)) MessageBoxW(hwnd, L"Windows could not reload the page. Please try again.", L"JoomEngine", MB_OK | MB_ICONERROR);
#endif
    }

    void failure(const wchar_t* detail) {
        if (hwnd) {
            MessageBoxW(hwnd, detail, L"JoomEngine", MB_OK | MB_ICONERROR);
            PostMessageW(hwnd, WM_CLOSE, 0, 0);
        }
    }

    void attach(std::shared_ptr<Popup> popup = {}) {
        auto self = shared_from_this();
        HRESULT started = environment->CreateCoreWebView2Controller(hwnd,
            Callback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler>(
                [self, popup](HRESULT result, ICoreWebView2Controller* created) -> HRESULT {
                    if (!self->hwnd) return S_OK;
                    if (FAILED(result) || !created || FAILED(created->get_CoreWebView2(&self->web))) {
                        self->failure(L"Windows could not create the Playground browser. Update Microsoft Edge WebView2 Runtime and reopen JoomEngine.");
                        return S_OK;
                    }
                    self->controller = created;
                    self->resize();
                    self->events();
#ifdef JOOMENGINE_NATIVE_QA
                    if (self->owner && !self->verifyCompactLayout()) {
                        PostMessageW(self->hwnd, WM_CLOSE, 0, 0);
                        return S_OK;
                    }
#endif
                    if (popup) {
                        // Give the original JS call a WindowProxy in the same
                        // environment, before any host-initiated navigation.
                        if (FAILED(popup->request->put_NewWindow(self->web.Get())))
                            self->failure(L"Windows could not connect this tool window to its Playground workspace.");
                    } else {
                        self->loadOwner();
                    }
                    return S_OK;
                }).Get());
        if (FAILED(started)) failure(L"The browser controller could not be started.");
    }

    void loadOwner() {
#ifdef JOOMENGINE_NATIVE_QA
        if (FAILED(configureQaDialogs())) {
            qaFailure("Could not register the WebView2 test dialog handler.");
            return;
        }
        auto self = shared_from_this();
        auto ready = Callback<ICoreWebView2AddScriptToExecuteOnDocumentCreatedCompletedHandler>(
            [self](HRESULT result, LPCWSTR) -> HRESULT {
                if (FAILED(result)) self->failure(L"Could not install the desktop test driver.");
                else if (self->hwnd) self->web->Navigate(wide(joomengine::url).c_str());
                return S_OK;
            });
        if (FAILED(web->AddScriptToExecuteOnDocumentCreated(wide(qa::script()).c_str(), ready.Get())))
            failure(L"Could not register the desktop test driver.");
#else
        web->Navigate(wide(joomengine::url).c_str());
#endif
    }

    void events() {
        std::weak_ptr<Window> weak = shared_from_this();
        EventRegistrationToken token{};
        ComPtr<ICoreWebView2Settings> settings;
        if (SUCCEEDED(web->get_Settings(&settings))) {
            settings->put_AreHostObjectsAllowed(FALSE);
            settings->put_IsWebMessageEnabled(FALSE);
        }
        web->add_NavigationStarting(Callback<ICoreWebView2NavigationStartingEventHandler>(
            [weak](ICoreWebView2*, ICoreWebView2NavigationStartingEventArgs* e) -> HRESULT {
                Text uri;
                if (FAILED(e->get_Uri(&uri.data))) return e->put_Cancel(TRUE);
                const auto url = uri.utf8();
                if (joomengine::isWorkspaceURL(url)) return S_OK;
                e->put_Cancel(TRUE);
                BOOL user = FALSE;
                e->get_IsUserInitiated(&user);
                if (auto self = weak.lock(); self && user && joomengine::isExternalWebURL(url))
                    ShellExecuteW(self->hwnd, L"open", uri.data, nullptr, nullptr, SW_SHOWNORMAL);
                return S_OK;
            }).Get(), &token);
        web->add_NavigationCompleted(Callback<ICoreWebView2NavigationCompletedEventHandler>(
            [weak](ICoreWebView2*, ICoreWebView2NavigationCompletedEventArgs* e) -> HRESULT {
                BOOL success = FALSE;
                e->get_IsSuccess(&success);
                COREWEBVIEW2_WEB_ERROR_STATUS error = COREWEBVIEW2_WEB_ERROR_STATUS_UNKNOWN;
                e->get_WebErrorStatus(&error);
                if (auto self = weak.lock()) {
                    if (error != COREWEBVIEW2_WEB_ERROR_STATUS_OPERATION_CANCELED)
                        self->failedNavigation = !success;
#ifdef JOOMENGINE_NATIVE_QA
                    if (self->owner) {
                        self->savedReloadConfirmation = false;
                        qa::logEvent("navigation", success ? "Completed top-level navigation." :
                            "Top-level navigation failed, WebView2 status " + std::to_string(error));
                    }
#endif
                }
                return S_OK;
            }).Get(), &token);
        web->add_NewWindowRequested(Callback<ICoreWebView2NewWindowRequestedEventHandler>(
            [weak](ICoreWebView2*, ICoreWebView2NewWindowRequestedEventArgs* e) -> HRESULT {
                e->put_Handled(TRUE);
                auto self = weak.lock();
                Text uri;
                if (!self || !self->hwnd || FAILED(e->get_Uri(&uri.data))) return S_OK;
                const auto url = uri.utf8();
                if (!joomengine::isWorkspaceURL(url)) {
                    BOOL user = FALSE;
                    e->get_IsUserInitiated(&user);
                    if (user && joomengine::isExternalWebURL(url))
                        ShellExecuteW(self->hwnd, L"open", uri.data, nullptr, nullptr, SW_SHOWNORMAL);
                    return S_OK;
                }
                auto popup = std::make_shared<Popup>();
                popup->request = e;
                if (FAILED(e->GetDeferral(&popup->deferral))) return S_OK;
                if (auto child = Window::create(self->hwnd)) child->attach(popup);
                return S_OK;
            }).Get(), &token);
        web->add_WindowCloseRequested(Callback<ICoreWebView2WindowCloseRequestedEventHandler>(
            [weak](ICoreWebView2*, IUnknown*) -> HRESULT {
                if (auto self = weak.lock(); self && self->hwnd) PostMessageW(self->hwnd, WM_CLOSE, 0, 0);
                return S_OK;
            }).Get(), &token);
        addContextMenuToggle();
        controller->add_AcceleratorKeyPressed(Callback<ICoreWebView2AcceleratorKeyPressedEventHandler>(
            [weak](ICoreWebView2Controller*, ICoreWebView2AcceleratorKeyPressedEventArgs* e) -> HRESULT {
                UINT key = 0;
                COREWEBVIEW2_KEY_EVENT_KIND kind{};
                e->get_VirtualKey(&key);
                e->get_KeyEventKind(&kind);
                if (kind != COREWEBVIEW2_KEY_EVENT_KIND_KEY_DOWN || !(GetKeyState(VK_CONTROL) & 0x8000)
                    || (GetKeyState(VK_MENU) & 0x8000)) return S_OK;
                UINT command = 0;
                if (key == 'R') command = reloadCommand;
                if (key == 'M' && (GetKeyState(VK_SHIFT) & 0x8000)) command = toggleMenuCommand;
                if (command) {
                    e->put_Handled(TRUE);
                    COREWEBVIEW2_PHYSICAL_KEY_STATUS state{};
                    e->get_PhysicalKeyStatus(&state);
                    if (auto self = weak.lock(); self && self->hwnd && !state.WasKeyDown)
                        PostMessageW(self->hwnd, WM_COMMAND, command, 0);
                }
                return S_OK;
            }).Get(), &token);
        web->add_DocumentTitleChanged(Callback<ICoreWebView2DocumentTitleChangedEventHandler>(
            [weak](ICoreWebView2* view, IUnknown*) -> HRESULT {
                auto self = weak.lock();
                Text title;
                if (!self || !self->hwnd || FAILED(view->get_DocumentTitle(&title.data))) return S_OK;
                if (title.data && *title.data) SetWindowTextW(self->hwnd, (std::wstring(L"JoomEngine — ") + title.data).c_str());
#ifdef JOOMENGINE_NATIVE_QA
                if (self->owner)
                    qa::onTitle(title.utf8(),
                        [self](bool savedReload) {
                            self->savedReloadConfirmation = savedReload && qa::environment("JOOMENGINE_QA_PHASE") == "restore";
                            if (!PostMessageW(self->hwnd, WM_COMMAND, reloadCommand, 0))
                                self->qaFailure("Could not post the native Reload command.");
                        },
                        [self] { PostMessageW(self->hwnd, WM_CLOSE, 0, 0); },
                        [self] { PostMessageW(self->hwnd, WM_COMMAND, selectAllCommand, 0); });
#endif
                return S_OK;
            }).Get(), &token);
#ifdef JOOMENGINE_NATIVE_QA
        // Production leaves the native download/Save As UI to the user.
        ComPtr<ICoreWebView2_4> downloads;
        if (SUCCEEDED(web.As(&downloads)))
            downloads->add_DownloadStarting(Callback<ICoreWebView2DownloadStartingEventHandler>(
                [](ICoreWebView2*, ICoreWebView2DownloadStartingEventArgs* e) -> HRESULT {
                    Text path;
                    if (FAILED(e->get_ResultFilePath(&path.data))) return S_OK;
                    const auto destination = qa::downloadPath(std::filesystem::path(path.data).filename().u8string());
                    if (!destination.empty() && SUCCEEDED(e->put_ResultFilePath(wide(destination).c_str())))
                        e->put_Handled(TRUE);
                    return S_OK;
                }).Get(), &token);
#endif
    }
};

LRESULT CALLBACK dispatch(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    auto handle = reinterpret_cast<WindowPtr*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
    if (msg == WM_NCCREATE) {
        auto create = reinterpret_cast<CREATESTRUCTW*>(lParam);
        handle = new WindowPtr(*static_cast<WindowPtr*>(create->lpCreateParams));
        (*handle)->hwnd = hwnd;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(handle));
    }
    if (handle) {
        auto self = *handle;
        switch (msg) {
            case WM_SYSCOMMAND:
                if ((wParam & 0xFFF0) == systemToggleMenuCommand) { self->toggleMenu(); return 0; }
                break;
            case WM_KEYDOWN:
                if (wParam == 'M' && (GetKeyState(VK_CONTROL) & 0x8000) && (GetKeyState(VK_SHIFT) & 0x8000)
                    && !(GetKeyState(VK_MENU) & 0x8000) && !(lParam & (1L << 30))) {
                    self->toggleMenu();
                    return 0;
                }
                break;
            case WM_COMMAND:
                if (LOWORD(wParam) == toggleMenuCommand) { self->toggleMenu(); return 0; }
                for (const auto& command : editCommands) {
                    if (LOWORD(wParam) == command.id) { self->edit(command.browserCommand); return 0; }
                }
                if (LOWORD(wParam) == reloadCommand) { self->reload(); return 0; }
                if (LOWORD(wParam) == closeCommand) { PostMessageW(hwnd, WM_CLOSE, 0, 0); return 0; }
                break;
            case WM_SETFOCUS:
                if (self->controller) self->controller->MoveFocus(COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC);
                break;
            case WM_SIZE:
                self->resize();
                break;
            case WM_NCDESTROY:
                SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
                self->hwnd = nullptr;
                if (self->controller) self->controller->Close();
                self->web.Reset();
                self->controller.Reset();
                delete handle;
                if (self->owner) PostQuitMessage(0);
                break;
        }
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

void runtimeError(const WindowPtr& owner, HRESULT hr) {
    if (!owner->hwnd) return;
    if (hr == HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)) {
        const auto answer = MessageBoxW(owner->hwnd,
            L"JoomEngine needs Microsoft Edge WebView2 Runtime. Open Microsoft's official download page to install the Evergreen runtime, then reopen JoomEngine?",
            L"JoomEngine", MB_YESNO | MB_ICONINFORMATION);
        if (answer == IDYES)
            ShellExecuteW(owner->hwnd, L"open", L"https://developer.microsoft.com/microsoft-edge/webview2/", nullptr, nullptr, SW_SHOWNORMAL);
        PostMessageW(owner->hwnd, WM_CLOSE, 0, 0);
    } else {
        wchar_t message[256]{};
        swprintf_s(message, L"Windows could not start WebView2 (0x%08X). Check that your local profile is writable and the WebView2 Runtime is up to date, then reopen JoomEngine.", static_cast<unsigned>(hr));
        owner->failure(message);
    }
}

int run(HINSTANCE instance) {
    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = dispatch;
    wc.hInstance = instance;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);
    wc.hIcon = LoadIconW(instance, MAKEINTRESOURCEW(101));
    wc.hbrBackground = reinterpret_cast<HBRUSH>(COLOR_WINDOW + 1);
    wc.lpszClassName = windowClass;
    if (!RegisterClassExW(&wc)) return 1;
    auto owner = Window::create(nullptr);
    if (!owner) return 1;

    std::filesystem::path profile;
#ifdef JOOMENGINE_NATIVE_QA
    profile = std::filesystem::u8path(qa::profilePath());
#else
    Text local;
    if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &local.data)))
        profile = std::filesystem::path(local.data) / L"JoomEngine" / L"WebView2";
#endif
    std::error_code ec;
    if (!profile.empty()) std::filesystem::create_directories(profile, ec);
    if (profile.empty() || ec) owner->failure(L"JoomEngine could not open its persistent browser profile.");
    else {
        HRESULT hr = CreateCoreWebView2EnvironmentWithOptions(nullptr, profile.c_str(), nullptr,
            Callback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler>(
                [owner](HRESULT result, ICoreWebView2Environment* created) -> HRESULT {
                    if (!owner->hwnd) return S_OK;
                    if (FAILED(result) || !created) runtimeError(owner, result);
                    else { environment = created; owner->attach(); }
                    return S_OK;
                }).Get());
        if (FAILED(hr)) runtimeError(owner, hr);
    }
    choc::messageloop::run();
    environment.Reset();
#ifdef JOOMENGINE_NATIVE_QA
    return qa::exitCode();
#else
    return 0;
#endif
}
} // namespace

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, PWSTR, int) {
    if (FAILED(CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED))) return 1;
    SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
    const int status = run(instance);
    CoUninitialize();
    return status;
}
