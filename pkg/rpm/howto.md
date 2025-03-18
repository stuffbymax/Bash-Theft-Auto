
### 1. Save the SPEC file
Save the following SPEC file in `/pkg/rpm/bash-theft-auto.spec`.

### 2. Download the source
```sh
cd /pkg/rpm/
wget https://github.com/stuffbymax/Bash-Theft-Auto/archive/refs/heads/main.zip
```

### 3. Build the RPM
```sh
rpmbuild -ba /pkg/rpm/bash-theft-auto.spec
```

### 4. Install the package
```sh
sudo dnf install /pkg/rpm/RPMS/noarch/bash-theft-auto-2.0.1-1.noarch.rpm
