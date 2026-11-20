#define JOOMENGINE_NATIVE_QA
#include "native_qa.hpp"
#include <iostream>

int main()
{
    using namespace joomengine;
    for (const auto* internal : {url, "https://playground.joomengine.org:443/__runtime/tool",
                                 "blob:https://playground.joomengine.org/session-export", "about:blank"}) {
        if (!isWorkspaceURL(internal) || isExternalWebURL(internal)) return 1;
    }
    for (const auto* other : {"https://api.github.com/repos/joomengine/joomengine", "http://localhost:11434",
                              "https://playground.joomengine.org.example.com", "https://playground.joomengine.org:444"}) {
        if (isWorkspaceURL(other) || !isExternalWebURL(other)) return 1;
    }
    for (const auto* invalid : {"file:///etc/hosts", "javascript:void(0)", "data:text/plain,hello",
                                "https://playground.joomengine.org@localhost/", "blob:https://example.com/id",
                                "https://example.com\\path", "https://example.com\n/", ""}) {
        if (isWorkspaceURL(invalid) || isExternalWebURL(invalid)) return 1;
    }
    bool pending = true;
    if (!qa::takeSavedReloadConfirmation(pending, true, url) ||
        qa::takeSavedReloadConfirmation(pending, true, url)) return 1;
    pending = true;
    if (qa::takeSavedReloadConfirmation(pending, false, url) || pending) return 1;
    for (const auto* other : {"about:blank", "blob:https://playground.joomengine.org/session",
                              "https://playground.joomengine.org.example.com", "https://playground.joomengine.org:444",
                              "https://playground.joomengine.org@localhost", "http://playground.joomengine.org"}) {
        pending = true;
        if (qa::takeSavedReloadConfirmation(pending, true, other) || pending) return 1;
    }
    std::cout << "Native window URL and saved Reload confirmation policies passed\n";
}
