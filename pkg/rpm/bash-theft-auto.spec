Name:           bash-theft-auto
Version:        2.0.1
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
# No build required

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/usr/share/doc/%{name}
install -Dm755 bta.sh %{buildroot}/usr/bin/bta
install -Dm644 README.md %{buildroot}/usr/share/doc/%{name}/README.md

%files
/usr/bin/bta
/usr/share/doc/%{name}/README.md

%changelog
* Tue Mar 18 2025 Your Name <martinp6282@gmail.com> - 2.0.1-1
- Initial Fedora RPM package
