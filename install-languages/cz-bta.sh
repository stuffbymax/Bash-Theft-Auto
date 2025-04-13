# Bash-Theft-Auto hudba a SFX © 2024 by stuffbymax - Martin Petik je licencován pod CC BY 4.0
# https://creativecommons.org/licenses/by/4.0/
# ver 2.0.5 (Opravy Terminal echo)
#!/bin/bash

# --- Počáteční nastavení ---
# Nastaví BASEDIR na adresář, kde se nachází skript
# Používá rozšíření parametrů pro potenciálně lepší kompatibilitu než realpath
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ukončí při chybě, aby se zabránilo neočekávanému chování
# set -e # Odkomentujte toto pro přísnější kontrolu chyb, ale může se snadno ukončit

# --- Funkce pro úklid a Trap ---
cleanup_and_exit() {
    echo -e "\nUklízím a ukončuji..."
    # Zastaví hudbu, pokud hraje
    if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
        echo "Zastavuji hudbu (PID: $music_pid)..."
        kill "$music_pid" &>/dev/null
        wait "$music_pid" 2>/dev/null
        music_pid=""
    fi
    # Obnoví terminálové echo
    stty echo
    echo "Úklid dokončen. Nashledanou."
    exit 0
}
# Trapuje běžné signály pro ukončení pro spuštění úklidové funkce
trap cleanup_and_exit SIGINT SIGTERM SIGHUP

# --- 0. Globální proměnné ---
player_name=""
location="Los Santos" # Výchozí počáteční lokace
cash=0
health=100 # Výchozí počáteční zdraví
declare -a guns=()
declare -a items=()
declare -A drugs=()
declare -A skills=()
body_armor_equipped=false
SAVE_DIR="saves" # Relativní k BASEDIR
declare -A gun_attributes=()
music_pid="" # PID pro přehrávač hudby na pozadí

# Inicializace atributů zbraní (zajistí, že pole je vyplněno)
gun_attributes=(
	["Pistol"]="success_bonus=5"
	["Shotgun"]="success_bonus=10"
	["SMG"]="success_bonus=15"
	["Rifle"]="success_bonus=20"
	["Sniper"]="success_bonus=25"
)

# Inicializace výchozích dovedností/drog (používá se v load_game a new_game)
declare -A default_skills=( ["driving"]=1 ["strength"]=1 ["charisma"]=1 ["stealth"]=1 ["drug_dealer"]=1 )
declare -A default_drugs=( ["Weed"]=0 ["Cocaine"]=0 ["Heroin"]=0 ["Meth"]=0 )


# --- Kontrola závislostí ---
mpg123_available=true
if ! command -v mpg123 &> /dev/null; then
    echo "###########################################################"
    echo "# Upozornění: příkaz 'mpg123' nebyl nalezen.              #" # Warning: 'mpg123' command not found.
    echo "# Zvukové efekty a hudba vyžadují mpg123.                  #" # Sound effects and music require mpg123.
    echo "# Nainstalujte jej pro plný zážitek.                       #" # Please install it for the full experience.
    echo "#---------------------------------------------------------#"
    echo "# Na Debian/Ubuntu: sudo apt update && sudo apt install mpg123 #"
    echo "# Na Fedora:        sudo dnf install mpg123               #"
    echo "# Na Arch Linux:    sudo pacman -S mpg123                 #"
    echo "# Na macOS (Homebrew): brew install mpg123                #"
    echo "###########################################################"
    read -r -p "Stiskněte Enter pro pokračování bez zvuku..." # Press Enter to continue without sound...
    mpg123_available=false
fi

# --- Nastavení zvukových efektů ---
sfx_dir="sfx"  # Adresář pro zvukové efekty relativní k BASEDIR

# Funkce pro přehrávání zvukových efektů (zpracovává chybějící mpg123)
play_sfx_mpg() {
    if ! $mpg123_available; then
        return 1 # Zvuk zakázán
    fi
    local sound_name="$1"
    local sound_file="$BASEDIR/$sfx_dir/${sound_name}.mp3"
    if [[ -f "$sound_file" ]]; then
        if command -v mpg123 &> /dev/null; then
           # Spustí na pozadí, odpojeně, zahodí stdout/stderr, pokud se neladí
           mpg123 -q "$sound_file" &>/dev/null &
            return 0  # Indikuje úspěch
        fi
    else
        # Tiše ignoruje chybějící SFX soubory nebo je protokoluje, pokud se ladí
        # >&2 echo "Debug: Zvukový soubor nebyl nalezen: '$sound_file'" # Debug: Sound file not found: '$sound_file'
        return 1
    fi
    return 1 # Indikuje selhání (např. kontrola mpg123 selhala uvnitř)
}

# --- 1. Načítání pluginů ---
plugin_dir="plugins" # Relativní k BASEDIR

if [[ -d "$BASEDIR/$plugin_dir" ]]; then
	# Použije find v kontextu BASEDIR
	while IFS= read -r -d $'\0' plugin_script; do
		# Source plugin pomocí jeho úplné cesty
		if [[ -f "$plugin_script" ]]; then
            # >&2 echo "Načítám plugin: $plugin_script" # Debug message: Loading plugin: $plugin_script
            source "$plugin_script"
        fi
	done < <(find "$BASEDIR/$plugin_dir" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)
else
	# Není to nutně chyba, jen informace
	echo "Info: Adresář pluginů '$BASEDIR/$plugin_dir' nebyl nalezen. Přeskakuji načítání pluginů." # Info: Plugin directory '$BASEDIR/$plugin_dir' not found. Skipping plugin load.
fi

# --- 3. Funkce ---

# Vymaže obrazovku a zobrazí záhlaví s herními informacemi
clear_screen() {
    clear
    printf "\e[93m=========================================\e[0m\n"
    printf "\e[1;43m|        Bash Theft Auto                |\e[0m\n"
    printf "\e[93m=========================================\e[0m\n"
    printf " Hráč: %-15s Lokace: %s\n" "$player_name" "$location" # Player: %-15s Location: %s
    printf " Peníze: \$%-16d Zdraví: %d%%\n" "$cash" "$health" # Cash: \$%-16d Health: %d%%
    # Zobrazí stav neprůstřelné vesty
    if $body_armor_equipped; then
        printf " Brnění: \e[1;32mVybaveno\e[0m\n" # Armor: Equipped
    else
        printf " Brnění: \e[1;31mŽádné\e[0m\n" # Armor: None
    fi
    printf "\e[1;34m=========================================\e[0m\n"
}

# --- O hře ---
about_music_sfx() {
	clear_screen
	echo "-----------------------------------------"
	echo "|  O hudbě a zvukových efektech         |" # About the Music and Sound Effects
	echo "-----------------------------------------"
	echo ""
	echo "Hudba a SFX © 2024 by stuffbymax - Martin Petik" # Music and SFX © 2024 by stuffbymax - Martin Petik
	echo "Licencováno pod CC BY 4.0:" # Licensed under CC BY 4.0:
	echo "https://creativecommons.org/licenses/by/4.0/"
	echo ""
	echo "Můžete tento materiál volně sdílet a upravovat" # You are free to share and adapt this material
	echo "pro jakýkoli účel, a to i komerčně, pod" # for any purpose, even commercially, under the
	echo "podmínkou, že uvedete odpovídající kredit." # condition that you give appropriate credit.
	echo ""
	echo "Příklad atribuce:" # Attribution example:
	echo "'Hudba/SFX © 2024 stuffbymax - Martin Petik, CC BY 4.0'" # 'Music/SFX © 2024 stuffbymax - Martin Petik, CC BY 4.0'
	echo ""
	echo "Více informací: https://stuffbymax.me/" # More info: https://stuffbymax.me/
	echo ""
	echo "-----------------------------------------"
	echo "|  Licence kódu                          |" # Code License
	echo "-----------------------------------------"
	echo ""
	echo "Kód hry © 2024 stuffbymax" # Game Code © 2024 stuffbymax
	echo "Licencováno pod licencí MIT." # Licensed under the MIT License.
	echo "Umožňuje opakované použití s uvedením zdroje." # Allows reuse with attribution.
	echo ""
	echo "Úplná licence:" # Full License:
	echo "https://github.com/stuffbymax/Bash-Theft-Auto/blob/main/LICENSE" # Zkontrolujte, zda je tento odkaz správný
	echo ""
	echo "Děkujeme za hraní!" # Thank you for playing!
    echo "-----------------------------------------"
	read -r -p "Stiskněte Enter pro návrat..." # Press Enter to return...
}

# Funkce pro kontrolu, zda je hráč naživu, a zpracování smrti
check_health() {
	if (( health <= 0 )); then
        health=0 # Zabraňuje zobrazení záporného zdraví
		clear_screen
		echo -e "\n      \e[1;31m Z T R Á T A \e[0m\n" # W A S T E D
		play_sfx_mpg "wasted"
		echo "Zhroutili jste se ze svých zranění..." # You collapsed from your injuries...
		sleep 1
		echo "Později se probudíte..." # You wake up later...
		read -r -p "Stiskněte Enter pro přechod do nemocnice..." # Press Enter to go to the hospital...
		hospitalize_player # Zpracovává následky smrti
        return 1 # Indikuje, že hráč byl hospitalizován (zemřel)
	fi
    return 0 # Indikuje, že hráč je v pořádku
}

# Funkce pro cestování na nové místo
travel_to() {
	local travel_cost="$1"
	local new_location="$2"
    local current_location="$location" # Uloží aktuální lokaci pro zprávu

    # Zabrání cestování na stejné místo
    if [[ "$new_location" == "$current_location" ]]; then
        echo "Už jste v $new_location." # You are already in $new_location.
        read -r -p "Stiskněte Enter..." # Press Enter...
        return
    fi

	if (( cash >= travel_cost )); then
		printf "Cestování z %s do %s (\$%d)...\n" "$current_location" "$new_location" "$travel_cost" # Traveling from %s to %s (\$%d)...
		play_sfx_mpg "air"

		# --- Animace letecké dopravy (Volitelné volání pluginu) ---
        if command -v air_travel_animation &> /dev/null; then
		    air_travel_animation "$current_location" "$new_location" # Předá lokace možná?
        else
            # Jednoduchá textová animace, pokud plugin chybí
            echo -n "["
            for _ in {1..20}; do echo -n "="; sleep 0.05; done
            echo ">]"
        fi
		# --- Konec animace ---

		cash=$((cash - travel_cost))
		location="$new_location"
		echo "Bezpečně jste dorazili do $new_location." # You have arrived safely in $new_location.
        read -r -p "Stiskněte Enter..." # Press Enter...
	else
		echo "Nedostatek peněz (\$$travel_cost potřeba) pro cestování do $new_location." # Not enough cash (\$$travel_cost needed) to travel to $new_location.
		read -r -p "Stiskněte Enter..." # Press Enter...
	fi
}

# Funkce pro menu nákupu zbraní
buy_guns() {
	local gun_choice=""
	clear_screen
	echo "--- Ammu-Nation ---"
	echo "Vítejte! Co pro vás mohu udělat?" # Welcome! What can I get for you?
	echo "-------------------"
	echo "1. Pistole      (\$100)" # 1. Pistol      ($100)
	echo "2. Brokovnice     (\$250)" # 2. Shotgun     ($250)
	echo "3. SMG         (\$500)" # 3. SMG         ($500)
	echo "4. Puška       (\$750)" # 4. Rifle       ($750)
	echo "5. Sniper      (\$1000)" # 5. Sniper      ($1000)
	echo "-------------------"
	echo "6. Odejít" # 6. Leave
    echo "-------------------"
    printf "Vaše peníze: \$%d\n" "$cash" # Your Cash: $%d
	read -r -p "Zadejte svou volbu: " gun_choice # Enter your choice:

	[[ ! "$gun_choice" =~ ^[0-9]+$ ]] && {
		echo "Neplatný vstup."; read -r -p "Stiskněte Enter..."; return # Invalid input. Press Enter...
	}

	case "$gun_choice" in
		1) buy_gun "Pistol" 100;; # Změněn název pomocníka pro jasnost
		2) buy_gun "Shotgun" 250;;
		3) buy_gun "SMG" 500;;
		4) buy_gun "Rifle" 750;;
		5) buy_gun "Sniper" 1000;;
		6) echo "Vraťte se kdykoli!"; sleep 1; return;; # Come back anytime!
		*) echo "Neplatná volba."; read -r -p "Stiskněte Enter...";; # Invalid choice. Press Enter...
	esac
}

# Pomocná funkce pro nákup ZBRANÍ konkrétně
buy_gun() {
	local gun_name="$1"
	local gun_cost="$2"
    local owned=false

    # Zkontroluje, zda již vlastníte
    for owned_gun in "${guns[@]}"; do
        if [[ "$owned_gun" == "$gun_name" ]]; then
            owned=true
            break
        fi
    done
    if $owned; then
        echo "Vypadá to, že už máš $gun_name, partnere." # Looks like you already got a $gun_name there, partner.
        read -r -p "Stiskněte Enter..." # Press Enter...
        return
    fi

    # Zkontroluje peníze
	if (( cash >= gun_cost )); then
        play_sfx_mpg "cash_register"
		# --- Animace nákupu (Volitelné volání pluginu) ---
        if command -v buy_animation &> /dev/null; then
            buy_animation "$gun_name"
        fi
        # --- Konec animace ---

		cash=$((cash - gun_cost))
		guns+=("$gun_name") # Přidá do pole zbraní
		echo "Jedna $gun_name, hned to bude! To bude \$$gun_cost." # One $gun_name, coming right up! That'll be \$$gun_cost.
		read -r -p "Stiskněte Enter..." # Press Enter...
	else
		echo "Promiň kámo, málo peněz na $gun_name (\$$gun_cost potřeba)." # Sorry pal, not enough cash for the $gun_name (\$$gun_cost needed).
		read -r -p "Stiskněte Enter..." # Press Enter...
	fi
}

# Funkce pro zobrazení inventáře
show_inventory() {
	clear_screen
	echo "--- Inventář & Statistiky ---" # Inventory & Stats
	printf " Peníze: \$%d\n" "$cash" # Cash: $%d
	printf " Zdraví: %d%%\n" "$health" # Health: %d%%
    if $body_armor_equipped; then
        printf " Brnění: \e[1;32mVybaveno\e[0m\n" # Armor: Equipped
    else
        printf " Brnění: \e[1;31mŽádné\e[0m\n" # Armor: None
    fi
	echo "--------------------------"
    echo " Zbraně:" # Guns:
    if (( ${#guns[@]} > 0 )); then
        printf "  - %s\n" "${guns[@]}"
    else
        echo "  (Žádné)" # (None)
    fi
    echo "--------------------------"
    echo " Předměty:" # Items:
     if (( ${#items[@]} > 0 )); then
        # Implementujte použití předmětů zde později?
        printf "  - %s\n" "${items[@]}"
    else
        echo "  (Žádné)" # (None)
    fi
	echo "--------------------------"
	echo " Drogy:" # Drugs:
	local drug_found=false
    for drug in "${!default_drugs[@]}"; do # Iterujte výchozí klíče pro zachování pořadí
        local amount=${drugs[$drug]:-0}
        if (( amount > 0 )); then
            printf "  - %-10s: %d jednotek\n" "$drug" "$amount" # units
            drug_found=true
        fi
    done
    if ! $drug_found; then echo "  (Žádné)"; fi # (None)
    echo "--------------------------"
	echo " Dovednosti:" # Skills:
    for skill in "${!default_skills[@]}"; do # Iterujte výchozí klíče
        printf "  - %-12s: %d\n" "$skill" "${skills[$skill]:-0}"
    done
	echo "--------------------------"
	read -r -p "Stiskněte Enter pro návrat..." # Press Enter to return...
}

# Funkce pro práci (Legální práce)
work_job() {
	local job_type="$1"
	local earnings=0 base_earnings=0 skill_bonus=0
	local min_earnings=0 max_earnings=0
	local relevant_skill_level=1 relevant_skill_name=""

	# Určete základní rozsah platu a relevantní dovednost podle lokace
	case "$location" in
		"Los Santos")   min_earnings=20; max_earnings=60;;
		"San Fierro")   min_earnings=25; max_earnings=70;;
		"Las Venturas") min_earnings=30; max_earnings=90;;
		"Vice City")    min_earnings=15; max_earnings=50;;
		"Liberty City") min_earnings=35; max_earnings=100;;
		*)              min_earnings=10; max_earnings=40;;
	esac
    base_earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings))

    # Určete vliv dovednosti na základě typu práce
	case "$job_type" in
		"taxi"|"delivery")
            relevant_skill_name="driving"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * (job_type == "delivery" ? 4 : 3) )) # Delivery používá dovednost o něco více
            [[ "$job_type" == "delivery" ]] && base_earnings=$((base_earnings + 10))
			play_sfx_mpg "taxi"
			;;
		"mechanic")
            relevant_skill_name="strength" # Možná síla pro zvedání? Nebo přidejte konkrétní dovednost později
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 1))
            base_earnings=$((base_earnings + 20))
			play_sfx_mpg "mechanic"
			;;
		"security")
            relevant_skill_name="strength"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 2))
            base_earnings=$((base_earnings + 30))
			play_sfx_mpg "security"
			;;
		"performer")
            relevant_skill_name="charisma"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 5))
            base_earnings=$((base_earnings - 10)) # Méně spolehlivý základ
            base_earnings=$(( base_earnings < 5 ? 5 : base_earnings )) # Min základ 5
			play_sfx_mpg "street_performer"
			;;
		*) echo "Interní chyba: Neplatný typ práce '$job_type'"; return;; # Internal Error: Invalid Job Type '$job_type'
	esac

    earnings=$((base_earnings + skill_bonus))
    (( earnings < 0 )) && earnings=0 # Zajistí, že výdělek není záporný

    # --- Pracovní animace (Volitelné volání pluginu) ---
    if command -v working_animation &> /dev/null; then
	    working_animation "$job_type"
    else
        echo "Pracuji jako $job_type..." # Working as a $job_type...
        sleep 2
    fi
    # --- Konec animace ---

	# --- Výsledek ---
	cash=$((cash + earnings))
	clear_screen
	printf "Dokončili jste směnu jako %s v %s.\n" "$job_type" "$location" # Finished your shift as a %s in %s.
    printf "Vydělali jste \$%d (Základ: \$%d, Bonus za dovednost: \$%d).\n" "$earnings" "$base_earnings" "$skill_bonus" # You earned $%d (Base: $%d, Skill Bonus: $%d).
    printf "Nyní máte \$%d.\n" "$cash" # You now have $%d.

    # Potenciální zvýšení dovedností
    if [[ -n "$relevant_skill_name" ]]; then # Pouze pokud byla dovednost relevantní
        local skill_increase_chance=20 # 20% základní šance
        if (( RANDOM % 100 < skill_increase_chance )); then
            skills[$relevant_skill_name]=$((relevant_skill_level + 1))
            printf "Vaše dovednost \e[1;32m%s\e[0m se zvýšila!\n" "$relevant_skill_name" # Your %s skill increased!
        fi
    fi

	read -r -p "Stiskněte Enter pro pokračování..." # Press Enter to continue...
}

# Funkce pro pouliční závody
street_race() {
    local driving_skill=${skills[driving]:-1}
	local base_win_chance=40
	local win_chance=$(( base_win_chance + driving_skill * 5 ))
    (( win_chance > 90 )) && win_chance=90 # Horní hranice šance na výhru 90%
    (( win_chance < 10 )) && win_chance=10 # Minimální šance na výhru 10%

    clear_screen
    echo "--- Pouliční závod ---" # Street Race
    echo "Připojuji se k nelegálnímu pouličnímu závodu v $location..." # Joining an illegal street race in $location...
    echo "Řidičská dovednost: $driving_skill | Šance na výhru: ${win_chance}%" # Driving Skill: $driving_skill | Win Chance: ${win_chance}%
    sleep 1

    # --- Animace pouličního závodu (Volitelné volání pluginu) ---
    if command -v race_animation &> /dev/null; then
        race_animation
    elif command -v working_animation &> /dev/null; then
        working_animation "street_race" # Záložní generická animace
    else
        echo "Připravte se..." ; sleep 1; echo "3... 2... 1... START!"; sleep 1 # Get ready... ; 3... 2... 1... GO!
    fi
    # --- Konec animace ---

    read -r -p "Stiskněte Enter pro výsledky závodu..." # Press Enter for the race results...

	local winnings=0 damage=0

	if (( RANDOM % 100 < win_chance )); then
        # --- Výhra ---
		winnings=$((RANDOM % 151 + 100 + driving_skill * 10)) # Výhra 100-250 + bonus
		cash=$((cash + winnings))
		damage=$((RANDOM % 15 + 5)) # Nízké poškození při výhře: 5-19%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2))
            damage=$((damage - armor_reduction))
			echo "Vaše neprůstřelná vesta absorbovala \e[1;31m${armor_reduction}%%\e[0m poškození!" # Your body armor absorbed %d%% damage!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
		printf "\e[1;32m*** VYHRÁLI JSTE ZÁVOD! ***\e[0m\n" # *** YOU WON THE RACE! ***
        printf "Získali jste \$%d jako výhru.\n" "$winnings" # You collected $%d in prize money.
        printf "Utrpěli jste menší poškození (-%d%% zdraví).\n" "$damage" # Took minor damage (-%d%% health).
        play_sfx_mpg "win"
		# Šance na zvýšení dovednosti při výhře
		if (( RANDOM % 3 == 0 )); then # 33% šance
            skills[driving]=$((driving_skill + 1))
            printf "Vaše \e[1;32mřidičská\e[0m dovednost se zvýšila!\n" # Your driving skill increased! (adjusted)
        fi
	else
        # --- Prohra ---
        winnings=0 # Žádné výhry při prohře
		damage=$((RANDOM % 31 + 15)) # Vyšší poškození při prohře: 15-45%
		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2))
            damage=$((damage - armor_reduction))
			echo "Vaše neprůstřelná vesta absorbovala \e[1;31m${armor_reduction}%%\e[0m poškození při nehodě!" # Your body armor absorbed %d%% damage in the crash!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- PROHRÁLI JSTE ZÁVOD! ---\e[0m\n" # --- YOU LOST THE RACE! ---
		printf "Havarovali jste a utrpěli jste %d%% poškození.\n" "$damage" # You crashed and took %d%% damage.
		play_sfx_mpg "lose" # Or a crash sound? "car_crash"?
	fi

    # Zobrazí konečné statistiky akce
    printf "Aktuální stav -> Peníze: \$%d | Zdraví: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%

    # Zkontroluje zdraví PO zobrazení výsledků
    check_health # Toto zpracuje hospitalizaci, pokud je zdraví <= 0
    read -r -p "Stiskněte Enter pro pokračování..." # Press Enter to continue...
}

# (Funkce use_guns zůstává nezměněna - zachována pro potenciální budoucí použití)
use_guns() {
	if [[ " ${guns[*]} " == *" $1 "* ]]; then
		echo "Použili jste svou $1 pro tuto práci." # You used your $1 for this job.
		play_sfx_mpg "gun_shot"
		read -r -p "Stiskněte Enter..." # Press Enter...
	else
		echo "Nemáte $1. Práce se nezdařila." # You don't have a $1. Job failed.
		read -r -p "Stiskněte Enter..." # Press Enter...
	fi
}

# Pomocná funkce pro zpracování výběru zbraně a uplatnění bonusu pro kriminální akce
apply_gun_bonus() {
    local base_chance=$1
    local action_message=$2
    local current_chance=$base_chance
    local gun_bonus=0
    local chosen_gun=""
    local gun_found=false
    local success_bonus=0 # Lokální proměnná pro zachycení bonusu z eval

    if (( ${#guns[@]} == 0 )); then
        echo "Nemáte žádné zbraně! Bude to podstatně těžší." # You have no guns! This will be significantly harder.
        gun_bonus=-15 # Významná penalizace za neozbrojení
    else
        echo "Dostupné zbraně: ${guns[*]}" # Available guns: ${guns[*]}
        read -r -p "Použít zbraň pro tuto $action_message? (a/n): " use_gun # Use a gun for this $action_message? (y/n): -> a/n for Ano/Ne

        if [[ "$use_gun" == "a" || "$use_gun" == "A" ]]; then # Check for 'a' or 'A'
            read -r -p "Kterou zbraň? (Zadejte přesný název): " chosen_gun # Which gun? (Enter exact name):

            # Zkontrolujte, zda hráč vlastní vybranou zbraň
            gun_found=false
            for gun in "${guns[@]}"; do
                if [[ "$gun" == "$chosen_gun" ]]; then
                    gun_found=true
                    break
                fi
            done

            if $gun_found; then
                echo "Vytahujete svou $chosen_gun!" # You draw your $chosen_gun!
                play_sfx_mpg "gun_cock"

                # Aplikuje Bonus zbraně, pokud je definován
                if [[ -v "gun_attributes[$chosen_gun]" ]]; then
                    eval "${gun_attributes[$chosen_gun]}" # Nastaví 'success_bonus' lokálně
                    gun_bonus=${success_bonus:-0}
                    if (( gun_bonus > 0 )); then
                        echo "$chosen_gun dává \e[1;32m+${gun_bonus}%%\e[0m šanci na úspěch." # The $chosen_gun gives a +%d%% success chance. (Rephrased for Czech)
                        play_sfx_mpg "gun_shot"
                    else
                        echo "$chosen_gun zde neposkytuje žádnou specifickou výhodu." # The $chosen_gun provides no specific advantage here. (Rephrased for Czech)
                    fi
                else
                    echo "Upozornění: Pro '$chosen_gun' nejsou definovány žádné bonusové atributy." # Warning: No bonus attributes defined for '$chosen_gun'.
                    gun_bonus=0
                fi
            else
                echo "Nevlastníte '$chosen_gun'! Pokračuji bez bonusu za zbraň." # You don't own '$chosen_gun'! Proceeding without a gun bonus.
                gun_bonus=0
            fi
        else
            echo "Pokračuji bez použití zbraně." # Proceeding without using a gun.
            gun_bonus=-5 # Malá penalizace za to, že se rozhodnete nepoužít dostupnou zbraň? Volitelné.
        fi
    fi

    current_chance=$((current_chance + gun_bonus))

    # Upíná šanci na úspěch (např. 5% až 95%)
    (( current_chance < 5 )) && current_chance=5
    (( current_chance > 95 )) && current_chance=95

    echo "$current_chance" # Vrátí konečnou vypočítanou šanci
}


# Funkce pro návštěvu nemocnice (Menu)
visit_hospital() {
	local hospital_choice=""
	while true; do # Smyčka, dokud uživatel neodejde
	    clear_screen
	    echo "--- Krajská všeobecná nemocnice ---" # County General Hospital
        printf " Vaše zdraví: %d%% | Peníze: \$%d\n" "$health" "$cash" # Your Health: %d%% | Cash: $%d
        echo "-------------------------------"
	    echo " Služby:" # Services:
	    echo " 1. Základní ošetření (\$50)  - Vyléčí na 100%" # 1. Basic Treatment ($50)  - Heal to 100%
	    echo " 2. Pokročilý sken (\$100) - Vyléčí na 110% (Dočasné maximum)" # 2. Advanced Scan ($100) - Heal to 110% (Temporary Max)
	    echo " 3. Koupit balíček zdraví (\$30) - Přidá 'Balíček zdraví' do předmětů" # 3. Buy Health Pack ($30) - Add 'Health Pack' to Items
	    echo " 4. Koupit neprůstřelnou vestu (\$75)  - Vybavit brnění (Jednorázové použití)" # 4. Buy Body Armor ($75)  - Equip Armor (One time use)
        echo "-------------------------------"
	    echo " 5. Opustit nemocnici" # 5. Leave Hospital
        echo "-------------------------------"
	    read -r -p "Zadejte svou volbu: " hospital_choice # Enter your choice:

	    [[ ! "$hospital_choice" =~ ^[0-9]+$ ]] && {
		    echo "Neplatný vstup."; sleep 1; continue # Invalid input.
	    }

	    case "$hospital_choice" in
		    1) buy_hospital_item 50 "basic_treatment";;
		    2) buy_hospital_item 100 "advanced_treatment";;
		    3) buy_hospital_item 30 "health_pack";;
		    4) buy_hospital_item 75 "body_armor";;
		    5) echo "Opouštím nemocnici..."; sleep 1; return;; # Leaving the hospital...
		    *) echo "Neplatná volba."; sleep 1;; # Invalid choice.
	    esac
        # Po akci se vraťte zpět k zobrazení menu, pokud se nerozhodli odejít
    done
}

# Pomocná funkce pro nákup nemocničních předmětů
buy_hospital_item() {
	local item_cost="$1"
	local item_type="$2"

	if (( cash >= item_cost )); then
        play_sfx_mpg "cash_register"
		cash=$((cash - item_cost))
		case "$item_type" in
			"basic_treatment")
				health=100
				echo "Obdržel/a jste základní ošetření. Zdraví plně obnoveno na 100%." # Received basic treatment. Health fully restored to 100%.
				play_sfx_mpg "heal"
				;;
			"advanced_treatment")
				health=110
				echo "Pokročilý sken dokončen. Zdraví posíleno na 110%!" # Advanced scan complete. Health boosted to 110%!
                echo "(Poznámka: Další léčení/poškození se počítá od 100% základu, pokud zdraví není > 100)" # (Note: Further healing/damage calculated from 100% base unless health is > 100)
				play_sfx_mpg "heal_adv"
				;;
			"health_pack")
				items+=("Health Pack") # Keep item name potentially, or "Lékárnička"? Keep English for consistency maybe.
				echo "Koupili jste si Health Pack. (Použití předmětů ještě není implementováno)" # You bought a Health Pack. (Item usage not yet implemented)
				play_sfx_mpg "item_buy"
				;;
			"body_armor")
                if $body_armor_equipped; then
                    echo "Už máte vybavenou neprůstřelnou vestu." # You already have Body Armor equipped.
                    cash=$((cash + item_cost)) # Vrácení peněz
                    play_sfx_mpg "error"
                else
				    body_armor_equipped=true
				    echo "Neprůstřelná vesta zakoupena a vybavena." # Body Armor purchased and equipped.
				    play_sfx_mpg "item_equip"
                fi
				;;
            *) # Nemělo by se dosáhnout
                echo "Interní chyba: Neznámý typ nemocničního předmětu '$item_type'" # Internal Error: Unknown hospital item type '$item_type'
                cash=$((cash + item_cost)) # Vrácení peněz
                ;;
		esac
        read -r -p "Stiskněte Enter..." # Press Enter...
	else
		echo "Nedostatek peněz na $item_type (\$$item_cost potřeba)." # Not enough cash for $item_type (\$$item_cost needed).
		read -r -p "Stiskněte Enter..." # Press Enter...
	fi
}

# Funkce pro vykradení obchodu
rob_store() {
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$((15 + stealth_skill * 5))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Vykradení obchodu ---" # Rob Store
    echo "Prohlížím si večerku v $location..." # Scoping out a convenience store in $location...
    sleep 1

    # --- Animace loupeže (Volitelné volání pluginu) ---
    if command -v robbing_animation &> /dev/null; then robbing_animation; else echo "Jdu na to..."; sleep 1; fi # Making your move...
    # --- Konec animace ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "loupež obchodu") # "robbery" -> "loupež obchodu"

    echo "Počítám šance... Konečná šance na úspěch: ${final_success_chance}%" # Calculating odds... Final success chance: ${final_success_chance}%
    read -r -p "Stiskněte Enter pro pokus o loupež..." # Press Enter to attempt the robbery...

    if (( RANDOM % 100 < final_success_chance )); then
        # --- Úspěch ---
        loot=$((RANDOM % 151 + 50 + stealth_skill * 10)) # Kořist: 50-200 + bonus
        cash=$((cash + loot))
        damage=$((RANDOM % 16 + 5)) # Poškození: 5-20%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Neprůstřelná vesta absorbovala \e[1;31m${armor_reduction}%%\e[0m poškození během útěku!" # Body armor absorbed %d%% damage during the getaway!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;32mÚspěch!\e[0m Zastrašili jste prodavače a sebrali \$%d.\n" "$loot" # Success! You intimidated the clerk and grabbed $%d.
        printf "Trochu jste se potloukli (-%d%% zdraví).\n" "$damage" # Got slightly roughed up (-%d%% health).
        play_sfx_mpg "cash_register"
        # Šance na zvýšení dovednosti
        if (( RANDOM % 3 == 0 )); then
            skills[stealth]=$((stealth_skill + 1))
            printf "Vaše \e[1;32mplížení\e[0m se zvýšilo!\n" # Your stealth skill increased! (using 'plížení')
        fi
    else
        # --- Neúspěch ---
        loot=0
        fine=$((RANDOM % 101 + 50)) # Pokuta: 50-150
        cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 26 + 10)) # Poškození: 10-35%

         if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Neprůstřelná vesta vás ochránila před \e[1;31m${armor_reduction}%%\e[0m poškození během zatčení!" # Body armor protected you from %d%% damage during the arrest!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;31mNeúspěch!\e[0m Tichý alarm se spustil, policie přijela rychle.\n" # Failed! The silent alarm tripped, cops arrived quickly.
        printf "Dostali jste pokutu \$%d a utrpěli %d%% poškození.\n" "$fine" "$damage" # You were fined $%d and took %d%% damage.
        play_sfx_mpg "police_siren"
    fi

    printf "Aktuální stav -> Peníze: \$%d | Zdraví: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health # Zkontroluje stav zdraví po události
    read -r -p "Stiskněte Enter pro pokračování..." # Press Enter to continue...
}

# Funkce pro účast na loupeži
heist() {
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$((10 + stealth_skill * 6)) # Těžší než vykrádání obchodu
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Plánování loupeže ---" # Plan Heist
    echo "Plánuji velkou akci v $location..." # Planning a high-stakes job in $location...
    sleep 1

    # --- Animace loupeže (Volitelné volání pluginu) ---
    if command -v heist_animation &> /dev/null; then heist_animation; else echo "Provádím plán..."; sleep 1; fi # Executing the plan...
    # --- Konec animace ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "loupež") # "heist" -> "loupež"

    echo "Posuzuji bezpečnostní rizika... Konečná šance na úspěch: ${final_success_chance}%" # Assessing security risks... Final success chance: ${final_success_chance}%
    read -r -p "Stiskněte Enter pro provedení loupeže..." # Press Enter to execute the heist...

	if (( RANDOM % 100 < final_success_chance )); then
        # --- Úspěch ---
		loot=$((RANDOM % 501 + 250 + stealth_skill * 25)) # Kořist: 250-750 + bonus
		cash=$((cash + loot))
		damage=$((RANDOM % 31 + 15)) # Poškození: 15-45%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Neprůstřelná vesta absorbovala \e[1;31m${armor_reduction}%%\e[0m poškození během přestřelky!" # Body armor absorbed %d%% damage during the firefight!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;32m*** LOUPEŽ ÚSPĚŠNÁ! ***\e[0m\n Získali jste \$%d!\n" "$loot" # *** HEIST SUCCESSFUL! *** You scored $%d!
        printf "Unikli jste s významnými zraněními (-%d%% zdraví).\n" "$damage" # Escaped with significant injuries (-%d%% health).
        play_sfx_mpg "win_big"
        # Zvýšení dovednosti
        if (( RANDOM % 2 == 0 )); then
            skills[stealth]=$((stealth_skill + 2)) # Velké zvýšení
            printf "Vaše \e[1;32mplížení\e[0m se výrazně zvýšilo!\n" # Your stealth skill increased significantly!
        fi
	else
        # --- Neúspěch ---
        loot=0
		fine=$((RANDOM % 201 + 100)) # Pokuta: 100-300
		cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 41 + 20)) # Poškození: 20-60%

        if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Neprůstřelná vesta vám zachránila život před \e[1;31m${armor_reduction}%%\e[0m poškození!" # Body armor saved your life from %d%% damage!
			body_armor_equipped=false
		fi
        health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- LOUPEŽ SE NEZDAŘILA! ---\e[0m\n Bezpečnost byla příliš silná, akci jste přerušili.\n" # --- HEIST FAILED! --- Security was too tight, aborted the job.
		printf "Ztratili jste \$%d a utrpěli %d%% poškození.\n" "$fine" "$damage" # You lost $%d and took %d%% damage.
		play_sfx_mpg "lose_big"
	fi

    printf "Aktuální stav -> Peníze: \$%d | Zdraví: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health
	read -r -p "Stiskněte Enter pro pokračování..." # Press Enter to continue...
}

# Funkce pro války gangů
gang_war() {
	if (( ${#guns[@]} == 0 )); then
		echo "Potřebujete zbraň k zahájení války gangů! Nejdřív si nějakou kupte." # You need a weapon to start a gang war! Buy one first.
		read -r -p "Stiskněte Enter..." ; return # Press Enter...
	fi

    local strength_skill=${skills[strength]:-1}
    local base_chance=$((20 + strength_skill * 5))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Válka gangů ---" # Gang War
    echo "Vyražím na území rivalů v $location..." # Rolling up on rival territory in $location...
    sleep 1

	# --- Animace války gangů (Volitelné volání pluginu) ---
    if command -v gang_war_animation &> /dev/null; then gang_war_animation; else echo "Kulky začínají létat!"; sleep 1; fi # Bullets start flying!
    # --- Konec animace ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "válka gangů") # "gang war" -> "válka gangů"

    echo "Posuzuji sílu rivalů... Konečná šance na úspěch: ${final_success_chance}%" # Assessing rival strength... Final success chance: ${final_success_chance}%
	read -r -p "Stiskněte Enter pro zahájení boje..." # Press Enter to start the fight...

	if (( RANDOM % 100 < final_success_chance )); then
        # --- Výhra ---
		loot=$((RANDOM % 201 + 100 + strength_skill * 15)) # Kořist 100-300 + bonus
		cash=$((cash + loot))
		damage=$((RANDOM % 41 + 20)) # Poškození: 20-60%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Neprůstřelná vesta schytala \e[1;31m${armor_reduction}%%\e[0m poškození od kulek!" # Body armor took %d%% damage from bullets!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;32m*** VÁLKA GANGŮ VYHRÁNA! ***\e[0m\n Získali jste území a \$%d jako kořist.\n" "$loot" # *** GANG WAR WON! *** You claimed the turf and $%d in spoils.
        printf "Utrpěli jste těžké poškození (-%d%% zdraví).\n" "$damage" # Suffered heavy damage (-%d%% health).
		play_sfx_mpg "win"
        # Zvýšení dovednosti
        if (( RANDOM % 2 == 0 )); then
            skills[strength]=$((strength_skill + 1))
            printf "Vaše \e[1;32msíla\e[0m se zvýšila!\n" # Your strength skill increased!
        fi
	else
        # --- Prohra ---
        loot=0
		fine=$((RANDOM % 151 + 75)) # Pokuta: 75-225
		cash=$((cash - fine))
        (( cash < 0 )) && cash=0
		damage=$((RANDOM % 51 + 25)) # Poškození: 25-75%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Neprůstřelná vesta zabránila \e[1;31m${armor_reduction}%%\e[0m fatálnímu poškození!" # Body armor prevented %d%% fatal damage!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- VÁLKA GANGŮ PROHRÁNA! ---\e[0m\n Byli jste přemoženi a stěží unikli.\n" # --- GANG WAR LOST! --- You were overrun and barely escaped.
		printf "Ztratili jste \$%d a utrpěli %d%% poškození.\n" "$fine" "$damage" # You lost $%d and took %d%% damage.
		play_sfx_mpg "lose"
	fi

    printf "Aktuální stav -> Peníze: \$%d | Zdraví: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health
	read -r -p "Stiskněte Enter pro pokračování..." # Press Enter to continue...
}

# Funkce pro krádež auta
carjack() {
    local driving_skill=${skills[driving]:-1}
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$(( 20 + driving_skill * 2 + stealth_skill * 3 ))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Krádež auta ---" # Carjack
    echo "Hledám vozidlo k 'zapůjčení' v $location..." # Looking for a vehicle to 'borrow' in $location...
    sleep 1

    # --- Animace krádeže auta (Volitelné volání pluginu) ---
    if command -v carjacking_animation &> /dev/null; then carjacking_animation; else echo "Vyhlížím cíl..."; sleep 1; fi # Spotting a target...
    # --- Konec animace ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "krádež auta") # "carjacking" -> "krádež auta"

    echo "Vybírám cíl... Konečná šance na úspěch: ${final_success_chance}%" # Choosing a target... Final success chance: ${final_success_chance}%
    read -r -p "Stiskněte Enter pro akci..." # Press Enter to make your move...

    if (( RANDOM % 100 < final_success_chance )); then
        # --- Úspěch ---
        loot=$((RANDOM % 101 + 50 + driving_skill * 5)) # Hodnota auta: 50 - 150 + bonus
        cash=$((cash + loot))
        damage=$((RANDOM % 16 + 5)) # Poškození: 5-20%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Neprůstřelná vesta absorbovala \e[1;31m${armor_reduction}%%\e[0m poškození během útěku!" # Body armor absorbed %d%% damage during the getaway!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;32mÚspěch!\e[0m Ukradli jste auto a prodali ho za \$%d.\n" "$loot" # Success! You boosted the car and fenced it for $%d.
        printf "Trochu jste se odřeli (-%d%% zdraví).\n" "$damage" # Got slightly banged up (-%d%% health).
        play_sfx_mpg "car_start"
        # Šance na zvýšení dovedností
        if (( RANDOM % 4 == 0 )); then skills[driving]=$((driving_skill+1)); printf "Vaše \e[1;32mřidičská\e[0m dovednost se zvýšila!\n"; fi # Your driving skill increased!
        if (( RANDOM % 4 == 0 )); then skills[stealth]=$((stealth_skill+1)); printf "Vaše \e[1;32mplížení\e[0m se zvýšilo!\n"; fi # Your stealth skill increased!
    else
        # --- Neúspěch ---
        loot=0
        fine=$((RANDOM % 76 + 25)) # Pokuta: 25-100
        cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 26 + 10)) # Poškození: 10-35%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Neprůstřelná vesta schytala \e[1;31m${armor_reduction}%%\e[0m poškození, když se majitel bránil!" # Body armor took %d%% damage when the owner fought back!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;31mNeúspěch!\e[0m Spustil se alarm / Majitel se bránil / Policie poblíž.\n" # Failed! Alarm blared / Owner resisted / Cops nearby.
        printf "Dostali jste pokutu \$%d a utrpěli %d%% poškození.\n" "$fine" "$damage" # You were fined $%d and took %d%% damage.
        play_sfx_mpg "police_siren"
    fi

    printf "Aktuální stav -> Peníze: \$%d | Zdraví: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health
    read -r -p "Stiskněte Enter pro pokračování..." # Press Enter to continue...
}

# Funkce pro zpracování následků smrti hráče (volána check_health)
hospitalize_player() {
	local hospital_bill=200
    echo "Nemocnice vás dala dohromady." # The hospital patched you up.
    sleep 1
    echo "Bohužel, lékařská péče není zadarmo. Účet: \$${hospital_bill}." # Unfortunately, medical care isn't free. Bill: $${hospital_bill}.

    if (( cash < hospital_bill )); then
        echo "Nemohli jste si dovolit celý účet (\$${hospital_bill}). Vzali vám všechny peníze (\$$cash)." # You couldn't afford the full bill ($${hospital_bill}). They took all your cash ($$cash).
        hospital_bill=$cash
    else
        echo "Zaplatili jste účet \$${hospital_bill}." # You paid the $${hospital_bill} bill.
    fi

	cash=$((cash - hospital_bill))
    health=50 # Resetuje zdraví na 50% po "smrti"
	body_armor_equipped=false # Ztráta brnění při "smrti"
    play_sfx_mpg "cash_register" # Zvuk placení účtu

	printf "Opouštíte nemocnici s \$%d v hotovosti a %d%% zdraví.\n" "$cash" "$health" # You leave the hospital with $%d cash and %d%% health.
	# Lokace se v této verzi při smrti nemění
    # Předměty v inventáři zůstávají (lze změnit pro větší obtížnost)
	read -r -p "Stiskněte Enter pro pokračování..." # Press Enter to continue...
}

# Funkce pro najmutí prostitutky
hire_hooker() {
    local charisma_skill=${skills[charisma]:-1}
    local base_min_cost=40 base_max_cost=100
    local cost_reduction=$((charisma_skill * 3))
    local min_cost=$((base_min_cost - cost_reduction))
    local max_cost=$((base_max_cost - cost_reduction))
    (( min_cost < 15 )) && min_cost=15
    (( max_cost <= min_cost )) && max_cost=$((min_cost + 20))

	local hooker_cost=$(( RANDOM % (max_cost - min_cost + 1) + min_cost ))
	local health_gain=$(( RANDOM % 21 + 15 )) # Zisk zdraví 15-35%
    # Zvážení horní hranice zdraví (aktuálně 100 nebo 110, pokud bylo použito pokročilé ošetření)
    local max_health=100
    (( health > 100 )) && max_health=110 # Upraví hranici, pokud má hráč dočasné posílení

    clear_screen
    echo "--- Hledání společnosti ---" # Seeking Company
	echo "Hledám nějaké 'uvolnění stresu' v $location..." # Looking for some 'stress relief' in $location...
    sleep 1
    echo "Přistoupíte k někomu slibnému... Nabídne vám cenu \$$hooker_cost." # You approach someone promising... They quote you $hooker_cost.

	if (( cash >= hooker_cost )); then
        read -r -p "Přijmout nabídku? (a/n): " accept # Accept the offer? (y/n): -> a/n
        if [[ "$accept" == "a" || "$accept" == "A" ]]; then # Check for 'a' or 'A'
            play_sfx_mpg "cash_register"
	        cash=$(( cash - hooker_cost ))
	        local previous_health=$health
            health=$(( health + health_gain ))
	        (( health > max_health )) && health=$max_health # Aplikuje hranici
            local actual_gain=$((health - previous_health))

            clear_screen
            echo "--- Transakce dokončena ---" # Transaction Complete
	        printf "Zaplatili jste \$%d.\n" "$hooker_cost" # You paid $%d.
            if (( actual_gain > 0 )); then
                 printf "Cítíte se osvěžení, získali jste \e[1;32m%d%%\e[0m zdraví.\n" "$actual_gain" # Feeling refreshed, you gained %d%% health.
            else
                 echo "Už jste měli maximální zdraví." # You were already at maximum health.
            fi
            printf "Aktuální stav -> Peníze: \$%d | Zdraví: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
	        play_sfx_mpg "hooker"
            # Šance na zvýšení dovednosti
            if (( RANDOM % 5 == 0 )); then
                skills[charisma]=$((charisma_skill+1))
                printf "Vaše \e[1;32mcharisma\e[0m se zvýšila!\n" # Your charisma skill increased!
            fi
        else
            echo "Rozhodli jste se proti tomu a odešli." # You decided against it and walked away.
        fi
    else
	    echo "Zkontrolujete si peněženku... nedostatek peněz (\$$hooker_cost potřeba)." # You check your wallet... not enough cash ($hooker_cost needed).
	fi
    read -r -p "Stiskněte Enter pro pokračování..." # Press Enter to continue...
}


# Centralizovaná funkce pro transakce s drogami
drug_transaction() {
	local action="$1" base_price="$3" drug_amount="$4"
    local drug_name="$2" # Ponechá název drogy zvlášť pro jasnost
    local cost=0 income=0 final_price=0
	local drug_dealer_skill=${skills[drug_dealer]:-1}

    # Ověří, zda je částka kladné celé číslo
    if ! [[ "$drug_amount" =~ ^[1-9][0-9]*$ ]]; then
        echo "Neplatné množství '$drug_amount'. Zadejte prosím číslo větší než 0." # Invalid amount '$drug_amount'. Please enter a number greater than 0.
        return 1
    fi

    # --- Dynamické ceny ---
    local price_fluctuation=$(( RANDOM % 21 - 10 )) # +/- 10%
    local location_modifier=0
    case "$location" in # Příklad modifikátorů
        "Liberty City") location_modifier=15;; "Las Venturas") location_modifier=10;;
        "Vice City")    location_modifier=-15;; *) location_modifier=0;;
    esac
    local current_market_price=$(( base_price + (base_price * (price_fluctuation + location_modifier) / 100) ))
    (( current_market_price < 1 )) && current_market_price=1 # Min cena $1

    # --- Provedení transakce ---
	if [[ "$action" == "buy" ]]; then
        final_price=$current_market_price
		cost=$((final_price * drug_amount))

		if (( cash >= cost )); then
            if command -v drug_transaction_animation &> /dev/null; then drug_transaction_animation "buy"; fi
			cash=$((cash - cost))
            drugs["$drug_name"]=$(( ${drugs[$drug_name]:-0} + drug_amount ))
			printf "Koupeno \e[1;33m%d\e[0m jednotek \e[1;33m%s\e[0m za \e[1;31m\$%d\e[0m (\$%d/jednotku).\n" \
                   "$drug_amount" "$drug_name" "$cost" "$final_price" # Bought %d units of %s for $%d ($%d/unit).
			play_sfx_mpg "cash_register" ; return 0
		else
			printf "Nedostatek peněz. Potřebujete \$%d, máte \$%d.\n" "$cost" "$cash" ; return 1 # Not enough cash. Need $%d, you have $%d.
		fi

	elif [[ "$action" == "sell" ]]; then
        local current_inventory=${drugs[$drug_name]:-0}
		if (( current_inventory >= drug_amount )); then
            local price_bonus_percent=$((drug_dealer_skill * 2))
            final_price=$(( current_market_price + (current_market_price * price_bonus_percent / 100) ))
            (( final_price < 1 )) && final_price=1 # Zajistí, že prodejní cena neklesne pod $1 kvůli negativním modifikátorům
			income=$((final_price * drug_amount))

            if command -v drug_transaction_animation &> /dev/null; then drug_transaction_animation "sell"; fi
			cash=$((cash + income))
			drugs["$drug_name"]=$((current_inventory - drug_amount))

			printf "Prodáno \e[1;33m%d\e[0m jednotek \e[1;33m%s\e[0m za \e[1;32m\$%d\e[0m (\$%d/jednotku, dovednost +%d%%).\n" \
                   "$drug_amount" "$drug_name" "$income" "$final_price" "$price_bonus_percent" # Sold %d units of %s for $%d ($%d/unit, skill +%d%%).
			play_sfx_mpg "cash_register"
            # Šance na zvýšení dovednosti
            if (( RANDOM % 2 == 0 )); then
			    skills[drug_dealer]=$((drug_dealer_skill + 1))
			    printf "Vaše \e[1;32mobchodování s drogami\e[0m se zvýšilo!\n" # Your drug dealing skill increased! (using 'obchodování s drogami')
            fi ; return 0
		else
			printf "Nedostatek %s k prodeji. Máte %d jednotek, pokusili jste se prodat %d.\n" \
                   "$drug_name" "$current_inventory" "$drug_amount" ; return 1 # Not enough %s to sell. You have %d units, tried to sell %d.
		fi
	else # Nemělo by se stát
		echo "Interní chyba: Neplatná akce '$action' v drug_transaction." ; return 1 # Internal Error: Invalid action '$action' in drug_transaction.
	fi
}

# Funkce pro zpracování menu nákupu drog
buy_drugs() {
	local drug_choice="" drug_amount=""
    declare -A drug_prices=( ["Weed"]=10 ["Cocaine"]=50 ["Heroin"]=100 ["Meth"]=75 )
    local drug_names=("Weed" "Cocaine" "Heroin" "Meth") # Pořadí pro menu

	while true; do
	    clear_screen
        echo "--- Drogový dealer (Nákup) ---" # Drug Dealer (Buy)
        printf " Lokace: %-15s | Peníze: \$%d\n" "$location" "$cash" # Location: %-15s | Cash: $%d
        echo "---------------------------"
        echo " Dostupný inventář (Základní tržní cena):" # Available Inventory (Market Base Price):
        local i=1
        for name in "${drug_names[@]}"; do
            # Zobrazit přibližnou aktuální tržní cenu?
            local base_p=${drug_prices[$name]}
            local approx_p=$(( base_p + (base_p * ( $( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0) ) / 100) ))
            (( approx_p < 1 )) && approx_p=1
            printf " %d. %-10s (\~$%d/jednotku)\n" "$i" "$name" "$approx_p" # /unit
            ((i++))
        done
        echo "---------------------------"
        printf " %d. Odejít\n" "$i" # Leave
        echo "---------------------------"
	    read -r -p "Vyberte drogu k nákupu (číslo): " drug_choice # Choose drug to buy (number):

        if [[ "$drug_choice" == "$i" ]]; then echo "Opouštím dealera..."; sleep 1; return; fi # Leaving the dealer...
	    if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#drug_names[@]} )); then
		    echo "Neplatná volba."; sleep 1; continue # Invalid choice.
	    fi

        local chosen_drug_name="${drug_names[$((drug_choice - 1))]}"
        local chosen_drug_price="${drug_prices[$chosen_drug_name]}"

	    read -r -p "Zadejte množství $chosen_drug_name k nákupu: " drug_amount # Enter amount of $chosen_drug_name to buy:

        # drug_transaction zpracovává zprávy pro úspěch/neúspěch/validaci
        drug_transaction "buy" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"
        read -r -p "Stiskněte Enter..." # Pause after transaction attempt: Press Enter...
    done
}

# Funkce pro zpracování menu prodeje drog
sell_drugs() {
    local drug_choice="" drug_amount=""
    declare -A drug_sell_prices=( ["Weed"]=15 ["Cocaine"]=75 ["Heroin"]=150 ["Meth"]=100 ) # Základní prodejní ceny
    local drug_names=("Weed" "Cocaine" "Heroin" "Meth") # Pořadí

    while true; do
	    clear_screen
        echo "--- Drogový dealer (Prodej) ---" # Drug Dealer (Sell)
        printf " Lokace: %-15s | Peníze: \$%d\n" "$location" "$cash" # Location: %-15s | Cash: $%d
        echo "--------------------------"
        echo " Váš inventář (Přibližná prodejní hodnota/jednotku):" # Your Inventory (Approx Sell Value/unit):
        local i=1
        local available_to_sell=() # Sleduje, které položky jsou k dispozici k výběru
        for name in "${drug_names[@]}"; do
            local inventory_amount=${drugs[$name]:-0}
            if (( inventory_amount > 0 )); then
                local base_p=${drug_sell_prices[$name]}
                local skill_bonus_p=$(( (skills[drug_dealer]:-1) * 2 ))
                local approx_p=$(( base_p + (base_p * ( $( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0) + skill_bonus_p ) / 100) ))
                (( approx_p < 1 )) && approx_p=1
                printf " %d. %-10s (%d jednotek) ~\$%d/jednotku\n" "$i" "$name" "$inventory_amount" "$approx_p" # units, /unit
                available_to_sell+=("$name") # Přidá název drogy, kterou může hráč prodat
                ((i++))
            fi
        done

        if (( ${#available_to_sell[@]} == 0 )); then
            echo "--------------------------"
            echo "Nemáte žádné drogy k prodeji." # You have no drugs to sell.
            read -r -p "Stiskněte Enter pro odchod..." ; return # Press Enter to leave...
        fi
        echo "--------------------------"
        printf " %d. Odejít\n" "$i" # Leave
        echo "--------------------------"

	    read -r -p "Vyberte drogu k prodeji (číslo): " drug_choice # Choose drug to sell (number):

        if [[ "$drug_choice" == "$i" ]]; then echo "Opouštím dealera..."; sleep 1; return; fi # Leaving the dealer...
	    if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#available_to_sell[@]} )); then
		    echo "Neplatná volba."; sleep 1; continue # Invalid choice.
	    fi

        local chosen_drug_name="${available_to_sell[$((drug_choice - 1))]}"
        local chosen_drug_price="${drug_sell_prices[$chosen_drug_name]}"
        local current_inventory=${drugs[$chosen_drug_name]}

	    read -r -p "Prodat kolik jednotek $chosen_drug_name? (Max: $current_inventory): " drug_amount # Sell how many units of $chosen_drug_name? (Max: $current_inventory):

        # drug_transaction zpracovává zprávy pro úspěch/neúspěch/validaci
        drug_transaction "sell" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"
        read -r -p "Stiskněte Enter..." # Pause after transaction attempt: Press Enter...
    done
}

# Funkce pro přehrávání hudby (Robustní verze s opravou stty echo)
play_music() {
    # 1. Zkontrolujte předpoklad: příkaz mpg123
    if ! $mpg123_available; then # Použije globální příznak zkontrolovaný na začátku
        echo "Přehrávání hudby zakázáno: příkaz 'mpg123' nebyl nalezen."; read -r -p "Stiskněte Enter..."; return 1; # Music playback disabled: 'mpg123' command not found. Press Enter...
    fi

    # 2. Definujte adresář hudby a najděte soubory
    local music_dir="$BASEDIR/music"
    local music_files=()
    local original_ifs="$IFS" # Uloží IFS

    if [[ ! -d "$music_dir" ]]; then
        echo "Chyba: Adresář hudby '$music_dir' nebyl nalezen!"; read -r -p "Stiskněte Enter..."; return 1; # Error: Music directory '$music_dir' not found! Press Enter...
    fi

    # Použije find a substituci procesu pro bezpečnější zpracování souborů
    while IFS= read -r -d $'\0' file; do
        music_files+=("$file")
    done < <(find "$music_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.MP3" \) -print0 2>/dev/null) # Najde .mp3 a .MP3
    IFS="$original_ifs" # Obnoví IFS

    if (( ${#music_files[@]} == 0 )); then
        echo "V '$music_dir' nebyly nalezeny žádné .mp3 soubory."; read -r -p "Stiskněte Enter..."; return 1; # No .mp3 files found in '$music_dir'. Press Enter...
    fi

    # 3. Smyčka přehrávače hudby
    local choice_stop="s" choice_back="b" music_choice=""
    local mpg123_log="/tmp/bta_mpg123_errors.$$.log" # Unikátní log pro relaci

    while true; do
        clear_screen
        echo "--- Přehrávač hudby ---" # Music Player
        echo " Adresář hudby: $music_dir" # Music Directory:
        echo "----------------------------------------"
        local current_status="Zastaveno" current_song_name="" # Stopped
        if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
            current_song_name=$(ps -p "$music_pid" -o args= 2>/dev/null | sed 's/.*mpg123 [-q]* //; s/ *$//' || echo "Přehrávám stopu") # Playing Track
            [[ -z "$current_song_name" ]] && current_song_name="Přehrávám stopu" # Playing Track
            current_status="Přehrávám: $(basename "$current_song_name") (PID: $music_pid)" # Playing: ... (PID: ...)
        else
            [[ -n "$music_pid" ]] && music_pid="" # Vyčistí zastaralý PID
            current_status="Zastaveno" # Stopped
        fi
        echo " Stav: $current_status" # Status:
        echo "----------------------------------------"
        echo " Dostupné stopy:" # Available Tracks:
        for i in "${!music_files[@]}"; do printf " %d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"; done
        echo "----------------------------------------"
        printf " [%s] Zastavit hudbu | [%s] Zpět do hry\n" "$choice_stop" "$choice_back" # Stop Music | Back to Game
        echo "----------------------------------------"

        # Zajistí, že terminálové echo je ZAPNUTÉ před tímto promptem
        stty echo
        read -r -p "Zadejte volbu (číslo, s, b): " music_choice # Enter choice (number, s, b):

        case "$music_choice" in
            "$choice_stop" | "q")
                if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
                    echo "Zastavuji hudbu (PID: $music_pid)..." # Stopping music (PID: $music_pid)...
                    kill "$music_pid" &>/dev/null; sleep 0.2
                    if kill -0 "$music_pid" &>/dev/null; then kill -9 "$music_pid" &>/dev/null; fi
                    wait "$music_pid" 2>/dev/null; music_pid=""; echo "Hudba zastavena." # Music stopped.
                else echo "Aktuálně nehraje žádná hudba."; fi # No music is currently playing.
                # Zajistí obnovení echa po pokusu o zastavení
                stty echo
                sleep 1 # Krátká pauza
                ;; # Smyčka se zopakuje a zobrazí aktualizované menu
            "$choice_back" | "b")
                echo "Vracím se do hry..."; sleep 1; break # Returning to game... # Ukončí smyčku hudby
                ;;
            *)
                if [[ "$music_choice" =~ ^[0-9]+$ ]] && (( music_choice >= 1 && music_choice <= ${#music_files[@]} )); then
                    local selected_track="${music_files[$((music_choice - 1))]}"
                    if [[ ! -f "$selected_track" ]]; then echo "Chyba: Soubor '$selected_track' nebyl nalezen!"; sleep 2; continue; fi # Error: File '$selected_track' not found!

                    if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
                        echo "Zastavuji předchozí stopu..."; kill "$music_pid" &>/dev/null; wait "$music_pid" 2>/dev/null; music_pid=""; sleep 0.2; # Stopping previous track...
                    fi

                    echo "Pokouším se přehrát: $(basename "$selected_track")" # Attempting to play: ...

                    # --- Příkaz pro přehrávání (Bez Subshellu) ---
                    echo "--- BTA Log $(date) --- Přehrávám: $selected_track" >> "$mpg123_log" # Playing:
                    mpg123 -q "$selected_track" 2>> "$mpg123_log" &
                    # ---------------------------------

                    local new_pid=$!
                    sleep 0.5 # Dáme tomu chvilku na start nebo selhání

                    if kill -0 "$new_pid" 2>/dev/null; then
                        music_pid=$new_pid; echo "Přehrávání spuštěno (PID: $music_pid)." # Playback started (PID: $music_pid).
                        # Nepauzovat zde, nechat smyčku opakovat pro zobrazení stavu
                    else
                        echo "Chyba: Nepodařilo se spustit proces mpg123 pro $(basename "$selected_track")." # Error: Failed to start mpg123 process for ...
                        echo "       Zkontrolujte log pro chyby (pokud existují): $mpg123_log" # Check log for errors (if any):
                        if [[ -f "$mpg123_log" ]]; then
                            echo "--- Poslední řádky logu ---"; tail -n 5 "$mpg123_log"; echo "-------------------------" # Last lines of log
                        fi
                        music_pid=""; read -r -p "Stiskněte Enter..." # Pause: Press Enter...
                    fi
                else
                    echo "Neplatná volba '$music_choice'." # Invalid choice '$music_choice'.
                    sleep 1
                fi;;
        esac
    done
    # Vyčistit log soubor pro tuto relaci při opuštění přehrávače hudby? Volitelné.
    # rm -f "$mpg123_log"
}


# Uloží stav hry do souboru (Robustnější)
save_game() {
    local save_path="$BASEDIR/$SAVE_DIR" # Použije úplnou cestu pro adresář uložení
    mkdir -p "$save_path" || { echo "Chyba: Nelze vytvořit adresář pro uložení '$save_path'."; read -r -p "Stiskněte Enter..."; return 1; } # Error: Could not create save directory '$save_path'. Press Enter...

    echo "Ukládám stav hry..." # Saving game state...
    # Definujte cesty k souborům
    local player_file="$save_path/player_name.sav"
    local loc_file="$save_path/location.sav"
    local cash_file="$save_path/cash.sav"
    local health_file="$save_path/health.sav"
    local armor_file="$save_path/body_armor_equipped.sav"
    local guns_file="$save_path/guns.sav"
    local items_file="$save_path/items.sav"
    local drugs_file="$save_path/drugs.sav"
    local skills_file="$save_path/skills.sav"
    local temp_ext=".tmp$$" # Unikátní dočasná přípona

    # Funkce pro atomické uložení (zápis do dočasného souboru, poté přejmenování)
    save_atomic() {
        local content="$1" file_path="$2" temp_file="${file_path}${temp_ext}"
        printf '%s\n' "$content" > "$temp_file" && mv "$temp_file" "$file_path" || {
            echo "Chyba při ukládání souboru: $file_path"; rm -f "$temp_file"; return 1; # Error saving file: $file_path
        }
        return 0
    }

    # --- Uložení jednoduchých proměnných ---
    save_atomic "$player_name" "$player_file" || return 1
	save_atomic "$location" "$loc_file" || return 1
	save_atomic "$cash" "$cash_file" || return 1
	save_atomic "$health" "$health_file" || return 1
    save_atomic "$body_armor_equipped" "$armor_file" || return 1

    # --- Uložení indexovaných polí ---
    printf '%s\n' "${guns[@]}" > "$guns_file$temp_ext" && mv "$guns_file$temp_ext" "$guns_file" || { echo "Chyba při ukládání zbraní."; rm -f "$guns_file$temp_ext"; return 1; } # Error saving guns.
	printf '%s\n' "${items[@]}" > "$items_file$temp_ext" && mv "$items_file$temp_ext" "$items_file" || { echo "Chyba při ukládání předmětů."; rm -f "$items_file$temp_ext"; return 1; } # Error saving items.

    # --- Uložení asociativních polí ---
	# Drogy
    : > "$drugs_file$temp_ext" # Vytvoří/vymaže dočasný soubor
	for key in "${!drugs[@]}"; do printf "%s %s\n" "$key" "${drugs[$key]}" >> "$drugs_file$temp_ext"; done
    if [[ -f "$drugs_file$temp_ext" ]]; then mv "$drugs_file$temp_ext" "$drugs_file"; else echo "Chyba při zápisu dočasného souboru drog."; return 1; fi # Error writing drugs temp file.

	# Dovednosti
    : > "$skills_file$temp_ext"
	for key in "${!skills[@]}"; do printf "%s %s\n" "$key" "${skills[$key]}" >> "$skills_file$temp_ext"; done
    if [[ -f "$skills_file$temp_ext" ]]; then mv "$skills_file$temp_ext" "$skills_file"; else echo "Chyba při zápisu dočasného souboru dovedností."; return 1; fi # Error writing skills temp file.

	echo "Hra úspěšně uložena do '$save_path'." # Game saved successfully to '$save_path'.
	read -r -p "Stiskněte Enter pro pokračování..." # Press Enter to continue...
    return 0
}

# Načte stav hry ze souboru (Robustnější)
load_game() {
    local load_success=true
    local original_ifs="$IFS"
    local key="" value="" line="" save_file="" # Deklaruje/vymaže lokální proměnné
    local save_path="$BASEDIR/$SAVE_DIR"

    echo "Pokouším se načíst hru z '$save_path'..." # Attempting to load game from '$save_path'...

    if [[ ! -d "$save_path" ]]; then
        echo "Chyba: Adresář pro uložení '$save_path' nebyl nalezen."; read -r -p "Stiskněte Enter..."; return 1; # Error: Save directory '$save_path' not found. Press Enter...
    fi

    # --- Načtení jednoduchých proměnných ---
    save_file="$save_path/player_name.sav"; [[ -f "$save_file" ]] && { read -r player_name < "$save_file" || { >&2 echo "Chyba čtení $save_file"; load_success=false; }; } || { >&2 echo "Varování: $save_file chybí"; player_name="Neznámý"; load_success=false; } # Error reading $save_file | Warn: $save_file missing | Unknown
    save_file="$save_path/location.sav"; [[ -f "$save_file" ]] && { read -r location < "$save_file" || { >&2 echo "Chyba čtení $save_file"; load_success=false; }; } || { >&2 echo "Varování: $save_file chybí"; location="Los Santos"; load_success=false; }
    save_file="$save_path/cash.sav"; [[ -f "$save_file" ]] && { read -r cash < "$save_file" || { >&2 echo "Chyba čtení $save_file"; load_success=false; }; } || { >&2 echo "Varování: $save_file chybí"; cash=0; load_success=false; }
    [[ ! "$cash" =~ ^-?[0-9]+$ ]] && { >&2 echo "Varování: Neplatné peníze '$cash'"; cash=0; load_success=false; } # Warn: Invalid cash '$cash'
    save_file="$save_path/health.sav"; [[ -f "$save_file" ]] && { read -r health < "$save_file" || { >&2 echo "Chyba čtení $save_file"; load_success=false; }; } || { >&2 echo "Varování: $save_file chybí"; health=100; load_success=false; }
    [[ ! "$health" =~ ^[0-9]+$ ]] && { >&2 echo "Varování: Neplatné zdraví '$health'"; health=100; load_success=false; } # Warn: Invalid health '$health'
    (( health <= 0 && load_success )) && { >&2 echo "Varování: Načtené zdraví <= 0"; health=50; } # Warn: Loaded health <= 0
    save_file="$save_path/body_armor_equipped.sav"; [[ -f "$save_file" ]] && { read -r body_armor_equipped < "$save_file" || { >&2 echo "Chyba čtení $save_file"; load_success=false; }; } || { >&2 echo "Varování: $save_file chybí"; body_armor_equipped=false; load_success=false; }
    [[ "$body_armor_equipped" != "true" && "$body_armor_equipped" != "false" ]] && { >&2 echo "Varování: Neplatné brnění '$body_armor_equipped'"; body_armor_equipped=false; load_success=false; } # Warn: Invalid armor '$body_armor_equipped'

    # --- Načtení indexovaných polí ---
    guns=(); save_file="$save_path/guns.sav"
    if [[ -f "$save_file" ]]; then
         if command -v readarray &> /dev/null; then readarray -t guns < "$save_file";
         else IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do guns+=("$line"); done < "$save_file"; IFS="$original_ifs"; fi
    else >&2 echo "Varování: $save_file chybí"; fi # Warn: $save_file missing

    items=(); save_file="$save_path/items.sav"
    if [[ -f "$save_file" ]]; then
        if command -v readarray &> /dev/null; then readarray -t items < "$save_file";
        else IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do items+=("$line"); done < "$save_file"; IFS="$original_ifs"; fi
    else >&2 echo "Varování: $save_file chybí"; fi # Warn: $save_file missing

    # --- Načtení asociativních polí ---
    declare -A drugs_loaded=(); save_file="$save_path/drugs.sav"
    if [[ -f "$save_file" ]]; then
        while IFS=' ' read -r key value || [[ -n "$key" ]]; do
            if [[ -n "$key" && -v "default_drugs[$key]" ]]; then
                 if [[ "$value" =~ ^[0-9]+$ ]]; then drugs_loaded["$key"]="$value"; else
                     >&2 echo "Varování: Neplatné množství drogy '$key'='$value'"; drugs_loaded["$key"]=0; load_success=false; fi # Warn: Invalid drug amt '$key'='$value'
            elif [[ -n "$key" ]]; then >&2 echo "Varování: Přeskakuji neznámou drogu '$key'"; fi # Warn: Skipping unknown drug '$key'
        done < "$save_file"
    else >&2 echo "Varování: $save_file chybí"; load_success=false; fi # Warn: $save_file missing
    declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${drugs_loaded[$key]:-${default_drugs[$key]}}; done

    declare -A skills_loaded=(); save_file="$save_path/skills.sav"
    if [[ -f "$save_file" ]]; then
        while IFS=' ' read -r key value || [[ -n "$key" ]]; do
             if [[ -n "$key" && -v "default_skills[$key]" ]]; then
                 if [[ "$value" =~ ^[0-9]+$ ]]; then skills_loaded["$key"]="$value"; else
                     >&2 echo "Varování: Neplatná úroveň dovednosti '$key'='$value'"; skills_loaded["$key"]=1; load_success=false; fi # Warn: Invalid skill lvl '$key'='$value'
             elif [[ -n "$key" ]]; then >&2 echo "Varování: Přeskakuji neznámou dovednost '$key'"; fi # Warn: Skipping unknown skill '$key'
        done < "$save_file"
    else >&2 echo "Varování: $save_file chybí"; load_success=false; fi # Warn: $save_file missing
    declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${skills_loaded[$key]:-${default_skills[$key]}}; done

    # --- Konečná kontrola ---
    IFS="$original_ifs"
    if $load_success; then echo "Hra úspěšně načtena."; else # Game loaded successfully.
        echo "Varování: Hra načtena s chybějícími/neplatnými daty. Použity výchozí hodnoty."; fi # Warning: Game loaded with missing/invalid data. Defaults used.
    read -r -p "Stiskněte Enter pro spuštění hry..." # Press Enter to start playing...
    return 0
}

# --- 4. Inicializace hry a smyčka ---

# Funkce pro inicializaci NOVÝCH herních proměnných
Game_variables() {
	clear_screen
	read -r -p "Zadejte jméno hráče: " player_name # Enter your player name:
	[[ -z "$player_name" ]] && player_name="Poutník" # Wanderer
	play_sfx_mpg "new_game"
	location="Los Santos"
	cash=500
	health=100
	guns=()
	items=()
    # Resetuje asociativní pole pomocí výchozích hodnot
    declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${default_drugs[$key]}; done
    declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${default_skills[$key]}; done
    body_armor_equipped=false
	echo "Vítejte v Bash Theft Auto, $player_name!" # Welcome to Bash Theft Auto, $player_name!
    echo "Začínáte v $location s \$${cash} a ${health}% zdraví." # Starting in $location with $${cash} and ${health}% health.
    read -r -p "Stiskněte Enter pro začátek..." # Press Enter to begin...
}

# Funkce pro bezpečné odstranění uložených souborů
remove_save_files() {
    local save_path="$BASEDIR/$SAVE_DIR"
    if [[ -d "$save_path" ]]; then
        echo "Mažu předchozí uložené soubory v '$save_path'..." # Deleting previous save files in '$save_path'...
        local found_files=$(find "$save_path" -maxdepth 1 -type f -name '*.sav' -print -delete)
        if [[ -n "$found_files" ]]; then echo "Staré uložené soubory úspěšně smazány."; else echo "Nebyly nalezeny žádné '.sav' soubory k smazání."; fi # Old save files deleted successfully. | No '.sav' files found to delete.
    else
        echo "Info: Nebyl nalezen žádný předchozí adresář pro uložení v '$save_path'." # Info: No previous save directory found at '$save_path'.
    fi
    sleep 1 # Krátká pauza
}

# --- Počáteční herní menu ---
run_initial_menu() {
    while true; do
	    clear_screen
	    echo "=== Bash Theft Auto ==="
	    echo "      Hlavní menu" # Main Menu
        echo "---------------------"
	    echo "1. Nová hra" # 1. New Game
	    echo "2. Načíst hru" # 2. Load Game
	    echo "3. Ukončit hru" # 3. Exit Game
        echo "---------------------"
        stty echo # Zajistí, že echo je zapnuté pro menu
	    read -r -p "Zadejte svou volbu: " initial_choice # Enter your choice:

	    case "$initial_choice" in
		    1)
                read -r -p "Spustit novou hru? Tím se smaže jakékoli existující uložení. (a/n): " confirm # Start new game? This deletes any existing save. (y/n): -> a/n
                if [[ "$confirm" == "a" || "$confirm" == "A" ]]; then # Check for 'a' or 'A'
                    remove_save_files
                    Game_variables
                    return 0 # Signalizuje spuštění herní smyčky
                else echo "Nová hra zrušena."; sleep 1; fi ;; # New game cancelled.
		    2)
                if load_game; then return 0; # Signalizuje spuštění herní smyčky
                else sleep 1; fi ;; # Načtení hry selhalo, pauza před opětovným zobrazením menu
		    3) cleanup_and_exit ;; # Použije úklidovou funkci
		    *) echo "Neplatná volba."; sleep 1 ;; # Invalid choice.
	    esac
    done
}

# --- Hlavní spuštění ---

# Spustí počáteční menu. Pokud se vrátí úspěšně (0), pokračuje do hlavní smyčky.
if ! run_initial_menu; then
    echo "Ukončuji kvůli selhání počátečního menu nebo požadavku uživatele." # Exiting due to initial menu failure or user request.
    stty echo # Zajistí, že echo je zapnuté pro jistotu
    exit 1
fi


# --- Hlavní herní smyčka ---
while true; do
    # Zkontroluje zdraví na ZAČÁTKU; zpracovává smrt/hospitalizaci a vrátí 1, pokud hráč zemřel
    if check_health; then
        # Hráč je naživu, vymaže obrazovku a zobrazí stav/menu
        clear_screen
    else
        # Hráč byl hospitalizován, obrazovka již byla zpracována check_health/hospitalize_player
        # Stačí znovu zobrazit hlavní menu poté, co stiskne Enter
        clear_screen # Zobrazí stav po nemocnici
    fi

    # --- Zobrazení hlavního menu ---
    echo "--- Akce ---" # Actions
    echo "1. Cestovat      | 6. Koupit drogy"    # 1. Travel        | 6. Buy Drugs
    echo "2. Koupit zbraně | 7. Prodat drogy"   # 2. Buy Guns      | 7. Sell Drugs
    echo "3. Inventář      | 8. Najmout prostitutku" # 3. Inventory     | 8. Hire Hooker
    echo "4. Práce (Legální)| 9. Navštívit nemocnici" # 4. Work (Legal)  | 9. Visit Hospital
    echo "5. Práce (Zločin) | 10. Pouliční závod"  # 5. Work (Crime)  | 10. Street Race
    echo "-----------------------------------------"
    echo "S. Uložit hru    | L. Načíst hru"     # S. Save Game     | L. Load Game
    echo "M. Přehrávač hud. | A. O hře"         # M. Music Player  | A. About
    echo "X. Ukončit hru"                     # X. Exit Game
    echo "-----------------------------------------"

    # --- Obnoví terminálové echo před čtením vstupu ---
    stty echo
    # --- Přečte volbu uživatele ---
    read -r -p "Zadejte svou volbu: " choice # Enter your choice:
    # Převede volbu na malá písmena pro příkazy
    choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    # --- Zpracování volby ---
    case "$choice_lower" in
	    1) # Menu cestování
            clear_screen; echo "--- Cestovní kancelář ---" # Travel Agency
            echo "1. Los Santos (\$50) | 2. San Fierro (\$75) | 3. Las Venturas (\$100)";
            echo "4. Vice City (\$150) | 5. Liberty City (\$200) | 6. Zůstat zde"; # Stay Here
            read -r -p "Zadejte volbu: " city_choice # Enter choice:
            [[ ! "$city_choice" =~ ^[1-6]$ ]] && { echo "Neplatná volba."; sleep 1; continue; } # Invalid choice.
            case "$city_choice" in
                1) travel_to 50 "Los Santos";; 2) travel_to 75 "San Fierro";;
                3) travel_to 100 "Las Venturas";; 4) travel_to 150 "Vice City";;
                5) travel_to 200 "Liberty City";; 6) ;;
            esac;;
	    2) buy_guns;;
	    3) show_inventory;;
	    4) # Menu legální práce
            clear_screen; echo "--- Poctivá práce ---" # Honest Work
            echo "1. Taxikář | 2. Rozvoz | 3. Mechanik | 4. Ochranka | 5. Umělec | 6. Zpět"; # Taxi Driver | Delivery | Mechanic | Security | Performer | Back
            read -r -p "Zadejte volbu: " job_choice # Enter choice:
            [[ ! "$job_choice" =~ ^[1-6]$ ]] && { echo "Neplatná volba."; sleep 1; continue; } # Invalid choice.
            case "$job_choice" in
                1) work_job "taxi";; 2) work_job "delivery";; 3) work_job "mechanic";;
                4) work_job "security";; 5) work_job "performer";; 6) ;;
            esac;;
	    5) # Menu kriminální činnosti
            clear_screen; echo "--- Kriminální aktivity ---" # Criminal Activities
            echo "1. Vykrást obchod | 2. Ukrást auto | 3. Válka gangů | 4. Loupež | 5. Zpět"; # Rob Store | Carjack | Gang War | Heist | Back
            read -r -p "Zadejte volbu: " criminal_choice # Enter choice:
            [[ ! "$criminal_choice" =~ ^[1-5]$ ]] && { echo "Neplatná volba."; sleep 1; continue; } # Invalid choice.
            case "$criminal_choice" in
                1) rob_store;; 2) carjack;; 3) gang_war;; 4) heist;; 5) ;;
            esac;;
	    6) buy_drugs;;
	    7) sell_drugs;;
	    8) hire_hooker;;
	    9) visit_hospital;;
        10) street_race;;
	    's') save_game;;
	    'l')
             read -r -p "Načíst hru? Neuložený postup bude ztracen. (a/n): " confirm # Load game? Unsaved progress will be lost. (y/n): -> a/n
             if [[ "$confirm" == "a" || "$confirm" == "A" ]]; then # Check for 'a' or 'A'
                 load_game # load_game zpracovává zprávy a pokračuje smyčkou
             else echo "Načtení zrušeno."; sleep 1; fi ;; # Load cancelled.
	    'm') play_music;;
	    'a') about_music_sfx;;
        'x')
             read -r -p "Opravdu chcete skončit? (a/n): " confirm # Are you sure you want to exit? (y/n): -> a/n
             if [[ "$confirm" == "a" || "$confirm" == "A" ]]; then # Check for 'a' or 'A'
                 # Volitelné: Automatické uložení před ukončením?
                 # read -r -p "Uložit před ukončením? (a/n): " save_confirm
                 # if [[ "$save_confirm" == "a" || "$save_confirm" == "A" ]]; then save_game; fi
                 cleanup_and_exit # Použije úklidovou funkci
             fi ;;
	    *) echo "Neplatná volba '$choice'."; sleep 1;; # Invalid choice '$choice'.
	esac
    # Smyčka pokračuje
done

# Nemělo by se dosáhnout, ale pokusí se o úklid, pokud se to někdy stane
cleanup_and_exit
