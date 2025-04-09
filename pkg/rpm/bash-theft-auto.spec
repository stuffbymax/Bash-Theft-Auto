Name:           bash-theft-auto
Version:        2.0.2
Release:        1%{?dist}
Summary:        A simple text-based game that simulates a car thief adventure

License:        MIT
URL:            https://github.com/stuffbymax/Bash-Theft-Auto
Source0:        https://github.com/stuffbymax/Bash-Theft-Auto/archive/refs/heads/main.zip

BuildArch:      noarch
Requires:       bash, mpg123

%description
Bash Theft Auto is a simple text-based game that simulates a car thief adventure.

%prep
%autosetup -n Bash-Theft-Auto-main

%build
# No build required, since it's a script

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/doc/%{name}
mkdir -p %{buildroot}/usr/share/%{name}/music
mkdir -p %{buildroot}/usr/share/%{name}/sfx
mkdir -p %{buildroot}/usr/share/%{name}/saves

# Install the main script
install -Dm755 bta.sh %{buildroot}/usr/bin/bta

# Install documentation
install -Dm644 README.md %{buildroot}/usr/share/doc/%{name}/README.md

# Install music, sfx, and saves directories (adjust the file paths as necessary)
install -Dm755 music/* %{buildroot}/usr/share/%{name}/music/
install -Dm755 sfx/* %{buildroot}/usr/share/%{name}/sfx/
install -Dm755 saves/* %{buildroot}/usr/share/%{name}/saves/

%files
/usr/bin/bta
/usr/share/doc/%{name}/README.md
/usr/share/%{name}/music/*
/usr/share/%{name}/sfx/*
/usr/share/%{name}/saves/*

%changelog
* Tue Mar 18 2025 Martin Petik <martinp6282@gmail.com> - 2.0.2-1
- Updated to version 2.0.2
- Fixed RPM spec for proper directory setup
* Mon Mar 15 2025 Martin Petik <martinp6282@gmail.com> - 2.0.1-1
- Initial Fedora RPM package
