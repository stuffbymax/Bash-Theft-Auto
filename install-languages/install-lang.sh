#!/bin/bash

# Check for root privileges
if [[ "$EUID" -ne 0 ]]; then
    echo "Please run this program as root (e.g., with sudo)."
    exit 1
fi

# Function to select the language
select_language() {
    echo "Select your language:"
    echo "1. English"
    echo "2. Arabic"
    echo "3. Czech"
    echo "4. Slovakian"
    echo "5. Russian"
    read -rp "Please enter your choice (1-5): " lang_choice

    case $lang_choice in
        1) lang="en" ;;
        2) lang="ar" ;;
        3) lang="cz" ;;
        4) lang="sk" ;;
        5) lang="ru" ;;
        *)
            echo "Invalid choice. Defaulting to English."
            lang="en"
            ;;
    esac
}

# Language options
en() {
    echo "Choose the language version you want to install:"
    echo "1. English (bta)"
    echo "2. Arabic (bta-arabic)"
    echo "3. Czech (cz-bta)"
    echo "4. Slovakian (sk-bta)"
    echo "5. Russian (ru-bta)"
    echo "6. Exit"
}

ar() {
    echo "اختر النسخة التي تريد تثبيتها:"
    echo "1. الإنجليزية (bta)"
    echo "2. العربية (bta-arabic)"
    echo "3. التشيكية (cz-bta)"
    echo "4. السلوفاكية (sk-bta)"
    echo "5. الروسية (ru-bta)"
    echo "6. خروج"
}

cz() {
    echo "Vyberte jazykovou verzi, kterou chcete nainstalovat:"
    echo "1. Anglická (bta)"
    echo "2. Arabská (bta-arabic)"
    echo "3. Česká (cz-bta)"
    echo "4. Slovenská (sk-bta)"
    echo "5. Ruská (ru-bta)"
    echo "6. Konec"
}

sk() {
    echo "Vyberte jazykovú verziu, ktorú chcete nainštalovať:"
    echo "1. Anglická (bta)"
    echo "2. Arabská (bta-arabic)"
    echo "3. Česká (cz-bta)"
    echo "4. Slovenská (sk-bta)"
    echo "5. Ruská (ru-bta)"
    echo "6. Koniec"
}

ru() {
    echo "Выберите версию языка, которую вы хотите установить:"
    echo "1. Английская (bta)"
    echo "2. Арабская (bta-arabic)"
    echo "3. Чешская (cz-bta)"
    echo "4. Словацкая (sk-bta)"
    echo "5. Русская (ru-bta)"
    echo "6. Выход"
}

# Function to display options in the selected language
display_options() {
    case $lang in
        en) en ;;
        ar) ar ;;
        cz) cz ;;
        sk) sk ;;
        ru) ru ;;
        *) en ;;  # Default to English
    esac
}

# Generic install function
install_version() {
    local file="$1"
    local lang_name="$2"

    if [[ ! -f "./$file" ]]; then
        echo "Error: $file not found!"
        exit 1
    fi

    echo "Installing the $lang_name version..."
    install -Dm755 "./$file" "/usr/local/bin/bta"
    echo "$lang_name version installed as 'bta' in /usr/local/bin"
}

# Select language first
select_language

# Main logic to handle user input
while true; do
    display_options
    read -rp "Please enter your choice (1-6): " choice

    case $choice in
        1)
            install_version "bta.sh" "English"
            break
            ;;
        2)
            install_version "bta-arabic.sh" "Arabic"
            break
            ;;
        3)
            install_version "cz-bta.sh" "Czech"
            break
            ;;
        4)
            install_version "sk-bta.sh" "Slovakian"
            break
            ;;
        5)
            install_version "bta-russian.sh" "Russian"
            break
            ;;
        6)
            echo "Exiting script."
            break
            ;;
        *)
            echo "Invalid choice. Please choose 1 to 6."
            ;;
    esac
done
