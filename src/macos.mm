#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

#include "desktop.hpp"
#include <choc/gui/choc_MessageLoop.h>
#ifdef JOOMENGINE_NATIVE_QA
#include "native_qa.hpp"
#endif

namespace {
NSString *nativeString(std::string_view text) {
    return [[NSString alloc] initWithBytes:text.data() length:text.size() encoding:NSUTF8StringEncoding];
}

bool isWorkspace(NSURL *url) {
    return url && joomengine::isWorkspaceURL(url.absoluteString.UTF8String ?: "");
}

bool isBlank(NSURL *url) {
    return !url || [url.absoluteString isEqualToString:@"about:blank"];
}

void openExternal(NSURL *url) {
    if (url && joomengine::isExternalWebURL(url.absoluteString.UTF8String ?: ""))
        [NSWorkspace.sharedWorkspace openURL:url];
}

void showMessage(NSString *title, NSString *message) {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = title;
    alert.informativeText = message;
    [alert runModal];
}

NSURL *workspaceURL() {
    return [NSURL URLWithString:nativeString(joomengine::url)];
}

#ifdef JOOMENGINE_NATIVE_QA
// Named persistent stores isolate the test profile from the everyday workspace.
WKWebsiteDataStore *testStore() {
    if (@available(macOS 14.0, *)) {
        NSString *profile = nativeString(qa::profilePath());
        NSFileManager *files = NSFileManager.defaultManager;
        if (![files createDirectoryAtPath:profile withIntermediateDirectories:YES attributes:nil error:nullptr])
            return nil;
        NSString *path = [profile stringByAppendingPathComponent:@"webkit-identifier"];
        NSUUID *identifier = [[NSUUID alloc] initWithUUIDString:
            ([NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nullptr] ?: @"")];
        if (!identifier) {
            identifier = NSUUID.UUID;
            if (![identifier.UUIDString writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nullptr])
                return nil;
        }
        return [WKWebsiteDataStore dataStoreForIdentifier:identifier];
    }
    return nil;
}
#endif
} // namespace

@interface DownloadTarget : NSObject
@property(nonatomic, strong) NSURL *destination;
@property(nonatomic, strong) NSURL *temporaryFile;
@property(nonatomic) BOOL replacing;
@end
@implementation DownloadTarget
@end

@interface JoomEngineHost : NSObject <NSApplicationDelegate, NSWindowDelegate, WKUIDelegate,
                                      WKNavigationDelegate, WKDownloadDelegate>
@property(nonatomic, strong) NSMutableArray<NSWindow *> *windows;
@property(nonatomic, weak) WKWebView *owner;
@property(nonatomic, strong) NSMapTable<WKDownload *, DownloadTarget *> *downloads;
@property(nonatomic, strong) NSMenuItem *reloadItem;
@end

@implementation JoomEngineHost

- (NSMenu *)addMenu:(NSString *)name {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:name action:nullptr keyEquivalent:@""];
    item.submenu = [[NSMenu alloc] initWithTitle:name];
    [NSApp.mainMenu addItem:item];
    return item.submenu;
}

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    self.windows = [NSMutableArray array];
    self.downloads = [NSMapTable strongToStrongObjectsMapTable];
    NSApp.mainMenu = [[NSMenu alloc] init];
    NSMenu *appMenu = [self addMenu:@"JoomEngine"];
    [appMenu addItemWithTitle:@"About JoomEngine" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [appMenu addItem:NSMenuItem.separatorItem];
    [appMenu addItemWithTitle:@"Quit JoomEngine" action:@selector(terminate:) keyEquivalent:@"q"];
    [[self addMenu:@"File"] addItemWithTitle:@"Close Window" action:@selector(performClose:) keyEquivalent:@"w"];
    NSMenu *edit = [self addMenu:@"Edit"];
    [edit addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    NSMenuItem *redo = [edit addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"z"];
    redo.keyEquivalentModifierMask = NSEventModifierFlagCommand | NSEventModifierFlagShift;
    [edit addItem:NSMenuItem.separatorItem];
    [edit addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [edit addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [edit addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [edit addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    self.reloadItem = [[self addMenu:@"View"] addItemWithTitle:@"Reload" action:@selector(reloadView:) keyEquivalent:@"r"];
    self.reloadItem.target = self;
    NSApp.windowsMenu = [self addMenu:@"Window"];
    [self openWorkspace];
    [NSApp activateIgnoringOtherApps:YES];
}

- (WKWebView *)addWindow:(WKWebViewConfiguration *)configuration child:(BOOL)child {
    WKWebView *view = [[WKWebView alloc] initWithFrame:NSZeroRect configuration:configuration];
    view.navigationDelegate = self;
    view.UIDelegate = self;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, child ? 1040 : 1300, child ? 720 : 850)
        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    window.releasedWhenClosed = NO;
    window.delegate = self;
    window.title = child ? @"JoomEngine Tool" : @"JoomEngine";
    window.contentView = view;
    [self.windows addObject:window];
    [window center];
    [window makeKeyAndOrderFront:nil];
    [window makeFirstResponder:view];
    return view;
}

- (void)openWorkspace {
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    config.limitsNavigationsToAppBoundDomains = YES;
    config.preferences.javaScriptCanOpenWindowsAutomatically = YES;
#ifdef JOOMENGINE_NATIVE_QA
    WKWebsiteDataStore *store = testStore();
    if (!store) { NSLog(@"Could not open the isolated test profile"); choc::messageloop::stop(); return; }
    config.websiteDataStore = store;
    WKUserScript *qaScript = [[WKUserScript alloc] initWithSource:nativeString(qa::script())
        injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:YES];
    [config.userContentController addUserScript:qaScript];
#endif
    self.owner = [self addWindow:config child:NO];
#ifdef JOOMENGINE_NATIVE_QA
    [self.owner addObserver:self forKeyPath:@"title" options:NSKeyValueObservingOptionNew context:nullptr];
#endif
    [self.owner loadRequest:[NSURLRequest requestWithURL:workspaceURL()]];
}

#ifdef JOOMENGINE_NATIVE_QA
- (void)observeValueForKeyPath:(NSString *)key ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object != self.owner || ![key isEqualToString:@"title"]) {
        [super observeValueForKeyPath:key ofObject:object change:change context:context];
        return;
    }
    qa::onTitle(self.owner.title.UTF8String ?: "", [self] {
        [self.owner.window makeKeyAndOrderFront:nil];
        [self.reloadItem.menu performActionForItemAtIndex:[self.reloadItem.menu indexOfItem:self.reloadItem]];
    }, [] {
        choc::messageloop::stop();
    });
}
#endif

- (void)reloadView:(id)sender {
    WKWebView *view = (WKWebView *)NSApp.keyWindow.contentView;
    if (![view isKindOfClass:WKWebView.class]) view = self.owner;
    if (isBlank(view.URL) && view == self.owner)
        [view loadRequest:[NSURLRequest requestWithURL:workspaceURL()]];
    else
        [view reload];
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)visible {
    if (!self.owner) [self openWorkspace];
    [self.owner.window makeKeyAndOrderFront:nil];
    return YES;
}

- (void)windowWillClose:(NSNotification *)note {
    NSWindow *window = note.object;
    if (window.contentView == self.owner) {
#ifdef JOOMENGINE_NATIVE_QA
        [self.owner removeObserver:self forKeyPath:@"title"];
#endif
        self.owner = nil;
        for (NSWindow *other in [self.windows copy])
            if (other != window) [other close];
    }
    [self.windows removeObject:window];
}

- (WKWebView *)webView:(WKWebView *)source createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
        forNavigationAction:(WKNavigationAction *)action windowFeatures:(WKWindowFeatures *)features {
    NSURL *url = action.request.URL;
    if (!isBlank(url) && !isWorkspace(url)) { openExternal(url); return nil; }
    // WebKit supplied this configuration for this specific browsing context.
    // Reusing it preserves the opener relationship and the owner's site storage.
    return [self addWindow:configuration child:YES];
}

- (void)webViewDidClose:(WKWebView *)view {
    [view.window close];
}

- (void)webView:(WKWebView *)view decidePolicyForNavigationAction:(WKNavigationAction *)action
        decisionHandler:(void (^)(WKNavigationActionPolicy))decide {
    NSURL *url = action.request.URL;
    if (action.shouldPerformDownload) {
        decide(WKNavigationActionPolicyDownload);
    } else if (action.targetFrame.isMainFrame && !isBlank(url) && !isWorkspace(url)) {
        openExternal(url);
        decide(WKNavigationActionPolicyCancel);
    } else {
        decide(WKNavigationActionPolicyAllow);
    }
}

- (void)webView:(WKWebView *)view decidePolicyForNavigationResponse:(WKNavigationResponse *)navigation
        decisionHandler:(void (^)(WKNavigationResponsePolicy))decide {
    NSURLResponse *response = navigation.response;
    NSString *disposition = nil;
    if ([response isKindOfClass:NSHTTPURLResponse.class])
        disposition = [(NSHTTPURLResponse *)response valueForHTTPHeaderField:@"Content-Disposition"];
    BOOL attachment = [[disposition lowercaseString] hasPrefix:@"attachment"];
    decide((attachment || !navigation.canShowMIMEType) ? WKNavigationResponsePolicyDownload : WKNavigationResponsePolicyAllow);
}

- (void)webView:(WKWebView *)view navigationAction:(WKNavigationAction *)action didBecomeDownload:(WKDownload *)download {
    download.delegate = self;
}
- (void)webView:(WKWebView *)view navigationResponse:(WKNavigationResponse *)response didBecomeDownload:(WKDownload *)download {
    download.delegate = self;
}

- (void)download:(WKDownload *)download decideDestinationUsingResponse:(NSURLResponse *)response
        suggestedFilename:(NSString *)name completionHandler:(void (^)(NSURL *))done {
    void (^saveTo)(NSURL *) = ^(NSURL *destination) {
        if (!destination) { done(nil); return; }
        NSFileManager *files = NSFileManager.defaultManager;
        NSURL *folder = [destination.URLByDeletingLastPathComponent URLByAppendingPathComponent:
            [@".joomengine-" stringByAppendingString:NSUUID.UUID.UUIDString] isDirectory:YES];
        NSError *error = nil;
        if (![files createDirectoryAtURL:folder withIntermediateDirectories:NO attributes:nil error:&error]) {
            done(nil); showMessage(@"Download could not start", error.localizedDescription); return;
        }
        DownloadTarget *target = [[DownloadTarget alloc] init];
        target.destination = destination;
        target.replacing = [files fileExistsAtPath:destination.path];
        target.temporaryFile = [folder URLByAppendingPathComponent:@"download"];
        [self.downloads setObject:target forKey:download];
        done(target.temporaryFile);
    };
#ifdef JOOMENGINE_NATIVE_QA
    auto path = qa::downloadPath(name.UTF8String ?: "");
    if (!path.empty()) { saveTo([NSURL fileURLWithPath:nativeString(path)]); return; }
#endif
    NSSavePanel *panel = NSSavePanel.savePanel;
    panel.nameFieldStringValue = name.lastPathComponent.length ? name.lastPathComponent : @"download";
    [panel beginWithCompletionHandler:^(NSModalResponse result) { saveTo(result == NSModalResponseOK ? panel.URL : nil); }];
}

- (void)downloadDidFinish:(WKDownload *)download {
    DownloadTarget *target = [self.downloads objectForKey:download];
    if (!target) return;
    [self.downloads removeObjectForKey:download];
    NSFileManager *files = NSFileManager.defaultManager;
    NSError *error = nil;
    BOOL success;
    if (target.replacing && [files fileExistsAtPath:target.destination.path])
        success = [files replaceItemAtURL:target.destination withItemAtURL:target.temporaryFile backupItemName:nil
                                  options:0 resultingItemURL:nullptr error:&error];
    else
        success = [files moveItemAtURL:target.temporaryFile toURL:target.destination error:&error];
    if (success) [files removeItemAtURL:target.temporaryFile.URLByDeletingLastPathComponent error:nullptr];
    else showMessage(@"Download could not be saved", [NSString stringWithFormat:@"%@\nThe downloaded file is at %@.",
                                                     error.localizedDescription, target.temporaryFile.path]);
}

- (void)download:(WKDownload *)download didFailWithError:(NSError *)error resumeData:(NSData *)resumeData {
    DownloadTarget *target = [self.downloads objectForKey:download];
    if (target) [NSFileManager.defaultManager removeItemAtURL:target.temporaryFile.URLByDeletingLastPathComponent error:nullptr];
    [self.downloads removeObjectForKey:download];
    if (!([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled))
        showMessage(@"Download failed", error.localizedDescription);
}

- (void)webView:(WKWebView *)view runOpenPanelWithParameters:(WKOpenPanelParameters *)parameters
        initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSArray<NSURL *> *))done {
    NSOpenPanel *panel = NSOpenPanel.openPanel;
    panel.allowsMultipleSelection = parameters.allowsMultipleSelection;
    panel.canChooseDirectories = parameters.allowsDirectories;
    panel.canChooseFiles = !parameters.allowsDirectories;
    [panel beginSheetModalForWindow:view.window completionHandler:^(NSModalResponse result) { done(result == NSModalResponseOK ? panel.URLs : nil); }];
}

- (void)webView:(WKWebView *)view runJavaScriptAlertPanelWithMessage:(NSString *)message
        initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))done {
    showMessage(@"JoomEngine", message); done();
}
- (void)webView:(WKWebView *)view runJavaScriptConfirmPanelWithMessage:(NSString *)message
        initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))done {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = message;
    [alert addButtonWithTitle:@"OK"]; [alert addButtonWithTitle:@"Cancel"];
    done([alert runModal] == NSAlertFirstButtonReturn);
}
- (void)webView:(WKWebView *)view runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)text
        initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString *))done {
    NSAlert *alert = [[NSAlert alloc] init]; alert.messageText = prompt;
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 320, 24)];
    input.stringValue = text ?: @""; alert.accessoryView = input;
    [alert addButtonWithTitle:@"OK"]; [alert addButtonWithTitle:@"Cancel"];
    alert.window.initialFirstResponder = input;
    done([alert runModal] == NSAlertFirstButtonReturn ? input.stringValue : nil);
}

- (void)webView:(WKWebView *)view didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    if (view != self.owner || ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) ||
        ([error.domain isEqualToString:@"WebKitErrorDomain"] && error.code == 102)) return;
    [view loadHTMLString:@"<meta name='viewport' content='width=device-width'><main style='font:18px system-ui;padding:3em'>"
        "<h1>Playground could not open</h1><p>Check your connection and try again.</p>"
        "<a href='https://playground.joomengine.org/'>Retry Playground</a></main>" baseURL:nil];
}
@end

int main() {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        JoomEngineHost *host = [[JoomEngineHost alloc] init];
        // NSApplication.delegate is weak. Retain the delegate until the run loop exits.
        __attribute__((objc_precise_lifetime)) JoomEngineHost *delegate = host;
        app.delegate = delegate;
        choc::messageloop::run();
#ifdef JOOMENGINE_NATIVE_QA
        return qa::exitCode();
#else
        return 0;
#endif
    }
}
