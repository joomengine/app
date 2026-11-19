#include "desktop.hpp"
#include <choc/gui/choc_MessageLoop.h>
#include <webkit2/webkit2.h>
#include <libsoup/soup.h>
#ifdef JOOMENGINE_NATIVE_QA
#include "native_qa.hpp"
#endif

#include <string>
#include <string_view>

namespace {

struct Window {
    GtkWidget* shell;
    WebKitWebView* view;
    GtkWidget* recovery;
    GtkWidget* reload;
    bool auxiliary;
    bool committed = false;
};

std::string profileDirectory(bool cache) {
#ifdef JOOMENGINE_NATIVE_QA
    return qa::profilePath() + (cache ? "/cache" : "/data");
#else
    return std::string(cache ? g_get_user_cache_dir() : g_get_user_data_dir()) + "/" + joomengine::id;
#endif
}

void showError(GtkWindow* parent, const char* message, const char* detail) {
    auto* dialog = gtk_message_dialog_new(parent, GTK_DIALOG_DESTROY_WITH_PARENT,
        GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE, "%s", message);
    gtk_message_dialog_format_secondary_text(GTK_MESSAGE_DIALOG(dialog), "%s", detail);
    g_signal_connect_swapped(dialog, "response", G_CALLBACK(gtk_widget_destroy), dialog);
    gtk_widget_show(dialog);
}

GtkWindow* downloadParent(WebKitDownload* download) {
    auto* view = webkit_download_get_web_view(download);
    auto* top = view ? gtk_widget_get_toplevel(GTK_WIDGET(view)) : nullptr;
    return GTK_IS_WINDOW(top) ? GTK_WINDOW(top) : nullptr;
}

gboolean chooseDestination(WebKitDownload* download, const gchar* suggested, gpointer) {
    std::string filename;
#ifdef JOOMENGINE_NATIVE_QA
    filename = qa::downloadPath(suggested ? suggested : "download");
#endif
    if (filename.empty()) {
        auto* chooser = gtk_file_chooser_native_new("Save Download", downloadParent(download),
            GTK_FILE_CHOOSER_ACTION_SAVE, "_Save", "_Cancel");
        auto* picker = GTK_FILE_CHOOSER(chooser);
        gchar* basename = g_path_get_basename(suggested && *suggested ? suggested : "download");
        const std::string_view leaf(basename);
        gtk_file_chooser_set_current_name(picker, leaf == "." || leaf == ".." || leaf == "/" ? "download" : basename);
        g_free(basename);
        gtk_file_chooser_set_do_overwrite_confirmation(picker, TRUE);
        if (gtk_native_dialog_run(GTK_NATIVE_DIALOG(chooser)) == GTK_RESPONSE_ACCEPT) {
            gchar* selected = gtk_file_chooser_get_filename(picker);
            if (selected) filename = selected;
            g_free(selected);
        }
        g_object_unref(chooser);
    }
    gchar* destination = filename.empty() ? nullptr : g_filename_to_uri(filename.c_str(), nullptr, nullptr);
    if (destination) {
        webkit_download_set_allow_overwrite(download, TRUE);
        webkit_download_set_destination(download, destination);
        g_free(destination);
    } else {
        webkit_download_cancel(download);
    }
    return TRUE;
}

void beginDownload(WebKitWebContext*, WebKitDownload* download, GtkApplication* app) {
    // Keep the event loop alive if the source window closes during an export.
    g_application_hold(G_APPLICATION(app));
    g_signal_connect(download, "decide-destination", G_CALLBACK(chooseDestination), nullptr);
    g_signal_connect_swapped(download, "finished", G_CALLBACK(g_application_release), app);
    g_signal_connect(download, "failed", G_CALLBACK(+[](WebKitDownload* item, GError* error, gpointer) {
        if (!g_error_matches(error, WEBKIT_DOWNLOAD_ERROR, WEBKIT_DOWNLOAD_ERROR_CANCELLED_BY_USER))
            showError(downloadParent(item), "Download failed", error->message);
    }), nullptr);
}

void destroyLater(GtkWidget* window) {
    g_object_ref(window);
    choc::messageloop::postMessage([window] {
        gtk_widget_destroy(window);
        g_object_unref(window);
    });
}

void openExternal(GtkWindow* parent, const char* uri) {
    if (!uri || !joomengine::isExternalWebURL(uri)) return;
    GError* error = nullptr;
    if (!gtk_show_uri_on_window(parent, uri, GDK_CURRENT_TIME, &error) && error) {
        showError(parent, "Could not open the link", error->message);
        g_error_free(error);
    }
}

gboolean decidePolicy(WebKitWebView*, WebKitPolicyDecision* decision, WebKitPolicyDecisionType type, Window* window) {
    // Main-resource response policy keeps cross-origin frames, fetches and
    // redirects to downloadable attachments on WebKit's normal paths.
    if (type != WEBKIT_POLICY_DECISION_TYPE_RESPONSE) return FALSE;
    auto* responseDecision = WEBKIT_RESPONSE_POLICY_DECISION(decision);
    if (!webkit_response_policy_decision_is_main_frame_main_resource(responseDecision)) return FALSE;
    auto* response = webkit_response_policy_decision_get_response(responseDecision);
    auto* headers = webkit_uri_response_get_http_headers(response);
    gchar* disposition = nullptr;
    if (headers) soup_message_headers_get_content_disposition(headers, &disposition, nullptr);
    const bool attachment = disposition && g_ascii_strcasecmp(disposition, "attachment") == 0;
    g_free(disposition);
    if (attachment || !webkit_response_policy_decision_is_mime_type_supported(responseDecision)) {
        webkit_policy_decision_download(decision);
        return TRUE;
    }
    const char* uri = webkit_uri_response_get_uri(response);
    if (uri && joomengine::isWorkspaceURL(uri)) return FALSE;
    webkit_policy_decision_ignore(decision);
    openExternal(GTK_WINDOW(window->shell), uri);
    if (window->auxiliary && !window->committed) destroyLater(window->shell);
    return TRUE;
}

Window* createWindow(GtkApplication* app, WebKitWebView* view, GtkWindow* opener) {
    auto* shell = gtk_application_window_new(app);
    auto* box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    auto* bar = gtk_menu_bar_new();
    auto* viewItem = gtk_menu_item_new_with_mnemonic("_View");
    auto* menu = gtk_menu_new();
    auto* reload = gtk_menu_item_new_with_mnemonic("_Reload");
    gtk_menu_item_set_submenu(GTK_MENU_ITEM(viewItem), menu);
    gtk_menu_shell_append(GTK_MENU_SHELL(menu), reload);
    gtk_menu_shell_append(GTK_MENU_SHELL(bar), viewItem);
    auto* shortcuts = gtk_accel_group_new();
    gtk_window_add_accel_group(GTK_WINDOW(shell), shortcuts);
    gtk_widget_add_accelerator(reload, "activate", shortcuts, GDK_KEY_r, GDK_CONTROL_MASK, GTK_ACCEL_VISIBLE);
    g_object_unref(shortcuts);
    g_signal_connect_swapped(reload, "activate", G_CALLBACK(webkit_web_view_reload), view);

    auto* recovery = gtk_info_bar_new_with_buttons("_Retry Playground", GTK_RESPONSE_ACCEPT, nullptr);
    gtk_info_bar_set_message_type(GTK_INFO_BAR(recovery), GTK_MESSAGE_WARNING);
    auto* label = gtk_label_new("Playground could not open. Check your connection and retry.");
    gtk_container_add(GTK_CONTAINER(gtk_info_bar_get_content_area(GTK_INFO_BAR(recovery))), label);
    gtk_widget_show(label);
    gtk_widget_set_no_show_all(recovery, TRUE);
    g_signal_connect(recovery, "response", G_CALLBACK(+[](GtkInfoBar*, gint, WebKitWebView* target) {
        webkit_web_view_load_uri(target, joomengine::url);
    }), view);

    gtk_box_pack_start(GTK_BOX(box), bar, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), recovery, FALSE, FALSE, 0);
    gtk_box_pack_start(GTK_BOX(box), GTK_WIDGET(view), TRUE, TRUE, 0);
    gtk_container_add(GTK_CONTAINER(shell), box);
    gtk_window_set_title(GTK_WINDOW(shell), joomengine::name);
    gtk_window_set_icon_name(GTK_WINDOW(shell), joomengine::id);
    gtk_window_set_default_size(GTK_WINDOW(shell), opener ? 1100 : 1400, opener ? 760 : 900);
    if (opener) {
        gtk_window_set_transient_for(GTK_WINDOW(shell), opener);
        gtk_window_set_destroy_with_parent(GTK_WINDOW(shell), TRUE);
    }
    auto* window = new Window{shell, view, recovery, reload, opener != nullptr};
    g_object_set_data_full(G_OBJECT(shell), "workspace-window", window, +[](gpointer p) { delete static_cast<Window*>(p); });
    g_signal_connect(view, "decide-policy", G_CALLBACK(decidePolicy), window);
    g_signal_connect(view, "create", G_CALLBACK(+[](WebKitWebView* source, WebKitNavigationAction* action, Window* parent) -> GtkWidget* {
        const char* uri = webkit_uri_request_get_uri(webkit_navigation_action_get_request(action));
        if (uri && *uri && !joomengine::isWorkspaceURL(uri) && !joomengine::isExternalWebURL(uri)) return nullptr;
        // Related views share the owning web process, website storage and the
        // opener used by detached Code and Adminer to exchange messages/DOM.
        auto* child = webkit_web_view_new_with_related_view(source);
        createWindow(gtk_window_get_application(GTK_WINDOW(parent->shell)), WEBKIT_WEB_VIEW(child), GTK_WINDOW(parent->shell));
        return child;
    }), window);
    g_signal_connect(view, "ready-to-show", G_CALLBACK(+[](WebKitWebView*, Window* target) {
        gtk_widget_show_all(target->shell);
    }), window);
    g_signal_connect(view, "close", G_CALLBACK(+[](WebKitWebView*, Window* target) {
        destroyLater(target->shell);
    }), window);
    g_signal_connect(shell, "delete-event", G_CALLBACK(+[](GtkWidget*, GdkEvent*, Window* target) -> gboolean {
        webkit_web_view_try_close(target->view);
        return TRUE;
    }), window);
    g_signal_connect(view, "load-changed", G_CALLBACK(+[](WebKitWebView*, WebKitLoadEvent event, Window* target) {
        if (event == WEBKIT_LOAD_STARTED) gtk_widget_hide(target->recovery);
        if (event == WEBKIT_LOAD_COMMITTED) target->committed = true;
    }), window);
    g_signal_connect(view, "load-failed", G_CALLBACK(+[](WebKitWebView*, WebKitLoadEvent, const gchar*, GError* error, Window* target) -> gboolean {
        if (g_error_matches(error, WEBKIT_NETWORK_ERROR, WEBKIT_NETWORK_ERROR_CANCELLED)
            || g_error_matches(error, WEBKIT_POLICY_ERROR, WEBKIT_POLICY_ERROR_FRAME_LOAD_INTERRUPTED_BY_POLICY_CHANGE))
            return FALSE;
        gtk_widget_show(target->recovery);
        return TRUE;
    }), window);
    g_signal_connect(view, "web-process-terminated", G_CALLBACK(+[](WebKitWebView*, WebKitWebProcessTerminationReason, Window* target) {
        gtk_widget_show(target->recovery);
    }), window);
    return window;
}

void activate(GtkApplication* app, gpointer) {
    if (auto* existing = gtk_application_get_active_window(app)) {
        gtk_window_present(existing);
        return;
    }
    const auto data = profileDirectory(false);
    const auto cache = profileDirectory(true);
    if (g_mkdir_with_parents(data.c_str(), 0700) || g_mkdir_with_parents(cache.c_str(), 0700)) {
        auto* message = gtk_message_dialog_new(nullptr, GTK_DIALOG_MODAL, GTK_MESSAGE_ERROR, GTK_BUTTONS_CLOSE,
            "Could not create JoomEngine's browser profile.");
        gtk_dialog_run(GTK_DIALOG(message));
        gtk_widget_destroy(message);
        return;
    }
    auto* manager = webkit_website_data_manager_new("base-data-directory", data.c_str(), "base-cache-directory", cache.c_str(), nullptr);
    auto* context = webkit_web_context_new_with_website_data_manager(manager);
    g_object_unref(manager);
    webkit_web_context_set_cache_model(context, WEBKIT_CACHE_MODEL_WEB_BROWSER);
    webkit_cookie_manager_set_persistent_storage(webkit_web_context_get_cookie_manager(context),
        (data + "/cookies.sqlite").c_str(), WEBKIT_COOKIE_PERSISTENT_STORAGE_SQLITE);
    g_signal_connect(context, "download-started", G_CALLBACK(beginDownload), app);
    auto* view = WEBKIT_WEB_VIEW(webkit_web_view_new_with_context(context));
    g_object_unref(context);
    auto* settings = webkit_web_view_get_settings(view);
    webkit_settings_set_javascript_can_open_windows_automatically(settings, TRUE);
    webkit_settings_set_enable_developer_extras(settings, TRUE);
    auto* owner = createWindow(app, view, nullptr);
#ifdef JOOMENGINE_NATIVE_QA
    auto* script = webkit_user_script_new(qa::script().c_str(), WEBKIT_USER_CONTENT_INJECT_TOP_FRAME,
        WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_END, nullptr, nullptr);
    webkit_user_content_manager_add_script(webkit_web_view_get_user_content_manager(view), script);
    webkit_user_script_unref(script);
    g_signal_connect(view, "notify::title", G_CALLBACK(+[](WebKitWebView* source, GParamSpec*, Window* target) {
        const char* title = webkit_web_view_get_title(source);
        if (title) qa::onTitle(title, [target] { gtk_menu_item_activate(GTK_MENU_ITEM(target->reload)); },
            [target] { gtk_window_close(GTK_WINDOW(target->shell)); });
    }), owner);
#endif
    gtk_widget_show_all(owner->shell);
    webkit_web_view_load_uri(view, joomengine::url);
}

} // namespace

int main(int argc, char** argv) {
    g_set_prgname(joomengine::id);
    g_set_application_name(joomengine::name);
#ifdef JOOMENGINE_NATIVE_QA
    auto flags = G_APPLICATION_NON_UNIQUE;
#else
    auto flags = G_APPLICATION_DEFAULT_FLAGS;
#endif
    auto* app = gtk_application_new(joomengine::id, flags);
    choc::messageloop::initialise();
    g_signal_connect(app, "activate", G_CALLBACK(activate), nullptr);
    const int status = g_application_run(G_APPLICATION(app), argc, argv);
    g_object_unref(app);
#ifdef JOOMENGINE_NATIVE_QA
    return status ? status : qa::exitCode();
#else
    return status;
#endif
}
