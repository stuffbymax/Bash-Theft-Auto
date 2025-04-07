#!/bin/bash

# Function to display the installation options
display_options() {
    echo "Choose the language version you want to install:"
    echo "1. English (bta)"
    echo "2. Arabic (bta-arabic)"
    echo "3. Czech (cz-bta)"
    echo "4. Exit"
}

# Function to install English version
install_english() {
    echo "Renaming and installing the English version..."
    # Rename and move the English version to /usr/local/bin (or another directory in your PATH)
    mv ./bta.sh /usr/local/bin/bta
    chmod +x /usr/local/bin/bta
    echo "English version installed as 'bta' in /usr/local/bin"
}

# Function to install Arabic version
install_arabic() {
    echo "Renaming and installing the Arabic version..."
    # Rename and move the Arabic version to /usr/local/bin (or another directory in your PATH)
    mv ./bta-arabic.sh /usr/local/bin/bta
    chmod +x /usr/local/bin/bta
    echo "Arabic version installed as 'bta' in /usr/local/bin"
}

# Function to install Czech version
install_czech() {
    echo "Renaming and installing the Czech version..."
    # Rename and move the Czech version to /usr/local/bin (or another directory in your PATH)
    mv ./cz-bta.sh /usr/local/bin/bta
    chmod +x /usr/local/bin/bta
    echo "Czech version installed as 'bta' in /usr/local/bin"
}

# Main logic to handle user input
while true; do
    display_options
    read -p "Please enter your choice (1-4): " choice

    case $choice in
        1)
            install_english
            break
            ;;
        2)
            install_arabic
            break
            ;;
        3)
            install_czech
            break
            ;;
        4)
            echo "Exiting script."
            break
            ;;
        *)
            echo "Invalid choice. Please choose 1, 2, 3, or 4."
            ;;
    esac
done
