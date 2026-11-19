#pragma once
#ifndef JOOMENGINE_NATIVE_QA
#error Native test hooks belong only in the separate QA build.
#endif

#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iterator>
#include <string>
#include <string_view>

namespace qa {
inline std::string environment(const char* name) {
    const char* value = std::getenv(name);
    return value ? value : "";
}

inline std::string profilePath() {
    return environment("JOOMENGINE_QA_PROFILE");
}

inline std::string script() {
    std::ifstream input(std::filesystem::u8path(environment("JOOMENGINE_QA_SCRIPT")), std::ios::binary);
    return std::string(std::istreambuf_iterator<char>(input), std::istreambuf_iterator<char>());
}

inline std::string downloadPath(std::string_view suggested) {
    return suggested.empty() ? std::string{} : environment("JOOMENGINE_QA_EXPORT");
}

inline int result = 1;
inline int exitCode() { return result; }

// Called only for the owner window in the QA build. File output also works
// for native GUI binaries without an attached console on Windows or macOS.
template<class Reload, class Quit>
void onTitle(std::string_view title, Reload reload, Quit quit) {
    const std::string prefix = "JE-QA/" + environment("JOOMENGINE_QA_ID") + "/";
    if (title.compare(0, prefix.size(), prefix) != 0) return;
    title.remove_prefix(prefix.size());
    const auto separator = title.find('/');
    if (separator == std::string_view::npos) return;
    const auto command = title.substr(0, separator);
    const auto detail = title.substr(separator + 1, 1600);
    if (command == "pass" &&
        !std::filesystem::exists(std::filesystem::u8path(environment("JOOMENGINE_QA_GATE")))) return;

    std::ofstream log(std::filesystem::u8path(environment("JOOMENGINE_QA_LOG")), std::ios::app);
    log << command << ' ' << detail << '\n';
    log.close();

    if (command == "reload" || command == "retry-module") reload();
    if (command == "fail" || command == "pass") {
        result = command == "pass" ? 0 : 1;
        quit();
    }
}
}  // namespace qa
