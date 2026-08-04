#!/bin/bash

# Get local version from version.txt
if [[ ! -f version.txt ]]; then
    echo "version.txt not found locally."
    exit 1
fi

LOCAL_VERSION=$(<version.txt)

# Correct RAW URL for remote version.txt
REMOTE_URL="https://raw.githubusercontent.com/stuffbymax/Bash-Theft-Auto/main/version.txt"

# Fetch remote version using curl
REMOTE_VERSION=$(curl -sL "$REMOTE_URL")

# Check if fetch was successful
if [[ -z "$REMOTE_VERSION" ]]; then
    echo " Failed to fetch remote version from GitHub."
    echo "Tried: $REMOTE_URL"
    exit 1
fi

# Version comparison function
version_gt() {
    # Compares semantic versions, returns 0 (true) if $1 > $2
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]
}

# Display version info
echo "🎮 Bash Theft Auto - Version Check"
echo "Local version:  $LOCAL_VERSION"
echo "Remote version: $REMOTE_VERSION"

# Compare and report
if version_gt "$REMOTE_VERSION" "$LOCAL_VERSION"; then
    echo " A new version is available! Please update:"
    echo "https://github.com/stuffbymax/Bash-Theft-Auto"
elif [[ "$REMOTE_VERSION" == "$LOCAL_VERSION" ]]; then
    echo " You are using the latest version."
else
    echo "Local version is newer than remote. (Dev build?)"
fi
