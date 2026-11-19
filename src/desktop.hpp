#pragma once

#include <algorithm>
#include <string_view>

namespace joomengine {

inline constexpr char name[] = "JoomEngine";
inline constexpr char url[] = "https://playground.joomengine.org/";
inline constexpr char id[] = "org.joomengine.app";

// Native engines supply serialized, absolute navigation URLs. These helpers
// classify top-level windows only; resource and API requests use the webview.
inline bool validURLText(std::string_view value)
{
    return !value.empty() && std::none_of(value.begin(), value.end(), [](unsigned char c) {
        return c <= 0x20 || c == 0x7f || c == '\\';
    });
}

inline std::string_view authority(std::string_view address, std::string_view scheme)
{
    if (address.substr(0, scheme.size()) != scheme) return {};
    const auto rest = address.substr(scheme.size());
    return rest.substr(0, rest.find_first_of("/?#"));
}

inline bool isWorkspaceURL(std::string_view address)
{
    if (address == "about:blank") return true;
    if (!validURLText(address)) return false;
    if (address.substr(0, 5) == "blob:") address.remove_prefix(5);
    const auto host = authority(address, "https://");
    return host == "playground.joomengine.org" || host == "playground.joomengine.org:443";
}

inline bool isExternalWebURL(std::string_view address)
{
    if (!validURLText(address) || isWorkspaceURL(address)) return false;
    auto host = authority(address, "https://");
    if (host.empty()) host = authority(address, "http://");
    return !host.empty() && host.find('@') == std::string_view::npos;
}

} // namespace joomengine
