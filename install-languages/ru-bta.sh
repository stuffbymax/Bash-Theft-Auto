# Bash-Theft-Auto music and sfx © 2024 by stuffbymax - Martin Petik is licensed under CC BY 4.0
# https://creativecommons.org/licenses/by/4.0/
# ver 2.0.5 (Terminal echo fixes)
#!/bin/bash

# --- Initial Setup ---
# Set BASEDIR to the directory where the script resides
# Using parameter expansion for potentially better compatibility than realpath
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Exit on error to prevent unexpected behavior
# set -e # Uncomment this for stricter error checking if desired, but might exit too easily

# --- Cleanup Function and Trap ---
cleanup_and_exit() {
    echo -e "\nОчистка и выход..."
    # Stop music if playing
    if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
        echo "Остановка музыки (PID: $music_pid)..."
        kill "$music_pid" &>/dev/null
        wait "$music_pid" 2>/dev/null
        music_pid=""
    fi
    # Restore terminal echo
    stty echo
    echo "Очистка завершена. До свидания."
    exit 0
}
# Trap common exit signals to run the cleanup function
trap cleanup_and_exit SIGINT SIGTERM SIGHUP

# --- 0. Global Variables ---
player_name=""
location="Los Santos" # Default starting location
cash=0
health=100 # Default starting health
declare -a guns=() # Internal names: Pistol, Shotgun, SMG, Rifle, Sniper
declare -a items=() # Internal names: Health Pack
declare -A drugs=() # Internal keys: Weed, Cocaine, Heroin, Meth
declare -A skills=() # Internal keys: driving, strength, charisma, stealth, drug_dealer
body_armor_equipped=false
SAVE_DIR="saves" # Relative to BASEDIR
declare -A gun_attributes=() # Internal keys: Pistol, Shotgun, SMG, Rifle, Sniper
music_pid="" # PID for the background music player

# Initialize Gun Attributes (ensure array is populated)
gun_attributes=(
	["Pistol"]="success_bonus=5"
	["Shotgun"]="success_bonus=10"
	["SMG"]="success_bonus=15"
	["Rifle"]="success_bonus=20"
	["Sniper"]="success_bonus=25"
)

# Initialize Default Skills/Drugs (used in load_game and new_game)
declare -A default_skills=( ["driving"]=1 ["strength"]=1 ["charisma"]=1 ["stealth"]=1 ["drug_dealer"]=1 )
declare -A default_drugs=( ["Weed"]=0 ["Cocaine"]=0 ["Heroin"]=0 ["Meth"]=0 )


# --- Dependency Check ---
mpg123_available=true
if ! command -v mpg123 &> /dev/null; then
    echo "###########################################################"
    echo "# Внимание: команда 'mpg123' не найдена.                      #" # Warning: 'mpg123' command not found.
    echo "# Звуковые эффекты и музыка требуют mpg123.                  #" # Sound effects and music require mpg123.
    echo "# Пожалуйста, установите его для полного погружения.             #" # Please install it for the full experience.
    echo "#---------------------------------------------------------#"
    echo "# На Debian/Ubuntu: sudo apt update && sudo apt install mpg123 #"
    echo "# На Fedora:        sudo dnf install mpg123               #"
    echo "# На Arch Linux:    sudo pacman -S mpg123                 #"
    echo "# На macOS (Homebrew): brew install mpg123                #"
    echo "###########################################################"
    read -r -p "Нажмите Enter для продолжения без звука..." # Press Enter to continue without sound...
    mpg123_available=false
fi

# --- Sound Effects Setup ---
sfx_dir="sfx"  # Directory for sound effects relative to BASEDIR

# Function to play sound effects (handles missing mpg123)
play_sfx_mpg() {
    if ! $mpg123_available; then
        return 1 # Sound disabled
    fi
    local sound_name="$1"
    local sound_file="$BASEDIR/$sfx_dir/${sound_name}.mp3"
    if [[ -f "$sound_file" ]]; then
        if command -v mpg123 &> /dev/null; then
           # Run in background, detached, discard stdout/stderr unless debugging
           mpg123 -q "$sound_file" &>/dev/null &
            return 0  # Indicate success
        fi
    else
        # Silently ignore missing SFX files or log them if debugging
        # >&2 echo "Debug: Sound file not found: '$sound_file'"
        return 1
    fi
    return 1 # Indicate failure (e.g., mpg123 check failed inside)
}

# --- 1. Plugin Loading ---
plugin_dir="plugins" # Relative to BASEDIR

if [[ -d "$BASEDIR/$plugin_dir" ]]; then
	# Use find within the BASEDIR context
	while IFS= read -r -d $'\0' plugin_script; do
		# Source the plugin using its full path
		if [[ -f "$plugin_script" ]]; then
            # >&2 echo "Loading plugin: $plugin_script" # Debug message
            source "$plugin_script"
        fi
	done < <(find "$BASEDIR/$plugin_dir" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)
else
	# Not necessarily an error, just information
	echo "Инфо: Каталог плагинов '$BASEDIR/$plugin_dir' не найден. Пропуск загрузки плагинов." # Info: Plugin directory '$BASEDIR/$plugin_dir' not found. Skipping plugin load.
fi

# --- 3. Functions ---

# Clear the screen and display game information header
clear_screen() {
    clear
    printf "\e[93m=========================================\e[0m\n"
    printf "\e[1;43m|        Bash Theft Auto                |\e[0m\n"
    printf "\e[93m=========================================\e[0m\n"
    printf " Игрок: %-15s | Локация: %s\n" "$player_name" "$location" # Player: %-15s | Location: %s
    printf " Деньги: \$%-16d | Здоровье: %d%%\n" "$cash" "$health" # Cash: \$%-16d | Health: %d%%
    # Display Body Armor Status
    if $body_armor_equipped; then
        printf " Броня: \e[1;32mНадета\e[0m\n" # Armor: Equipped
    else
        printf " Броня: \e[1;31mНет\e[0m\n" # Armor: None
    fi
    printf "\e[1;34m=========================================\e[0m\n"
}

# --- About ---
about_music_sfx() {
	clear_screen
	echo "-----------------------------------------"
	echo "|    О Музыке и Звуковых Эффектах      |" # About the Music and Sound Effects
	echo "-----------------------------------------"
	echo ""
	echo "Музыка и SFX © 2024 от stuffbymax - Martin Petik" # Music and SFX © 2024 by stuffbymax - Martin Petik
	echo "Лицензировано под CC BY 4.0:" # Licensed under CC BY 4.0:
	echo "https://creativecommons.org/licenses/by/4.0/"
	echo ""
	echo "Вы можете свободно делиться и адаптировать этот материал" # You are free to share and adapt this material
	echo "для любых целей, даже коммерческих, при условии," # for any purpose, even commercially, under the
	echo "что вы укажете соответствующее авторство." # condition that you give appropriate credit.
	echo ""
	echo "Пример указания авторства:" # Attribution example:
	echo "'Music/SFX © 2024 stuffbymax - Martin Petik, CC BY 4.0'" # Keep as is.
	echo ""
	echo "Больше информации: https://stuffbymax.me/" # More info: https://stuffbymax.me/
	echo ""
	echo "-----------------------------------------"
	echo "|          Лицензия Кода               |" # Code License
	echo "-----------------------------------------"
	echo ""
	echo "Код Игры © 2024 stuffbymax" # Game Code © 2024 stuffbymax
	echo "Лицензировано под Лицензией MIT." # Licensed under the MIT License.
	echo "Позволяет повторное использование с указанием авторства." # Allows reuse with attribution.
	echo ""
	echo "Полная Лицензия:" # Full License:
	echo "https://github.com/stuffbymax/Bash-Theft-Auto/blob/main/LICENSE" # Ensure this link is correct
	echo ""
	echo "Спасибо за игру!" # Thank you for playing!
    echo "-----------------------------------------"
	read -r -p "Нажмите Enter для возврата..." # Press Enter to return...
}

# Function to check if the player is alive and handle death
check_health() {
	if (( health <= 0 )); then
        health=0 # Prevent negative health display
		clear_screen
		echo -e "\n      \e[1;31m W A S T E D \e[0m\n" # Keep English WASTED for iconic value
		play_sfx_mpg "wasted"
		echo "Вы потеряли сознание от ран..." # You collapsed from your injuries...
		sleep 1
		echo "Вы очнулись позже..." # You wake up later...
		read -r -p "Нажмите Enter, чтобы отправиться в больницу..." # Press Enter to go to the hospital...
		hospitalize_player # Handles the consequences of death
        return 1 # Indicate player was hospitalized (died)
	fi
    return 0 # Indicate player is okay
}

# Function for traveling to a new location
travel_to() {
	local travel_cost="$1"
	local new_location="$2"
    local current_location="$location" # Store current location for message

    # Prevent traveling to the same location
    if [[ "$new_location" == "$current_location" ]]; then
        echo "Вы уже в $new_location." # You are already in $new_location.
        read -r -p "Нажмите Enter..." # Press Enter...
        return
    fi

	if (( cash >= travel_cost )); then
		printf "Перемещаемся из %s в %s (\$%d)...\n" "$current_location" "$new_location" "$travel_cost" # Traveling from %s to %s (\$%d)...
		play_sfx_mpg "air"

		# --- Air Travel Animation (Optional Plugin Call) ---
        if command -v air_travel_animation &> /dev/null; then
		    air_travel_animation "$current_location" "$new_location" # Pass locations maybe?
        else
            # Simple text-based animation if plugin missing
            echo -n "["
            for _ in {1..20}; do echo -n "="; sleep 0.05; done
            echo ">]"
        fi
		# --- End Animation ---

		cash=$((cash - travel_cost))
		location="$new_location"
		echo "Вы благополучно прибыли в $new_location." # You have arrived safely in $new_location.
        read -r -p "Нажмите Enter..." # Press Enter...
	else
		echo "Недостаточно денег (\$$travel_cost необходимо) для поездки в $new_location." # Not enough cash (\$$travel_cost needed) to travel to $new_location.
		read -r -p "Нажмите Enter..." # Press Enter...
	fi
}

# Function for buying guns menu
buy_guns() {
	local gun_choice=""
	clear_screen
	echo "--- Ammu-Nation ---" # Keep English name
	echo "Добро пожаловать! Чем могу помочь?" # Welcome! What can I get for you?
	echo "-------------------"
	echo "1. Пистолет    (\$100)" # 1. Pistol      ($100)
	echo "2. Дробовик    (\$250)" # 2. Shotgun     ($250)
	echo "3. ПП           (\$500)" # 3. SMG         ($500) -> ПП (Пистолет-пулемет)
	echo "4. Винтовка    (\$750)" # 4. Rifle       ($750)
	echo "5. Снайперка   (\$1000)" # 5. Sniper      ($1000)
	echo "-------------------"
	echo "6. Уйти" # 6. Leave
    echo "-------------------"
    printf "Ваши деньги: \$%d\n" "$cash" # Your Cash: $%d
	read -r -p "Введите ваш выбор: " gun_choice # Enter your choice:

	[[ ! "$gun_choice" =~ ^[0-9]+$ ]] && {
		echo "Неверный ввод."; read -r -p "Нажмите Enter..."; return # Invalid input. Press Enter...
	}

	case "$gun_choice" in
		1) buy_gun "Pistol" 100;; # Pass internal English name
		2) buy_gun "Shotgun" 250;;
		3) buy_gun "SMG" 500;;
		4) buy_gun "Rifle" 750;;
		5) buy_gun "Sniper" 1000;;
		6) echo "Заходите еще!"; sleep 1; return;; # Come back anytime!
		*) echo "Неверный выбор."; read -r -p "Нажмите Enter...";; # Invalid choice. Press Enter...
	esac
}

# Helper function for buying GUNS specifically
buy_gun() {
	local gun_name_internal="$1" # Expecting internal English name
	local gun_cost="$2"
    local owned=false
    local gun_name_display="" # Translated name for display

    # Map internal name to display name
    case "$gun_name_internal" in
        "Pistol") gun_name_display="Пистолет";;
        "Shotgun") gun_name_display="Дробовик";;
        "SMG") gun_name_display="ПП";;
        "Rifle") gun_name_display="Винтовка";;
        "Sniper") gun_name_display="Снайперка";;
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
        echo "Похоже, у вас уже есть $gun_name_display, партнер." # Looks like you already got a $gun_name_display there, partner.
        read -r -p "Нажмите Enter..." # Press Enter...
        return
    fi

    # Check cash
	if (( cash >= gun_cost )); then
        play_sfx_mpg "cash_register"
		# --- Buy Animation (Optional Plugin Call) ---
        if command -v buy_animation &> /dev/null; then
            buy_animation "$gun_name_internal" # Use internal name if plugin expects it
        fi
        # --- End Animation ---

		cash=$((cash - gun_cost))
		guns+=("$gun_name_internal") # Add internal (English) name to guns array
		echo "Один $gun_name_display, уже несу! Это будет \$ $gun_cost." # One $gun_name_display, coming right up! That'll be \$$gun_cost.
		read -r -p "Нажмите Enter..." # Press Enter...
	else
		echo "Извини, приятель, не хватает денег на $gun_name_display (нужно \$ $gun_cost)." # Sorry pal, not enough cash for the $gun_name_display (\$$gun_cost needed).
		read -r -p "Нажмите Enter..." # Press Enter...
	fi
}

# Function to show inventory
show_inventory() {
	clear_screen
	echo "--- Инвентарь и Статистика ---" # Inventory & Stats
	printf " Деньги: \$%d\n" "$cash" # Cash: $%d
	printf " Здоровье: %d%%\n" "$health" # Health: %d%%
    if $body_armor_equipped; then
        printf " Броня: \e[1;32mНадета\e[0m\n" # Armor: Equipped
    else
        printf " Броня: \e[1;31mНет\e[0m\n" # Armor: None
    fi
	echo "--------------------------"
    echo " Оружие:" # Guns:
    if (( ${#guns[@]} > 0 )); then
        # Display translated names
        local translated_gun_name=""
        for gun in "${guns[@]}"; do # Iterate internal names
             case "$gun" in
                "Pistol") translated_gun_name="Пистолет";;
                "Shotgun") translated_gun_name="Дробовик";;
                "SMG") translated_gun_name="ПП";;
                "Rifle") translated_gun_name="Винтовка";;
                "Sniper") translated_gun_name="Снайперка";;
                *) translated_gun_name="$gun" ;; # Fallback
            esac
            printf "  - %s\n" "$translated_gun_name"
        done
    else
        echo "  (Нет)" # (None)
    fi
    echo "--------------------------"
    echo " Предметы:" # Items:
     if (( ${#items[@]} > 0 )); then
        # Implement item usage here later?
        local translated_item_name=""
        for item in "${items[@]}"; do # Iterate internal names
             case "$item" in
                "Health Pack") translated_item_name="Аптечка";;
                # Add other item translations here if needed
                *) translated_item_name="$item" ;;
            esac
            printf "  - %s\n" "$translated_item_name"
        done
    else
        echo "  (Нет)" # (None)
    fi
	echo "--------------------------"
	echo " Наркотики:" # Drugs:
	local drug_found=false
    for drug in "${!default_drugs[@]}"; do # Iterate default keys (internal names)
        local amount=${drugs[$drug]:-0}
        if (( amount > 0 )); then
            # Keep internal drug name for display for simplicity unless specified otherwise
            printf "  - %-10s: %d шт.\n" "$drug" "$amount" # шт. for units
            drug_found=true
        fi
    done
    if ! $drug_found; then echo "  (Нет)"; fi # (None)
    echo "--------------------------"
	echo " Навыки:" # Skills:
    local translated_skill_name=""
    for skill in "${!default_skills[@]}"; do # Iterate default keys (internal names)
         case "$skill" in
            "driving") translated_skill_name="Вождение";;
            "strength") translated_skill_name="Сила";;
            "charisma") translated_skill_name="Харизма";;
            "stealth") translated_skill_name="Скрытность";;
            "drug_dealer") translated_skill_name="Торговля наркотиками";;
            *) translated_skill_name="$skill" ;; # Fallback
        esac
        printf "  - %-22s: %d\n" "$translated_skill_name" "${skills[$skill]:-0}" # Adjusted width for Russian
    done
	echo "--------------------------"
	read -r -p "Нажмите Enter для возврата..." # Press Enter to return...
}

# Function for working (Legal Jobs)
work_job() {
	local job_type_display="$1" # Expecting Russian job type from menu
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

    # Determine skill influence based on job type (map from Russian to internal)
	case "$job_type_display" in
		"Таксист"|"Доставка")
            job_type_internal=$([[ "$job_type_display" == "Таксист" ]] && echo "taxi" || echo "delivery")
            relevant_skill_name="driving"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * (job_type_internal == "delivery" ? 4 : 3) )) # Delivery uses skill slightly more
            [[ "$job_type_internal" == "delivery" ]] && base_earnings=$((base_earnings + 10))
			play_sfx_mpg "taxi" # Keep SFX name consistent
			;;
		"Механик")
            job_type_internal="mechanic"
            relevant_skill_name="strength" # Maybe strength for lifting? Or add specific skill later
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 1))
            base_earnings=$((base_earnings + 20))
			play_sfx_mpg "mechanic"
			;;
		"Охранник")
            job_type_internal="security"
            relevant_skill_name="strength"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 2))
            base_earnings=$((base_earnings + 30))
			play_sfx_mpg "security"
			;;
		"Уличный артист")
            job_type_internal="performer"
            relevant_skill_name="charisma"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 5))
            base_earnings=$((base_earnings - 10)) # Less reliable base
            base_earnings=$(( base_earnings < 5 ? 5 : base_earnings )) # Min base 5
			play_sfx_mpg "street_performer"
			;;
		*) echo "Внутренняя ошибка: Неверный тип работы '$job_type_display'"; return;; # Internal Error: Invalid Job Type '$job_type_display'
	esac

    earnings=$((base_earnings + skill_bonus))
    (( earnings < 0 )) && earnings=0 # Ensure earnings aren't negative

    # --- Working Animation (Optional Plugin Call) ---
    if command -v working_animation &> /dev/null; then
	    working_animation "$job_type_internal" # Use internal name if plugin expects it
    else
        echo "Работаем как $job_type_display..." # Working as a $job_type_display...
        sleep 2
    fi
    # --- End Animation ---

	# --- Outcome ---
	cash=$((cash + earnings))
	clear_screen
	printf "Закончили смену как %s в %s.\n" "$job_type_display" "$location" # Finished your shift as a %s in %s.
    printf "Вы заработали \$%d (База: \$%d, Бонус навыка: \$%d).\n" "$earnings" "$base_earnings" "$skill_bonus" # You earned $%d (Base: $%d, Skill Bonus: $%d).
    printf "Теперь у вас \$%d.\n" "$cash" # You now have $%d.

    # Potential skill increase
    if [[ -n "$relevant_skill_name" ]]; then # Only if a skill was relevant
        local skill_increase_chance=20 # 20% base chance
        if (( RANDOM % 100 < skill_increase_chance )); then
            skills[$relevant_skill_name]=$((relevant_skill_level + 1))
            local translated_skill_name=""
             case "$relevant_skill_name" in # Translate skill name for display
                "driving") translated_skill_name="Вождение";;
                "strength") translated_skill_name="Сила";;
                "charisma") translated_skill_name="Харизма";;
                *) translated_skill_name="$relevant_skill_name" ;;
            esac
            printf "Ваш навык \e[1;32m%s\e[0m увеличился!\n" "$translated_skill_name" # Your %s skill increased!
        fi
    fi

	read -r -p "Нажмите Enter для продолжения..." # Press Enter to continue...
}

# Function for street racing
street_race() {
    local driving_skill=${skills[driving]:-1}
	local base_win_chance=40
	local win_chance=$(( base_win_chance + driving_skill * 5 ))
    (( win_chance > 90 )) && win_chance=90 # Cap win chance at 90%
    (( win_chance < 10 )) && win_chance=10 # Min win chance 10%

    clear_screen
    echo "--- Уличная Гонка ---" # Street Race
    echo "Присоединяемся к нелегальной уличной гонке в $location..." # Joining an illegal street race in $location...
    echo "Навык Вождения: $driving_skill | Шанс Победы: ${win_chance}%" # Driving Skill: $driving_skill | Win Chance: ${win_chance}%
    sleep 1

    # --- Street Race Animation (Optional Plugin Call) ---
    if command -v race_animation &> /dev/null; then
        race_animation
    elif command -v working_animation &> /dev/null; then
        working_animation "street_race" # Fallback to generic animation
    else
        echo "Приготовьтесь..." ; sleep 1; echo "3... 2... 1... СТАРТ!"; sleep 1 # Get ready... ; 3... 2... 1... GO!
    fi
    # --- End Animation ---

    read -r -p "Нажмите Enter для результатов гонки..." # Press Enter for the race results...

	local winnings=0 damage=0

	if (( RANDOM % 100 < win_chance )); then
        # --- Win ---
		winnings=$((RANDOM % 151 + 100 + driving_skill * 10)) # Win 100-250 + bonus
		cash=$((cash + winnings))
		damage=$((RANDOM % 15 + 5)) # Low damage on win: 5-19%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2))
            damage=$((damage - armor_reduction))
			echo "Ваша броня поглотила \e[1;31m${armor_reduction}%%\e[0m урона!" # Your body armor absorbed %d%% damage!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
		printf "\e[1;32m*** ВЫ ВЫИГРАЛИ ГОНКУ! ***\e[0m\n" # *** YOU WON THE RACE! ***
        printf "Вы получили \$%d призовых денег.\n" "$winnings" # You collected $%d in prize money.
        printf "Получен небольшой урон (-%d%% здоровья).\n" "$damage" # Took minor damage (-%d%% health).
        play_sfx_mpg "win"
		# Skill increase chance on win
		if (( RANDOM % 3 == 0 )); then # 33% chance
            skills[driving]=$((driving_skill + 1))
            printf "Ваш навык \e[1;32mвождения\e[0m увеличился!\n" # Your driving skill increased!
        fi
	else
        # --- Lose ---
        winnings=0 # No winnings on loss
		damage=$((RANDOM % 31 + 15)) # Higher damage on loss: 15-45%
		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2))
            damage=$((damage - armor_reduction))
			echo "Ваша броня поглотила \e[1;31m${armor_reduction}%%\e[0m урона в аварии!" # Your body armor absorbed %d%% damage in the crash!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- ВЫ ПРОИГРАЛИ ГОНКУ! ---\e[0m\n" # --- YOU LOST THE RACE! ---
		printf "Вы разбились и получили %d%% урона.\n" "$damage" # You crashed and took %d%% damage.
		play_sfx_mpg "lose" # Or a crash sound? "car_crash"?
	fi

    # Display final stats for the action
    printf "Текущий статус -> Деньги: \$%d | Здоровье: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%

    # Check health AFTER showing results
    check_health # This will handle hospitalization if health <= 0
    read -r -p "Нажмите Enter для продолжения..." # Press Enter to continue...
}

# (Function use_guns remains unchanged - kept for potential future use)
use_guns() {
    # This function expects internal English names, translate output only
	if [[ " ${guns[*]} " == *" $1 "* ]]; then
        local translated_gun_name=""
         case "$1" in
            "Pistol") translated_gun_name="Пистолет";; "Shotgun") translated_gun_name="Дробовик";;
            "SMG") translated_gun_name="ПП";; "Rifle") translated_gun_name="Винтовка";;
            "Sniper") translated_gun_name="Снайперка";; *) translated_gun_name="$1" ;;
        esac
		echo "Вы использовали $translated_gun_name для этого дела." # You used your $1 for this job.
		play_sfx_mpg "gun_shot"
		read -r -p "Нажмите Enter..." # Press Enter...
	else
        local translated_gun_name=""
         case "$1" in
            "Pistol") translated_gun_name="Пистолет";; "Shotgun") translated_gun_name="Дробовик";;
            "SMG") translated_gun_name="ПП";; "Rifle") translated_gun_name="Винтовка";;
            "Sniper") translated_gun_name="Снайперка";; *) translated_gun_name="$1" ;;
        esac
		echo "У вас нет $translated_gun_name. Задание провалено." # You don't have a $1. Job failed.
		read -r -p "Нажмите Enter..." # Press Enter...
	fi
}

# Helper function to handle gun selection and apply bonus for criminal actions
apply_gun_bonus() {
    local base_chance=$1
    local action_message="$2" # Expecting Russian action description
    local current_chance=$base_chance
    local gun_bonus=0
    local chosen_gun_display="" # Russian name entered by user
    local chosen_gun_internal="" # Internal English name for logic/attributes
    local gun_found=false
    local success_bonus=0 # Local variable to capture bonus from eval

    if (( ${#guns[@]} == 0 )); then
        echo "У вас нет оружия! Это будет значительно сложнее." # You have no guns! This will be significantly harder.
        gun_bonus=-15 # Significant penalty for being unarmed
    else
        # Display available guns with translated names
        echo -n "Доступное оружие: " # Available guns:
        local first_gun=true
        for gun_internal in "${guns[@]}"; do
            local translated_gun_name=""
            case "$gun_internal" in
                "Pistol") translated_gun_name="Пистолет";; "Shotgun") translated_gun_name="Дробовик";;
                "SMG") translated_gun_name="ПП";; "Rifle") translated_gun_name="Винтовка";;
                "Sniper") translated_gun_name="Снайперка";; *) translated_gun_name="$gun_internal" ;;
            esac
            if ! $first_gun; then echo -n ", "; fi
            echo -n "$translated_gun_name"
            first_gun=false
        done
        echo "" # Newline

        read -r -p "Использовать оружие для '$action_message'? (д/н): " use_gun # Use a gun for this $action_message? (y/n): -> д/н for да/нет

        if [[ "$use_gun" == "д" || "$use_gun" == "Д" || "$use_gun" == "y" || "$use_gun" == "Y" ]]; then # Check for Russian 'д' or 'y'/'Y'
            read -r -p "Какое оружие? (Введите точное название): " chosen_gun_display # Which gun? (Enter exact name):

            # Map Russian name back to internal English name
            case "$chosen_gun_display" in
                "Пистолет") chosen_gun_internal="Pistol";; "Дробовик") chosen_gun_internal="Shotgun";;
                "ПП") chosen_gun_internal="SMG";; "Винтовка") chosen_gun_internal="Rifle";;
                "Снайперка") chosen_gun_internal="Sniper";;
                *) chosen_gun_internal="" ;; # Not a recognized Russian name
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
                echo "Вы достаете свой $chosen_gun_display!" # You draw your $chosen_gun_display!
                play_sfx_mpg "gun_cock"

                # Apply Gun Bonus if defined (using internal name)
                if [[ -v "gun_attributes[$chosen_gun_internal]" ]]; then
                    eval "${gun_attributes[$chosen_gun_internal]}" # Sets 'success_bonus' locally
                    gun_bonus=${success_bonus:-0}
                    if (( gun_bonus > 0 )); then
                        echo "$chosen_gun_display дает \e[1;32m+${gun_bonus}%%\e[0m шанс на успех." # The $chosen_gun_display gives a +%d%% success chance.
                        play_sfx_mpg "gun_shot"
                    else
                        echo "$chosen_gun_display не дает здесь особых преимуществ." # The $chosen_gun_display provides no specific advantage here.
                    fi
                else
                    echo "Внимание: Для '$chosen_gun_display' не определены бонусные атрибуты." # Warning: No bonus attributes defined for '$chosen_gun_display'.
                    gun_bonus=0
                fi
            else
                echo "У вас нет '$chosen_gun_display'! Продолжаем без бонуса за оружие." # You don't own '$chosen_gun_display'! Proceeding without a gun bonus.
                gun_bonus=0
            fi
        else
            echo "Продолжаем без использования оружия." # Proceeding without using a gun.
            gun_bonus=-5 # Small penalty for choosing not to use an available gun? Optional.
        fi
    fi

    current_chance=$((current_chance + gun_bonus))

    # Clamp the success chance (e.g., 5% to 95%)
    (( current_chance < 5 )) && current_chance=5
    (( current_chance > 95 )) && current_chance=95

    echo "$current_chance" # Return the final calculated chance
}


# Function for visiting the hospital (Menu)
visit_hospital() {
	local hospital_choice=""
	while true; do # Loop until user leaves
	    clear_screen
	    echo "--- Окружная Больница ---" # County General Hospital
        printf " Ваше Здоровье: %d%% | Деньги: \$%d\n" "$health" "$cash" # Your Health: %d%% | Cash: $%d
        echo "-------------------------------"
	    echo " Услуги:" # Services:
	    echo " 1. Базовое Лечение (\$50)    - Исцелить до 100%" # 1. Basic Treatment ($50)  - Heal to 100%
	    echo " 2. Улучшенное Лечение (\$100) - Исцелить до 110% (Временный Максимум)" # 2. Advanced Scan ($100) - Heal to 110% (Temporary Max)
	    echo " 3. Купить Аптечку (\$30)     - Добавить 'Аптечка' в Предметы" # 3. Buy Health Pack ($30) - Add 'Health Pack' to Items -> 'Аптечка'
	    echo " 4. Купить Бронежилет (\$75)  - Надеть Броню (Одноразовое)" # 4. Buy Body Armor ($75)  - Equip Armor (One time use) -> 'Бронежилет'
        echo "-------------------------------"
	    echo " 5. Покинуть Больницу" # 5. Leave Hospital
        echo "-------------------------------"
	    read -r -p "Введите ваш выбор: " hospital_choice # Enter your choice:

	    [[ ! "$hospital_choice" =~ ^[0-9]+$ ]] && {
		    echo "Неверный ввод."; sleep 1; continue # Invalid input.
	    }

	    case "$hospital_choice" in
		    1) buy_hospital_item 50 "basic_treatment";; # Use internal key
		    2) buy_hospital_item 100 "advanced_treatment";; # Use internal key
		    3) buy_hospital_item 30 "health_pack";; # Use internal key
		    4) buy_hospital_item 75 "body_armor";; # Use internal key
		    5) echo "Покидаем больницу..."; sleep 1; return;; # Leaving the hospital...
		    *) echo "Неверный выбор."; sleep 1;; # Invalid choice.
	    esac
        # After an action, loop back to show the menu again unless they chose to leave
    done
}

# Helper function for buying hospital items
buy_hospital_item() {
	local item_cost="$1"
	local item_type="$2" # Internal English type
    local item_display_name="" # Russian display name

    # Map internal type to display name
    case "$item_type" in
        "basic_treatment") item_display_name="базовое лечение";;
        "advanced_treatment") item_display_name="улучшенное лечение";;
        "health_pack") item_display_name="Аптечку";;
        "body_armor") item_display_name="Бронежилет";;
        *) item_display_name=$item_type;;
    esac

	if (( cash >= item_cost )); then
        play_sfx_mpg "cash_register"
		cash=$((cash - item_cost))
		case "$item_type" in
			"basic_treatment")
				health=100
				echo "Получено базовое лечение. Здоровье полностью восстановлено до 100%." # Received basic treatment. Health fully restored to 100%.
				play_sfx_mpg "heal"
				;;
			"advanced_treatment")
				health=110
				echo "Улучшенное лечение завершено. Здоровье увеличено до 110%!" # Advanced scan complete. Health boosted to 110%!
                echo "(Примечание: Дальнейшее исцеление/урон рассчитывается от 100% базы, если здоровье не > 100)" # (Note: Further healing/damage calculated from 100% base unless health is > 100)
				play_sfx_mpg "heal_adv"
				;;
			"health_pack")
				items+=("Health Pack") # Add internal name to items array
				echo "Вы купили $item_display_name. (Использование предметов еще не реализовано)" # You bought a Health Pack. (Item usage not yet implemented)
				play_sfx_mpg "item_buy"
				;;
			"body_armor")
                if $body_armor_equipped; then
                    echo "У вас уже надет Бронежилет." # You already have Body Armor equipped.
                    cash=$((cash + item_cost)) # Refund
                    play_sfx_mpg "error"
                else
				    body_armor_equipped=true
				    echo "Бронежилет куплен и надет." # Body Armor purchased and equipped.
				    play_sfx_mpg "item_equip"
                fi
				;;
            *) # Should not be reached
                echo "Внутренняя ошибка: Неизвестный тип предмета больницы '$item_type'" # Internal Error: Unknown hospital item type '$item_type'
                cash=$((cash + item_cost)) # Refund
                ;;
		esac
        read -r -p "Нажмите Enter..." # Press Enter...
	else
		echo "Недостаточно денег для '$item_display_name' (нужно \$ $item_cost)." # Not enough cash for $item_display_name (\$$item_cost needed).
		read -r -p "Нажмите Enter..." # Press Enter...
	fi
}

# Function for robbing a store
rob_store() {
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$((15 + stealth_skill * 5))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Ограбление Магазина ---" # Rob Store
    echo "Осматриваем магазинчик в $location..." # Scoping out a convenience store in $location...
    sleep 1

    # --- Robbery Animation (Optional Plugin Call) ---
    if command -v robbing_animation &> /dev/null; then robbing_animation; else echo "Действуем..."; sleep 1; fi # Making your move...
    # --- End Animation ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "ограбление магазина") # Pass Russian description

    echo "Рассчитываем шансы... Итоговый шанс успеха: ${final_success_chance}%" # Calculating odds... Final success chance: ${final_success_chance}%
    read -r -p "Нажмите Enter, чтобы попытаться ограбить..." # Press Enter to attempt the robbery...

    if (( RANDOM % 100 < final_success_chance )); then
        # --- Success ---
        loot=$((RANDOM % 151 + 50 + stealth_skill * 10)) # Loot: 50-200 + bonus
        cash=$((cash + loot))
        damage=$((RANDOM % 16 + 5)) # Damage: 5-20%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Броня поглотила \e[1;31m${armor_reduction}%%\e[0m урона во время побега!" # Body armor absorbed %d%% damage during the getaway!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;32mУспех!\e[0m Вы напугали продавца и забрали \$%d.\n" "$loot" # Success! You intimidated the clerk and grabbed $%d.
        printf "Немного помяли (-%d%% здоровья).\n" "$damage" # Got slightly roughed up (-%d%% health).
        play_sfx_mpg "cash_register"
        # Skill increase chance
        if (( RANDOM % 3 == 0 )); then
            skills[stealth]=$((stealth_skill + 1))
            printf "Ваш навык \e[1;32mскрытности\e[0m увеличился!\n" # Your stealth skill increased!
        fi
    else
        # --- Failure ---
        loot=0
        fine=$((RANDOM % 101 + 50)) # Fine: 50-150
        cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 26 + 10)) # Damage: 10-35%

         if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Броня защитила вас от \e[1;31m${armor_reduction}%%\e[0m урона во время ареста!" # Body armor protected you from %d%% damage during the arrest!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;31mПровал!\e[0m Сработала тихая тревога, копы приехали быстро.\n" # Failed! The silent alarm tripped, cops arrived quickly.
        printf "Вас оштрафовали на \$%d и вы получили %d%% урона.\n" "$fine" "$damage" # You were fined $%d and took %d%% damage.
        play_sfx_mpg "police_siren"
    fi

    printf "Текущий статус -> Деньги: \$%d | Здоровье: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health # Check health status after the event
    read -r -p "Нажмите Enter для продолжения..." # Press Enter to continue...
}

# Function for participating in a heist
heist() {
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$((10 + stealth_skill * 6)) # Harder than robbery
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Планирование Ограбления ---" # Plan Heist
    echo "Планируем крупное дело в $location..." # Planning a high-stakes job in $location...
    sleep 1

    # --- Heist Animation (Optional Plugin Call) ---
    if command -v heist_animation &> /dev/null; then heist_animation; else echo "Выполняем план..."; sleep 1; fi # Executing the plan...
    # --- End Animation ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "ограбление") # Pass Russian description

    echo "Оцениваем риски безопасности... Итоговый шанс успеха: ${final_success_chance}%" # Assessing security risks... Final success chance: ${final_success_chance}%
    read -r -p "Нажмите Enter, чтобы начать ограбление..." # Press Enter to execute the heist...

	if (( RANDOM % 100 < final_success_chance )); then
        # --- Success ---
		loot=$((RANDOM % 501 + 250 + stealth_skill * 25)) # Loot: 250-750 + bonus
		cash=$((cash + loot))
		damage=$((RANDOM % 31 + 15)) # Damage: 15-45%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Броня поглотила \e[1;31m${armor_reduction}%%\e[0m урона во время перестрелки!" # Body armor absorbed %d%% damage during the firefight!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;32m*** ОГРАБЛЕНИЕ УСПЕШНО! ***\e[0m\n Вы заработали \$%d!\n" "$loot" # *** HEIST SUCCESSFUL! *** You scored $%d!
        printf "Сбежали со значительными ранениями (-%d%% здоровья).\n" "$damage" # Escaped with significant injuries (-%d%% health).
        play_sfx_mpg "win_big"
        # Skill increase
        if (( RANDOM % 2 == 0 )); then
            skills[stealth]=$((stealth_skill + 2)) # Major increase
            printf "Ваш навык \e[1;32mскрытности\e[0m значительно увеличился!\n" # Your stealth skill increased significantly!
        fi
	else
        # --- Failure ---
        loot=0
		fine=$((RANDOM % 201 + 100)) # Fine: 100-300
		cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 41 + 20)) # Damage: 20-60%

        if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Броня спасла вам жизнь от \e[1;31m${armor_reduction}%%\e[0m урона!" # Body armor saved your life from %d%% damage!
			body_armor_equipped=false
		fi
        health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- ОГРАБЛЕНИЕ ПРОВАЛЕНО! ---\e[0m\n Охрана была слишком сильной, дело сорвалось.\n" # --- HEIST FAILED! --- Security was too tight, aborted the job.
		printf "Вы потеряли \$%d и получили %d%% урона.\n" "$fine" "$damage" # You lost $%d and took %d%% damage.
		play_sfx_mpg "lose_big"
	fi

    printf "Текущий статус -> Деньги: \$%d | Здоровье: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health
	read -r -p "Нажмите Enter для продолжения..." # Press Enter to continue...
}

# Function for gang wars
gang_war() {
	if (( ${#guns[@]} == 0 )); then
		echo "Вам нужно оружие, чтобы начать войну банд! Купите сначала." # You need a weapon to start a gang war! Buy one first.
		read -r -p "Нажмите Enter..." ; return # Press Enter...
	fi

    local strength_skill=${skills[strength]:-1}
    local base_chance=$((20 + strength_skill * 5))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Война Банд ---" # Gang War
    echo "Надвигаемся на территорию врага в $location..." # Rolling up on rival territory in $location...
    sleep 1

	# --- Gang War Animation (Optional Plugin Call) ---
    if command -v gang_war_animation &> /dev/null; then gang_war_animation; else echo "Пули засвистели!"; sleep 1; fi # Bullets start flying!
    # --- End Animation ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "война банд") # Pass Russian description

    echo "Оцениваем силу врага... Итоговый шанс успеха: ${final_success_chance}%" # Assessing rival strength... Final success chance: ${final_success_chance}%
	read -r -p "Нажмите Enter, чтобы начать бой..." # Press Enter to start the fight...

	if (( RANDOM % 100 < final_success_chance )); then
        # --- Win ---
		loot=$((RANDOM % 201 + 100 + strength_skill * 15)) # Loot 100-300 + bonus
		cash=$((cash + loot))
		damage=$((RANDOM % 41 + 20)) # Damage: 20-60%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Броня приняла \e[1;31m${armor_reduction}%%\e[0m урона от пуль!" # Body armor took %d%% damage from bullets!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;32m*** ВОЙНА БАНД ВЫИГРАНА! ***\e[0m\n Вы захватили территорию и \$%d трофеев.\n" "$loot" # *** GANG WAR WON! *** You claimed the turf and $%d in spoils.
        printf "Получен тяжелый урон (-%d%% здоровья).\n" "$damage" # Suffered heavy damage (-%d%% health).
		play_sfx_mpg "win"
        # Skill increase
        if (( RANDOM % 2 == 0 )); then
            skills[strength]=$((strength_skill + 1))
            printf "Ваш навык \e[1;32mсилы\e[0m увеличился!\n" # Your strength skill increased!
        fi
	else
        # --- Lose ---
        loot=0
		fine=$((RANDOM % 151 + 75)) # Fine: 75-225
		cash=$((cash - fine))
        (( cash < 0 )) && cash=0
		damage=$((RANDOM % 51 + 25)) # Damage: 25-75%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Броня предотвратила \e[1;31m${armor_reduction}%%\e[0m фатального урона!" # Body armor prevented %d%% fatal damage!
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- ВОЙНА БАНД ПРОИГРАНА! ---\e[0m\n Вас разбили, и вы едва унесли ноги.\n" "$loot" # --- GANG WAR LOST! --- You were overrun and barely escaped. (Corrected loot variable usage - it should be fine)
		printf "Вы потеряли \$%d и получили %d%% урона.\n" "$fine" "$damage" # You lost $%d and took %d%% damage.
		play_sfx_mpg "lose"
	fi

    printf "Текущий статус -> Деньги: \$%d | Здоровье: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health
	read -r -p "Нажмите Enter для продолжения..." # Press Enter to continue...
}

# Function for carjacking
carjack() {
    local driving_skill=${skills[driving]:-1}
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$(( 20 + driving_skill * 2 + stealth_skill * 3 ))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Угон Автомобиля ---" # Carjack
    echo "Ищем машину, чтобы 'одолжить' в $location..." # Looking for a vehicle to 'borrow' in $location...
    sleep 1

    # --- Carjacking Animation (Optional Plugin Call) ---
    if command -v carjacking_animation &> /dev/null; then carjacking_animation; else echo "Замечена цель..."; sleep 1; fi # Spotting a target...
    # --- End Animation ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "угон автомобиля") # Pass Russian description

    echo "Выбираем цель... Итоговый шанс успеха: ${final_success_chance}%" # Choosing a target... Final success chance: ${final_success_chance}%
    read -r -p "Нажмите Enter, чтобы действовать..." # Press Enter to make your move...

    if (( RANDOM % 100 < final_success_chance )); then
        # --- Success ---
        loot=$((RANDOM % 101 + 50 + driving_skill * 5)) # Car value: 50 - 150 + bonus
        cash=$((cash + loot))
        damage=$((RANDOM % 16 + 5)) # Damage: 5-20%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Броня поглотила \e[1;31m${armor_reduction}%%\e[0m урона во время побега!" # Body armor absorbed %d%% damage during the getaway!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;32mУспех!\e[0m Вы угнали машину и продали ее за \$%d.\n" "$loot" # Success! You boosted the car and fenced it for $%d.
        printf "Немного помялись (-%d%% здоровья).\n" "$damage" # Got slightly banged up (-%d%% health).
        play_sfx_mpg "car_start"
        # Skill increase chances
        if (( RANDOM % 4 == 0 )); then skills[driving]=$((driving_skill+1)); printf "Ваш навык \e[1;32mвождения\e[0m увеличился!\n"; fi # Your driving skill increased!
        if (( RANDOM % 4 == 0 )); then skills[stealth]=$((stealth_skill+1)); printf "Ваш навык \e[1;32mскрытности\e[0m увеличился!\n"; fi # Your stealth skill increased!
    else
        # --- Failure ---
        loot=0
        fine=$((RANDOM % 76 + 25)) # Fine: 25-100
        cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 26 + 10)) # Damage: 10-35%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Броня приняла \e[1;31m${armor_reduction}%%\e[0m урона, когда владелец дал отпор!" # Body armor took %d%% damage when the owner fought back!
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;31mПровал!\e[0m Сработала сигнализация / Владелец сопротивлялся / Копы рядом.\n" # Failed! Alarm blared / Owner resisted / Cops nearby.
        printf "Вас оштрафовали на \$%d и вы получили %d%% урона.\n" "$fine" "$damage" # You were fined $%d and took %d%% damage.
        play_sfx_mpg "police_siren"
    fi

    printf "Текущий статус -> Деньги: \$%d | Здоровье: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
    check_health
    read -r -p "Нажмите Enter для продолжения..." # Press Enter to continue...
}

# Function to handle consequences of player death (called by check_health)
hospitalize_player() {
	local hospital_bill=200
    echo "Больница вас подлатала." # The hospital patched you up.
    sleep 1
    echo "К сожалению, медицина не бесплатна. Счет: \$${hospital_bill}." # Unfortunately, medical care isn't free. Bill: $${hospital_bill}.

    if (( cash < hospital_bill )); then
        echo "Вы не смогли оплатить полный счет (\$${hospital_bill}). Они забрали все ваши деньги (\$$cash)." # You couldn't afford the full bill ($${hospital_bill}). They took all your cash ($$cash).
        hospital_bill=$cash
    else
        echo "Вы оплатили счет в \$${hospital_bill}." # You paid the $${hospital_bill} bill.
    fi

	cash=$((cash - hospital_bill))
    health=50 # Reset health to 50% after "death"
	body_armor_equipped=false # Lose armor on "death"
    play_sfx_mpg "cash_register" # Sound for paying bill

	printf "Вы выходите из больницы с \$%d наличными и %d%% здоровья.\n" "$cash" "$health" # You leave the hospital with $%d cash and %d%% health.
	# Location doesn't change on death in this version
    # Inventory items are kept (could change this for more difficulty)
	read -r -p "Нажмите Enter для продолжения..." # Press Enter to continue...
}

# Function to hire a hooker (Sensitive content)
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
    echo "--- В Поисках Компании ---" # Seeking Company
	echo "Ищем 'снятие стресса' в $location..." # Looking for some 'stress relief' in $location...
    sleep 1
    echo "Вы подходите к кому-то многообещающему... Цена \$ $hooker_cost." # You approach someone promising... They quote you $hooker_cost.

	if (( cash >= hooker_cost )); then
        read -r -p "Принять предложение? (д/н): " accept # Accept the offer? (y/n): -> д/н
        if [[ "$accept" == "д" || "$accept" == "Д" || "$accept" == "y" || "$accept" == "Y" ]]; then # Check for Russian 'д' or 'y'/'Y'
            play_sfx_mpg "cash_register"
	        cash=$(( cash - hooker_cost ))
	        local previous_health=$health
            health=$(( health + health_gain ))
	        (( health > max_health )) && health=$max_health # Apply cap
            local actual_gain=$((health - previous_health))

            clear_screen
            echo "--- Сделка Завершена ---" # Transaction Complete
	        printf "Вы заплатили \$%d.\n" "$hooker_cost" # You paid $%d.
            if (( actual_gain > 0 )); then
                 printf "Чувствуете себя освеженным, вы получили \e[1;32m%d%%\e[0m здоровья.\n" "$actual_gain" # Feeling refreshed, you gained %d%% health.
            else
                 echo "У вас уже было максимальное здоровье." # You were already at maximum health.
            fi
            printf "Текущий статус -> Деньги: \$%d | Здоровье: %d%%\n" "$cash" "$health" # Current Status -> Cash: $%d | Health: %d%%
	        play_sfx_mpg "hooker" # Sensitive SFX name
            # Skill increase chance
            if (( RANDOM % 5 == 0 )); then
                skills[charisma]=$((charisma_skill+1))
                printf "Ваш навык \e[1;32mхаризмы\e[0m увеличился!\n" # Your charisma skill increased!
            fi
        else
            echo "Вы передумали и ушли." # You decided against it and walked away.
        fi
    else
	    echo "Вы проверяете кошелек... недостаточно денег (нужно \$ $hooker_cost)." # You check your wallet... not enough cash ($hooker_cost needed).
	fi
    read -r -p "Нажмите Enter для продолжения..." # Press Enter to continue...
}


# Centralized Drug Transaction Function
drug_transaction() {
	local action="$1" base_price="$3" drug_amount="$4"
    local drug_name="$2" # Keep internal (English) drug name separate for clarity
    local cost=0 income=0 final_price=0
	local drug_dealer_skill=${skills[drug_dealer]:-1}

    # Validate amount is a positive integer
    if ! [[ "$drug_amount" =~ ^[1-9][0-9]*$ ]]; then
        echo "Неверное количество '$drug_amount'. Введите число больше 0." # Invalid amount '$drug_amount'. Please enter a number greater than 0.
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
			printf "Куплено \e[1;33m%d\e[0m шт. \e[1;33m%s\e[0m за \e[1;31m\$%d\e[0m (\$%d/шт.).\n" \
                   "$drug_amount" "$drug_name" "$cost" "$final_price" # Bought %d units of %s for $%d ($%d/unit). (Kept internal drug name)
			play_sfx_mpg "cash_register" ; return 0
		else
			printf "Недостаточно денег. Нужно \$%d, у вас \$%d.\n" "$cost" "$cash" ; return 1 # Not enough cash. Need $%d, you have $%d.
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

			printf "Продано \e[1;33m%d\e[0m шт. \e[1;33m%s\e[0m за \e[1;32m\$%d\e[0m (\$%d/шт., навык +%d%%).\n" \
                   "$drug_amount" "$drug_name" "$income" "$final_price" "$price_bonus_percent" # Sold %d units of %s for $%d ($%d/unit, skill +%d%%). (Kept internal drug name)
			play_sfx_mpg "cash_register"
            # Skill increase chance
            if (( RANDOM % 2 == 0 )); then
			    skills[drug_dealer]=$((drug_dealer_skill + 1))
			    printf "Ваш навык \e[1;32mторговли наркотиками\e[0m увеличился!\n" # Your drug dealing skill increased!
            fi ; return 0
		else
			printf "Недостаточно %s для продажи. У вас %d шт., пытались продать %d.\n" \
                   "$drug_name" "$current_inventory" "$drug_amount" ; return 1 # Not enough %s to sell. You have %d units, tried to sell %d. (Kept internal drug name)
		fi
	else # Should not happen
		echo "Внутренняя ошибка: Неверное действие '$action' в drug_transaction." ; return 1 # Internal Error: Invalid action '$action' in drug_transaction.
	fi
}

# Function to handle buying drugs menu
buy_drugs() {
	local drug_choice="" drug_amount=""
    declare -A drug_prices=( ["Weed"]=10 ["Cocaine"]=50 ["Heroin"]=100 ["Meth"]=75 ) # Internal names/prices
    local drug_names=("Weed" "Cocaine" "Heroin" "Meth") # Order for menu (internal names)

	while true; do
	    clear_screen
        echo "--- Наркодилер (Покупка) ---" # Drug Dealer (Buy)
        printf " Локация: %-15s | Деньги: \$%d\n" "$location" "$cash" # Location: %-15s | Cash: $%d
        echo "---------------------------"
        echo " Доступный Товар (Базовая Рыночная Цена):" # Available Inventory (Market Base Price):
        local i=1
        for name in "${drug_names[@]}"; do # Iterate internal names
            # Show approximate current market price?
            local base_p=${drug_prices[$name]}
            local approx_p=$(( base_p + (base_p * ( $( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0) ) / 100) ))
            (( approx_p < 1 )) && approx_p=1
            # Display internal name
            printf " %d. %-10s (\~$%d/шт.)\n" "$i" "$name" "$approx_p" # /unit -> /шт.
            ((i++))
        done
        echo "---------------------------"
        printf " %d. Уйти\n" "$i" # Leave
        echo "---------------------------"
	    read -r -p "Выберите наркотик для покупки (номер): " drug_choice # Choose drug to buy (number):

        if [[ "$drug_choice" == "$i" ]]; then echo "Уходим от дилера..."; sleep 1; return; fi # Leaving the dealer...
	    if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#drug_names[@]} )); then
		    echo "Неверный выбор."; sleep 1; continue # Invalid choice.
	    fi

        local chosen_drug_name="${drug_names[$((drug_choice - 1))]}" # Internal name
        local chosen_drug_price="${drug_prices[$chosen_drug_name]}"

	    read -r -p "Введите количество $chosen_drug_name для покупки: " drug_amount # Enter amount of $chosen_drug_name to buy: (Using internal name)

        # drug_transaction handles messages for success/failure/validation
        drug_transaction "buy" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"
        read -r -p "Нажмите Enter..." # Pause after transaction attempt: Press Enter...
    done
}

# Function to handle selling drugs menu
sell_drugs() {
    local drug_choice="" drug_amount=""
    declare -A drug_sell_prices=( ["Weed"]=15 ["Cocaine"]=75 ["Heroin"]=150 ["Meth"]=100 ) # Base sell prices (internal names)
    local drug_names=("Weed" "Cocaine" "Heroin" "Meth") # Order (internal names)

    while true; do
	    clear_screen
        echo "--- Наркодилер (Продажа) ---" # Drug Dealer (Sell)
        printf " Локация: %-15s | Деньги: \$%d\n" "$location" "$cash" # Location: %-15s | Cash: $%d
        echo "--------------------------"
        echo " Ваш Инвентарь (Примерная Цена Продажи/шт.):" # Your Inventory (Approx Sell Value/unit):
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
                printf " %d. %-10s (%d шт.) ~\$%d/шт.\n" "$i" "$name" "$inventory_amount" "$approx_p" # units -> шт., /unit -> /шт.
                available_to_sell+=("$name") # Add internal drug name player can sell
                ((i++))
            fi
        done

        if (( ${#available_to_sell[@]} == 0 )); then
            echo "--------------------------"
            echo "У вас нет наркотиков для продажи." # You have no drugs to sell.
            read -r -p "Нажмите Enter, чтобы уйти..." ; return # Press Enter to leave...
        fi
        echo "--------------------------"
        printf " %d. Уйти\n" "$i" # Leave
        echo "--------------------------"

	    read -r -p "Выберите наркотик для продажи (номер): " drug_choice # Choose drug to sell (number):

        if [[ "$drug_choice" == "$i" ]]; then echo "Уходим от дилера..."; sleep 1; return; fi # Leaving the dealer...
	    if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#available_to_sell[@]} )); then
		    echo "Неверный выбор."; sleep 1; continue # Invalid choice.
	    fi

        local chosen_drug_name="${available_to_sell[$((drug_choice - 1))]}" # Internal name
        local chosen_drug_price="${drug_sell_prices[$chosen_drug_name]}"
        local current_inventory=${drugs[$chosen_drug_name]}

	    read -r -p "Продать сколько шт. $chosen_drug_name? (Макс: $current_inventory): " drug_amount # Sell how many units of $chosen_drug_name? (Max: $current_inventory): (Using internal name, шт. for units)

        # drug_transaction handles messages for success/failure/validation
        drug_transaction "sell" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"
        read -r -p "Нажмите Enter..." # Pause after transaction attempt: Press Enter...
    done
}

# Function to play music (Robust Version with stty echo fix)
play_music() {
    # 1. Check Prerequisite: mpg123 command
    if ! $mpg123_available; then # Use the global flag checked at start
        echo "Воспроизведение музыки отключено: команда 'mpg123' не найдена."; read -r -p "Нажмите Enter..."; return 1; # Music playback disabled: 'mpg123' command not found. Press Enter...
    fi

    # 2. Define Music Directory and Find Files
    local music_dir="$BASEDIR/music"
    local music_files=()
    local original_ifs="$IFS" # Save IFS

    if [[ ! -d "$music_dir" ]]; then
        echo "Ошибка: Каталог музыки '$music_dir' не найден!"; read -r -p "Нажмите Enter..."; return 1; # Error: Music directory '$music_dir' not found! Press Enter...
    fi

    # Use find and process substitution for safer file handling
    while IFS= read -r -d $'\0' file; do
        music_files+=("$file")
    done < <(find "$music_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.MP3" \) -print0 2>/dev/null) # Find .mp3 and .MP3
    IFS="$original_ifs" # Restore IFS

    if (( ${#music_files[@]} == 0 )); then
        echo "Файлы .mp3 не найдены в '$music_dir'."; read -r -p "Нажмите Enter..."; return 1; # No .mp3 files found in '$music_dir'. Press Enter...
    fi

    # 3. Music Player Loop
    local choice_stop="с" choice_back="н" music_choice="" # с = стоп, н = назад
    local mpg123_log="/tmp/bta_mpg123_errors.$$.log" # Unique log per session

    while true; do
        clear_screen
        echo "--- Музыкальный Плеер ---" # Music Player
        echo " Каталог Музыки: $music_dir" # Music Directory:
        echo "----------------------------------------"
        local current_status="Остановлено" current_song_name="" # Stopped
        if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
            current_song_name=$(ps -p "$music_pid" -o args= 2>/dev/null | sed 's/.*mpg123 [-q]* //; s/ *$//' || echo "Играет трек") # Playing Track
            [[ -z "$current_song_name" ]] && current_song_name="Играет трек" # Playing Track
            current_status="Играет: $(basename "$current_song_name") (PID: $music_pid)" # Playing: ... (PID: ...)
        else
            [[ -n "$music_pid" ]] && music_pid="" # Clear stale PID
            current_status="Остановлено" # Stopped
        fi
        echo " Статус: $current_status" # Status:
        echo "----------------------------------------"
        echo " Доступные Треки:" # Available Tracks:
        for i in "${!music_files[@]}"; do printf " %d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"; done
        echo "----------------------------------------"
        printf " [%s] Остановить | [%s] Назад в Игру\n" "$choice_stop" "$choice_back" # Stop Music | Back to Game
        echo "----------------------------------------"

        # Ensure terminal echo is ON before this prompt
        stty echo
        read -r -p "Введите выбор (номер, с, н): " music_choice # Enter choice (number, s, b): -> с, н

        case "$music_choice" in
            "$choice_stop" | "q" | "с") # Check for Russian 'с' too
                if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
                    echo "Остановка музыки (PID: $music_pid)..." # Stopping music (PID: $music_pid)...
                    kill "$music_pid" &>/dev/null; sleep 0.2
                    if kill -0 "$music_pid" &>/dev/null; then kill -9 "$music_pid" &>/dev/null; fi
                    wait "$music_pid" 2>/dev/null; music_pid=""; echo "Музыка остановлена." # Music stopped.
                else echo "Сейчас музыка не играет."; fi # No music is currently playing.
                # Ensure echo restored after stopping attempt
                stty echo
                sleep 1 # Pause briefly
                ;; # Loop will repeat and show updated menu
            "$choice_back" | "b" | "н") # Check for Russian 'н' too
                echo "Возвращаемся в игру..."; sleep 1; break # Returning to game... # Exit the music loop
                ;;
            *)
                if [[ "$music_choice" =~ ^[0-9]+$ ]] && (( music_choice >= 1 && music_choice <= ${#music_files[@]} )); then
                    local selected_track="${music_files[$((music_choice - 1))]}"
                    if [[ ! -f "$selected_track" ]]; then echo "Ошибка: Файл '$selected_track' не найден!"; sleep 2; continue; fi # Error: File '$selected_track' not found!

                    if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
                        echo "Остановка предыдущего трека..."; kill "$music_pid" &>/dev/null; wait "$music_pid" 2>/dev/null; music_pid=""; sleep 0.2; # Stopping previous track...
                    fi

                    echo "Попытка воспроизвести: $(basename "$selected_track")" # Attempting to play: ...

                    # --- Play Command (No Subshell) ---
                    echo "--- BTA Log $(date) --- Играет: $selected_track" >> "$mpg123_log" # Playing:
                    mpg123 -q "$selected_track" 2>> "$mpg123_log" &
                    # ---------------------------------

                    local new_pid=$!
                    sleep 0.5 # Give it a moment to start or fail

                    if kill -0 "$new_pid" 2>/dev/null; then
                        music_pid=$new_pid; echo "Воспроизведение начато (PID: $music_pid)." # Playback started (PID: $music_pid).
                        # Don't pause here, let loop repeat to show status
                    else
                        echo "Ошибка: Не удалось запустить процесс mpg123 для $(basename "$selected_track")." # Error: Failed to start mpg123 process for ...
                        echo "       Проверьте лог на наличие ошибок (если есть): $mpg123_log" # Check log for errors (if any):
                        if [[ -f "$mpg123_log" ]]; then
                            echo "--- Последние строки лога ---"; tail -n 5 "$mpg123_log"; echo "-------------------------" # Last lines of log
                        fi
                        music_pid=""; read -r -p "Нажмите Enter..." # Pause: Press Enter...
                    fi
                else
                    echo "Неверный выбор '$music_choice'." # Invalid choice '$music_choice'.
                    sleep 1
                fi;;
        esac
    done
    # Clean up log file for this session when exiting music player? Optional.
    # rm -f "$mpg123_log"
}


# Save the game state to a file (More robust)
save_game() {
    local save_path="$BASEDIR/$SAVE_DIR" # Use full path for save dir
    mkdir -p "$save_path" || { echo "Ошибка: Не удалось создать каталог сохранения '$save_path'."; read -r -p "Нажмите Enter..."; return 1; } # Error: Could not create save directory '$save_path'. Press Enter...

    echo "Сохранение состояния игры..." # Saving game state...
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
            echo "Ошибка сохранения файла: $file_path"; rm -f "$temp_file"; return 1; # Error saving file: $file_path
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
    printf '%s\n' "${guns[@]}" > "$guns_file$temp_ext" && mv "$guns_file$temp_ext" "$guns_file" || { echo "Ошибка сохранения оружия."; rm -f "$guns_file$temp_ext"; return 1; } # Error saving guns.
	printf '%s\n' "${items[@]}" > "$items_file$temp_ext" && mv "$items_file$temp_ext" "$items_file" || { echo "Ошибка сохранения предметов."; rm -f "$items_file$temp_ext"; return 1; } # Error saving items.

    # --- Save Associative Arrays (internal keys) ---
	# Drugs
    : > "$drugs_file$temp_ext" # Create/clear temp file
	for key in "${!drugs[@]}"; do printf "%s %s\n" "$key" "${drugs[$key]}" >> "$drugs_file$temp_ext"; done
    if [[ -f "$drugs_file$temp_ext" ]]; then mv "$drugs_file$temp_ext" "$drugs_file"; else echo "Ошибка записи временного файла наркотиков."; return 1; fi # Error writing drugs temp file.

	# Skills
    : > "$skills_file$temp_ext"
	for key in "${!skills[@]}"; do printf "%s %s\n" "$key" "${skills[$key]}" >> "$skills_file$temp_ext"; done
    if [[ -f "$skills_file$temp_ext" ]]; then mv "$skills_file$temp_ext" "$skills_file"; else echo "Ошибка записи временного файла навыков."; return 1; fi # Error writing skills temp file.

	echo "Игра успешно сохранена в '$save_path'." # Game saved successfully to '$save_path'.
	read -r -p "Нажмите Enter для продолжения..." # Press Enter to continue...
    return 0
}

# Load the game state from a file (More robust)
load_game() {
    local load_success=true
    local original_ifs="$IFS"
    local key="" value="" line="" save_file="" # Declare/clear local variables
    local save_path="$BASEDIR/$SAVE_DIR"

    echo "Попытка загрузить игру из '$save_path'..." # Attempting to load game from '$save_path'...

    if [[ ! -d "$save_path" ]]; then
        echo "Ошибка: Каталог сохранения '$save_path' не найден."; read -r -p "Нажмите Enter..."; return 1; # Error: Save directory '$save_path' not found. Press Enter...
    fi

    # --- Load Simple Variables ---
    save_file="$save_path/player_name.sav"; [[ -f "$save_file" ]] && { read -r player_name < "$save_file" || { >&2 echo "Ошибка чтения $save_file"; load_success=false; }; } || { >&2 echo "Внимание: $save_file отсутствует"; player_name="Неизвестный"; load_success=false; } # Error reading $save_file | Warn: $save_file missing | Unknown
    save_file="$save_path/location.sav"; [[ -f "$save_file" ]] && { read -r location < "$save_file" || { >&2 echo "Ошибка чтения $save_file"; load_success=false; }; } || { >&2 echo "Внимание: $save_file отсутствует"; location="Los Santos"; load_success=false; }
    save_file="$save_path/cash.sav"; [[ -f "$save_file" ]] && { read -r cash < "$save_file" || { >&2 echo "Ошибка чтения $save_file"; load_success=false; }; } || { >&2 echo "Внимание: $save_file отсутствует"; cash=0; load_success=false; }
    [[ ! "$cash" =~ ^-?[0-9]+$ ]] && { >&2 echo "Внимание: Неверные деньги '$cash'"; cash=0; load_success=false; } # Warn: Invalid cash '$cash'
    save_file="$save_path/health.sav"; [[ -f "$save_file" ]] && { read -r health < "$save_file" || { >&2 echo "Ошибка чтения $save_file"; load_success=false; }; } || { >&2 echo "Внимание: $save_file отсутствует"; health=100; load_success=false; }
    [[ ! "$health" =~ ^[0-9]+$ ]] && { >&2 echo "Внимание: Неверное здоровье '$health'"; health=100; load_success=false; } # Warn: Invalid health '$health'
    (( health <= 0 && load_success )) && { >&2 echo "Внимание: Загруженное здоровье <= 0"; health=50; } # Warn: Loaded health <= 0
    save_file="$save_path/body_armor_equipped.sav"; [[ -f "$save_file" ]] && { read -r body_armor_equipped < "$save_file" || { >&2 echo "Ошибка чтения $save_file"; load_success=false; }; } || { >&2 echo "Внимание: $save_file отсутствует"; body_armor_equipped=false; load_success=false; }
    [[ "$body_armor_equipped" != "true" && "$body_armor_equipped" != "false" ]] && { >&2 echo "Внимание: Неверная броня '$body_armor_equipped'"; body_armor_equipped=false; load_success=false; } # Warn: Invalid armor '$body_armor_equipped'

    # --- Load Indexed Arrays (loads internal names) ---
    guns=(); save_file="$save_path/guns.sav"
    if [[ -f "$save_file" ]]; then
         if command -v readarray &> /dev/null; then readarray -t guns < "$save_file";
         else IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do guns+=("$line"); done < "$save_file"; IFS="$original_ifs"; fi
    else >&2 echo "Внимание: $save_file отсутствует"; fi # Warn: $save_file missing

    items=(); save_file="$save_path/items.sav"
    if [[ -f "$save_file" ]]; then
        if command -v readarray &> /dev/null; then readarray -t items < "$save_file";
        else IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do items+=("$line"); done < "$save_file"; IFS="$original_ifs"; fi
    else >&2 echo "Внимание: $save_file отсутствует"; fi # Warn: $save_file missing

    # --- Load Associative Arrays (loads internal keys) ---
    declare -A drugs_loaded=(); save_file="$save_path/drugs.sav"
    if [[ -f "$save_file" ]]; then
        while IFS=' ' read -r key value || [[ -n "$key" ]]; do
            if [[ -n "$key" && -v "default_drugs[$key]" ]]; then # Check against default_drugs keys (internal names)
                 if [[ "$value" =~ ^[0-9]+$ ]]; then drugs_loaded["$key"]="$value"; else
                     >&2 echo "Внимание: Неверное кол-во наркотиков '$key'='$value'"; drugs_loaded["$key"]=0; load_success=false; fi # Warn: Invalid drug amt '$key'='$value'
            elif [[ -n "$key" ]]; then >&2 echo "Внимание: Пропуск неизвестного наркотика '$key'"; fi # Warn: Skipping unknown drug '$key'
        done < "$save_file"
    else >&2 echo "Внимание: $save_file отсутствует"; load_success=false; fi # Warn: $save_file missing
    declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${drugs_loaded[$key]:-${default_drugs[$key]}}; done

    declare -A skills_loaded=(); save_file="$save_path/skills.sav"
    if [[ -f "$save_file" ]]; then
        while IFS=' ' read -r key value || [[ -n "$key" ]]; do
             if [[ -n "$key" && -v "default_skills[$key]" ]]; then # Check against default_skills keys (internal names)
                 if [[ "$value" =~ ^[0-9]+$ ]]; then skills_loaded["$key"]="$value"; else
                     >&2 echo "Внимание: Неверный уровень навыка '$key'='$value'"; skills_loaded["$key"]=1; load_success=false; fi # Warn: Invalid skill lvl '$key'='$value'
             elif [[ -n "$key" ]]; then >&2 echo "Внимание: Пропуск неизвестного навыка '$key'"; fi # Warn: Skipping unknown skill '$key'
        done < "$save_file"
    else >&2 echo "Внимание: $save_file отсутствует"; load_success=false; fi # Warn: $save_file missing
    declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${skills_loaded[$key]:-${default_skills[$key]}}; done

    # --- Final Check ---
    IFS="$original_ifs"
    if $load_success; then echo "Игра успешно загружена."; else # Game loaded successfully.
        echo "Внимание: Игра загружена с отсутствующими/неверными данными. Использованы значения по умолчанию."; fi # Warning: Game loaded with missing/invalid data. Defaults used.
    read -r -p "Нажмите Enter, чтобы начать играть..." # Press Enter to start playing...
    return 0
}

# --- 4. Game Initialization and Loop ---

# Function to initialize NEW game variables
Game_variables() {
	clear_screen
	read -r -p "Введите имя игрока: " player_name # Enter your player name:
	[[ -z "$player_name" ]] && player_name="Странник" # Wanderer
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
	echo "Добро пожаловать в Bash Theft Auto, $player_name!" # Welcome to Bash Theft Auto, $player_name!
    echo "Начинаем в $location с \$${cash} и ${health}% здоровья." # Starting in $location with $${cash} and ${health}% health.
    read -r -p "Нажмите Enter, чтобы начать..." # Press Enter to begin...
}

# Function to remove save files safely
remove_save_files() {
    local save_path="$BASEDIR/$SAVE_DIR"
    if [[ -d "$save_path" ]]; then
        echo "Удаление предыдущих файлов сохранения в '$save_path'..." # Deleting previous save files in '$save_path'...
        local found_files=$(find "$save_path" -maxdepth 1 -type f -name '*.sav' -print -delete)
        if [[ -n "$found_files" ]]; then echo "Старые файлы сохранения успешно удалены."; else echo "Файлы '.sav' для удаления не найдены."; fi # Old save files deleted successfully. | No '.sav' files found to delete.
    else
        echo "Инфо: Предыдущий каталог сохранения не найден в '$save_path'." # Info: No previous save directory found at '$save_path'.
    fi
    sleep 1 # Short pause
}

# --- Initial Game Menu ---
run_initial_menu() {
    while true; do
	    clear_screen
	    echo "=== Bash Theft Auto ==="
	    echo "    Главное Меню" # Main Menu
        echo "---------------------"
	    echo "1. Новая Игра" # 1. New Game
	    echo "2. Загрузить Игру" # 2. Load Game
	    echo "3. Выйти из Игры" # 3. Exit Game
        echo "---------------------"
        stty echo # Ensure echo is on for menu
	    read -r -p "Введите ваш выбор: " initial_choice # Enter your choice:

	    case "$initial_choice" in
		    1)
                read -r -p "Начать новую игру? Это удалит существующее сохранение. (д/н): " confirm # Start new game? This deletes any existing save. (y/n): -> д/н
                if [[ "$confirm" == "д" || "$confirm" == "Д" || "$confirm" == "y" || "$confirm" == "Y" ]]; then # Check for Russian 'д' or 'y'/'Y'
                    remove_save_files
                    Game_variables
                    return 0 # Signal to start game loop
                else echo "Новая игра отменена."; sleep 1; fi ;; # New game cancelled.
		    2)
                if load_game; then return 0; # Signal to start game loop
                else sleep 1; fi ;; # Load game failed, pause before showing menu again
		    3) cleanup_and_exit ;; # Use cleanup function
		    *) echo "Неверный выбор."; sleep 1 ;; # Invalid choice.
	    esac
    done
}

# --- Main Execution ---

# Run initial menu. If it returns successfully (0), proceed to main loop.
if ! run_initial_menu; then
    echo "Выход из-за сбоя начального меню или по запросу пользователя." # Exiting due to initial menu failure or user request.
    stty echo # Ensure echo is on just in case
    exit 1
fi


# --- Main Game Loop ---
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

    # --- Main Menu Display ---
    echo "--- Действия ---" # Actions
    echo "1. Путешествовать      | 6. Купить наркотики"       # 1. Travel        | 6. Buy Drugs
    echo "2. Купить оружие       | 7. Продать наркотики"      # 2. Buy Guns      | 7. Sell Drugs
    echo "3. Инвентарь           | 8. Нанять проститутку"     # 3. Inventory     | 8. Hire Hooker
    echo "4. Работа (Легально)   | 9. Посетить больницу"      # 4. Work (Legal)  | 9. Visit Hospital
    echo "5. Работа (Криминал)   | 10. Уличная гонка"         # 5. Work (Crime)  | 10. Street Race
    echo "-----------------------------------------"
    echo "S. Сохранить игру     | L. Загрузить игру"         # S. Save Game     | L. Load Game
    echo "M. Муз. плеер         | A. Об игре"                # M. Music Player  | A. About
    echo "X. Выйти из игры"                                  # X. Exit Game
    echo "-----------------------------------------"

    # --- Restore terminal echo before reading input ---
    stty echo
    # --- Read user choice ---
    read -r -p "Введите ваш выбор: " choice # Enter your choice:
    # Convert choice to lowercase for commands
    choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    # --- Process Choice ---
    case "$choice_lower" in
	    1) # Travel Menu
            clear_screen; echo "--- Турагентство ---" # Travel Agency
            echo "1. Los Santos (\$50) | 2. San Fierro (\$75) | 3. Las Venturas (\$100)";
            echo "4. Vice City (\$150) | 5. Liberty City (\$200) | 6. Остаться здесь"; # Stay Here
            read -r -p "Введите выбор: " city_choice # Enter choice:
            [[ ! "$city_choice" =~ ^[1-6]$ ]] && { echo "Неверный выбор."; sleep 1; continue; } # Invalid choice.
            case "$city_choice" in
                1) travel_to 50 "Los Santos";; 2) travel_to 75 "San Fierro";;
                3) travel_to 100 "Las Venturas";; 4) travel_to 150 "Vice City";;
                5) travel_to 200 "Liberty City";; 6) ;;
            esac;;
	    2) buy_guns;;
	    3) show_inventory;;
	    4) # Legal Work Menu
            clear_screen; echo "--- Честная Работа ---" # Honest Work
            echo "1. Таксист | 2. Доставка | 3. Механик | 4. Охранник | 5. Уличный артист | 6. Назад"; # Taxi Driver | Delivery | Mechanic | Security | Performer | Back
            read -r -p "Введите выбор: " job_choice # Enter choice:
            [[ ! "$job_choice" =~ ^[1-6]$ ]] && { echo "Неверный выбор."; sleep 1; continue; } # Invalid choice.
            case "$job_choice" in
                1) work_job "Таксист";; 2) work_job "Доставка";; 3) work_job "Механик";;
                4) work_job "Охранник";; 5) work_job "Уличный артист";; 6) ;;
            esac;;
	    5) # Criminal Activity Menu
            clear_screen; echo "--- Криминальные Дела ---" # Criminal Activities
            echo "1. Ограбить магазин | 2. Угнать машину | 3. Война банд | 4. Ограбление | 5. Назад"; # Rob Store | Carjack | Gang War | Heist | Back
            read -r -p "Введите выбор: " criminal_choice # Enter choice:
            [[ ! "$criminal_choice" =~ ^[1-5]$ ]] && { echo "Неверный выбор."; sleep 1; continue; } # Invalid choice.
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
             read -r -p "Загрузить игру? Несохраненный прогресс будет потерян. (д/н): " confirm # Load game? Unsaved progress will be lost. (y/n): -> д/н
             if [[ "$confirm" == "д" || "$confirm" == "Д" || "$confirm" == "y" || "$confirm" == "Y" ]]; then # Check for Russian 'д' or 'y'/'Y'
                 load_game # Load game handles messages and continues loop
             else echo "Загрузка отменена."; sleep 1; fi ;; # Load cancelled.
	    'm') play_music;;
	    'a') about_music_sfx;;
        'x')
             read -r -p "Вы уверены, что хотите выйти? (д/н): " confirm # Are you sure you want to exit? (y/n): -> д/н
             if [[ "$confirm" == "д" || "$confirm" == "Д" || "$confirm" == "y" || "$confirm" == "Y" ]]; then # Check for Russian 'д' or 'y'/'Y'
                 # Optional: Auto-save before exit?
                 # read -r -p "Сохранить перед выходом? (д/н): " save_confirm
                 # if [[ "$save_confirm" == "д" || "$save_confirm" == "Д" || "$save_confirm" == "y" || "$save_confirm" == "Y" ]]; then save_game; fi
                 cleanup_and_exit # Use cleanup function
             fi ;;
	    *) echo "Неверный выбор '$choice'."; sleep 1;; # Invalid choice '$choice'.
	esac
    # Loop continues
done

# Should not be reached, but attempt cleanup if it ever does
cleanup_and_exit
