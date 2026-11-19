Name:           joomengine
Version:        %{project_version}
Release:        1%{?dist}
Summary:        Desktop application for JoomEngine Playground
License:        Apache-2.0
URL:            https://github.com/joomengine/joomengine
Source0:        https://github.com/joomengine/joomengine/archive/refs/tags/v%{version}.tar.gz#/%{name}-%{version}.tar.gz
BuildRequires:  gcc-c++
BuildRequires:  cmake >= 3.24
BuildRequires:  ninja-build
BuildRequires:  qt6-qtbase-devel >= 6.8
BuildRequires:  qt6-qtwebengine-devel >= 6.8
BuildRequires:  desktop-file-utils
Requires:       qt6-qtwebengine >= 6.8

%description
Open the hosted JoomEngine Playground in a native desktop window with
persistent local projects, related tool windows and site downloads.

%prep
%autosetup

%build
%cmake -G Ninja
%cmake_build

%install
%cmake_install

%check
desktop-file-validate %{buildroot}%{_datadir}/applications/org.joomengine.app.desktop

%files
%{_bindir}/joomengine
%{_datadir}/applications/org.joomengine.app.desktop
%{_datadir}/icons/hicolor/*/apps/org.joomengine.app.png
%{_datadir}/metainfo/org.joomengine.app.metainfo.xml
%{_datadir}/licenses/joomengine/
