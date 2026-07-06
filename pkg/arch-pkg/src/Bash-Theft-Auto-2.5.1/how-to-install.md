# Install

## For Arch Linux:

### not yet on AUR

## manual

1.  Navigate to the package directory.
    ```
    cd /home/zdislav/Bash-Theft-Auto/pkg/arch-pkg/
    ```
    
2.  Build and install the package.
    ```
    makepkg -si
    ```

---

## For Fedora Linux:

1.  Navigate to the package directory.
    ```
    cd /home/zdislav/Bash-Theft-Auto/pkg/rpm/
    ```
    
2.  Build the RPM package.
    ```
    rpmbuild -ba bash-theft-auto.spec
    ```
    
3.  Install the package (pls adjust the version if needed).
    ```
    # The built RPM is usually in ~/rpmbuild/RPMS/noarch/
    sudo dnf install ~/rpmbuild/RPMS/noarch/bash-theft-auto-*.noarch.rpm
    ```
# Usage

## After System Installation:

Once installed using the steps above, you should be able to run the command directly:

```
bta
```

## from source

1. make it executiable 

```
chmod +x bta
```

## then type

```
./bta
```

## windows no official support
## bsd no official support
## mac no official support
