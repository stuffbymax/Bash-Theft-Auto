#!/bin/bash

# Local version - read from local file
LOCAL_VERSION=$(<version.txt)

# Remote version file URL
REMOTE_URL="https://raw.githubusercontent.com/stuffbymax/Bash-Theft-Auto/main/version.txt"

# Fetch remote version
REMOTE_VERSION=$(curl -s "$REMOTE_URL")

# Function to compare versions
version_gt() {
    # Returns 0 if $1 > $2
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" != "$1" ]
}

echo "🎮 Bash Theft Auto - Version Check"
echo "Local version:  $LOCAL_VERSION"
echo "Remote version: $REMOTE_VERSION"

if version_gt "$REMOTE_VERSION" "$LOCAL_VERSION"; then
    echo "🔔 A new version is available! Update recommended."
else
    echo "✅ You are using the latest version."
fi
