# Bash-Theft-Auto muzyka i SFX © 2024 by stuffbymax - Martin Petik na licencji CC BY 4.0
# https://creativecommons.org/licenses/by/4.0/
# wer. 2.0.5 (Poprawki echa terminala)
#!/bin/bash

# --- Ustawienia Początkowe ---
# Ustaw BASEDIR na katalog, w którym znajduje się skrypt
# Używanie rozszerzenia parametrów dla potencjalnie lepszej kompatybilności niż realpath
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Wyjdź w przypadku błędu, aby zapobiec nieoczekiwanemu zachowaniu
# set -e # Odkomentuj, aby uzyskać bardziej rygorystyczne sprawdzanie błędów, jeśli jest to pożądane, ale może zbyt łatwo zakończyć działanie

# --- Funkcja Czyszczenia i Przechwytywanie Sygnałów ---
cleanup_and_exit() {
    echo -e "\nCzyszczenie i wychodzenie..."
    # Zatrzymaj muzykę, jeśli gra
    if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
        echo "Zatrzymywanie muzyki (PID: $music_pid)..."
        kill "$music_pid" &>/dev/null
        wait "$music_pid" 2>/dev/null
        music_pid=""
    fi
    # Przywróć echo terminala
    stty echo
    echo "Czyszczenie zakończone. Do widzenia."
    exit 0
}
# Przechwyć popularne sygnały wyjścia, aby uruchomić funkcję czyszczenia
trap cleanup_and_exit SIGINT SIGTERM SIGHUP

# --- 0. Zmienne Globalne ---
player_name=""
location="Los Santos" # Domyślna lokalizacja startowa
cash=0
health=100 # Domyślne zdrowie startowe
declare -a guns=() # Nazwy wewnętrzne: Pistol, Shotgun, SMG, Rifle, Sniper
declare -a items=() # Nazwy wewnętrzne: Health Pack
declare -A drugs=() # Klucze wewnętrzne: Weed, Cocaine, Heroin, Meth
declare -A skills=() # Klucze wewnętrzne: driving, strength, charisma, stealth, drug_dealer
body_armor_equipped=false
SAVE_DIR="saves" # Względem BASEDIR
declare -A gun_attributes=() # Klucze wewnętrzne: Pistol, Shotgun, SMG, Rifle, Sniper
music_pid="" # PID dla odtwarzacza muzyki w tle

# Inicjalizacja Atrybutów Broni (upewnij się, że tablica jest wypełniona)
gun_attributes=(
	["Pistol"]="success_bonus=5"
	["Shotgun"]="success_bonus=10"
	["SMG"]="success_bonus=15"
	["Rifle"]="success_bonus=20"
	["Sniper"]="success_bonus=25"
)

# Inicjalizacja Domyślnych Umiejętności/Narkotyków (używane w load_game i new_game)
declare -A default_skills=( ["driving"]=1 ["strength"]=1 ["charisma"]=1 ["stealth"]=1 ["drug_dealer"]=1 )
declare -A default_drugs=( ["Weed"]=0 ["Cocaine"]=0 ["Heroin"]=0 ["Meth"]=0 )


# --- Sprawdzanie Zależności ---
mpg123_available=true
if ! command -v mpg123 &> /dev/null; then
    echo "###########################################################"
    echo "# Ostrzeżenie: polecenie 'mpg123' nie znalezione.         #" # Warning: 'mpg123' command not found.
    echo "# Efekty dźwiękowe i muzyka wymagają mpg123.               #" # Sound effects and music require mpg123.
    echo "# Zainstaluj go, aby uzyskać pełne wrażenia.              #" # Please install it for the full experience.
    echo "#---------------------------------------------------------#"
    echo "# Na Debian/Ubuntu: sudo apt update && sudo apt install mpg123 #"
    echo "# Na Fedora:        sudo dnf install mpg123               #"
    echo "# Na Arch Linux:    sudo pacman -S mpg123                 #"
    echo "# Na macOS (Homebrew): brew install mpg123                #"
    echo "###########################################################"
    read -r -p "Naciśnij Enter, aby kontynuować bez dźwięku..." # Press Enter to continue without sound...
    mpg123_available=false
fi

# --- Ustawienia Efektów Dźwiękowych ---
sfx_dir="sfx"  # Katalog efektów dźwiękowych względem BASEDIR

# Funkcja do odtwarzania efektów dźwiękowych (obsługuje brak mpg123)
play_sfx_mpg() {
    if ! $mpg123_available; then
        return 1 # Dźwięk wyłączony
    fi
    local sound_name="$1" # Nazwa wewnętrzna (angielska)
    local sound_file="$BASEDIR/$sfx_dir/${sound_name}.mp3"
    if [[ -f "$sound_file" ]]; then
        if command -v mpg123 &> /dev/null; then
           # Uruchom w tle, odłączone, odrzuć stdout/stderr, chyba że debugujesz
           mpg123 -q "$sound_file" &>/dev/null &
            return 0  # Wskaż sukces
        fi
    else
        # Cicho ignoruj brakujące pliki SFX lub loguj je podczas debugowania
        # >&2 echo "Debug: Nie znaleziono pliku dźwiękowego: '$sound_file'" # Debug: Sound file not found: '$sound_file'
        return 1
    fi
    return 1 # Wskaż błąd (np. sprawdzenie mpg123 wewnątrz zawiodło)
}

# --- 1. Ładowanie Pluginów ---
plugin_dir="plugins" # Względem BASEDIR

if [[ -d "$BASEDIR/$plugin_dir" ]]; then
	# Użyj find w kontekście BASEDIR
	while IFS= read -r -d $'\0' plugin_script; do
		# Załaduj plugin używając pełnej ścieżki
		if [[ -f "$plugin_script" ]]; then
            # >&2 echo "Ładowanie pluginu: $plugin_script" # Debug message: Loading plugin: $plugin_script
            source "$plugin_script"
        fi
	done < <(find "$BASEDIR/$plugin_dir" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)
else
	# Niekoniecznie błąd, tylko informacja
	echo "Info: Katalog pluginów '$BASEDIR/$plugin_dir' nie znaleziony. Pomijanie ładowania pluginów." # Info: Plugin directory '$BASEDIR/$plugin_dir' not found. Skipping plugin load.
fi

# --- 3. Funkcje ---

# Wyczyść ekran i wyświetl nagłówek informacji o grze
clear_screen() {
    clear
    printf "\e[93m=========================================\e[0m\n"
    printf "\e[1;43m|        Bash Theft Auto                |\e[0m\n"
    printf "\e[93m=========================================\e[0m\n"
    printf " Gracz: %-15s | Lokalizacja: %s\n" "$player_name" "$location" # Player: %-15s | Location: %s
    printf " Kasa: \$%-16d | Zdrowie: %d%%\n" "$cash" "$health" # Cash: \$%-16d | Health: %d%%
    # Wyświetl status kamizelki kuloodpornej
    if $body_armor_equipped; then
        printf " Pancerz: \e[1;32mZałożony\e[0m\n" # Armor: Equipped
    else
        printf " Pancerz: \e[1;31mBrak\e[0m\n" # Armor: None
    fi
    printf "\e[1;34m=========================================\e[0m\n"
}

# --- O Grze ---
about_music_sfx() {
	clear_screen
	echo "-----------------------------------------"
	echo "|    O Muzyce i Efektach Dźwiękowych    |" # About the Music and Sound Effects
	echo "-----------------------------------------"
	echo ""
	echo "Muzyka i SFX © 2024 przez stuffbymax - Martin Petik" # Music and SFX © 2024 by stuffbymax - Martin Petik
	echo "Licencjonowane na CC BY 4.0:" # Licensed under CC BY 4.0:
	echo "https://creativecommons.org/licenses/by/4.0/"
	echo ""
	echo "Możesz swobodnie udostępniać i adaptować ten materiał" # You are free to share and adapt this material
	echo "w dowolnym celu, nawet komercyjnym, pod warunkiem," # for any purpose, even commercially, under the
	echo "że podasz odpowiednie uznanie autorstwa." # condition that you give appropriate credit.
	echo ""
	echo "Przykład uznania autorstwa:" # Attribution example:
	echo "'Music/SFX © 2024 stuffbymax - Martin Petik, CC BY 4.0'" # Keep as is
	echo ""
	echo "Więcej informacji: https://stuffbymax.me/" # More info: https://stuffbymax.me/
	echo ""
	echo "-----------------------------------------"
	echo "|          Licencja Kodu               |" # Code License
	echo "-----------------------------------------"
	echo ""
	echo "Kod Gry © 2024 stuffbymax" # Game Code © 2024 stuffbymax
	echo "Licencjonowane na Licencji MIT." # Licensed under the MIT License.
	echo "Pozwala na ponowne użycie z podaniem autorstwa." # Allows reuse with attribution.
	echo ""
	echo "Pełna Licencja:" # Full License:
	echo "https://github.com/stuffbymax/Bash-Theft-Auto/blob/main/LICENSE" # Ensure this link is correct
	echo ""
	echo "Dziękujemy za grę!" # Thank you for playing!
    echo "-----------------------------------------"
	read -r -p "Naciśnij Enter, aby wrócić..." # Press Enter to return...
}

# Funkcja sprawdzająca, czy gracz żyje i obsługująca śmierć
check_health() {
	if (( health <= 0 )); then
        health=0 # Zapobiegaj wyświetlaniu ujemnego zdrowia
		clear_screen
		echo -e "\n      \e[1;31m W A S T E D \e[0m\n" # Keep English WASTED for iconic value
		play_sfx_mpg "wasted"
		echo "Upadłeś z powodu odniesionych ran..." # You collapsed from your injuries...
		sleep 1
		echo "Budzisz się później..." # You wake up later...
		read -r -p "Naciśnij Enter, aby udać się do szpitala..." # Press Enter to go to the hospital...
		hospitalize_player # Obsługuje konsekwencje śmierci
        return 1 # Wskaż, że gracz był hospitalizowany (zginął)
	fi
    return 0 # Wskaż, że gracz jest w porządku
}

# Funkcja podróżowania do nowej lokalizacji
travel_to() {
	local travel_cost="$1"
	local new_location="$2"
    local current_location="$location" # Zapisz bieżącą lokalizację dla wiadomości

    # Zapobiegaj podróżowaniu do tej samej lokalizacji
    if [[ "$new_location" == "$current_location" ]]; then
        echo "Już jesteś w $new_location." # You are already in $new_location.
        read -r -p "Naciśnij Enter..." # Press Enter...
        return
    fi

	if (( cash >= travel_cost )); then
		printf "Podróżowanie z %s do %s (\$%d)...\n" "$current_location" "$new_location" "$travel_cost" # Traveling from %s to %s (\$%d)...
		play_sfx_mpg "air"

		# --- Animacja Podróży Lotniczej (Opcjonalne wywołanie pluginu) ---
        if command -v air_travel_animation &> /dev/null; then
		    air_travel_animation "$current_location" "$new_location" # Przekaż lokalizacje, może?
        else
            # Prosta animacja tekstowa, jeśli brakuje pluginu
            echo -n "["
            for _ in {1..20}; do echo -n "="; sleep 0.05; done
            echo ">]"
        fi
		# --- Koniec Animacji ---

		cash=$((cash - travel_cost))
		location="$new_location"
		echo "Bezpiecznie dotarłeś do $new_location." # You have arrived safely in $new_location.
        read -r -p "Naciśnij Enter..." # Press Enter...
	else
		echo "Za mało kasy (\$$travel_cost potrzeba) na podróż do $new_location." # Not enough cash (\$$travel_cost needed) to travel to $new_location.
		read -r -p "Naciśnij Enter..." # Press Enter...
	fi
}

# Funkcja menu zakupu broni
buy_guns() {
	local gun_choice=""
	clear_screen
	echo "--- Ammu-Nation ---" # Keep English name
	echo "Witaj! Co mogę dla ciebie zrobić?" # Welcome! What can I get for you?
	echo "-------------------"
	echo "1. Pistolet    (\$100)" # 1. Pistol      ($100)
	echo "2. Strzelba    (\$250)" # 2. Shotgun     ($250)
	echo "3. PM          (\$500)" # 3. SMG         ($500) -> Pistolet Maszynowy
	echo "4. Karabin     (\$750)" # 4. Rifle       ($750)
	echo "5. Snajperka   (\$1000)" # 5. Sniper      ($1000)
	echo "-------------------"
	echo "6. Wyjdź" # 6. Leave
    echo "-------------------"
    printf "Twoja kasa: \$%d\n" "$cash" # Your Cash: $%d
	read -r -p "Wpisz swój wybór: " gun_choice # Enter your choice:

	[[ ! "$gun_choice" =~ ^[0-9]+$ ]] && {
		echo "Nieprawidłowe dane wejściowe."; read -r -p "Naciśnij Enter..."; return # Invalid input. Press Enter...
	}

	case "$gun_choice" in
		1) buy_gun "Pistol" 100;; # Pass internal English name
		2) buy_gun "Shotgun" 250;;
		3) buy_gun "SMG" 500;;
		4) buy_gun "Rifle" 750;;
		5) buy_gun "Sniper" 1000;;
		6) echo "Wpadnij jeszcze!"; sleep 1; return;; # Come back anytime!
		*) echo "Nieprawidłowy wybór."; read -r -p "Naciśnij Enter...";; # Invalid choice. Press Enter...
	esac
}

# Funkcja pomocnicza do kupowania BRONI
buy_gun() {
	local gun_name_internal="$1" # Expecting internal English name
	local gun_cost="$2"
    local owned=false
    local gun_name_display="" # Translated name for display

    # Map internal name to display name
    case "$gun_name_internal" in
        "Pistol") gun_name_display="Pistolet";;
        "Shotgun") gun_name_display="Strzelba";;
        "SMG") gun_name_display="PM";;
        "Rifle") gun_name_display="Karabin";;
        "Sniper") gun_name_display="Snajperka";;
        *) gun_name_display="$gun_name_internal" ;; # Fallback
    esac

    # Check if already owned (using internal name)
    for owned_gun in "${guns[@]}"; do
        if [[ "$owned_gun" == "$gun_name_internal" ]]; then
            owned=true
            break
        fi
    done
    if $owned; then
        echo "Wygląda na to, że już masz $gun_name_display, partnerze." # Looks like you already got a $gun_name_display there, partner.
        read -r -p "Naciśnij Enter..." # Press Enter...
        return
    fi

    # Check cash
	if (( cash >= gun_cost )); then
        play_sfx_mpg "cash_register"
		# --- Animacja Zakupu (Opcjonalne wywołanie pluginu) ---
        if command -v buy_animation &> /dev/null; then
            buy_animation "$gun_name_internal" # Use internal name if plugin expects it
        fi
        # --- Koniec Animacji ---

		cash=$((cash - gun_cost))
		guns+=("$gun_name_internal") # Add internal (English) name to guns array
		echo "Jeden $gun_name_display, już podaję! To będzie \$ $gun_cost." # One $gun_name_display, coming right up! That'll be \$$gun_cost.
		read -r -p "Naciśnij Enter..." # Press Enter...
	else
		echo "Sorki, kolego, za mało kasy na $gun_name_display (potrzeba \$ $gun_cost)." # Sorry pal, not enough cash for the $gun_name_display (\$$gun_cost needed).
		read -r -p "Naciśnij Enter..." # Press Enter...
	fi
}

# Funkcja pokazująca ekwipunek
show_inventory() {
	clear_screen
	echo "--- Ekwipunek i Statystyki ---" # Inventory & Stats
	printf " Kasa: \$%d\n" "$cash" # Cash: $%d
	printf " Zdrowie: %d%%\n" "$health" # Health: %d%%
    if $body_armor_equipped; then
        printf " Pancerz: \e[1;32mZałożony\e[0m\n" # Armor: Equipped
    else
        printf " Pancerz: \e[1;31mBrak\e[0m\n" # Armor: None
    fi
	echo "--------------------------"
    echo " Broń:" # Guns:
    if (( ${#guns[@]} > 0 )); then
        # Display translated names
        local translated_gun_name=""
        for gun in "${guns[@]}"; do # Iterate internal names
             case "$gun" in
                "Pistol") translated_gun_name="Pistolet";;
                "Shotgun") translated_gun_name="Strzelba";;
                "SMG") translated_gun_name="PM";;
                "Rifle") translated_gun_name="Karabin";;
                "Sniper") translated_gun_name="Snajperka";;
                *) translated_gun_name="$gun" ;; # Fallback
            esac
            printf "  - %s\n" "$translated_gun_name"
        done
    else
        echo "  (Brak)" # (None)
    fi
    echo "--------------------------"
    echo " Przedmioty:" # Items:
     if (( ${#items[@]} > 0 )); then
        # Implement item usage here later?
        local translated_item_name=""
        for item in "${items[@]}"; do # Iterate internal names
             case "$item" in
                "Health Pack") translated_item_name="Apteczka";;
                # Add other item translations here if needed
                *) translated_item_name="$item" ;;
            esac
            printf "  - %s\n" "$translated_item_name"
        done
    else
        echo "  (Brak)" # (None)
    fi
	echo "--------------------------"
	echo " Narkotyki:" # Drugs:
	local drug_found=false
    for drug in "${!default_drugs[@]}"; do # Iterate default keys (internal names)
        local amount=${drugs[$drug]:-0}
        if (( amount > 0 )); then
            # Keep internal drug name for display for simplicity unless specified otherwise
            printf "  - %-10s: %d szt.\n" "$drug" "$amount" # szt. for units
            drug_found=true
        fi
    done
    if ! $drug_found; then echo "  (Brak)"; fi # (None)
    echo "--------------------------"
	echo " Umiejętności:" # Skills:
    local translated_skill_name=""
    for skill in "${!default_skills[@]}"; do # Iterate default keys (internal names)
         case "$skill" in
            "driving") translated_skill_name="Jazda";;
            "strength") translated_skill_name="Siła";;
            "charisma") translated_skill_name="Charyzma";;
            "stealth") translated_skill_name="Skradanie";;
            "drug_dealer") translated_skill_name="Handel narkotykami";;
            *) translated_skill_name="$skill" ;; # Fallback
        esac
        printf "  - %-22s: %d\n" "$translated_skill_name" "${skills[$skill]:-0}" # Adjusted width for Polish
    done
	echo "--------------------------"
	read -r -p "Naciśnij Enter, aby wrócić..." # Press Enter to return...
}

# Funkcja pracy (Legalne prace)
work_job() {
	local job_type_display="$1" # Expecting Polish job type from menu
	local earnings=0 base_earnings=0 skill_bonus=0
	local min_earnings=0 max_earnings=0
	local relevant_skill_level=1 relevant_skill_name="" # Internal English skill name
    local job_type_internal="" # Internal English job type name

	# Determine base pay range & relevant skill by location
	case "$location" in
		"Los Santos")   min_earnings=20; max_earnings=60;;
		"San Fierro")   min_earnings=25; max_earnings=70;;
		"Las Venturas") min_earnings=30; max_earnings=90;;
		"Vice City")    min_earnings=15; max_earnings=50;;
		"Liberty City") min_earnings=35; max_earnings=100;;
		*)              min_earnings=10; max_earnings=40;;
	esac
    base_earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings))

    # Determine skill influence based on job type (map from Polish to internal)
	case "$job_type_display" in
		"Taksówkarz"|"Dostawca")
            job_type_internal=$([[ "$job_type_display" == "Taksówkarz" ]] && echo "taxi" || echo "delivery")
            relevant_skill_name="driving"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * (job_type_internal == "delivery" ? 4 : 3) )) # Delivery uses skill slightly more
            [[ "$job_type_internal" == "delivery" ]] && base_earnings=$((base_earnings + 10))
			play_sfx_mpg "taxi" # Keep SFX name consistent
			;;
		"Mechanik")
            job_type_internal="mechanic"
            relevant_skill_name="strength" # Maybe strength for lifting? Or add specific skill later
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 1))
            base_earnings=$((base_earnings + 20))
			play_sfx_mpg "mechanic"
			;;
		"Ochroniarz")
            job_type_internal="security"
            relevant_skill_name="strength"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 2))
            base_earnings=$((base_earnings + 30))
			play_sfx_mpg "security"
			;;
		"Artysta uliczny")
            job_type_internal="performer"
            relevant_skill_name="charisma"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 5))
            base_earnings=$((base_earnings - 10)) # Less reliable base
            base_earnings=$(( base_earnings < 5 ? 5 : base_earnings )) # Min base 5
			play_sfx_mpg "street_performer"
			;;
		*) echo "Błąd wewnętrzny: Nieprawidłowy typ pracy '$job_type_display'"; return;; # Internal Error: Invalid Job Type '$job_type_display'
	esac

    earnings=$((base_earnings + skill_bonus))
    (( earnings < 0 )) && earnings=0 # Ensure earnings aren't negative

    # --- Animacja Pracy (Opcjonalne wywołanie pluginu) ---
    if command -v working_animation &> /dev/null; then
	    working_animation "$job_type_internal" # Use internal name if plugin expects it
    else
        echo "Pracujesz jako $job_type_display..." # Working as a $job_type_display...
        sleep 2
    fi
    # --- Koniec Animacji ---

	# --- Wynik ---
	cash=$((cash + earnings))
	clear_screen
	printf "Zakończyłeś zmianę jako %s w %s.\n" "$job_type_display" "$location" # Finished your shift as a %s in %s.
    printf "Zarobiłeś \$%d (Podstawa: \$%d, Bonus za umiejętność: \$%d).\n" "$earnings" "$base_earnings" "$skill_bonus" # You earned $%d (Base: $%d, Skill Bonus: $%d).
    printf "Masz teraz \$%d.\n" "$cash" # You now have $%d.

    # Potential skill increase
    if [[ -n "$relevant_skill_name" ]]; then # Only if a skill was relevant
        local skill_increase_chance=20 # 20% base chance
        if (( RANDOM % 100 < skill_increase_chance )); then
            skills[$relevant_skill_name]=$((relevant_skill_level + 1))
            local translated_skill_name=""
             case "$relevant_skill_name" in # Translate skill name for display
                "driving") translated_skill_name="Jazda";;
                "strength") translated_skill_name="Siła";;
                "charisma") translated_skill_name="Charyzma";;
                *) translated_skill_name="$relevant_skill_name" ;;
            esac
            printf "Twoja umiejętność \e[1;32m%s\e[0m wzrosła!\n" "$translated_skill_name" # Your %s skill increased!
        fi
    fi

	read -r -p "Naciśnij Enter, aby kontynuować..." # Press Enter to continue...
}

# Funkcja wyścigów ulicznych
street_race() {
    local driving_skill=${skills[driving]:-1}
	local base_win_chance=40
	local win_chance=$(( base_win_chance + driving_skill * 5 ))
    (( win_chance > 90 )) && win_chance=90 # Cap win chance at 90%
    (( win_chance < 10 )) && win_chance=10 # Min win chance 10%

    clear_screen
    echo "--- Wyścig Uliczny ---" # Street Race
    echo "Dołączasz do nielegalnego wyścigu ulicznego w $location..." # Joining an illegal street race in $location...
    echo "Umiejętność Jazdy: $driving_skill | Szansa na Wygraną: ${win_chance}%" # Driving Skill: $driving_skill | Win Chance: ${win_chance}%
    sleep 1

    # --- Animacja Wyścigu Ulicznego (Opcjonalne wywołanie pluginu) ---
    if command -v race_animation &> /dev/null; then
        race_animation
    elif command -v working_animation &> /dev/null; then
        working_animation "street_race" # Fallback to generic animation
    else
        echo "Przygotuj się..." ; sleep 1; echo "3... 2... 1... START!"; sleep 1 # Get ready... ; 3... 2... 1... GO!
    fi
    # --- Koniec Animacji ---

    read -r -p "Naciśnij Enter, aby zobaczyć wyniki wyścigu..." # Press Enter for the race results...

	local winnings=0 damage=0

	if (( RANDOM % 100 < win_chance )); then
        # --- Wygrana ---
		winnings=$((RANDOM % 151 + 100 + driving_skill * 10)) # Win 100-250 + bonus
		cash=$((cash + winnings))
		damage=$((RANDOM % 15 + 5)) # Low damage on win: 5-19%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2))
            damage=$((damage - armor_reduction))
			echo "Twój pancerz pochłonął \e[1;31m${armor_reduction}%%\e[0m obrażeń!" # Your body armor absorbed %d%% damage!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
		printf "\e[1;32m*** WYGRAŁEŚ WYŚCIG! ***\e[0m\n" # *** YOU WON THE RACE! ***
        printf "Zebrałeś \$%d nagrody pieniężnej.\n" "$winnings" # You collected $%d in prize money.
        printf "Odniosłeś niewielkie obrażenia (-%d%% zdrowia).\n" "$damage" # Took minor damage (-%d%% health).
        play_sfx_mpg "win"
		# Skill increase chance on win
		if (( RANDOM % 3 == 0 )); then # 33% chance
            skills[driving]=$((driving_skill + 1))
            printf "Twoja umiejętność \e[1;32mjazdy\e[0m wzrosła!\n" # Your driving skill increased!
        fi
	else
        # --- Przegrana ---
        winnings=0 # No winnings on loss
		damage=$((RANDOM % 31 + 15)) # Higher damage on loss: 15-45%
		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2))
            damage=$((damage - armor_reduction))
			echo "Twój pancerz pochłonął \e[1;31m${armor_reduction}%%\e[0m obrażeń w wypadku!" # Your body armor absorbed %d%% damage in the crash!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- PRZEGRAŁEŚ WYŚCIG! ---\e[0m\n" # --- YOU LOST THE RACE! ---
		printf "Rozbiłeś się i odniosłeś %d%% obrażeń.\n" "$damage" # You crashed and took %d%% damage.
		play_sfx_mpg "lose" # Or a crash sound? "car_crash"?
	fi

    # Display final stats for the action
    printf "Aktualny stan -> Kasa: \$%d | Zdrowie: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%

    # Check health AFTER showing results
    check_health # This will handle hospitalization if health <= 0
    read -r -p "Naciśnij Enter, aby kontynuować..." # Press Enter to continue...
}

# (Funkcja use_guns pozostaje bez zmian - zachowana do potencjalnego przyszłego użytku)
use_guns() {
    # This function expects internal English names, translate output only
	if [[ " ${guns[*]} " == *" $1 "* ]]; then
        local translated_gun_name=""
         case "$1" in
            "Pistol") translated_gun_name="Pistolet";; "Shotgun") translated_gun_name="Strzelbę";;
            "SMG") translated_gun_name="PM";; "Rifle") translated_gun_name="Karabin";;
            "Sniper") translated_gun_name="Snajperkę";; *) translated_gun_name="$1" ;;
        esac
		echo "Użyłeś swojej $translated_gun_name do tej roboty." # You used your $1 for this job.
		play_sfx_mpg "gun_shot"
		read -r -p "Naciśnij Enter..." # Press Enter...
	else
        local translated_gun_name=""
         case "$1" in
            "Pistol") translated_gun_name="Pistoletu";; "Shotgun") translated_gun_name="Strzelby";;
            "SMG") translated_gun_name="PM-a";; "Rifle") translated_gun_name="Karabinu";;
            "Sniper") translated_gun_name="Snajperki";; *) translated_gun_name="$1" ;;
        esac
		echo "Nie masz $translated_gun_name. Robota nieudana." # You don't have a $1. Job failed.
		read -r -p "Naciśnij Enter..." # Press Enter...
	fi
}

# Funkcja pomocnicza do obsługi wyboru broni i zastosowania bonusu do działań przestępczych
apply_gun_bonus() {
    local base_chance=$1
    local action_message="$2" # Expecting Polish action description
    local current_chance=$base_chance
    local gun_bonus=0
    local chosen_gun_display="" # Polish name entered by user
    local chosen_gun_internal="" # Internal English name for logic/attributes
    local gun_found=false
    local success_bonus=0 # Local variable to capture bonus from eval

    if (( ${#guns[@]} == 0 )); then
        echo "Nie masz broni! Będzie znacznie trudniej." # You have no guns! This will be significantly harder.
        gun_bonus=-15 # Significant penalty for being unarmed
    else
        # Display available guns with translated names
        echo -n "Dostępna broń: " # Available guns:
        local first_gun=true
        for gun_internal in "${guns[@]}"; do
            local translated_gun_name=""
            case "$gun_internal" in
                "Pistol") translated_gun_name="Pistolet";; "Shotgun") translated_gun_name="Strzelba";;
                "SMG") translated_gun_name="PM";; "Rifle") translated_gun_name="Karabin";;
                "Sniper") translated_gun_name="Snajperka";; *) translated_gun_name="$gun_internal" ;;
            esac
            if ! $first_gun; then echo -n ", "; fi
            echo -n "$translated_gun_name"
            first_gun=false
        done
        echo "" # Newline

        read -r -p "Użyć broni do '$action_message'? (t/n): " use_gun # Use a gun for this $action_message? (y/n): -> t/n for Tak/Nie

        if [[ "$use_gun" == "t" || "$use_gun" == "T" || "$use_gun" == "y" || "$use_gun" == "Y" ]]; then # Check for Polish 't' or 'y'/'Y'
            read -r -p "Której broni? (Wpisz dokładną nazwę): " chosen_gun_display # Which gun? (Enter exact name):

            # Map Polish name back to internal English name
            case "$chosen_gun_display" in
                "Pistolet") chosen_gun_internal="Pistol";; "Strzelba") chosen_gun_internal="Shotgun";;
                "PM") chosen_gun_internal="SMG";; "Karabin") chosen_gun_internal="Rifle";;
                "Snajperka") chosen_gun_internal="Sniper";;
                *) chosen_gun_internal="" ;; # Not a recognized Polish name
            esac

            # Check if player owns the gun (by internal name)
            gun_found=false
            if [[ -n "$chosen_gun_internal" ]]; then
                for gun in "${guns[@]}"; do
                    if [[ "$gun" == "$chosen_gun_internal" ]]; then
                        gun_found=true
                        break
                    fi
                done
            fi

            if $gun_found; then
                echo "Wyciągasz swój $chosen_gun_display!" # You draw your $chosen_gun_display!
                play_sfx_mpg "gun_cock"

                # Apply Gun Bonus if defined (using internal name)
                if [[ -v "gun_attributes[$chosen_gun_internal]" ]]; then
                    eval "${gun_attributes[$chosen_gun_internal]}" # Sets 'success_bonus' locally
                    gun_bonus=${success_bonus:-0}
                    if (( gun_bonus > 0 )); then
                        echo "$chosen_gun_display daje \e[1;32m+${gun_bonus}%%\e[0m szansy na sukces." # The $chosen_gun_display gives a +%d%% success chance.
                        play_sfx_mpg "gun_shot"
                    else
                        echo "$chosen_gun_display не daje tutaj żadnej szczególnej przewagi." # The $chosen_gun_display provides no specific advantage here.
                    fi
                else
                    echo "Ostrzeżenie: Dla '$chosen_gun_display' nie zdefiniowano atrybutów bonusowych." # Warning: No bonus attributes defined for '$chosen_gun_display'.
                    gun_bonus=0
                fi
            else
                echo "Nie posiadasz '$chosen_gun_display'! Kontynuowanie bez bonusu za broń." # You don't own '$chosen_gun_display'! Proceeding without a gun bonus.
                gun_bonus=0
            fi
        else
            echo "Kontynuowanie bez użycia broni." # Proceeding without using a gun.
            gun_bonus=-5 # Small penalty for choosing not to use an available gun? Optional.
        fi
    fi

    current_chance=$((current_chance + gun_bonus))

    # Clamp the success chance (e.g., 5% to 95%)
    (( current_chance < 5 )) && current_chance=5
    (( current_chance > 95 )) && current_chance=95

    echo "$current_chance" # Return the final calculated chance
}


# Funkcja wizyty w szpitalu (Menu)
visit_hospital() {
	local hospital_choice=""
	while true; do # Pętla dopóki użytkownik nie wyjdzie
	    clear_screen
	    echo "--- Szpital Ogólny Hrabstwa ---" # County General Hospital
        printf " Twoje Zdrowie: %d%% | Kasa: \$%d\n" "$health" "$cash" # Your Health: %d%% | Cash: $%d
        echo "-------------------------------"
	    echo " Usługi:" # Services:
	    echo " 1. Podstawowe Leczenie (\$50)    - Leczy do 100%" # 1. Basic Treatment ($50)  - Heal to 100%
	    echo " 2. Zaawansowany Skan (\$100)   - Leczy do 110% (Tymczasowy Maks.)" # 2. Advanced Scan ($100) - Heal to 110% (Temporary Max)
	    echo " 3. Kup Apteczkę (\$30)        - Dodaj 'Apteczka' do Przedmiotów" # 3. Buy Health Pack ($30) - Add 'Health Pack' to Items -> 'Apteczka'
	    echo " 4. Kup Kamizelkę (\$75)     - Załóż Pancerz (Jednorazowe)" # 4. Buy Body Armor ($75)  - Equip Armor (One time use) -> 'Kamizelka'
        echo "-------------------------------"
	    echo " 5. Opuść Szpital" # 5. Leave Hospital
        echo "-------------------------------"
	    read -r -p "Wpisz swój wybór: " hospital_choice # Enter your choice:

	    [[ ! "$hospital_choice" =~ ^[0-9]+$ ]] && {
		    echo "Nieprawidłowe dane wejściowe."; sleep 1; continue # Invalid input.
	    }

	    case "$hospital_choice" in
		    1) buy_hospital_item 50 "basic_treatment";; # Use internal key
		    2) buy_hospital_item 100 "advanced_treatment";; # Use internal key
		    3) buy_hospital_item 30 "health_pack";; # Use internal key
		    4) buy_hospital_item 75 "body_armor";; # Use internal key
		    5) echo "Opuszczanie szpitala..."; sleep 1; return;; # Leaving the hospital...
		    *) echo "Nieprawidłowy wybór."; sleep 1;; # Invalid choice.
	    esac
        # Po akcji wróć do wyświetlania menu, chyba że wybrano wyjście
    done
}

# Funkcja pomocnicza do kupowania przedmiotów szpitalnych
buy_hospital_item() {
	local item_cost="$1"
	local item_type="$2" # Internal English type
    local item_display_name="" # Polish display name

    # Map internal type to display name
    case "$item_type" in
        "basic_treatment") item_display_name="podstawowe leczenie";;
        "advanced_treatment") item_display_name="zaawansowany skan";;
        "health_pack") item_display_name="Apteczkę";;
        "body_armor") item_display_name="Kamizelkę";;
        *) item_display_name=$item_type;;
    esac

	if (( cash >= item_cost )); then
        play_sfx_mpg "cash_register"
		cash=$((cash - item_cost))
		case "$item_type" in
			"basic_treatment")
				health=100
				echo "Otrzymano podstawowe leczenie. Zdrowie w pełni przywrócone do 100%." # Received basic treatment. Health fully restored to 100%.
				play_sfx_mpg "heal"
				;;
			"advanced_treatment")
				health=110
				echo "Zaawansowany skan zakończony. Zdrowie zwiększone do 110%!" # Advanced scan complete. Health boosted to 110%!
                echo "(Uwaga: Dalsze leczenie/obrażenia obliczane są od 100% bazy, chyba że zdrowie > 100)" # (Note: Further healing/damage calculated from 100% base unless health is > 100)
				play_sfx_mpg "heal_adv"
				;;
			"health_pack")
				items+=("Health Pack") # Add internal name to items array
				echo "Kupiłeś $item_display_name. (Użycie przedmiotu jeszcze nie zaimplementowane)" # You bought a Health Pack. (Item usage not yet implemented)
				play_sfx_mpg "item_buy"
				;;
			"body_armor")
                if $body_armor_equipped; then
                    echo "Masz już założoną Kamizelkę." # You already have Body Armor equipped.
                    cash=$((cash + item_cost)) # Refund
                    play_sfx_mpg "error"
                else
				    body_armor_equipped=true
				    echo "Kamizelka kupiona i założona." # Body Armor purchased and equipped.
				    play_sfx_mpg "item_equip"
                fi
				;;
            *) # Should not be reached
                echo "Błąd wewnętrzny: Nieznany typ przedmiotu szpitalnego '$item_type'" # Internal Error: Unknown hospital item type '$item_type'
                cash=$((cash + item_cost)) # Refund
                ;;
		esac
        read -r -p "Naciśnij Enter..." # Press Enter...
	else
		echo "Za mało kasy na '$item_display_name' (potrzeba \$ $item_cost)." # Not enough cash for $item_display_name (\$$item_cost needed).
		read -r -p "Naciśnij Enter..." # Press Enter...
	fi
}

# Funkcja napadu na sklep
rob_store() {
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$((15 + stealth_skill * 5))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Napad na Sklep ---" # Rob Store
    echo "Obserwujesz sklep spożywczy w $location..." # Scoping out a convenience store in $location...
    sleep 1

    # --- Animacja Napadu (Opcjonalne wywołanie pluginu) ---
    if command -v robbing_animation &> /dev/null; then robbing_animation; else echo "Przechodzisz do działania..."; sleep 1; fi # Making your move...
    # --- Koniec Animacji ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "napad na sklep") # Pass Polish description

    echo "Obliczanie szans... Ostateczna szansa powodzenia: ${final_success_chance}%" # Calculating odds... Final success chance: ${final_success_chance}%
    read -r -p "Naciśnij Enter, aby spróbować napadu..." # Press Enter to attempt the robbery...

    if (( RANDOM % 100 < final_success_chance )); then
        # --- Sukces ---
        loot=$((RANDOM % 151 + 50 + stealth_skill * 10)) # Loot: 50-200 + bonus
        cash=$((cash + loot))
        damage=$((RANDOM % 16 + 5)) # Damage: 5-20%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Pancerz pochłonął \e[1;31m${armor_reduction}%%\e[0m obrażeń podczas ucieczki!" # Body armor absorbed %d%% damage during the getaway!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;32mSukces!\e[0m Zastraszyłeś sprzedawcę i zgarnąłeś \$%d.\n" "$loot" # Success! You intimidated the clerk and grabbed $%d.
        printf "Trochę cię poturbowano (-%d%% zdrowia).\n" "$damage" # Got slightly roughed up (-%d%% health).
        play_sfx_mpg "cash_register"
        # Skill increase chance
        if (( RANDOM % 3 == 0 )); then
            skills[stealth]=$((stealth_skill + 1))
            printf "Twoja umiejętność \e[1;32mskradania\e[0m wzrosła!\n" # Your stealth skill increased!
        fi
    else
        # --- Porażka ---
        loot=0
        fine=$((RANDOM % 101 + 50)) # Fine: 50-150
        cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 26 + 10)) # Damage: 10-35%

         if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Pancerz ochronił cię przed \e[1;31m${armor_reduction}%%\e[0m obrażeń podczas aresztowania!" # Body armor protected you from %d%% damage during the arrest!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;31mPorażka!\e[0m Cichy alarm zadziałał, gliny szybko przyjechały.\n" # Failed! The silent alarm tripped, cops arrived quickly.
        printf "Dostałeś mandat \$%d i odniosłeś %d%% obrażeń.\n" "$fine" "$damage" # You were fined $%d and took %d%% damage.
        play_sfx_mpg "police_siren"
    fi

    printf "Aktualny stan -> Kasa: \$%d | Zdrowie: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health # Check health status after the event
    read -r -p "Naciśnij Enter, aby kontynuować..." # Press Enter to continue...
}

# Funkcja udziału w napadzie (większym)
heist() {
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$((10 + stealth_skill * 6)) # Trudniejsze niż napad na sklep
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Planowanie Napadu ---" # Plan Heist
    echo "Planujesz robotę wysokiego ryzyka w $location..." # Planning a high-stakes job in $location...
    sleep 1

    # --- Animacja Napadu (Opcjonalne wywołanie pluginu) ---
    if command -v heist_animation &> /dev/null; then heist_animation; else echo "Realizujesz plan..."; sleep 1; fi # Executing the plan...
    # --- Koniec Animacji ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "napad") # Pass Polish description

    echo "Ocenianie ryzyka bezpieczeństwa... Ostateczna szansa powodzenia: ${final_success_chance}%" # Assessing security risks... Final success chance: ${final_success_chance}%
    read -r -p "Naciśnij Enter, aby wykonać napad..." # Press Enter to execute the heist...

	if (( RANDOM % 100 < final_success_chance )); then
        # --- Sukces ---
		loot=$((RANDOM % 501 + 250 + stealth_skill * 25)) # Loot: 250-750 + bonus
		cash=$((cash + loot))
		damage=$((RANDOM % 31 + 15)) # Damage: 15-45%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Pancerz pochłonął \e[1;31m${armor_reduction}%%\e[0m obrażeń podczas strzelaniny!" # Body armor absorbed %d%% damage during the firefight!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;32m*** NAPAD UDANY! ***\e[0m\n Zdobyłeś \$%d!\n" "$loot" # *** HEIST SUCCESSFUL! *** You scored $%d!
        printf "Uciekłeś ze znacznymi obrażeniami (-%d%% zdrowia).\n" "$damage" # Escaped with significant injuries (-%d%% health).
        play_sfx_mpg "win_big"
        # Skill increase
        if (( RANDOM % 2 == 0 )); then
            skills[stealth]=$((stealth_skill + 2)) # Major increase
            printf "Twoja umiejętność \e[1;32mskradania\e[0m znacznie wzrosła!\n" # Your stealth skill increased significantly!
        fi
	else
        # --- Porażka ---
        loot=0
		fine=$((RANDOM % 201 + 100)) # Fine: 100-300
		cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 41 + 20)) # Damage: 20-60%

        if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Pancerz uratował ci życie przed \e[1;31m${armor_reduction}%%\e[0m obrażeń!" # Body armor saved your life from %d%% damage!
			body_armor_equipped=false
		fi
        health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- NAPAD NIEUDANY! ---\e[0m\n Ochrona była zbyt silna, przerwałeś akcję.\n" # --- HEIST FAILED! --- Security was too tight, aborted the job.
		printf "Straciłeś \$%d i odniosłeś %d%% obrażeń.\n" "$fine" "$damage" # You lost $%d and took %d%% damage.
		play_sfx_mpg "lose_big"
	fi

    printf "Aktualny stan -> Kasa: \$%d | Zdrowie: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health
	read -r -p "Naciśnij Enter, aby kontynuować..." # Press Enter to continue...
}

# Funkcja wojen gangów
gang_war() {
	if (( ${#guns[@]} == 0 )); then
		echo "Potrzebujesz broni, aby rozpocząć wojnę gangów! Kup najpierw." # You need a weapon to start a gang war! Buy one first.
		read -r -p "Naciśnij Enter..." ; return # Press Enter...
	fi

    local strength_skill=${skills[strength]:-1}
    local base_chance=$((20 + strength_skill * 5))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Wojna Gangów ---" # Gang War
    echo "Wjeżdżasz na terytorium rywali w $location..." # Rolling up on rival territory in $location...
    sleep 1

	# --- Animacja Wojny Gangów (Opcjonalne wywołanie pluginu) ---
    if command -v gang_war_animation &> /dev/null; then gang_war_animation; else echo "Kule zaczynają latać!"; sleep 1; fi # Bullets start flying!
    # --- Koniec Animacji ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "wojna gangów") # Pass Polish description

    echo "Ocenianie siły rywali... Ostateczna szansa powodzenia: ${final_success_chance}%" # Assessing rival strength... Final success chance: ${final_success_chance}%
	read -r -p "Naciśnij Enter, aby rozpocząć walkę..." # Press Enter to start the fight...

	if (( RANDOM % 100 < final_success_chance )); then
        # --- Wygrana ---
		loot=$((RANDOM % 201 + 100 + strength_skill * 15)) # Loot 100-300 + bonus
		cash=$((cash + loot))
		damage=$((RANDOM % 41 + 20)) # Damage: 20-60%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Pancerz przyjął \e[1;31m${armor_reduction}%%\e[0m obrażeń od kul!" # Body armor took %d%% damage from bullets!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;32m*** WOJNA GANGÓW WYGRANA! ***\e[0m\n Przejąłeś teren i \$%d łupów.\n" "$loot" # *** GANG WAR WON! *** You claimed the turf and $%d in spoils.
        printf "Odniosłeś ciężkie obrażenia (-%d%% zdrowia).\n" "$damage" # Suffered heavy damage (-%d%% health).
		play_sfx_mpg "win"
        # Skill increase
        if (( RANDOM % 2 == 0 )); then
            skills[strength]=$((strength_skill + 1))
            printf "Twoja umiejętność \e[1;32msiły\e[0m wzrosła!\n" # Your strength skill increased!
        fi
	else
        # --- Przegrana ---
        loot=0
		fine=$((RANDOM % 151 + 75)) # Fine: 75-225
		cash=$((cash - fine))
        (( cash < 0 )) && cash=0
		damage=$((RANDOM % 51 + 25)) # Damage: 25-75%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Pancerz zapobiegł \e[1;31m${armor_reduction}%%\e[0m śmiertelnym obrażeniom!" # Body armor prevented %d%% fatal damage!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- WOJNA GANGÓW PRZEGRANA! ---\e[0m\n Zostaliście pokonani i ledwo uciekliście.\n" "$loot" # --- GANG WAR LOST! --- You were overrun and barely escaped. (Corrected loot variable usage - should be fine)
		printf "Straciłeś \$%d i odniosłeś %d%% obrażeń.\n" "$fine" "$damage" # You lost $%d and took %d%% damage.
		play_sfx_mpg "lose"
	fi

    printf "Aktualny stan -> Kasa: \$%d | Zdrowie: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health
	read -r -p "Naciśnij Enter, aby kontynuować..." # Press Enter to continue...
}

# Funkcja kradzieży samochodu
carjack() {
    local driving_skill=${skills[driving]:-1}
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$(( 20 + driving_skill * 2 + stealth_skill * 3 ))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Kradzież Samochodu ---" # Carjack
    echo "Szukasz pojazdu do 'pożyczenia' w $location..." # Looking for a vehicle to 'borrow' in $location...
    sleep 1

    # --- Animacja Kradzieży Samochodu (Opcjonalne wywołanie pluginu) ---
    if command -v carjacking_animation &> /dev/null; then carjacking_animation; else echo "Namierzanie celu..."; sleep 1; fi # Spotting a target...
    # --- Koniec Animacji ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "kradzież samochodu") # Pass Polish description

    echo "Wybieranie celu... Ostateczna szansa powodzenia: ${final_success_chance}%" # Choosing a target... Final success chance: ${final_success_chance}%
    read -r -p "Naciśnij Enter, aby wykonać ruch..." # Press Enter to make your move...

    if (( RANDOM % 100 < final_success_chance )); then
        # --- Sukces ---
        loot=$((RANDOM % 101 + 50 + driving_skill * 5)) # Car value: 50 - 150 + bonus
        cash=$((cash + loot))
        damage=$((RANDOM % 16 + 5)) # Damage: 5-20%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Pancerz pochłonął \e[1;31m${armor_reduction}%%\e[0m obrażeń podczas ucieczki!" # Body armor absorbed %d%% damage during the getaway!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;32mSukces!\e[0m Ukradłeś samochód i sprzedałeś go za \$%d.\n" "$loot" # Success! You boosted the car and fenced it for $%d.
        printf "Trochę cię poobijano (-%d%% zdrowia).\n" "$damage" # Got slightly banged up (-%d%% health).
        play_sfx_mpg "car_start"
        # Skill increase chances
        if (( RANDOM % 4 == 0 )); then skills[driving]=$((driving_skill+1)); printf "Twoja umiejętność \e[1;32mjazdy\e[0m wzrosła!\n"; fi # Your driving skill increased!
        if (( RANDOM % 4 == 0 )); then skills[stealth]=$((stealth_skill+1)); printf "Twoja umiejętność \e[1;32mskradania\e[0m wzrosła!\n"; fi # Your stealth skill increased!
    else
        # --- Porażka ---
        loot=0
        fine=$((RANDOM % 76 + 25)) # Fine: 25-100
        cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 26 + 10)) # Damage: 10-35%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Pancerz przyjął \e[1;31m${armor_reduction}%%\e[0m obrażeń, gdy właściciel się bronił!" # Body armor took %d%% damage when the owner fought back!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;31mPorażka!\e[0m Alarm wył / Właściciel się opierał / Gliny w pobliżu.\n" # Failed! Alarm blared / Owner resisted / Cops nearby.
        printf "Dostałeś mandat \$%d i odniosłeś %d%% obrażeń.\n" "$fine" "$damage" # You were fined $%d and took %d%% damage.
        play_sfx_mpg "police_siren"
    fi

    printf "Aktualny stan -> Kasa: \$%d | Zdrowie: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health
	read -r -p "Naciśnij Enter, aby kontynuować..." # Press Enter to continue...
}

# Funkcja obsługująca konsekwencje śmierci gracza (wywoływana przez check_health)
hospitalize_player() {
	local hospital_bill=200
    echo "Szpital cię połatał." # The hospital patched you up.
    sleep 1
    echo "Niestety, opieka medyczna nie jest darmowa. Rachunek: \$${hospital_bill}." # Unfortunately, medical care isn't free. Bill: $${hospital_bill}.

    if (( cash < hospital_bill )); then
        echo "Nie stać cię było na pełny rachunek (\$${hospital_bill}). Zabrali ci całą kasę (\$$cash)." # You couldn't afford the full bill ($${hospital_bill}). They took all your cash ($$cash).
        hospital_bill=$cash
    else
        echo "Zapłaciłeś rachunek \$${hospital_bill}." # You paid the $${hospital_bill} bill.
    fi

	cash=$((cash - hospital_bill))
    health=50 # Reset health to 50% after "death"
	body_armor_equipped=false # Lose armor on "death"
    play_sfx_mpg "cash_register" # Sound for paying bill

	printf "Wychodzisz ze szpitala z \$%d gotówki i %d%% zdrowia.\n" "$cash" "$health" # You leave the hospital with $%d cash and %d%% health.
	# Location doesn't change on death in this version
    # Inventory items are kept (could change this for more difficulty)
	read -r -p "Naciśnij Enter, aby kontynuować..." # Press Enter to continue...
}

# Funkcja wynajęcia prostytutki (Treść wrażliwa)
hire_hooker() {
    local charisma_skill=${skills[charisma]:-1}
    local base_min_cost=40 base_max_cost=100
    local cost_reduction=$((charisma_skill * 3))
    local min_cost=$((base_min_cost - cost_reduction))
    local max_cost=$((base_max_cost - cost_reduction))
    (( min_cost < 15 )) && min_cost=15
    (( max_cost <= min_cost )) && max_cost=$((min_cost + 20))

	local hooker_cost=$(( RANDOM % (max_cost - min_cost + 1) + min_cost ))
	local health_gain=$(( RANDOM % 21 + 15 )) # Health gain 15-35%
    # Max health cap consideration (currently 100 or 110 if advanced treatment used)
    local max_health=100
    (( health > 100 )) && max_health=110 # Adjust cap if player has temp boost

    clear_screen
    echo "--- Szukanie Towarzystwa ---" # Seeking Company
	echo "Szukasz 'odstresowania' w $location..." # Looking for some 'stress relief' in $location...
    sleep 1
    echo "Podchodzisz do kogoś obiecującego... Proponuje cenę \$ $hooker_cost." # You approach someone promising... They quote you $hooker_cost.

	if (( cash >= hooker_cost )); then
        read -r -p "Przyjąć ofertę? (t/n): " accept # Accept the offer? (y/n): -> t/n
        if [[ "$accept" == "t" || "$accept" == "T" || "$accept" == "y" || "$accept" == "Y" ]]; then # Check for Polish 't' or 'y'/'Y'
            play_sfx_mpg "cash_register"
	        cash=$(( cash - hooker_cost ))
	        local previous_health=$health
            health=$(( health + health_gain ))
	        (( health > max_health )) && health=$max_health # Apply cap
            local actual_gain=$((health - previous_health))

            clear_screen
            echo "--- Transakcja Zakończona ---" # Transaction Complete
	        printf "Zapłaciłeś \$%d.\n" "$hooker_cost" # You paid $%d.
            if (( actual_gain > 0 )); then
                 printf "Czujesz się odświeżony, zyskałeś \e[1;32m%d%%\e[0m zdrowia.\n" "$actual_gain" # Feeling refreshed, you gained %d%% health.
            else
                 echo "Miałeś już maksymalne zdrowie." # You were already at maximum health.
            fi
            printf "Aktualny stan -> Kasa: \$%d | Zdrowie: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
	        play_sfx_mpg "hooker" # Sensitive SFX name
            # Skill increase chance
            if (( RANDOM % 5 == 0 )); then
                skills[charisma]=$((charisma_skill+1))
                printf "Twoja umiejętność \e[1;32mcharyzmy\e[0m wzrosła!\n" # Your charisma skill increased!
            fi
        else
            echo "Zdecydowałeś się nie korzystać i odszedłeś." # You decided against it and walked away.
        fi
    else
	    echo "Sprawdzasz portfel... za mało kasy (potrzeba \$ $hooker_cost)." # You check your wallet... not enough cash ($hooker_cost needed).
	fi
    read -r -p "Naciśnij Enter, aby kontynuować..." # Press Enter to continue...
}


# Scentralizowana funkcja transakcji narkotykami
drug_transaction() {
	local action="$1" base_price="$3" drug_amount="$4"
    local drug_name="$2" # Keep internal (English) drug name separate for clarity
    local cost=0 income=0 final_price=0
	local drug_dealer_skill=${skills[drug_dealer]:-1}

    # Validate amount is a positive integer
    if ! [[ "$drug_amount" =~ ^[1-9][0-9]*$ ]]; then
        echo "Nieprawidłowa ilość '$drug_amount'. Wpisz liczbę większą niż 0." # Invalid amount '$drug_amount'. Please enter a number greater than 0.
        return 1
    fi

    # --- Dynamic Pricing ---
    local price_fluctuation=$(( RANDOM % 21 - 10 )) # +/- 10%
    local location_modifier=0
    case "$location" in # Example modifiers
        "Liberty City") location_modifier=15;; "Las Venturas") location_modifier=10;;
        "Vice City")    location_modifier=-15;; *) location_modifier=0;;
    esac
    local current_market_price=$(( base_price + (base_price * (price_fluctuation + location_modifier) / 100) ))
    (( current_market_price < 1 )) && current_market_price=1 # Min price $1

    # --- Perform Transaction ---
	if [[ "$action" == "buy" ]]; then
        final_price=$current_market_price
		cost=$((final_price * drug_amount))

		if (( cash >= cost )); then
            if command -v drug_transaction_animation &> /dev/null; then drug_transaction_animation "buy"; fi
			cash=$((cash - cost))
            drugs["$drug_name"]=$(( ${drugs[$drug_name]:-0} + drug_amount )) # Use internal drug name as key
			printf "Kupiono \e[1;33m%d\e[0m szt. \e[1;33m%s\e[0m za \e[1;31m\$%d\e[0m (\$%d/szt.).\n" \
                   "$drug_amount" "$drug_name" "$cost" "$final_price" # Bought %d units of %s for $%d ($%d/unit). (Kept internal drug name)
			play_sfx_mpg "cash_register" ; return 0
		else
			printf "Za mało kasy. Potrzebujesz \$%d, masz \$%d.\n" "$cost" "$cash" ; return 1 # Not enough cash. Need $%d, you have $%d.
		fi

	elif [[ "$action" == "sell" ]]; then
        local current_inventory=${drugs[$drug_name]:-0} # Use internal drug name as key
		if (( current_inventory >= drug_amount )); then
            local price_bonus_percent=$((drug_dealer_skill * 2))
            final_price=$(( current_market_price + (current_market_price * price_bonus_percent / 100) ))
            (( final_price < 1 )) && final_price=1 # Ensure selling price isn't driven below $1 by negative modifiers
			income=$((final_price * drug_amount))

            if command -v drug_transaction_animation &> /dev/null; then drug_transaction_animation "sell"; fi
			cash=$((cash + income))
			drugs["$drug_name"]=$((current_inventory - drug_amount)) # Use internal drug name as key

			printf "Sprzedano \e[1;33m%d\e[0m szt. \e[1;33m%s\e[0m za \e[1;32m\$%d\e[0m (\$%d/szt., umiej. +%d%%).\n" \
                   "$drug_amount" "$drug_name" "$income" "$final_price" "$price_bonus_percent" # Sold %d units of %s for $%d ($%d/unit, skill +%d%%). (Kept internal drug name)
			play_sfx_mpg "cash_register"
            # Skill increase chance
            if (( RANDOM % 2 == 0 )); then
			    skills[drug_dealer]=$((drug_dealer_skill + 1))
			    printf "Twoja umiejętność \e[1;32mhandlu narkotykami\e[0m wzrosła!\n" # Your drug dealing skill increased!
            fi ; return 0
		else
			printf "Za mało %s na sprzedaż. Masz %d szt., próbowałeś sprzedać %d.\n" \
                   "$drug_name" "$current_inventory" "$drug_amount" ; return 1 # Not enough %s to sell. You have %d units, tried to sell %d. (Kept internal drug name)
		fi
	else # Should not happen
		echo "Błąd wewnętrzny: Nieprawidłowa akcja '$action' w drug_transaction." ; return 1 # Internal Error: Invalid action '$action' in drug_transaction.
	fi
}

# Funkcja obsługi menu kupna narkotyków
buy_drugs() {
	local drug_choice="" drug_amount=""
    declare -A drug_prices=( ["Weed"]=10 ["Cocaine"]=50 ["Heroin"]=100 ["Meth"]=75 ) # Internal names/prices
    local drug_names=("Weed" "Cocaine" "Heroin" "Meth") # Order for menu (internal names)

	while true; do
	    clear_screen
        echo "--- Diler Narkotyków (Kupno) ---" # Drug Dealer (Buy)
        printf " Lokalizacja: %-15s | Kasa: \$%d\n" "$location" "$cash" # Location: %-15s | Cash: $%d
        echo "---------------------------"
        echo " Dostępny Towar (Bazowa Cena Rynkowa):" # Available Inventory (Market Base Price):
        local i=1
        for name in "${drug_names[@]}"; do # Iterate internal names
            # Show approximate current market price?
            local base_p=${drug_prices[$name]}
            local approx_p=$(( base_p + (base_p * ( $( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0) ) / 100) ))
            (( approx_p < 1 )) && approx_p=1
            # Display internal name
            printf " %d. %-10s (\~$%d/szt.)\n" "$i" "$name" "$approx_p" # /unit -> /szt.
            ((i++))
        done
        echo "---------------------------"
        printf " %d. Wyjdź\n" "$i" # Leave
        echo "---------------------------"
	    read -r -p "Wybierz narkotyk do kupienia (numer): " drug_choice # Choose drug to buy (number):

        if [[ "$drug_choice" == "$i" ]]; then echo "Odchodzisz od dilera..."; sleep 1; return; fi # Leaving the dealer...
	    if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#drug_names[@]} )); then
		    echo "Nieprawidłowy wybór."; sleep 1; continue # Invalid choice.
	    fi

        local chosen_drug_name="${drug_names[$((drug_choice - 1))]}" # Internal name
        local chosen_drug_price="${drug_prices[$chosen_drug_name]}"

	    read -r -p "Wpisz ilość $chosen_drug_name do kupienia: " drug_amount # Enter amount of $chosen_drug_name to buy: (Using internal name)

        # drug_transaction handles messages for success/failure/validation
        drug_transaction "buy" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"
        read -r -p "Naciśnij Enter..." # Pause after transaction attempt: Press Enter...
    done
}

# Funkcja obsługi menu sprzedaży narkotyków
sell_drugs() {
    local drug_choice="" drug_amount=""
    declare -A drug_sell_prices=( ["Weed"]=15 ["Cocaine"]=75 ["Heroin"]=150 ["Meth"]=100 ) # Base sell prices (internal names)
    local drug_names=("Weed" "Cocaine" "Heroin" "Meth") # Order (internal names)

    while true; do
	    clear_screen
        echo "--- Diler Narkotyków (Sprzedaż) ---" # Drug Dealer (Sell)
        printf " Lokalizacja: %-15s | Kasa: \$%d\n" "$location" "$cash" # Location: %-15s | Cash: $%d
        echo "--------------------------"
        echo " Twój Ekwipunek (Przybliżona Wartość Sprzedaży/szt.):" # Your Inventory (Approx Sell Value/unit):
        local i=1
        local available_to_sell=() # Track which items (internal names) are available to choose
        for name in "${drug_names[@]}"; do # Iterate internal names
            local inventory_amount=${drugs[$name]:-0}
            if (( inventory_amount > 0 )); then
                local base_p=${drug_sell_prices[$name]}
                local skill_bonus_p=$(( (skills[drug_dealer]:-1) * 2 ))
                local approx_p=$(( base_p + (base_p * ( $( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0) + skill_bonus_p ) / 100) ))
                (( approx_p < 1 )) && approx_p=1
                # Display internal name
                printf " %d. %-10s (%d szt.) ~\$%d/szt.\n" "$i" "$name" "$inventory_amount" "$approx_p" # units -> szt., /unit -> /szt.
                available_to_sell+=("$name") # Add internal drug name player can sell
                ((i++))
            fi
        done

        if (( ${#available_to_sell[@]} == 0 )); then
            echo "--------------------------"
            echo "Nie masz narkotyków na sprzedaż." # You have no drugs to sell.
            read -r -p "Naciśnij Enter, aby wyjść..." ; return # Press Enter to leave...
        fi
        echo "--------------------------"
        printf " %d. Wyjdź\n" "$i" # Leave
        echo "--------------------------"

	    read -r -p "Wybierz narkotyk do sprzedania (numer): " drug_choice # Choose drug to sell (number):

        if [[ "$drug_choice" == "$i" ]]; then echo "Odchodzisz od dilera..."; sleep 1; return; fi # Leaving the dealer...
	    if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#available_to_sell[@]} )); then
		    echo "Nieprawidłowy wybór."; sleep 1; continue # Invalid choice.
	    fi

        local chosen_drug_name="${available_to_sell[$((drug_choice - 1))]}" # Internal name
        local chosen_drug_price="${drug_sell_prices[$chosen_drug_name]}"
        local current_inventory=${drugs[$chosen_drug_name]}

	    read -r -p "Sprzedać ile sztuk $chosen_drug_name? (Maks: $current_inventory): " drug_amount # Sell how many units of $chosen_drug_name? (Max: $current_inventory): (Using internal name, szt. for units)

        # drug_transaction handles messages for success/failure/validation
        drug_transaction "sell" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"
        read -r -p "Naciśnij Enter..." # Pause after transaction attempt: Press Enter...
    done
}

# Funkcja odtwarzania muzyki (Wersja stabilna z poprawką stty echo)
play_music() {
    # 1. Sprawdź Wymagania: polecenie mpg123
    if ! $mpg123_available; then # Use the global flag checked at start
        echo "Odtwarzanie muzyki wyłączone: polecenie 'mpg123' nie znalezione."; read -r -p "Naciśnij Enter..."; return 1; # Music playback disabled: 'mpg123' command not found. Press Enter...
    fi

    # 2. Zdefiniuj Katalog Muzyki i Znajdź Pliki
    local music_dir="$BASEDIR/music"
    local music_files=()
    local original_ifs="$IFS" # Save IFS

    if [[ ! -d "$music_dir" ]]; then
        echo "Błąd: Katalog muzyki '$music_dir' nie znaleziony!"; read -r -p "Naciśnij Enter..."; return 1; # Error: Music directory '$music_dir' not found! Press Enter...
    fi

    # Use find and process substitution for safer file handling
    while IFS= read -r -d $'\0' file; do
        music_files+=("$file")
    done < <(find "$music_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.MP3" \) -print0 2>/dev/null) # Find .mp3 and .MP3
    IFS="$original_ifs" # Restore IFS

    if (( ${#music_files[@]} == 0 )); then
        echo "Nie znaleziono plików .mp3 w '$music_dir'."; read -r -p "Naciśnij Enter..."; return 1; # No .mp3 files found in '$music_dir'. Press Enter...
    fi

    # 3. Pętla Odtwarzacza Muzyki
    local choice_stop="s" choice_back="p" music_choice="" # s = stop, p = powrót
    local mpg123_log="/tmp/bta_mpg123_errors.$$.log" # Unique log per session

    while true; do
        clear_screen
        echo "--- Odtwarzacz Muzyki ---" # Music Player
        echo " Katalog Muzyki: $music_dir" # Music Directory:
        echo "----------------------------------------"
        local current_status="Zatrzymano" current_song_name="" # Stopped
        if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
            current_song_name=$(ps -p "$music_pid" -o args= 2>/dev/null | sed 's/.*mpg123 [-q]* //; s/ *$//' || echo "Odtwarzanie utworu") # Playing Track
            [[ -z "$current_song_name" ]] && current_song_name="Odtwarzanie utworu" # Playing Track
            current_status="Odtwarzanie: $(basename "$current_song_name") (PID: $music_pid)" # Playing: ... (PID: ...)
        else
            [[ -n "$music_pid" ]] && music_pid="" # Clear stale PID
            current_status="Zatrzymano" # Stopped
        fi
        echo " Status: $current_status" # Status:
        echo "----------------------------------------"
        echo " Dostępne Utwory:" # Available Tracks:
        for i in "${!music_files[@]}"; do printf " %d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"; done
        echo "----------------------------------------"
        printf " [%s] Zatrzymaj Muzykę | [%s] Powrót do Gry\n" "$choice_stop" "$choice_back" # Stop Music | Back to Game
        echo "----------------------------------------"

        # Ensure terminal echo is ON before this prompt
        stty echo
        read -r -p "Wpisz wybór (numer, s, p): " music_choice # Enter choice (number, s, b): -> s, p

        case "$music_choice" in
            "$choice_stop" | "q" | "s") # Check for 's' too
                if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
                    echo "Zatrzymywanie muzyki (PID: $music_pid)..." # Stopping music (PID: $music_pid)...
                    kill "$music_pid" &>/dev/null; sleep 0.2
                    if kill -0 "$music_pid" &>/dev/null; then kill -9 "$music_pid" &>/dev/null; fi
                    wait "$music_pid" 2>/dev/null; music_pid=""; echo "Muzyka zatrzymana." # Music stopped.
                else echo "Obecnie nie gra żadna muzyka."; fi # No music is currently playing.
                # Ensure echo restored after stopping attempt
                stty echo
                sleep 1 # Pause briefly
                ;; # Loop will repeat and show updated menu
            "$choice_back" | "b" | "p") # Check for 'p' too
                echo "Powrót do gry..."; sleep 1; break # Returning to game... # Exit the music loop
                ;;
            *)
                if [[ "$music_choice" =~ ^[0-9]+$ ]] && (( music_choice >= 1 && music_choice <= ${#music_files[@]} )); then
                    local selected_track="${music_files[$((music_choice - 1))]}"
                    if [[ ! -f "$selected_track" ]]; then echo "Błąd: Plik '$selected_track' nie znaleziony!"; sleep 2; continue; fi # Error: File '$selected_track' not found!

                    if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
                        echo "Zatrzymywanie poprzedniego utworu..."; kill "$music_pid" &>/dev/null; wait "$music_pid" 2>/dev/null; music_pid=""; sleep 0.2; # Stopping previous track...
                    fi

                    echo "Próba odtworzenia: $(basename "$selected_track")" # Attempting to play: ...

                    # --- Play Command (No Subshell) ---
                    echo "--- BTA Log $(date) --- Odtwarzanie: $selected_track" >> "$mpg123_log" # Playing:
                    mpg123 -q "$selected_track" 2>> "$mpg123_log" &
                    # ---------------------------------

                    local new_pid=$!
                    sleep 0.5 # Give it a moment to start or fail

                    if kill -0 "$new_pid" 2>/dev/null; then
                        music_pid=$new_pid; echo "Odtwarzanie rozpoczęte (PID: $music_pid)." # Playback started (PID: $music_pid).
                        # Don't pause here, let loop repeat to show status
                    else
                        echo "Błąd: Nie udało się uruchomić procesu mpg123 dla $(basename "$selected_track")." # Error: Failed to start mpg123 process for ...
                        echo "       Sprawdź log błędów (jeśli istnieją): $mpg123_log" # Check log for errors (if any):
                        if [[ -f "$mpg123_log" ]]; then
                            echo "--- Ostatnie linie logu ---"; tail -n 5 "$mpg123_log"; echo "-------------------------" # Last lines of log
                        fi
                        music_pid=""; read -r -p "Naciśnij Enter..." # Pause: Press Enter...
                    fi
                else
                    echo "Nieprawidłowy wybór '$music_choice'." # Invalid choice '$music_choice'.
                    sleep 1
                fi;;
        esac
    done
    # Clean up log file for this session when exiting music player? Optional.
    # rm -f "$mpg123_log"
}


# Zapisz stan gry do pliku (Bardziej stabilne)
save_game() {
    local save_path="$BASEDIR/$SAVE_DIR" # Use full path for save dir
    mkdir -p "$save_path" || { echo "Błąd: Nie można utworzyć katalogu zapisu '$save_path'."; read -r -p "Naciśnij Enter..."; return 1; } # Error: Could not create save directory '$save_path'. Press Enter...

    echo "Zapisywanie stanu gry..." # Saving game state...
    # Define file paths
    local player_file="$save_path/player_name.sav"
    local loc_file="$save_path/location.sav"
    local cash_file="$save_path/cash.sav"
    local health_file="$save_path/health.sav"
    local armor_file="$save_path/body_armor_equipped.sav"
    local guns_file="$save_path/guns.sav" # Stores internal English names
    local items_file="$save_path/items.sav" # Stores internal English names
    local drugs_file="$save_path/drugs.sav" # Stores internal English keys
    local skills_file="$save_path/skills.sav" # Stores internal English keys
    local temp_ext=".tmp$$" # Unique temporary extension

    # Function to save atomically (write to temp, then rename)
    save_atomic() {
        local content="$1" file_path="$2" temp_file="${file_path}${temp_ext}"
        printf '%s\n' "$content" > "$temp_file" && mv "$temp_file" "$file_path" || {
            echo "Błąd zapisu pliku: $file_path"; rm -f "$temp_file"; return 1; # Error saving file: $file_path
        }
        return 0
    }

    # --- Save Simple Variables ---
    save_atomic "$player_name" "$player_file" || return 1
	save_atomic "$location" "$loc_file" || return 1
	save_atomic "$cash" "$cash_file" || return 1
	save_atomic "$health" "$health_file" || return 1
    save_atomic "$body_armor_equipped" "$armor_file" || return 1

    # --- Save Indexed Arrays (internal names) ---
    printf '%s\n' "${guns[@]}" > "$guns_file$temp_ext" && mv "$guns_file$temp_ext" "$guns_file" || { echo "Błąd zapisu broni."; rm -f "$guns_file$temp_ext"; return 1; } # Error saving guns.
	printf '%s\n' "${items[@]}" > "$items_file$temp_ext" && mv "$items_file$temp_ext" "$items_file" || { echo "Błąd zapisu przedmiotów."; rm -f "$items_file$temp_ext"; return 1; } # Error saving items.

    # --- Save Associative Arrays (internal keys) ---
	# Drugs
    : > "$drugs_file$temp_ext" # Create/clear temp file
	for key in "${!drugs[@]}"; do printf "%s %s\n" "$key" "${drugs[$key]}" >> "$drugs_file$temp_ext"; done
    if [[ -f "$drugs_file$temp_ext" ]]; then mv "$drugs_file$temp_ext" "$drugs_file"; else echo "Błąd zapisu tymczasowego pliku narkotyków."; return 1; fi # Error writing drugs temp file.

	# Skills
    : > "$skills_file$temp_ext"
	for key in "${!skills[@]}"; do printf "%s %s\n" "$key" "${skills[$key]}" >> "$skills_file$temp_ext"; done
    if [[ -f "$skills_file$temp_ext" ]]; then mv "$skills_file$temp_ext" "$skills_file"; else echo "Błąd zapisu tymczasowego pliku umiejętności."; return 1; fi # Error writing skills temp file.

	echo "Gra zapisana pomyślnie w '$save_path'." # Game saved successfully to '$save_path'.
	read -r -p "Naciśnij Enter, aby kontynuować..." # Press Enter to continue...
    return 0
}

# Wczytaj stan gry z pliku (Bardziej stabilne)
load_game() {
    local load_success=true
    local original_ifs="$IFS"
    local key="" value="" line="" save_file="" # Declare/clear local variables
    local save_path="$BASEDIR/$SAVE_DIR"

    echo "Próba wczytania gry z '$save_path'..." # Attempting to load game from '$save_path'...

    if [[ ! -d "$save_path" ]]; then
        echo "Błąd: Katalog zapisu '$save_path' nie znaleziony."; read -r -p "Naciśnij Enter..."; return 1; # Error: Save directory '$save_path' not found. Press Enter...
    fi

    # --- Load Simple Variables ---
    save_file="$save_path/player_name.sav"; [[ -f "$save_file" ]] && { read -r player_name < "$save_file" || { >&2 echo "Błąd odczytu $save_file"; load_success=false; }; } || { >&2 echo "Ostrzeżenie: $save_file brak"; player_name="Nieznany"; load_success=false; } # Error reading $save_file | Warn: $save_file missing | Unknown
    save_file="$save_path/location.sav"; [[ -f "$save_file" ]] && { read -r location < "$save_file" || { >&2 echo "Błąd odczytu $save_file"; load_success=false; }; } || { >&2 echo "Ostrzeżenie: $save_file brak"; location="Los Santos"; load_success=false; }
    save_file="$save_path/cash.sav"; [[ -f "$save_file" ]] && { read -r cash < "$save_file" || { >&2 echo "Błąd odczytu $save_file"; load_success=false; }; } || { >&2 echo "Ostrzeżenie: $save_file brak"; cash=0; load_success=false; }
    [[ ! "$cash" =~ ^-?[0-9]+$ ]] && { >&2 echo "Ostrzeżenie: Nieprawidłowa kasa '$cash'"; cash=0; load_success=false; } # Warn: Invalid cash '$cash'
    save_file="$save_path/health.sav"; [[ -f "$save_file" ]] && { read -r health < "$save_file" || { >&2 echo "Błąd odczytu $save_file"; load_success=false; }; } || { >&2 echo "Ostrzeżenie: $save_file brak"; health=100; load_success=false; }
    [[ ! "$health" =~ ^[0-9]+$ ]] && { >&2 echo "Ostrzeżenie: Nieprawidłowe zdrowie '$health'"; health=100; load_success=false; } # Warn: Invalid health '$health'
    (( health <= 0 && load_success )) && { >&2 echo "Ostrzeżenie: Wczytane zdrowie <= 0"; health=50; } # Warn: Loaded health <= 0
    save_file="$save_path/body_armor_equipped.sav"; [[ -f "$save_file" ]] && { read -r body_armor_equipped < "$save_file" || { >&2 echo "Błąd odczytu $save_file"; load_success=false; }; } || { >&2 echo "Ostrzeżenie: $save_file brak"; body_armor_equipped=false; load_success=false; }
    [[ "$body_armor_equipped" != "true" && "$body_armor_equipped" != "false" ]] && { >&2 echo "Ostrzeżenie: Nieprawidłowy pancerz '$body_armor_equipped'"; body_armor_equipped=false; load_success=false; } # Warn: Invalid armor '$body_armor_equipped'

    # --- Load Indexed Arrays (loads internal names) ---
    guns=(); save_file="$save_path/guns.sav"
    if [[ -f "$save_file" ]]; then
         if command -v readarray &> /dev/null; then readarray -t guns < "$save_file";
         else IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do guns+=("$line"); done < "$save_file"; IFS="$original_ifs"; fi
    else >&2 echo "Ostrzeżenie: $save_file brak"; fi # Warn: $save_file missing

    items=(); save_file="$save_path/items.sav"
    if [[ -f "$save_file" ]]; then
        if command -v readarray &> /dev/null; then readarray -t items < "$save_file";
        else IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do items+=("$line"); done < "$save_file"; IFS="$original_ifs"; fi
    else >&2 echo "Ostrzeżenie: $save_file brak"; fi # Warn: $save_file missing

    # --- Load Associative Arrays (loads internal keys) ---
    declare -A drugs_loaded=(); save_file="$save_path/drugs.sav"
    if [[ -f "$save_file" ]]; then
        while IFS=' ' read -r key value || [[ -n "$key" ]]; do
            if [[ -n "$key" && -v "default_drugs[$key]" ]]; then # Check against default_drugs keys (internal names)
                 if [[ "$value" =~ ^[0-9]+$ ]]; then drugs_loaded["$key"]="$value"; else
                     >&2 echo "Ostrzeżenie: Nieprawidłowa ilość narkotyku '$key'='$value'"; drugs_loaded["$key"]=0; load_success=false; fi # Warn: Invalid drug amt '$key'='$value'
            elif [[ -n "$key" ]]; then >&2 echo "Ostrzeżenie: Pomijanie nieznanego narkotyku '$key'"; fi # Warn: Skipping unknown drug '$key'
        done < "$save_file"
    else >&2 echo "Ostrzeżenie: $save_file brak"; load_success=false; fi # Warn: $save_file missing
    declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${drugs_loaded[$key]:-${default_drugs[$key]}}; done

    declare -A skills_loaded=(); save_file="$save_path/skills.sav"
    if [[ -f "$save_file" ]]; then
        while IFS=' ' read -r key value || [[ -n "$key" ]]; do
             if [[ -n "$key" && -v "default_skills[$key]" ]]; then # Check against default_skills keys (internal names)
                 if [[ "$value" =~ ^[0-9]+$ ]]; then skills_loaded["$key"]="$value"; else
                     >&2 echo "Ostrzeżenie: Nieprawidłowy poziom umiejętności '$key'='$value'"; skills_loaded["$key"]=1; load_success=false; fi # Warn: Invalid skill lvl '$key'='$value'
             elif [[ -n "$key" ]]; then >&2 echo "Ostrzeżenie: Pomijanie nieznanej umiejętności '$key'"; fi # Warn: Skipping unknown skill '$key'
        done < "$save_file"
    else >&2 echo "Ostrzeżenie: $save_file brak"; load_success=false; fi # Warn: $save_file missing
    declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${skills_loaded[$key]:-${default_skills[$key]}}; done

    # --- Final Check ---
    IFS="$original_ifs"
    if $load_success; then echo "Gra wczytana pomyślnie."; else # Game loaded successfully.
        echo "Ostrzeżenie: Gra wczytana z brakującymi/nieprawidłowymi danymi. Użyto wartości domyślnych."; fi # Warning: Game loaded with missing/invalid data. Defaults used.
    read -r -p "Naciśnij Enter, aby rozpocząć grę..." # Press Enter to start playing...
    return 0
}

# --- 4. Inicjalizacja Gry i Pętla ---

# Funkcja inicjalizacji NOWYCH zmiennych gry
Game_variables() {
	clear_screen
	read -r -p "Wpisz swoją nazwę gracza: " player_name # Enter your player name:
	[[ -z "$player_name" ]] && player_name="Włóczęga" # Wanderer
	play_sfx_mpg "new_game"
	location="Los Santos"
	cash=500
	health=100
	guns=() # Reset internal arrays
	items=()
    # Reset associative arrays using defaults (internal keys)
    declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${default_drugs[$key]}; done
    declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${default_skills[$key]}; done
    body_armor_equipped=false
	echo "Witaj w Bash Theft Auto, $player_name!" # Welcome to Bash Theft Auto, $player_name!
    echo "Zaczynasz w $location z \$${cash} i ${health}% zdrowia." # Starting in $location with $${cash} and ${health}% health.
    read -r -p "Naciśnij Enter, aby zacząć..." # Press Enter to begin...
}

# Funkcja bezpiecznego usuwania plików zapisu
remove_save_files() {
    local save_path="$BASEDIR/$SAVE_DIR"
    if [[ -d "$save_path" ]]; then
        echo "Usuwanie poprzednich plików zapisu w '$save_path'..." # Deleting previous save files in '$save_path'...
        local found_files=$(find "$save_path" -maxdepth 1 -type f -name '*.sav' -print -delete)
        if [[ -n "$found_files" ]]; then echo "Stare pliki zapisu usunięte pomyślnie."; else echo "Nie znaleziono plików '.sav' do usunięcia."; fi # Old save files deleted successfully. | No '.sav' files found to delete.
    else
        echo "Info: Nie znaleziono poprzedniego katalogu zapisu w '$save_path'." # Info: No previous save directory found at '$save_path'.
    fi
    sleep 1 # Short pause
}

# --- Początkowe Menu Gry ---
run_initial_menu() {
    while true; do
	    clear_screen
	    echo "=== Bash Theft Auto ==="
	    echo "    Menu Główne" # Main Menu
        echo "---------------------"
	    echo "1. Nowa Gra" # 1. New Game
	    echo "2. Wczytaj Grę" # 2. Load Game
	    echo "3. Wyjdź z Gry" # 3. Exit Game
        echo "---------------------"
        stty echo # Ensure echo is on for menu
	    read -r -p "Wpisz swój wybór: " initial_choice # Enter your choice:

	    case "$initial_choice" in
		    1)
                read -r -p "Rozpocząć nową grę? Spowoduje to usunięcie istniejącego zapisu. (t/n): " confirm # Start new game? This deletes any existing save. (y/n): -> t/n
                if [[ "$confirm" == "t" || "$confirm" == "T" || "$confirm" == "y" || "$confirm" == "Y" ]]; then # Check for Polish 't' or 'y'/'Y'
                    remove_save_files
                    Game_variables
                    return 0 # Signal to start game loop
                else echo "Nowa gra anulowana."; sleep 1; fi ;; # New game cancelled.
		    2)
                if load_game; then return 0; # Signal to start game loop
                else sleep 1; fi ;; # Load game failed, pause before showing menu again
		    3) cleanup_and_exit ;; # Use cleanup function
		    *) echo "Nieprawidłowy wybór."; sleep 1 ;; # Invalid choice.
	    esac
    done
}

# --- Główne Wykonanie ---

# Run initial menu. If it returns successfully (0), proceed to main loop.
if ! run_initial_menu; then
    echo "Wyjście z powodu błędu menu początkowego lub żądania użytkownika." # Exiting due to initial menu failure or user request.
    stty echo # Ensure echo is on just in case
    exit 1
fi


# --- Główna Pętla Gry ---
while true; do
    # Check health at START; handles death/hospitalization and returns 1 if player died
    if check_health; then
        # Player is alive, clear screen and show status/menu
        clear_screen
    else
        # Player was hospitalized, screen already handled by check_health/hospitalize_player
        # Just need to show the main menu again after they press Enter
        clear_screen # Show status after hospital
    fi

    # --- Wyświetlanie Głównego Menu ---
    echo "--- Akcje ---" # Actions
    echo "1. Podróżuj          | 6. Kup narkotyki"         # 1. Travel        | 6. Buy Drugs
    echo "2. Kup broń          | 7. Sprzedaj narkotyki"    # 2. Buy Guns      | 7. Sell Drugs
    echo "3. Ekwipunek         | 8. Wynajmij prostytutkę"  # 3. Inventory     | 8. Hire Hooker
    echo "4. Praca (Legalna)   | 9. Odwiedź szpital"       # 4. Work (Legal)  | 9. Visit Hospital
    echo "5. Praca (Przestęp.) | 10. Wyścig uliczny"       # 5. Work (Crime)  | 10. Street Race
    echo "-----------------------------------------"
    echo "Z. Zapisz grę        | W. Wczytaj grę"           # S. Save Game     | L. Load Game -> Z/W
    echo "M. Odtwarzacz muzyki | O. O grze"                # M. Music Player  | A. About -> M/O
    echo "X. Wyjdź z gry"                                  # X. Exit Game
    echo "-----------------------------------------"

    # --- Restore terminal echo before reading input ---
    stty echo
    # --- Read user choice ---
    read -r -p "Wpisz swój wybór: " choice # Enter your choice:
    # Convert choice to lowercase for commands
    choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    # --- Process Choice ---
    case "$choice_lower" in
	    1) # Travel Menu
            clear_screen; echo "--- Biuro Podróży ---" # Travel Agency
            echo "1. Los Santos (\$50) | 2. San Fierro (\$75) | 3. Las Venturas (\$100)";
            echo "4. Vice City (\$150) | 5. Liberty City (\$200) | 6. Zostań tutaj"; # Stay Here
            read -r -p "Wpisz wybór: " city_choice # Enter choice:
            [[ ! "$city_choice" =~ ^[1-6]$ ]] && { echo "Nieprawidłowy wybór."; sleep 1; continue; } # Invalid choice.
            case "$city_choice" in
                1) travel_to 50 "Los Santos";; 2) travel_to 75 "San Fierro";;
                3) travel_to 100 "Las Venturas";; 4) travel_to 150 "Vice City";;
                5) travel_to 200 "Liberty City";; 6) ;;
            esac;;
	    2) buy_guns;;
	    3) show_inventory;;
	    4) # Legal Work Menu
            clear_screen; echo "--- Uczciwa Praca ---" # Honest Work
            echo "1. Taksówkarz | 2. Dostawca | 3. Mechanik | 4. Ochroniarz | 5. Artysta uliczny | 6. Wróć"; # Taxi Driver | Delivery | Mechanic | Security | Performer | Back
            read -r -p "Wpisz wybór: " job_choice # Enter choice:
            [[ ! "$job_choice" =~ ^[1-6]$ ]] && { echo "Nieprawidłowy wybór."; sleep 1; continue; } # Invalid choice.
            case "$job_choice" in
                1) work_job "Taksówkarz";; 2) work_job "Dostawca";; 3) work_job "Mechanik";;
                4) work_job "Ochroniarz";; 5) work_job "Artysta uliczny";; 6) ;;
            esac;;
	    5) # Criminal Activity Menu
            clear_screen; echo "--- Działalność Przestępcza ---" # Criminal Activities
            echo "1. Napad na sklep | 2. Kradzież samochodu | 3. Wojna gangów | 4. Napad | 5. Wróć"; # Rob Store | Carjack | Gang War | Heist | Back
            read -r -p "Wpisz wybór: " criminal_choice # Enter choice:
            [[ ! "$criminal_choice" =~ ^[1-5]$ ]] && { echo "Nieprawidłowy wybór."; sleep 1; continue; } # Invalid choice.
            case "$criminal_choice" in
                1) rob_store;; 2) carjack;; 3) gang_war;; 4) heist;; 5) ;;
            esac;;
	    6) buy_drugs;;
	    7) sell_drugs;;
	    8) hire_hooker;;
	    9) visit_hospital;;
        10) street_race;;
	    'z') save_game;; # Z for Zapisz
	    'w') # W for Wczytaj
             read -r -p "Wczytać grę? Niezapisane postępy zostaną utracone. (t/n): " confirm # Load game? Unsaved progress will be lost. (y/n): -> t/n
             if [[ "$confirm" == "t" || "$confirm" == "T" || "$confirm" == "y" || "$confirm" == "Y" ]]; then # Check for Polish 't' or 'y'/'Y'
                 load_game # Load game handles messages and continues loop
             else echo "Wczytywanie anulowane."; sleep 1; fi ;; # Load cancelled.
	    'm') play_music;; # M for Muzyka
	    'o') about_music_sfx;; # O for O grze
        'x')
             read -r -p "Czy na pewno chcesz wyjść? (t/n): " confirm # Are you sure you want to exit? (y/n): -> t/n
             if [[ "$confirm" == "t" || "$confirm" == "T" || "$confirm" == "y" || "$confirm" == "Y" ]]; then # Check for Polish 't' or 'y'/'Y'
                 # Optional: Auto-save before exit?
                 # read -r -p "Zapisać przed wyjściem? (t/n): " save_confirm
                 # if [[ "$save_confirm" == "t" || "$save_confirm" == "T" || "$save_confirm" == "y" || "$save_confirm" == "Y" ]]; then save_game; fi
                 cleanup_and_exit # Use cleanup function
             fi ;;
	    *) echo "Nieprawidłowy wybór '$choice'."; sleep 1;; # Invalid choice '$choice'.
	esac
    # Loop continues
done

# Should not be reached, but attempt cleanup if it ever does
cleanup_and_exit
