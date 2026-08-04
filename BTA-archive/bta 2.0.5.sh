#Bash-Theft-Auto music and sfx © 2024 by stuffbymax - Martin Petik is licensed under CC BY 4.0
#https://creativecommons.org/licenses/by/4.0/
#ver 2.0.5 (Terminal echo fixes)
#!/bin/bash

# --- Initial Setup ---
# Set BASEDIR to the directory where the script resides
# Using parameter expansion for potentially better compatibility than realpath
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Exit on error to prevent unexpected behavior
# set -e # Uncomment this for stricter error checking if desired, but might exit too easily

# --- Cleanup Function and Trap ---
cleanup_and_exit() {
    echo -e "\nCleaning up and exiting..."
    # Stop music if playing
    if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
        echo "Stopping music (PID: $music_pid)..."
        kill "$music_pid" &>/dev/null
        wait "$music_pid" 2>/dev/null
        music_pid=""
    fi
    # Restore terminal echo
    stty echo
    echo "Cleanup complete. Goodbye."
    exit 0
}
# Trap common exit signals to run the cleanup function
trap cleanup_and_exit SIGINT SIGTERM SIGHUP

# --- 0. Global Variables ---
player_name=""
location="Los Santos" # Default starting location
cash=0
health=100 # Default starting health
declare -a guns=()
declare -a items=()
declare -A drugs=()
declare -A skills=()
body_armor_equipped=false
SAVE_DIR="saves" # Relative to BASEDIR
declare -A gun_attributes=()
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
    echo "# Warning: 'mpg123' command not found.                    #"
    echo "# Sound effects and music require mpg123.                 #"
    echo "# Please install it for the full experience.              #"
    echo "#---------------------------------------------------------#"
    echo "# On Debian/Ubuntu: sudo apt update && sudo apt install mpg123 #"
    echo "# On Fedora:        sudo dnf install mpg123               #"
    echo "# On Arch Linux:    sudo pacman -S mpg123                 #"
    echo "# On macOS (Homebrew): brew install mpg123                #"
    echo "###########################################################"
    read -r -p "Press Enter to continue without sound..."
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
	echo "Info: Plugin directory '$BASEDIR/$plugin_dir' not found. Skipping plugin load."
fi

# --- 3. Functions ---

# Clear the screen and display game information header
clear_screen() {
    clear
    printf "\e[93m=========================================\e[0m\n"
    printf "\e[1;43m|        Bash Theft Auto                |\e[0m\n"
    printf "\e[93m=========================================\e[0m\n"
    printf " Player: %-15s Location: %s\n" "$player_name" "$location"
    printf " Cash: \$%-16d Health: %d%%\n" "$cash" "$health"
    # Display Body Armor Status
    if $body_armor_equipped; then
        printf " Armor: \e[1;32mEquipped\e[0m\n"
    else
        printf " Armor: \e[1;31mNone\e[0m\n"
    fi
    printf "\e[1;34m=========================================\e[0m\n"
}

# --- About ---
about_music_sfx() {
	clear_screen
	echo "-----------------------------------------"
	echo "|  About the Music and Sound Effects    |"
	echo "-----------------------------------------"
	echo ""
	echo "Music and SFX © 2024 by stuffbymax - Martin Petik"
	echo "Licensed under CC BY 4.0:"
	echo "https://creativecommons.org/licenses/by/4.0/"
	echo ""
	echo "You are free to share and adapt this material"
	echo "for any purpose, even commercially, under the"
	echo "condition that you give appropriate credit."
	echo ""
	echo "Attribution example:"
	echo "'Music/SFX © 2024 stuffbymax - Martin Petik, CC BY 4.0'"
	echo ""
	echo "More info: https://stuffbymax.me/"
	echo ""
	echo "-----------------------------------------"
	echo "|  Code License                         |"
	echo "-----------------------------------------"
	echo ""
	echo "Game Code © 2024 stuffbymax"
	echo "Licensed under the MIT License."
	echo "Allows reuse with attribution."
	echo ""
	echo "Full License:"
	echo "https://github.com/stuffbymax/Bash-Theft-Auto/blob/main/LICENSE" # Ensure this link is correct
	echo ""
	echo "Thank you for playing!"
    echo "-----------------------------------------"
	read -r -p "Press Enter to return..."
}

# Function to check if the player is alive and handle death
check_health() {
	if (( health <= 0 )); then
        health=0 # Prevent negative health display
		clear_screen
		echo -e "\n      \e[1;31m W A S T E D \e[0m\n"
		play_sfx_mpg "wasted"
		echo "You collapsed from your injuries..."
		sleep 1
		echo "You wake up later..."
		read -r -p "Press Enter to go to the hospital..."
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
        echo "You are already in $new_location."
        read -r -p "Press Enter..."
        return
    fi

	if (( cash >= travel_cost )); then
		printf "Traveling from %s to %s (\$%d)...\n" "$current_location" "$new_location" "$travel_cost"
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
		echo "You have arrived safely in $new_location."
        read -r -p "Press Enter..."
	else
		echo "Not enough cash (\$$travel_cost needed) to travel to $new_location."
		read -r -p "Press Enter..."
	fi
}

# Function for buying guns menu
buy_guns() {
	local gun_choice=""
	clear_screen
	echo "--- Ammu-Nation ---"
	echo "Welcome! What can I get for you?"
	echo "-------------------"
	echo "1. Pistol      (\$100)"
	echo "2. Shotgun     (\$250)"
	echo "3. SMG         (\$500)"
	echo "4. Rifle       (\$750)"
	echo "5. Sniper      (\$1000)"
	echo "-------------------"
	echo "6. Leave"
    echo "-------------------"
    printf "Your Cash: \$%d\n" "$cash"
	read -r -p "Enter your choice: " gun_choice

	[[ ! "$gun_choice" =~ ^[0-9]+$ ]] && {
		echo "Invalid input."; read -r -p "Press Enter..."; return
	}

	case "$gun_choice" in
		1) buy_gun "Pistol" 100;; # Changed helper name for clarity
		2) buy_gun "Shotgun" 250;;
		3) buy_gun "SMG" 500;;
		4) buy_gun "Rifle" 750;;
		5) buy_gun "Sniper" 1000;;
		6) echo "Come back anytime!"; sleep 1; return;;
		*) echo "Invalid choice."; read -r -p "Press Enter...";;
	esac
}

# Helper function for buying GUNS specifically
buy_gun() {
	local gun_name="$1"
	local gun_cost="$2"
    local owned=false

    # Check if already owned
    for owned_gun in "${guns[@]}"; do
        if [[ "$owned_gun" == "$gun_name" ]]; then
            owned=true
            break
        fi
    done
    if $owned; then
        echo "Looks like you already got a $gun_name there, partner."
        read -r -p "Press Enter..."
        return
    fi

    # Check cash
	if (( cash >= gun_cost )); then
        play_sfx_mpg "cash_register"
		# --- Buy Animation (Optional Plugin Call) ---
        if command -v buy_animation &> /dev/null; then
            buy_animation "$gun_name"
        fi
        # --- End Animation ---

		cash=$((cash - gun_cost))
		guns+=("$gun_name") # Add to guns array
		echo "One $gun_name, coming right up! That'll be \$$gun_cost."
		read -r -p "Press Enter..."
	else
		echo "Sorry pal, not enough cash for the $gun_name (\$$gun_cost needed)."
		read -r -p "Press Enter..."
	fi
}

# Function to show inventory
show_inventory() {
	clear_screen
	echo "--- Inventory & Stats ---"
	printf " Cash: \$%d\n" "$cash"
	printf " Health: %d%%\n" "$health"
    if $body_armor_equipped; then
        printf " Armor: \e[1;32mEquipped\e[0m\n"
    else
        printf " Armor: \e[1;31mNone\e[0m\n"
    fi
	echo "--------------------------"
    echo " Guns:"
    if (( ${#guns[@]} > 0 )); then
        printf "  - %s\n" "${guns[@]}"
    else
        echo "  (None)"
    fi
    echo "--------------------------"
    echo " Items:"
     if (( ${#items[@]} > 0 )); then
        # Implement item usage here later?
        printf "  - %s\n" "${items[@]}"
    else
        echo "  (None)"
    fi
	echo "--------------------------"
	echo " Drugs:"
	local drug_found=false
    for drug in "${!default_drugs[@]}"; do # Iterate default keys to maintain order
        local amount=${drugs[$drug]:-0}
        if (( amount > 0 )); then
            printf "  - %-10s: %d units\n" "$drug" "$amount"
            drug_found=true
        fi
    done
    if ! $drug_found; then echo "  (None)"; fi
    echo "--------------------------"
	echo " Skills:"
    for skill in "${!default_skills[@]}"; do # Iterate default keys
        printf "  - %-12s: %d\n" "$skill" "${skills[$skill]:-0}"
    done
	echo "--------------------------"
	read -r -p "Press Enter to return..."
}

# Function for working (Legal Jobs)
work_job() {
	local job_type="$1"
	local earnings=0 base_earnings=0 skill_bonus=0
	local min_earnings=0 max_earnings=0
	local relevant_skill_level=1 relevant_skill_name=""

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

    # Determine skill influence based on job type
	case "$job_type" in
		"taxi"|"delivery")
            relevant_skill_name="driving"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * (job_type == "delivery" ? 4 : 3) )) # Delivery uses skill slightly more
            [[ "$job_type" == "delivery" ]] && base_earnings=$((base_earnings + 10))
			play_sfx_mpg "taxi"
			;;
		"mechanic")
            relevant_skill_name="strength" # Maybe strength for lifting? Or add specific skill later
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
            base_earnings=$((base_earnings - 10)) # Less reliable base
            base_earnings=$(( base_earnings < 5 ? 5 : base_earnings )) # Min base 5
			play_sfx_mpg "street_performer"
			;;
		*) echo "Internal Error: Invalid Job Type '$job_type'"; return;;
	esac

    earnings=$((base_earnings + skill_bonus))
    (( earnings < 0 )) && earnings=0 # Ensure earnings aren't negative

    # --- Working Animation (Optional Plugin Call) ---
    if command -v working_animation &> /dev/null; then
	    working_animation "$job_type"
    else
        echo "Working as a $job_type..."
        sleep 2
    fi
    # --- End Animation ---

	# --- Outcome ---
	cash=$((cash + earnings))
	clear_screen
	printf "Finished your shift as a %s in %s.\n" "$job_type" "$location"
    printf "You earned \$%d (Base: \$%d, Skill Bonus: \$%d).\n" "$earnings" "$base_earnings" "$skill_bonus"
    printf "You now have \$%d.\n" "$cash"

    # Potential skill increase
    if [[ -n "$relevant_skill_name" ]]; then # Only if a skill was relevant
        local skill_increase_chance=20 # 20% base chance
        if (( RANDOM % 100 < skill_increase_chance )); then
            skills[$relevant_skill_name]=$((relevant_skill_level + 1))
            printf "Your \e[1;32m%s\e[0m skill increased!\n" "$relevant_skill_name"
        fi
    fi

	read -r -p "Press Enter to continue..."
}

# Function for street racing
street_race() {
    local driving_skill=${skills[driving]:-1}
	local base_win_chance=40
	local win_chance=$(( base_win_chance + driving_skill * 5 ))
    (( win_chance > 90 )) && win_chance=90 # Cap win chance at 90%
    (( win_chance < 10 )) && win_chance=10 # Min win chance 10%

    clear_screen
    echo "--- Street Race ---"
    echo "Joining an illegal street race in $location..."
    echo "Driving Skill: $driving_skill | Win Chance: ${win_chance}%"
    sleep 1

    # --- Street Race Animation (Optional Plugin Call) ---
    if command -v race_animation &> /dev/null; then
        race_animation
    elif command -v working_animation &> /dev/null; then
        working_animation "street_race" # Fallback to generic animation
    else
        echo "Get ready..." ; sleep 1; echo "3... 2... 1... GO!"; sleep 1
    fi
    # --- End Animation ---

    read -r -p "Press Enter for the race results..."

	local winnings=0 damage=0

	if (( RANDOM % 100 < win_chance )); then
        # --- Win ---
		winnings=$((RANDOM % 151 + 100 + driving_skill * 10)) # Win 100-250 + bonus
		cash=$((cash + winnings))
		damage=$((RANDOM % 15 + 5)) # Low damage on win: 5-19%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2))
            damage=$((damage - armor_reduction))
			echo "Your body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage!"
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
		printf "\e[1;32m*** YOU WON THE RACE! ***\e[0m\n"
        printf "You collected \$%d in prize money.\n" "$winnings"
        printf "Took minor damage (-%d%% health).\n" "$damage"
        play_sfx_mpg "win"
		# Skill increase chance on win
		if (( RANDOM % 3 == 0 )); then # 33% chance
            skills[driving]=$((driving_skill + 1))
            printf "Your \e[1;32mdriving\e[0m skill increased!\n"
        fi
	else
        # --- Lose ---
        winnings=0 # No winnings on loss
		damage=$((RANDOM % 31 + 15)) # Higher damage on loss: 15-45%
		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2))
            damage=$((damage - armor_reduction))
			echo "Your body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage in the crash!"
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- YOU LOST THE RACE! ---\e[0m\n"
		printf "You crashed and took %d%% damage.\n" "$damage"
		play_sfx_mpg "lose" # Or a crash sound? "car_crash"?
	fi

    # Display final stats for the action
    printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"

    # Check health AFTER showing results
    check_health # This will handle hospitalization if health <= 0
    read -r -p "Press Enter to continue..."
}

# (Function use_guns remains unchanged - kept for potential future use)
use_guns() {
	if [[ " ${guns[*]} " == *" $1 "* ]]; then
		echo "You used your $1 for this job."
		play_sfx_mpg "gun_shot"
		read -r -p "Press Enter..."
	else
		echo "You don't have a $1. Job failed."
		read -r -p "Press Enter..."
	fi
}

# Helper function to handle gun selection and apply bonus for criminal actions
apply_gun_bonus() {
    local base_chance=$1
    local action_message=$2
    local current_chance=$base_chance
    local gun_bonus=0
    local chosen_gun=""
    local gun_found=false
    local success_bonus=0 # Local variable to capture bonus from eval

    if (( ${#guns[@]} == 0 )); then
        echo "You have no guns! This will be significantly harder."
        gun_bonus=-15 # Significant penalty for being unarmed
    else
        echo "Available guns: ${guns[*]}"
        read -r -p "Use a gun for this $action_message? (y/n): " use_gun

        if [[ "$use_gun" == "y" || "$use_gun" == "Y" ]]; then
            read -r -p "Which gun? (Enter exact name): " chosen_gun

            # Check if the player owns the chosen gun
            gun_found=false
            for gun in "${guns[@]}"; do
                if [[ "$gun" == "$chosen_gun" ]]; then
                    gun_found=true
                    break
                fi
            done

            if $gun_found; then
                echo "You draw your $chosen_gun!"
                play_sfx_mpg "gun_cock"

                # Apply Gun Bonus if defined
                if [[ -v "gun_attributes[$chosen_gun]" ]]; then
                    eval "${gun_attributes[$chosen_gun]}" # Sets 'success_bonus' locally
                    gun_bonus=${success_bonus:-0}
                    if (( gun_bonus > 0 )); then
                        echo "The $chosen_gun gives a \e[1;32m+${gun_bonus}%%\e[0m success chance."
                        play_sfx_mpg "gun_shot"
                    else
                        echo "The $chosen_gun provides no specific advantage here."
                    fi
                else
                    echo "Warning: No bonus attributes defined for '$chosen_gun'."
                    gun_bonus=0
                fi
            else
                echo "You don't own '$chosen_gun'! Proceeding without a gun bonus."
                gun_bonus=0
            fi
        else
            echo "Proceeding without using a gun."
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
	    echo "--- County General Hospital ---"
        printf " Your Health: %d%% | Cash: \$%d\n" "$health" "$cash"
        echo "-------------------------------"
	    echo " Services:"
	    echo " 1. Basic Treatment (\$50)  - Heal to 100%"
	    echo " 2. Advanced Scan (\$100) - Heal to 110% (Temporary Max)"
	    echo " 3. Buy Health Pack (\$30) - Add 'Health Pack' to Items"
	    echo " 4. Buy Body Armor (\$75)  - Equip Armor (One time use)"
        echo "-------------------------------"
	    echo " 5. Leave Hospital"
        echo "-------------------------------"
	    read -r -p "Enter your choice: " hospital_choice

	    [[ ! "$hospital_choice" =~ ^[0-9]+$ ]] && {
		    echo "Invalid input."; sleep 1; continue
	    }

	    case "$hospital_choice" in
		    1) buy_hospital_item 50 "basic_treatment";;
		    2) buy_hospital_item 100 "advanced_treatment";;
		    3) buy_hospital_item 30 "health_pack";;
		    4) buy_hospital_item 75 "body_armor";;
		    5) echo "Leaving the hospital..."; sleep 1; return;;
		    *) echo "Invalid choice."; sleep 1;;
	    esac
        # After an action, loop back to show the menu again unless they chose to leave
    done
}

# Helper function for buying hospital items
buy_hospital_item() {
	local item_cost="$1"
	local item_type="$2"

	if (( cash >= item_cost )); then
        play_sfx_mpg "cash_register"
		cash=$((cash - item_cost))
		case "$item_type" in
			"basic_treatment")
				health=100
				echo "Received basic treatment. Health fully restored to 100%."
				play_sfx_mpg "heal"
				;;
			"advanced_treatment")
				health=110
				echo "Advanced scan complete. Health boosted to 110%!"
                echo "(Note: Further healing/damage calculated from 100% base unless health is > 100)"
				play_sfx_mpg "heal_adv"
				;;
			"health_pack")
				items+=("Health Pack")
				echo "You bought a Health Pack. (Item usage not yet implemented)"
				play_sfx_mpg "item_buy"
				;;
			"body_armor")
                if $body_armor_equipped; then
                    echo "You already have Body Armor equipped."
                    cash=$((cash + item_cost)) # Refund
                    play_sfx_mpg "error"
                else
				    body_armor_equipped=true
				    echo "Body Armor purchased and equipped."
				    play_sfx_mpg "item_equip"
                fi
				;;
            *) # Should not be reached
                echo "Internal Error: Unknown hospital item type '$item_type'"
                cash=$((cash + item_cost)) # Refund
                ;;
		esac
        read -r -p "Press Enter..."
	else
		echo "Not enough cash for $item_type (\$$item_cost needed)."
		read -r -p "Press Enter..."
	fi
}

# Function for robbing a store
rob_store() {
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$((15 + stealth_skill * 5))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Rob Store ---"
    echo "Scoping out a convenience store in $location..."
    sleep 1

    # --- Robbery Animation (Optional Plugin Call) ---
    if command -v robbing_animation &> /dev/null; then robbing_animation; else echo "Making your move..."; sleep 1; fi
    # --- End Animation ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "robbery")

    echo "Calculating odds... Final success chance: ${final_success_chance}%"
    read -r -p "Press Enter to attempt the robbery..."

    if (( RANDOM % 100 < final_success_chance )); then
        # --- Success ---
        loot=$((RANDOM % 151 + 50 + stealth_skill * 10)) # Loot: 50-200 + bonus
        cash=$((cash + loot))
        damage=$((RANDOM % 16 + 5)) # Damage: 5-20%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage during the getaway!"
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;32mSuccess!\e[0m You intimidated the clerk and grabbed \$%d.\n" "$loot"
        printf "Got slightly roughed up (-%d%% health).\n" "$damage"
        play_sfx_mpg "cash_register"
        # Skill increase chance
        if (( RANDOM % 3 == 0 )); then
            skills[stealth]=$((stealth_skill + 1))
            printf "Your \e[1;32mstealth\e[0m skill increased!\n"
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
            echo "Body armor protected you from \e[1;31m${armor_reduction}%%\e[0m damage during the arrest!"
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;31mFailed!\e[0m The silent alarm tripped, cops arrived quickly.\n"
        printf "You were fined \$%d and took %d%% damage.\n" "$fine" "$damage"
        play_sfx_mpg "police_siren"
    fi

    printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"
    check_health # Check health status after the event
    read -r -p "Press Enter to continue..."
}

# Function for participating in a heist
heist() {
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$((10 + stealth_skill * 6)) # Harder than robbery
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Plan Heist ---"
    echo "Planning a high-stakes job in $location..."
    sleep 1

    # --- Heist Animation (Optional Plugin Call) ---
    if command -v heist_animation &> /dev/null; then heist_animation; else echo "Executing the plan..."; sleep 1; fi
    # --- End Animation ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "heist")

    echo "Assessing security risks... Final success chance: ${final_success_chance}%"
    read -r -p "Press Enter to execute the heist..."

	if (( RANDOM % 100 < final_success_chance )); then
        # --- Success ---
		loot=$((RANDOM % 501 + 250 + stealth_skill * 25)) # Loot: 250-750 + bonus
		cash=$((cash + loot))
		damage=$((RANDOM % 31 + 15)) # Damage: 15-45%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage during the firefight!"
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;32m*** HEIST SUCCESSFUL! ***\e[0m\n You scored \$%d!\n" "$loot"
        printf "Escaped with significant injuries (-%d%% health).\n" "$damage"
        play_sfx_mpg "win_big"
        # Skill increase
        if (( RANDOM % 2 == 0 )); then
            skills[stealth]=$((stealth_skill + 2)) # Major increase
            printf "Your \e[1;32mstealth\e[0m skill increased significantly!\n"
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
			echo "Body armor saved your life from \e[1;31m${armor_reduction}%%\e[0m damage!"
			body_armor_equipped=false
		fi
        health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- HEIST FAILED! ---\e[0m\n Security was too tight, aborted the job.\n"
		printf "You lost \$%d and took %d%% damage.\n" "$fine" "$damage"
		play_sfx_mpg "lose_big"
	fi

    printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"
    check_health
	read -r -p "Press Enter to continue..."
}

# Function for gang wars
gang_war() {
	if (( ${#guns[@]} == 0 )); then
		echo "You need a weapon to start a gang war! Buy one first."
		read -r -p "Press Enter..." ; return
	fi

    local strength_skill=${skills[strength]:-1}
    local base_chance=$((20 + strength_skill * 5))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Gang War ---"
    echo "Rolling up on rival territory in $location..."
    sleep 1

	# --- Gang War Animation (Optional Plugin Call) ---
    if command -v gang_war_animation &> /dev/null; then gang_war_animation; else echo "Bullets start flying!"; sleep 1; fi
    # --- End Animation ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "gang war")

    echo "Assessing rival strength... Final success chance: ${final_success_chance}%"
	read -r -p "Press Enter to start the fight..."

	if (( RANDOM % 100 < final_success_chance )); then
        # --- Win ---
		loot=$((RANDOM % 201 + 100 + strength_skill * 15)) # Loot 100-300 + bonus
		cash=$((cash + loot))
		damage=$((RANDOM % 41 + 20)) # Damage: 20-60%

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Body armor took \e[1;31m${armor_reduction}%%\e[0m damage from bullets!"
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;32m*** GANG WAR WON! ***\e[0m\n You claimed the turf and \$%d in spoils.\n" "$loot"
        printf "Suffered heavy damage (-%d%% health).\n" "$damage"
		play_sfx_mpg "win"
        # Skill increase
        if (( RANDOM % 2 == 0 )); then
            skills[strength]=$((strength_skill + 1))
            printf "Your \e[1;32mstrength\e[0m skill increased!\n"
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
			echo "Body armor prevented \e[1;31m${armor_reduction}%%\e[0m fatal damage!"
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
        printf "\e[1;31m--- GANG WAR LOST! ---\e[0m\n You were overrun and barely escaped.\n"
		printf "You lost \$%d and took %d%% damage.\n" "$fine" "$damage"
		play_sfx_mpg "lose"
	fi

    printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"
    check_health
	read -r -p "Press Enter to continue..."
}

# Function for carjacking
carjack() {
    local driving_skill=${skills[driving]:-1}
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$(( 20 + driving_skill * 2 + stealth_skill * 3 ))
    local loot=0 damage=0 fine=0

    clear_screen
    echo "--- Carjack ---"
    echo "Looking for a vehicle to 'borrow' in $location..."
    sleep 1

    # --- Carjacking Animation (Optional Plugin Call) ---
    if command -v carjacking_animation &> /dev/null; then carjacking_animation; else echo "Spotting a target..."; sleep 1; fi
    # --- End Animation ---

    local final_success_chance=$(apply_gun_bonus "$base_chance" "carjacking")

    echo "Choosing a target... Final success chance: ${final_success_chance}%"
    read -r -p "Press Enter to make your move..."

    if (( RANDOM % 100 < final_success_chance )); then
        # --- Success ---
        loot=$((RANDOM % 101 + 50 + driving_skill * 5)) # Car value: 50 - 150 + bonus
        cash=$((cash + loot))
        damage=$((RANDOM % 16 + 5)) # Damage: 5-20%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage during the getaway!"
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;32mSuccess!\e[0m You boosted the car and fenced it for \$%d.\n" "$loot"
        printf "Got slightly banged up (-%d%% health).\n" "$damage"
        play_sfx_mpg "car_start"
        # Skill increase chances
        if (( RANDOM % 4 == 0 )); then skills[driving]=$((driving_skill+1)); printf "Your \e[1;32mdriving\e[0m skill increased!\n"; fi
        if (( RANDOM % 4 == 0 )); then skills[stealth]=$((stealth_skill+1)); printf "Your \e[1;32mstealth\e[0m skill increased!\n"; fi
    else
        # --- Failure ---
        loot=0
        fine=$((RANDOM % 76 + 25)) # Fine: 25-100
        cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 26 + 10)) # Damage: 10-35%

        if $body_armor_equipped; then
            local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
            echo "Body armor took \e[1;31m${armor_reduction}%%\e[0m damage when the owner fought back!"
            body_armor_equipped=false
        fi
        health=$((health - damage))

        clear_screen
        printf "\e[1;31mFailed!\e[0m Alarm blared / Owner resisted / Cops nearby.\n"
        printf "You were fined \$%d and took %d%% damage.\n" "$fine" "$damage"
        play_sfx_mpg "police_siren"
    fi

    printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"
    check_health
    read -r -p "Press Enter to continue..."
}

# Function to handle consequences of player death (called by check_health)
hospitalize_player() {
	local hospital_bill=200
    echo "The hospital patched you up."
    sleep 1
    echo "Unfortunately, medical care isn't free. Bill: \$${hospital_bill}."

    if (( cash < hospital_bill )); then
        echo "You couldn't afford the full bill (\$${hospital_bill}). They took all your cash (\$$cash)."
        hospital_bill=$cash
    else
        echo "You paid the \$${hospital_bill} bill."
    fi

	cash=$((cash - hospital_bill))
    health=50 # Reset health to 50% after "death"
	body_armor_equipped=false # Lose armor on "death"
    play_sfx_mpg "cash_register" # Sound for paying bill

	printf "You leave the hospital with \$%d cash and %d%% health.\n" "$cash" "$health"
	# Location doesn't change on death in this version
    # Inventory items are kept (could change this for more difficulty)
	read -r -p "Press Enter to continue..."
}

# Function to hire a hooker
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
    echo "--- Seeking Company ---"
	echo "Looking for some 'stress relief' in $location..."
    sleep 1
    echo "You approach someone promising... They quote you \$$hooker_cost."

	if (( cash >= hooker_cost )); then
        read -r -p "Accept the offer? (y/n): " accept
        if [[ "$accept" == "y" || "$accept" == "Y" ]]; then
            play_sfx_mpg "cash_register"
	        cash=$(( cash - hooker_cost ))
	        local previous_health=$health
            health=$(( health + health_gain ))
	        (( health > max_health )) && health=$max_health # Apply cap
            local actual_gain=$((health - previous_health))

            clear_screen
            echo "--- Transaction Complete ---"
	        printf "You paid \$%d.\n" "$hooker_cost"
            if (( actual_gain > 0 )); then
                 printf "Feeling refreshed, you gained \e[1;32m%d%%\e[0m health.\n" "$actual_gain"
            else
                 echo "You were already at maximum health."
            fi
            printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"
	        play_sfx_mpg "hooker"
            # Skill increase chance
            if (( RANDOM % 5 == 0 )); then
                skills[charisma]=$((charisma_skill+1))
                printf "Your \e[1;32mcharisma\e[0m skill increased!\n"
            fi
        else
            echo "You decided against it and walked away."
        fi
    else
	    echo "You check your wallet... not enough cash (\$$hooker_cost needed)."
	fi
    read -r -p "Press Enter to continue..."
}


# Centralized Drug Transaction Function
drug_transaction() {
	local action="$1" base_price="$3" drug_amount="$4"
    local drug_name="$2" # Keep drug name separate for clarity
    local cost=0 income=0 final_price=0
	local drug_dealer_skill=${skills[drug_dealer]:-1}

    # Validate amount is a positive integer
    if ! [[ "$drug_amount" =~ ^[1-9][0-9]*$ ]]; then
        echo "Invalid amount '$drug_amount'. Please enter a number greater than 0."
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
            drugs["$drug_name"]=$(( ${drugs[$drug_name]:-0} + drug_amount ))
			printf "Bought \e[1;33m%d\e[0m units of \e[1;33m%s\e[0m for \e[1;31m\$%d\e[0m (\$%d/unit).\n" \
                   "$drug_amount" "$drug_name" "$cost" "$final_price"
			play_sfx_mpg "cash_register" ; return 0
		else
			printf "Not enough cash. Need \$%d, you have \$%d.\n" "$cost" "$cash" ; return 1
		fi

	elif [[ "$action" == "sell" ]]; then
        local current_inventory=${drugs[$drug_name]:-0}
		if (( current_inventory >= drug_amount )); then
            local price_bonus_percent=$((drug_dealer_skill * 2))
            final_price=$(( current_market_price + (current_market_price * price_bonus_percent / 100) ))
            (( final_price < 1 )) && final_price=1 # Ensure selling price isn't driven below $1 by negative modifiers
			income=$((final_price * drug_amount))

            if command -v drug_transaction_animation &> /dev/null; then drug_transaction_animation "sell"; fi
			cash=$((cash + income))
			drugs["$drug_name"]=$((current_inventory - drug_amount))

			printf "Sold \e[1;33m%d\e[0m units of \e[1;33m%s\e[0m for \e[1;32m\$%d\e[0m (\$%d/unit, skill +%d%%).\n" \
                   "$drug_amount" "$drug_name" "$income" "$final_price" "$price_bonus_percent"
			play_sfx_mpg "cash_register"
            # Skill increase chance
            if (( RANDOM % 2 == 0 )); then
			    skills[drug_dealer]=$((drug_dealer_skill + 1))
			    printf "Your \e[1;32mdrug dealing\e[0m skill increased!\n"
            fi ; return 0
		else
			printf "Not enough %s to sell. You have %d units, tried to sell %d.\n" \
                   "$drug_name" "$current_inventory" "$drug_amount" ; return 1
		fi
	else # Should not happen
		echo "Internal Error: Invalid action '$action' in drug_transaction." ; return 1
	fi
}

# Function to handle buying drugs menu
buy_drugs() {
	local drug_choice="" drug_amount=""
    declare -A drug_prices=( ["Weed"]=10 ["Cocaine"]=50 ["Heroin"]=100 ["Meth"]=75 )
    local drug_names=("Weed" "Cocaine" "Heroin" "Meth") # Order for menu

	while true; do
	    clear_screen
        echo "--- Drug Dealer (Buy) ---"
        printf " Location: %-15s | Cash: \$%d\n" "$location" "$cash"
        echo "---------------------------"
        echo " Available Inventory (Market Base Price):"
        local i=1
        for name in "${drug_names[@]}"; do
            # Show approximate current market price?
            local base_p=${drug_prices[$name]}
            local approx_p=$(( base_p + (base_p * ( $( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0) ) / 100) ))
            (( approx_p < 1 )) && approx_p=1
            printf " %d. %-10s (\~$%d/unit)\n" "$i" "$name" "$approx_p"
            ((i++))
        done
        echo "---------------------------"
        printf " %d. Leave\n" "$i"
        echo "---------------------------"
	    read -r -p "Choose drug to buy (number): " drug_choice

        if [[ "$drug_choice" == "$i" ]]; then echo "Leaving the dealer..."; sleep 1; return; fi
	    if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#drug_names[@]} )); then
		    echo "Invalid choice."; sleep 1; continue
	    fi

        local chosen_drug_name="${drug_names[$((drug_choice - 1))]}"
        local chosen_drug_price="${drug_prices[$chosen_drug_name]}"

	    read -r -p "Enter amount of $chosen_drug_name to buy: " drug_amount

        # drug_transaction handles messages for success/failure/validation
        drug_transaction "buy" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"
        read -r -p "Press Enter..." # Pause after transaction attempt
    done
}

# Function to handle selling drugs menu
sell_drugs() {
    local drug_choice="" drug_amount=""
    declare -A drug_sell_prices=( ["Weed"]=15 ["Cocaine"]=75 ["Heroin"]=150 ["Meth"]=100 ) # Base sell prices
    local drug_names=("Weed" "Cocaine" "Heroin" "Meth") # Order

    while true; do
	    clear_screen
        echo "--- Drug Dealer (Sell) ---"
        printf " Location: %-15s | Cash: \$%d\n" "$location" "$cash"
        echo "--------------------------"
        echo " Your Inventory (Approx Sell Value/unit):"
        local i=1
        local available_to_sell=() # Track which items are available to choose
        for name in "${drug_names[@]}"; do
            local inventory_amount=${drugs[$name]:-0}
            if (( inventory_amount > 0 )); then
                local base_p=${drug_sell_prices[$name]}
                local skill_bonus_p=$(( (skills[drug_dealer]:-1) * 2 ))
                local approx_p=$(( base_p + (base_p * ( $( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0) + skill_bonus_p ) / 100) ))
                (( approx_p < 1 )) && approx_p=1
                printf " %d. %-10s (%d units) ~\$%d/unit\n" "$i" "$name" "$inventory_amount" "$approx_p"
                available_to_sell+=("$name") # Add drug name player can sell
                ((i++))
            fi
        done

        if (( ${#available_to_sell[@]} == 0 )); then
            echo "--------------------------"
            echo "You have no drugs to sell."
            read -r -p "Press Enter to leave..." ; return
        fi
        echo "--------------------------"
        printf " %d. Leave\n" "$i"
        echo "--------------------------"

	    read -r -p "Choose drug to sell (number): " drug_choice

        if [[ "$drug_choice" == "$i" ]]; then echo "Leaving the dealer..."; sleep 1; return; fi
	    if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#available_to_sell[@]} )); then
		    echo "Invalid choice."; sleep 1; continue
	    fi

        local chosen_drug_name="${available_to_sell[$((drug_choice - 1))]}"
        local chosen_drug_price="${drug_sell_prices[$chosen_drug_name]}"
        local current_inventory=${drugs[$chosen_drug_name]}

	    read -r -p "Sell how many units of $chosen_drug_name? (Max: $current_inventory): " drug_amount

        # drug_transaction handles messages for success/failure/validation
        drug_transaction "sell" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"
        read -r -p "Press Enter..." # Pause after transaction attempt
    done
}

# Function to play music (Robust Version with stty echo fix)
play_music() {
    # 1. Check Prerequisite: mpg123 command
    if ! $mpg123_available; then # Use the global flag checked at start
        echo "Music playback disabled: 'mpg123' command not found."; read -r -p "Press Enter..."; return 1;
    fi

    # 2. Define Music Directory and Find Files
    local music_dir="$BASEDIR/music"
    local music_files=()
    local original_ifs="$IFS" # Save IFS

    if [[ ! -d "$music_dir" ]]; then
        echo "Error: Music directory '$music_dir' not found!"; read -r -p "Press Enter..."; return 1;
    fi

    # Use find and process substitution for safer file handling
    while IFS= read -r -d $'\0' file; do
        music_files+=("$file")
    done < <(find "$music_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.MP3" \) -print0 2>/dev/null) # Find .mp3 and .MP3
    IFS="$original_ifs" # Restore IFS

    if (( ${#music_files[@]} == 0 )); then
        echo "No .mp3 files found in '$music_dir'."; read -r -p "Press Enter..."; return 1;
    fi

    # 3. Music Player Loop
    local choice_stop="s" choice_back="b" music_choice=""
    local mpg123_log="/tmp/bta_mpg123_errors.$$.log" # Unique log per session

    while true; do
        clear_screen
        echo "--- Music Player ---"
        echo " Music Directory: $music_dir"
        echo "----------------------------------------"
        local current_status="Stopped" current_song_name=""
        if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
            current_song_name=$(ps -p "$music_pid" -o args= 2>/dev/null | sed 's/.*mpg123 [-q]* //; s/ *$//' || echo "Playing Track")
            [[ -z "$current_song_name" ]] && current_song_name="Playing Track"
            current_status="Playing: $(basename "$current_song_name") (PID: $music_pid)"
        else
            [[ -n "$music_pid" ]] && music_pid="" # Clear stale PID
            current_status="Stopped"
        fi
        echo " Status: $current_status"
        echo "----------------------------------------"
        echo " Available Tracks:"
        for i in "${!music_files[@]}"; do printf " %d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"; done
        echo "----------------------------------------"
        printf " [%s] Stop Music | [%s] Back to Game\n" "$choice_stop" "$choice_back"
        echo "----------------------------------------"

        # Ensure terminal echo is ON before this prompt
        stty echo
        read -r -p "Enter choice (number, s, b): " music_choice

        case "$music_choice" in
            "$choice_stop" | "q")
                if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
                    echo "Stopping music (PID: $music_pid)..."
                    kill "$music_pid" &>/dev/null; sleep 0.2
                    if kill -0 "$music_pid" &>/dev/null; then kill -9 "$music_pid" &>/dev/null; fi
                    wait "$music_pid" 2>/dev/null; music_pid=""; echo "Music stopped."
                else echo "No music is currently playing."; fi
                # Ensure echo restored after stopping attempt
                stty echo
                sleep 1 # Pause briefly
                ;; # Loop will repeat and show updated menu
            "$choice_back" | "b")
                echo "Returning to game..."; sleep 1; break # Exit the music loop
                ;;
            *)
                if [[ "$music_choice" =~ ^[0-9]+$ ]] && (( music_choice >= 1 && music_choice <= ${#music_files[@]} )); then
                    local selected_track="${music_files[$((music_choice - 1))]}"
                    if [[ ! -f "$selected_track" ]]; then echo "Error: File '$selected_track' not found!"; sleep 2; continue; fi

                    if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
                        echo "Stopping previous track..."; kill "$music_pid" &>/dev/null; wait "$music_pid" 2>/dev/null; music_pid=""; sleep 0.2;
                    fi

                    echo "Attempting to play: $(basename "$selected_track")"

                    # --- Play Command (No Subshell) ---
                    echo "--- BTA Log $(date) --- Playing: $selected_track" >> "$mpg123_log"
                    mpg123 -q "$selected_track" 2>> "$mpg123_log" &
                    # ---------------------------------

                    local new_pid=$!
                    sleep 0.5 # Give it a moment to start or fail

                    if kill -0 "$new_pid" 2>/dev/null; then
                        music_pid=$new_pid; echo "Playback started (PID: $music_pid)."
                        # Don't pause here, let loop repeat to show status
                    else
                        echo "Error: Failed to start mpg123 process for $(basename "$selected_track")."
                        echo "       Check log for errors (if any): $mpg123_log"
                        if [[ -f "$mpg123_log" ]]; then
                            echo "--- Last lines of log ---"; tail -n 5 "$mpg123_log"; echo "-------------------------"
                        fi
                        music_pid=""; read -r -p "Press Enter..." # Pause
                    fi
                else
                    echo "Invalid choice '$music_choice'."
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
    mkdir -p "$save_path" || { echo "Error: Could not create save directory '$save_path'."; read -r -p "Press Enter..."; return 1; }

    echo "Saving game state..."
    # Define file paths
    local player_file="$save_path/player_name.sav"
    local loc_file="$save_path/location.sav"
    local cash_file="$save_path/cash.sav"
    local health_file="$save_path/health.sav"
    local armor_file="$save_path/body_armor_equipped.sav"
    local guns_file="$save_path/guns.sav"
    local items_file="$save_path/items.sav"
    local drugs_file="$save_path/drugs.sav"
    local skills_file="$save_path/skills.sav"
    local temp_ext=".tmp$$" # Unique temporary extension

    # Function to save atomically (write to temp, then rename)
    save_atomic() {
        local content="$1" file_path="$2" temp_file="${file_path}${temp_ext}"
        printf '%s\n' "$content" > "$temp_file" && mv "$temp_file" "$file_path" || {
            echo "Error saving file: $file_path"; rm -f "$temp_file"; return 1;
        }
        return 0
    }

    # --- Save Simple Variables ---
    save_atomic "$player_name" "$player_file" || return 1
	save_atomic "$location" "$loc_file" || return 1
	save_atomic "$cash" "$cash_file" || return 1
	save_atomic "$health" "$health_file" || return 1
    save_atomic "$body_armor_equipped" "$armor_file" || return 1

    # --- Save Indexed Arrays ---
    printf '%s\n' "${guns[@]}" > "$guns_file$temp_ext" && mv "$guns_file$temp_ext" "$guns_file" || { echo "Error saving guns."; rm -f "$guns_file$temp_ext"; return 1; }
	printf '%s\n' "${items[@]}" > "$items_file$temp_ext" && mv "$items_file$temp_ext" "$items_file" || { echo "Error saving items."; rm -f "$items_file$temp_ext"; return 1; }

    # --- Save Associative Arrays ---
	# Drugs
    : > "$drugs_file$temp_ext" # Create/clear temp file
	for key in "${!drugs[@]}"; do printf "%s %s\n" "$key" "${drugs[$key]}" >> "$drugs_file$temp_ext"; done
    if [[ -f "$drugs_file$temp_ext" ]]; then mv "$drugs_file$temp_ext" "$drugs_file"; else echo "Error writing drugs temp file."; return 1; fi

	# Skills
    : > "$skills_file$temp_ext"
	for key in "${!skills[@]}"; do printf "%s %s\n" "$key" "${skills[$key]}" >> "$skills_file$temp_ext"; done
    if [[ -f "$skills_file$temp_ext" ]]; then mv "$skills_file$temp_ext" "$skills_file"; else echo "Error writing skills temp file."; return 1; fi

	echo "Game saved successfully to '$save_path'."
	read -r -p "Press Enter to continue..."
    return 0
}

# Load the game state from a file (More robust)
load_game() {
    local load_success=true
    local original_ifs="$IFS"
    local key="" value="" line="" save_file="" # Declare/clear local variables
    local save_path="$BASEDIR/$SAVE_DIR"

    echo "Attempting to load game from '$save_path'..."

    if [[ ! -d "$save_path" ]]; then
        echo "Error: Save directory '$save_path' not found."; read -r -p "Press Enter..."; return 1;
    fi

    # --- Load Simple Variables ---
    save_file="$save_path/player_name.sav"; [[ -f "$save_file" ]] && { read -r player_name < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; player_name="Unknown"; load_success=false; }
    save_file="$save_path/location.sav"; [[ -f "$save_file" ]] && { read -r location < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; location="Los Santos"; load_success=false; }
    save_file="$save_path/cash.sav"; [[ -f "$save_file" ]] && { read -r cash < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; cash=0; load_success=false; }
    [[ ! "$cash" =~ ^-?[0-9]+$ ]] && { >&2 echo "Warn: Invalid cash '$cash'"; cash=0; load_success=false; }
    save_file="$save_path/health.sav"; [[ -f "$save_file" ]] && { read -r health < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; health=100; load_success=false; }
    [[ ! "$health" =~ ^[0-9]+$ ]] && { >&2 echo "Warn: Invalid health '$health'"; health=100; load_success=false; }
    (( health <= 0 && load_success )) && { >&2 echo "Warn: Loaded health <= 0"; health=50; }
    save_file="$save_path/body_armor_equipped.sav"; [[ -f "$save_file" ]] && { read -r body_armor_equipped < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; body_armor_equipped=false; load_success=false; }
    [[ "$body_armor_equipped" != "true" && "$body_armor_equipped" != "false" ]] && { >&2 echo "Warn: Invalid armor '$body_armor_equipped'"; body_armor_equipped=false; load_success=false; }

    # --- Load Indexed Arrays ---
    guns=(); save_file="$save_path/guns.sav"
    if [[ -f "$save_file" ]]; then
         if command -v readarray &> /dev/null; then readarray -t guns < "$save_file";
         else IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do guns+=("$line"); done < "$save_file"; IFS="$original_ifs"; fi
    else >&2 echo "Warn: $save_file missing"; fi

    items=(); save_file="$save_path/items.sav"
    if [[ -f "$save_file" ]]; then
        if command -v readarray &> /dev/null; then readarray -t items < "$save_file";
        else IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do items+=("$line"); done < "$save_file"; IFS="$original_ifs"; fi
    else >&2 echo "Warn: $save_file missing"; fi

    # --- Load Associative Arrays ---
    declare -A drugs_loaded=(); save_file="$save_path/drugs.sav"
    if [[ -f "$save_file" ]]; then
        while IFS=' ' read -r key value || [[ -n "$key" ]]; do
            if [[ -n "$key" && -v "default_drugs[$key]" ]]; then
                 if [[ "$value" =~ ^[0-9]+$ ]]; then drugs_loaded["$key"]="$value"; else
                     >&2 echo "Warn: Invalid drug amt '$key'='$value'"; drugs_loaded["$key"]=0; load_success=false; fi
            elif [[ -n "$key" ]]; then >&2 echo "Warn: Skipping unknown drug '$key'"; fi
        done < "$save_file"
    else >&2 echo "Warn: $save_file missing"; load_success=false; fi
    declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${drugs_loaded[$key]:-${default_drugs[$key]}}; done

    declare -A skills_loaded=(); save_file="$save_path/skills.sav"
    if [[ -f "$save_file" ]]; then
        while IFS=' ' read -r key value || [[ -n "$key" ]]; do
             if [[ -n "$key" && -v "default_skills[$key]" ]]; then
                 if [[ "$value" =~ ^[0-9]+$ ]]; then skills_loaded["$key"]="$value"; else
                     >&2 echo "Warn: Invalid skill lvl '$key'='$value'"; skills_loaded["$key"]=1; load_success=false; fi
             elif [[ -n "$key" ]]; then >&2 echo "Warn: Skipping unknown skill '$key'"; fi
        done < "$save_file"
    else >&2 echo "Warn: $save_file missing"; load_success=false; fi
    declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${skills_loaded[$key]:-${default_skills[$key]}}; done

    # --- Final Check ---
    IFS="$original_ifs"
    if $load_success; then echo "Game loaded successfully."; else
        echo "Warning: Game loaded with missing/invalid data. Defaults used."; fi
    read -r -p "Press Enter to start playing..."
    return 0
}

# --- 4. Game Initialization and Loop ---

# Function to initialize NEW game variables
Game_variables() {
	clear_screen
	read -r -p "Enter your player name: " player_name
	[[ -z "$player_name" ]] && player_name="Wanderer"
	play_sfx_mpg "new_game"
	location="Los Santos"
	cash=500
	health=100
	guns=()
	items=()
    # Reset associative arrays using defaults
    declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${default_drugs[$key]}; done
    declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${default_skills[$key]}; done
    body_armor_equipped=false
	echo "Welcome to Bash Theft Auto, $player_name!"
    echo "Starting in $location with \$${cash} and ${health}% health."
    read -r -p "Press Enter to begin..."
}

# Function to remove save files safely
remove_save_files() {
    local save_path="$BASEDIR/$SAVE_DIR"
    if [[ -d "$save_path" ]]; then
        echo "Deleting previous save files in '$save_path'..."
        local found_files=$(find "$save_path" -maxdepth 1 -type f -name '*.sav' -print -delete)
        if [[ -n "$found_files" ]]; then echo "Old save files deleted successfully."; else echo "No '.sav' files found to delete."; fi
    else
        echo "Info: No previous save directory found at '$save_path'."
    fi
    sleep 1 # Short pause
}

# --- Initial Game Menu ---
run_initial_menu() {
    while true; do
	    clear_screen
	    echo "=== Bash Theft Auto ==="
	    echo "      Main Menu"
        echo "---------------------"
	    echo "1. New Game"
	    echo "2. Load Game"
	    echo "3. Exit Game"
        echo "---------------------"
        stty echo # Ensure echo is on for menu
	    read -r -p "Enter your choice: " initial_choice

	    case "$initial_choice" in
		    1)
                read -r -p "Start new game? This deletes any existing save. (y/n): " confirm
                if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                    remove_save_files
                    Game_variables
                    return 0 # Signal to start game loop
                else echo "New game cancelled."; sleep 1; fi ;;
		    2)
                if load_game; then return 0; # Signal to start game loop
                else sleep 1; fi ;; # Load game failed, pause before showing menu again
		    3) cleanup_and_exit ;; # Use cleanup function
		    *) echo "Invalid choice."; sleep 1 ;;
	    esac
    done
}

# --- Main Execution ---

# Run initial menu. If it returns successfully (0), proceed to main loop.
if ! run_initial_menu; then
    echo "Exiting due to initial menu failure or user request."
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
    echo "--- Actions ---"
    echo "1. Travel        | 6. Buy Drugs"
    echo "2. Buy Guns      | 7. Sell Drugs"
    echo "3. Inventory     | 8. Hire Hooker"
    echo "4. Work (Legal)  | 9. Visit Hospital"
    echo "5. Work (Crime)  | 10. Street Race"
    echo "-----------------------------------------"
    echo "S. Save Game     | L. Load Game"
    echo "M. Music Player  | A. About"
    echo "X. Exit Game"
    echo "-----------------------------------------"

    # --- Restore terminal echo before reading input ---
    stty echo
    # --- Read user choice ---
    read -r -p "Enter your choice: " choice
    # Convert choice to lowercase for commands
    choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

    # --- Process Choice ---
    case "$choice_lower" in
	    1) # Travel Menu
            clear_screen; echo "--- Travel Agency ---"
            echo "1. Los Santos (\$50) | 2. San Fierro (\$75) | 3. Las Venturas (\$100)";
            echo "4. Vice City (\$150) | 5. Liberty City (\$200) | 6. Stay Here";
            read -r -p "Enter choice: " city_choice
            [[ ! "$city_choice" =~ ^[1-6]$ ]] && { echo "Invalid choice."; sleep 1; continue; }
            case "$city_choice" in
                1) travel_to 50 "Los Santos";; 2) travel_to 75 "San Fierro";;
                3) travel_to 100 "Las Venturas";; 4) travel_to 150 "Vice City";;
                5) travel_to 200 "Liberty City";; 6) ;;
            esac;;
	    2) buy_guns;;
	    3) show_inventory;;
	    4) # Legal Work Menu
            clear_screen; echo "--- Honest Work ---"
            echo "1. Taxi Driver | 2. Delivery | 3. Mechanic | 4. Security | 5. Performer | 6. Back";
            read -r -p "Enter choice: " job_choice
            [[ ! "$job_choice" =~ ^[1-6]$ ]] && { echo "Invalid choice."; sleep 1; continue; }
            case "$job_choice" in
                1) work_job "taxi";; 2) work_job "delivery";; 3) work_job "mechanic";;
                4) work_job "security";; 5) work_job "performer";; 6) ;;
            esac;;
	    5) # Criminal Activity Menu
            clear_screen; echo "--- Criminal Activities ---"
            echo "1. Rob Store | 2. Carjack | 3. Gang War | 4. Heist | 5. Back";
            read -r -p "Enter choice: " criminal_choice
            [[ ! "$criminal_choice" =~ ^[1-5]$ ]] && { echo "Invalid choice."; sleep 1; continue; }
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
             read -r -p "Load game? Unsaved progress will be lost. (y/n): " confirm
             if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                 load_game # Load game handles messages and continues loop
             else echo "Load cancelled."; sleep 1; fi ;;
	    'm') play_music;;
	    'a') about_music_sfx;;
        'x')
             read -r -p "Are you sure you want to exit? (y/n): " confirm
             if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                 # Optional: Auto-save before exit?
                 # read -r -p "Save before exiting? (y/n): " save_confirm
                 # if [[ "$save_confirm" == "y" || "$save_confirm" == "Y" ]]; then save_game; fi
                 cleanup_and_exit # Use cleanup function
             fi ;;
	    *) echo "Invalid choice '$choice'."; sleep 1;;
	esac
    # Loop continues
done

# Should not be reached, but attempt cleanup if it ever does
cleanup_and_exit
