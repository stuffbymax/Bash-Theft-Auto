#!/bin/bash
# ver 2.2.1
# Bash-Theft-Auto music © 2024 by stuffbymax - Martin Petik is licensed under CC BY 4.0
# https://creativecommons.org/licenses/by/4.0/

# set -e # Uncomment this for stricter error checking if desired, but might exit too easily
BASEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Cleanup Function and Trap ---
cleanup_and_exit() {
	echo -e "\nCleaning up and exiting..."
	if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
		echo "Stopping music (PID: $music_pid)..."
		kill "$music_pid" &>/dev/null
		wait "$music_pid" 2>/dev/null
		music_pid=""
	fi
	stty echo
	echo "Cleanup complete. Goodbye."
	exit 0
}
trap cleanup_and_exit SIGINT SIGTERM SIGHUP

# --- Global Variables ---
player_name=""
location="Los Santos"
cash=0
health=100
declare -a guns=()
declare -a items=()
declare -A drugs=()
declare -A skills=()
body_armor_equipped=false
SAVE_DIR="saves"
declare -A gun_attributes=()
music_pid=""
wanted_level=0 # Player's current wanted level (0-5 stars)
MAX_WANTED_LEVEL=5
declare -a owned_vehicles=() # Array to store names of owned vehicles
declare -A vehicle_types=( ["Sedan"]=2000 ["Motorcycle"]=1500 ["Truck"]=2500 ["Sports Car"]=5000 ) # Name=Price
declare -A market_conditions=() # Stores current event modifiers ["crackdown_multiplier", "demand_multiplier", "event_message"]

gun_attributes=(
	["Pistol"]="success_bonus=5"
	["Shotgun"]="success_bonus=10"
	["SMG"]="success_bonus=15"
	["Rifle"]="success_bonus=20"
	["Sniper"]="success_bonus=25"
)

declare -A default_skills=( ["driving"]=1 ["strength"]=1 ["charisma"]=1 ["stealth"]=1 ["drug_dealer"]=1 )
declare -A default_drugs=( ["Weed"]=0 ["Cocaine"]=0 ["Heroin"]=0 ["Meth"]=0 )

# --- Clock System ---
game_day=1
game_hour=8
PAYOUT_HOUR=0 # Midnight

# --- Gang System ---
player_gang="None"
player_gang_rank="Outsider" # Internal state, "N/A" is used for display
player_respect=0
declare -a player_recruits=() # Format: "Name:Strength:Upkeep"
max_recruits=2
declare -A gang_upgrades=() # Format: ["upgrade_name"]=level
declare -A gang_relations=() # Format: ["gang_name"]="War/Hostile/Neutral"

declare -A GANG_RANKS_RESPECT=(
    ["Outsider"]=0
    ["Associate"]=100
    ["Soldier"]=500
    ["Enforcer"]=1500
    ["Lieutenant"]=4000
    ["Underboss"]=10000
    ["Boss"]=25000
)
declare -a GANG_RANK_HIERARCHY=("Outsider" "Associate" "Soldier" "Enforcer" "Lieutenant" "Underboss" "Boss")
GANG_CREATION_RESPECT_REQ=1500
declare -A GANG_HOME_CITY

# --- World Data ---
declare -A territory_owner
declare -A district_heat
declare -A available_properties
declare -A owned_businesses

# BTA_GANG_SYSTEM: Initialize world data
initialize_world_data() {
    territory_owner=(
        ["Los Santos|Idlewood"]="Ballas"
        ["Los Santos|East Los Santos"]="Vagos"
        ["Los Santos|Verdant Bluffs"]="Grove Street"
        ["Los Santos|Downtown"]="Unaffiliated"
        ["Los Santos|Docks"]="Unaffiliated"
        ["San Fierro|Chinatown"]="Triads"
        ["San Fierro|Doherty"]="Unaffiliated"
        ["San Fierro|Easter Basin"]="Da Nang Boys"
        ["San Fierro|Downtown"]="Unaffiliated"
        ["Las Venturas|The Strip"]="Leone Family"
        ["Las Venturas|Roca Escalante"]="Sindacco Family"
        ["Las Venturas|Redsands East"]="Unaffiliated"
        ["Las Venturas|Old Venturas Strip"]="Unaffiliated"
    )
    district_heat=(
        ["Los Santos"]=10 ["San Fierro"]=5 ["Las Venturas"]=15 ["Liberty City"]=20 ["Vice City"]=5
    )
    available_properties=(
        ["LS Car Wash"]="15000:Los Santos:Legal"
        ["LS Warehouse"]="25000:Los Santos:IllegalFront"
        ["SF Pizza Shop"]="20000:San Fierro:Legal"
        ["SF Auto Repair"]="35000:San Fierro:Legal"
        ["SF Shipping Depot"]="60000:San Fierro:IllegalFront"
        ["LV Chapel"]="18000:Las Venturas:Legal"
        ["LV Casino Front"]="100000:Las Venturas:IllegalFront"
        ["LV Chop Shop"]="45000:Las Venturas:IllegalFront"
    )
    owned_businesses=()
    
    GANG_HOME_CITY=(
        ["Grove Street"]="Los Santos" ["Ballas"]="Los Santos" ["Vagos"]="Los Santos"
        ["Triads"]="San Fierro" ["Da Nang Boys"]="San Fierro"
        ["Leone Family"]="Las Venturas" ["Sindacco Family"]="Las Venturas"
    )

    # Initialize gang systems for a new game
    player_recruits=()
    gang_upgrades=( ["safe_house"]=0 ["weapon_locker"]=0 ["smuggling_routes"]=0 )
    gang_relations=()
    apply_gang_upgrades # Set initial values like max_recruits
}

# --- Dependency Check ---
mpg123_available=true
if ! command -v mpg123 &> /dev/null; then
	echo "###########################################################"
	echo "# Warning: 'mpg123' command not found.                    #"
	echo "# Sound effects and music require mpg123.                 #"
	echo "# On Debian/Ubuntu: sudo apt install mpg123               #"
	echo "###########################################################"
	read -r -p "Press Enter to continue without sound..."
	mpg123_available=false
fi
if ! command -v bc &> /dev/null; then
	echo "############################################################"
	echo "# Warning: 'bc' command not found.                         #"
	echo "# Advanced drug market calculations require bc.            #"
	echo "# On Debian/Ubuntu: sudo apt install bc                    #"
	echo "############################################################"
	read -r -p "Press Enter to continue with basic market calculations..."
fi


# --- Sound Effects Setup ---
sfx_dir="sfx"

play_sfx_mpg() {
	if ! $mpg123_available; then return 1; fi
	local sound_name="$1"
	local sound_file="$BASEDIR/$sfx_dir/${sound_name}.mp3"
	if [[ -f "$sound_file" ]]; then
		if command -v mpg123 &> /dev/null; then
			 mpg123 -q "$sound_file" &>/dev/null &
			return 0
		fi
	fi
	return 1
}

# --- Plugin Loading ---
plugin_dir="plugins"
if [[ -d "$BASEDIR/$plugin_dir" ]]; then
	while IFS= read -r -d $'\0' plugin_script; do
		[[ -f "$plugin_script" ]] && source "$plugin_script"
	done < <(find "$BASEDIR/$plugin_dir" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)
fi

# --- Functions ---

clear_screen() {
	clear
	printf "\e[93m============================================================\e[0m\n"
	printf "\e[1;43m|                       Bash Theft Auto                      |\e[0m\n"
	printf "\e[93m============================================================\e[0m\n"
    printf " Day: %-10d Time: %02d:00\n" "$game_day" "$game_hour"
	printf " Player: %-15s Location: %s\n" "$player_name" "$location"
	printf " Cash: \$%-19d Health: %d%%\n" "$cash" "$health"
	if $body_armor_equipped; then printf " Armor: \e[1;32mEquipped\e[0m"; else printf " Armor: \e[1;31mNone\e[0m    "; fi
	local stars=""; for ((i=0; i<wanted_level; i++)); do stars+="*"; done
	printf " | Wanted: \e[1;31m%-5s\e[0m\n" "$stars"
    local display_gang="$player_gang"
    local display_rank="$player_gang_rank"
    if [[ "$player_gang" == "None" ]]; then
        display_gang="N/A"
        display_rank="N/A"
    fi
	printf " Gang: %-20s Rank: %s\n" "$display_gang" "$display_rank"
    printf " Respect: %-16d District Heat: %s\n" "${player_respect}" "${district_heat[$location]:-0}"
	printf "\e[1;34m============================================================\e[0m\n"
}

about_music_sfx() {
	clear_screen
	echo "-----------------------------------------"
	echo "|  About the Music and Sound Effects    |"
	echo "-----------------------------------------"
	echo ""
	echo "Music and some SFX © 2024 by stuffbymax - Martin Petik"
	echo "Licensed under CC BY 4.0:"
	echo "https://creativecommons.org/licenses/by/4.0/"
	echo "for more information check the Creators.md in /sfx"
	echo ""
	echo "Full game code is licensed under the MIT License."
	echo "https://github.com/stuffbymax/Bash-Theft-Auto/blob/main/LICENSE"
	echo ""
	echo "Thank you for playing!"
	echo "-----------------------------------------"
	read -r -p "Press Enter to return..."
}

check_health() {
	if (( health <= 0 )); then
		health=0
		clear_screen
		echo -e "\n      \e[1;31m W A S T E D \e[0m\n"
		play_sfx_mpg "wasted"
		echo "You collapsed from your injuries..."
		sleep 1
        local respect_loss=$(( RANDOM % 50 + 25 ))
        echo "You lost ${respect_loss} Respect for being taken down."
        player_respect=$((player_respect - respect_loss))
        (( player_respect < 0 )) && player_respect=0
		read -r -p "Press Enter to go to the hospital..."
		hospitalize_player
		return 1
	fi
	return 0
}

award_respect() {
    local amount=$1
    player_respect=$((player_respect + amount))
    echo -e "You gained \e[1;32m${amount}\e[0m Respect."

    if [[ "$player_gang" != "None" ]]; then
        local current_rank_index=-1
        local next_rank_index=-1
        for i in "${!GANG_RANK_HIERARCHY[@]}"; do
            if [[ "${GANG_RANK_HIERARCHY[$i]}" == "$player_gang_rank" ]]; then
                current_rank_index=$i
                next_rank_index=$((i + 1))
                break
            fi
        done

        if (( next_rank_index < ${#GANG_RANK_HIERARCHY[@]} )); then
            local next_rank_name="${GANG_RANK_HIERARCHY[$next_rank_index]}"
            local respect_needed=${GANG_RANKS_RESPECT[$next_rank_name]}
            if (( player_respect >= respect_needed )); then
                player_gang_rank="$next_rank_name"
                play_sfx_mpg "win_big"
                echo -e "\n\e[1;32m*** RANK UP! ***\e[0m"
                echo "You have been promoted to \e[1;33m${player_gang_rank}\e[0m!"
            fi
        fi
    fi
}

# --- Clock & World State ---
calculate_and_apply_payouts() {
    clear_screen
    echo "--- Daily Payouts (Day ${game_day}, 00:00) ---"
    
    local territory_income=0
    local business_income=0
    local upkeep_cost=0

    if [[ "$player_gang" != "None" ]]; then
        for key in "${!territory_owner[@]}"; do
            if [[ "${territory_owner[$key]}" == "$player_gang" ]]; then
                territory_income=$((territory_income + 150))
            fi
        done
    fi
    
    local smuggling_level=${gang_upgrades[smuggling_routes]:-0}
    local smuggling_bonus=$((smuggling_level * 100))
    for prop in "${!owned_businesses[@]}"; do
        if [[ "${owned_businesses[$prop]}" == *"Legal"* ]]; then
            business_income=$((business_income + 200))
        elif [[ "${owned_businesses[$prop]}" == *"IllegalFront"* ]]; then
            business_income=$((business_income + 500 + smuggling_bonus))
        fi
    done

    for recruit in "${player_recruits[@]}"; do
        local upkeep; IFS=':' read -r - - upkeep <<< "$recruit"
        upkeep_cost=$((upkeep_cost + upkeep))
    done

    local total_income=$((territory_income + business_income))
    local net_change=$((total_income - upkeep_cost))
    cash=$((cash + net_change))

    echo "Territory Income:  \$${territory_income}"
    echo "Business Income:   \$${business_income}"
    echo "-----------------------------------"
    echo "Total Gross Income: \$${total_income}"
    echo "Recruit Upkeep:    -\$${upkeep_cost}"
    echo "-----------------------------------"
    if (( net_change >= 0 )); then
        echo -e "Net Daily Profit:  \e[1;32m\$${net_change}\e[0m"
    else
        echo -e "Net Daily Loss:    \e[1;31m\$${net_change}\e[0m"
    fi
    echo "-----------------------------------"

    for city_name in "${!district_heat[@]}"; do
        if (( ${district_heat[$city_name]} > 0 )); then
            district_heat[$city_name]=$(( ${district_heat[$city_name]} - 1 ))
        fi
    done
    echo "The heat has cooled down slightly across the cities."

    read -r -p "Press Enter to continue..."
}

### BUG FIX: The original clock logic for payouts was complex and unreliable.
### This version is simpler and correct: if the hour advances past 24, a new
### day has begun, and daily payouts are processed.
run_clock() {
    local hours_to_pass=$1
    if (( hours_to_pass == 0 )); then return; fi
    
    game_hour=$((game_hour + hours_to_pass))

    # Check for day rollovers and trigger daily events
    while (( game_hour >= 24 )); do
        game_hour=$((game_hour - 24))
        game_day=$((game_day + 1))
        # Since a new day has started, trigger the midnight payouts/events.
        calculate_and_apply_payouts
    done
}

update_world_state() {
    # This function can be expanded later to include more world events.
    # For now, it's a placeholder that ensures the clock runs.
    run_clock 0
}

# --- Game Actions ---
travel_to() {
	local travel_cost="$1"
	local new_location="$2"
	local current_location="$location"
	local use_own_vehicle=false
    local travel_time=4

	if [[ "$new_location" == "$current_location" ]]; then
		echo "You are already in $new_location."; read -r -p "Press Enter..."; return
	fi

	if (( ${#owned_vehicles[@]} > 0 )); then
		echo "You have vehicles available: (${owned_vehicles[*]})."
		read -r -p "Use your own vehicle for free travel? (y/n): " use_vehicle_choice
		if [[ "$use_vehicle_choice" == "y" || "$use_vehicle_choice" == "Y" ]]; then
			use_own_vehicle=true
			travel_cost=0
			echo "You hop into one of your vehicles."; play_sfx_mpg "car_start"
		fi
	fi

	if $use_own_vehicle || (( cash >= travel_cost )); then
		if ! $use_own_vehicle; then
			cash=$((cash - travel_cost))
            play_sfx_mpg "air"
		fi

        # ANIMATION INTEGRATION
		if $use_own_vehicle; then printf "Driving from %s to %s...\n" "$current_location" "$new_location"
		else printf "Traveling from %s to %s...\n" "$current_location" "$new_location"; fi
		if command -v air_travel_animation &> /dev/null; then
			if $use_own_vehicle && command -v drive_animation &> /dev/null; then
				drive_animation "$current_location" "$new_location"
			else
				air_travel_animation "$current_location" "$new_location"
			fi
		else
			echo -n "["; for _ in {1..20}; do echo -n "="; sleep 0.05; done; echo ">]"
		fi
        
        run_clock $travel_time
        location="$new_location"
        echo "You have arrived safely in $new_location after ${travel_time} hours."
		read -r -p "Press Enter..."
	else
		echo "Not enough cash (\$$travel_cost needed) to travel to $new_location."
		read -r -p "Press Enter..."
	fi
}

buy_guns() {
    run_clock 1
	local gun_choice=""
	clear_screen
	echo "--- Ammu-Nation ---"
	echo "1. Pistol(\$100) 2. Shotgun(\$250) 3. SMG(\$500) 4. Rifle(\$750) 5. Sniper(\$1000) 6. Leave"
	printf "Your Cash: \$%d\n" "$cash"
	read -r -p "Enter your choice: " gun_choice
	[[ ! "$gun_choice" =~ ^[0-9]+$ ]] && { echo "Invalid input."; read -r -p "Press Enter..."; return; }
	case "$gun_choice" in
		1) buy_gun "Pistol" 100;; 2) buy_gun "Shotgun" 250;; 3) buy_gun "SMG" 500;;
		4) buy_gun "Rifle" 750;; 5) buy_gun "Sniper" 1000;; 6) return;;
		*) echo "Invalid choice."; read -r -p "Press Enter...";;
	esac
}

buy_gun() {
	local gun_name="$1"
	local gun_cost="$2"
	for owned_gun in "${guns[@]}"; do
		if [[ "$owned_gun" == "$gun_name" ]]; then
			echo "Looks like you already got a $gun_name there, partner."; read -r -p "Press Enter..."; return
		fi
	done
	if (( cash >= gun_cost )); then
		play_sfx_mpg "cash_register"
        # ANIMATION INTEGRATION
        if command -v buy_animation &> /dev/null; then buy_animation "$gun_name"; fi
		cash=$((cash - gun_cost))
		guns+=("$gun_name")
		echo "One $gun_name, coming right up! That'll be \$$gun_cost."
		read -r -p "Press Enter..."
	else
		echo "Sorry pal, not enough cash for the $gun_name (\$$gun_cost needed)."
		read -r -p "Press Enter..."
	fi
}

buy_vehicle() {
    run_clock 1
	local vehicle_choice=""
	local i=1; local buyable_vehicles=()
	while true; do
		clear_screen; echo "--- Premium Deluxe Motorsport ---"
		buyable_vehicles=(); i=1
		for type in "${!vehicle_types[@]}"; do
			local price=${vehicle_types[$type]}
			printf " %d. %-12s (\$ %d)\n" "$i" "$type" "$price"
			buyable_vehicles+=("$type"); ((i++))
		done
		printf " %d. Leave\n" "$i"; printf "Your Cash: \$%d\n" "$cash"
		read -r -p "Enter your choice: " vehicle_choice
		if [[ "$vehicle_choice" == "$i" ]]; then echo "Come back when you want REAL quality!"; sleep 1; return; fi
		if ! [[ "$vehicle_choice" =~ ^[0-9]+$ ]] || (( vehicle_choice < 1 || vehicle_choice > ${#buyable_vehicles[@]} )); then
			echo "Invalid choice."; sleep 1; continue
		fi
		local chosen_type="${buyable_vehicles[$((vehicle_choice - 1))]}"
		local chosen_price="${vehicle_types[$chosen_type]}"
		if (( cash >= chosen_price )); then
			play_sfx_mpg "cash_register"; cash=$((cash - chosen_price))
			owned_vehicles+=("$chosen_type")
			echo "Congratulations on your new $chosen_type! That's \$${chosen_price}."
			play_sfx_mpg "car_start"; read -r -p "Press Enter..."
		else
			echo "Sorry, you need \$${chosen_price} for the $chosen_type."; read -r -p "Press Enter..."
		fi
	done
}

show_inventory() {
    run_clock 0
	clear_screen; echo "--- Inventory & Stats ---"
	printf " Cash: \$%d\n" "$cash"; printf " Health: %d%%\n" "$health"
	echo "--------------------------"
    echo " Gang Affiliation:"
    if [[ "$player_gang" == "None" ]]; then printf "  - Gang: N/A\n"; printf "  - Rank: N/A\n"
    else printf "  - Gang: %s\n" "$player_gang"; printf "  - Rank: %s\n" "$player_gang_rank"; fi
    printf "  - Respect: %d\n" "$player_respect"
	echo "--------------------------"
	echo " Guns:"; if (( ${#guns[@]} > 0 )); then printf "  - %s\n" "${guns[@]}"; else echo "  (None)"; fi
	echo "--------------------------"
	echo " Items:"; if (( ${#items[@]} > 0 )); then printf "  - %s\n" "${items[@]}"; else echo "  (None)"; fi
	echo "--------------------------"
	echo " Drugs:"; local drug_found=false
	for drug in "${!default_drugs[@]}"; do
		local amount=${drugs[$drug]:-0}
		if (( amount > 0 )); then printf "  - %-10s: %d units\n" "$drug" "$amount"; drug_found=true; fi
	done
	if ! $drug_found; then echo "  (None)"; fi
	echo "--------------------------"
	echo " Vehicles:"; if (( ${#owned_vehicles[@]} > 0 )); then printf "  - %s\n" "${owned_vehicles[@]}"; else echo "  (None)"; fi
	echo "--------------------------"
	echo " Skills:"; for skill in "${!default_skills[@]}"; do printf "  - %-12s: %d\n" "$skill" "${skills[$skill]:-0}"; done
	echo "--------------------------"
    echo " Owned Properties/Businesses:"
    if (( ${#owned_businesses[@]} > 0 )); then
        for prop in "${!owned_businesses[@]}"; do
            ### BUG FIX: Changed string replacement to use a pipe for better formatting.
            printf "  - %-20s (%s)\n" "$prop" "${owned_businesses[$prop]// / | }"
        done
    else
        echo "  (None)"
    fi
	echo "--------------------------"; read -r -p "Press Enter to return..."
}

### BUG FIX: The original code used a C-style ternary operator '(... ? ... : ...)'
### which is not valid syntax in Bash. It has been replaced with a standard,
### multi-line 'case' statement with 'if' conditions for correctness and readability.
work_job() {
	local job_type="$1"
    run_clock 4
	local earnings=0 base_earnings=0 skill_bonus=0; local min_earnings=0 max_earnings=0
	local relevant_skill_level=1 relevant_skill_name=""
	case "$location" in "Los Santos") min_earnings=20; max_earnings=60;; "San Fierro") min_earnings=25; max_earnings=70;; "Las Venturas") min_earnings=30; max_earnings=90;; "Vice City") min_earnings=15; max_earnings=50;; "Liberty City") min_earnings=35; max_earnings=100;; *) min_earnings=10; max_earnings=40;; esac
	base_earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings))

	case "$job_type" in
		"taxi"|"delivery")
			relevant_skill_name="driving"
			relevant_skill_level=${skills[$relevant_skill_name]:-1}
			if [[ "$job_type" == "delivery" ]]; then
				skill_bonus=$((relevant_skill_level * 4))
			else
				skill_bonus=$((relevant_skill_level * 3))
			fi
			play_sfx_mpg "taxi"
			;;
		"mechanic")
			relevant_skill_name="strength"
			relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$((relevant_skill_level * 1))
			play_sfx_mpg "mechanic"
			;;
		"security")
			relevant_skill_name="strength"
			relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$((relevant_skill_level * 2))
			play_sfx_mpg "security"
			;;
		"performer")
			relevant_skill_name="charisma"
			relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$((relevant_skill_level * 5))
			play_sfx_mpg "street_performer"
			;;
		"bus_driver")
			relevant_skill_name="driving"
			relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$((relevant_skill_level * 2))
			play_sfx_mpg "bus_driving"
			;;
		*)
			echo "Internal Error: Invalid Job Type '$job_type'"; return;;
	esac

    # ANIMATION INTEGRATION
    if command -v working_animation &> /dev/null; then
		working_animation "$job_type"
	else
		echo "Working as a $job_type..."; sleep 2
	fi

	earnings=$((base_earnings + skill_bonus)); (( earnings < 0 )) && earnings=0
	cash=$((cash + earnings)); clear_screen
	printf "Finished your shift. You earned \$%d (Base: \$%d, Skill Bonus: \$%d).\n" "$earnings" "$base_earnings" "$skill_bonus"
	if (( wanted_level > 0 && RANDOM % 4 == 0 )); then
			wanted_level=$((wanted_level - 1)); echo -e "\e[1;32mLaying low seems to have worked. Wanted Level Decreased!\e[0m"
	fi
	if [[ -n "$relevant_skill_name" ]] && (( RANDOM % 5 == 0 )); then
			skills[$relevant_skill_name]=$((relevant_skill_level + 1)); printf "Your \e[1;32m%s\e[0m skill increased!\n" "$relevant_skill_name"
	fi
	read -r -p "Press Enter to continue..."
}

street_race() {
    run_clock 2
	local driving_skill=${skills[driving]:-1}; local base_win_chance=40
	local win_chance=$(( base_win_chance + driving_skill * 5 )); (( win_chance > 90 )) && win_chance=90
	clear_screen; echo "--- Street Race ---"; echo "Win Chance: ${win_chance}%"; sleep 1
    
    # ANIMATION INTEGRATION
    if command -v race_animation &> /dev/null; then
		race_animation
	else
		echo "3... 2... 1... GO!"; sleep 1
	fi

	read -r -p "Press Enter for the race results..."
	local winnings=0 damage=0
	if (( RANDOM % 100 < win_chance )); then
		winnings=$((RANDOM % 151 + 100 + driving_skill * 10)); cash=$((cash + winnings))
		damage=$((RANDOM % 15 + 5)); if $body_armor_equipped; then local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction)); body_armor_equipped=false; fi
		health=$((health - damage)); clear_screen
		printf "\e[1;32m*** YOU WON THE RACE! ***\e[0m\n"
		printf "You collected \$%d.\n" "$winnings"; printf "Took minor damage (-%d%% health).\n" "$damage"
		play_sfx_mpg "win"; award_respect $((RANDOM % 15 + 10))
		if (( RANDOM % 3 == 0 )); then skills[driving]=$((driving_skill + 1)); printf "Your \e[1;32mdriving\e[0m skill increased!\n"; fi
	else
		damage=$((RANDOM % 31 + 15)); if $body_armor_equipped; then local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction)); body_armor_equipped=false; fi
		health=$((health - damage)); clear_screen
		printf "\e[1;31m--- YOU LOST THE RACE! ---\e[0m\n"; printf "You crashed and took %d%% damage.\n" "$damage"
        player_respect=$((player_respect - 5)); ((player_respect < 0)) && player_respect=0; echo "You lost 5 Respect."
		play_sfx_mpg "lose"
	fi
	check_health; read -r -p "Press Enter to continue..."
}

apply_gun_bonus() {
	local base_chance=$1; local action_message=$2; local current_chance=$base_chance
	local gun_bonus=0; local chosen_gun=""; local gun_found=false; local success_bonus=0
	if (( ${#guns[@]} == 0 )); then
		echo "You have no guns! This will be significantly harder."; gun_bonus=-15
	else
		echo "Available guns: ${guns[*]}"; read -r -p "Use a gun for this $action_message? (y/n): " use_gun
		if [[ "$use_gun" == "y" || "$use_gun" == "Y" ]]; then
			read -r -p "Which gun? (Enter exact name): " chosen_gun
			gun_found=false
			for gun in "${guns[@]}"; do if [[ "$gun" == "$chosen_gun" ]]; then gun_found=true; break; fi; done
			if $gun_found; then
				echo "You draw your $chosen_gun!"; play_sfx_mpg "gun_cock"
				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}"; gun_bonus=${success_bonus:-0}
					if (( gun_bonus > 0 )); then echo "The $chosen_gun gives a \e[1;32m+${gun_bonus}%%\e[0m success chance."; play_sfx_mpg "gun_shot"; fi
				fi
			else echo "You don't own '$chosen_gun'!"; fi
		else echo "Proceeding without using a gun."; gun_bonus=-5; fi
	fi
	current_chance=$((current_chance + gun_bonus))
	(( current_chance < 5 )) && current_chance=5; (( current_chance > 95 )) && current_chance=95
	echo "$current_chance"
}

visit_hospital() {
    run_clock 1
	local hospital_choice=""
	while true; do
		clear_screen; echo "--- County General Hospital ---"
		printf " Your Health: %d%% | Cash: \$%d\n" "$health" "$cash"
		echo "-------------------------------"
		echo " 1. Basic Treatment (\$50) | 2. Advanced Scan (\$100) | 3. Buy Health Pack (\$30) | 4. Buy Body Armor (\$75) | 5. Leave"
		read -r -p "Enter your choice: " hospital_choice
		[[ ! "$hospital_choice" =~ ^[0-9]+$ ]] && { echo "Invalid input."; sleep 1; continue; }
		case "$hospital_choice" in
			1) buy_hospital_item 50 "basic_treatment";; 2) buy_hospital_item 100 "advanced_treatment";;
			3) buy_hospital_item 30 "health_pack";; 4) buy_hospital_item 75 "body_armor";;
			5) echo "Leaving the hospital..."; sleep 1; return;; *) echo "Invalid choice."; sleep 1;;
		esac
	done
}

buy_hospital_item() {
	local item_cost="$1" item_type="$2"
	if (( cash >= item_cost )); then
		play_sfx_mpg "cash_register"; cash=$((cash - item_cost))
		case "$item_type" in
			"basic_treatment") health=100; echo "Health restored to 100%."; play_sfx_mpg "heal";;
			"advanced_treatment") health=110; echo "Health boosted to 110%!"; play_sfx_mpg "heal_adv";;
			"health_pack") items+=("Health Pack"); echo "You bought a Health Pack."; play_sfx_mpg "item_buy";;
			"body_armor")
				if $body_armor_equipped; then
					echo "You already have Body Armor."; cash=$((cash + item_cost)); play_sfx_mpg "error"
				else
					body_armor_equipped=true; echo "Body Armor equipped."; play_sfx_mpg "item_equip"
				fi
				;;
		esac
		read -r -p "Press Enter..."
	else
		echo "Not enough cash (\$$item_cost needed)."; read -r -p "Press Enter..."
	fi
}

rob_store() {
    run_clock 2
	local stealth_skill=${skills[stealth]:-1}
	local base_chance=$((15 + stealth_skill * 5))
	clear_screen; echo "--- Rob Store ---"
    # ANIMATION INTEGRATION
    if command -v robbing_animation &> /dev/null; then robbing_animation; else echo "Making your move..."; sleep 1; fi
	local final_success_chance=$(apply_gun_bonus "$base_chance" "robbery")
	echo "Calculating odds... Final success chance: ${final_success_chance}%"
	read -r -p "Press Enter to attempt the robbery..."
	if (( RANDOM % 100 < final_success_chance )); then
		local loot=$((RANDOM % 151 + 50 + stealth_skill * 10)); cash=$((cash + loot))
		health=$((health - (RANDOM % 16 + 5))); clear_screen
		printf "\e[1;32mSuccess!\e[0m You grabbed \$%d.\n" "$loot"; play_sfx_mpg "cash_register"
        award_respect $((RANDOM % 10 + 5)); district_heat["$location"]=$(( ${district_heat[$location]:-0} + 2 ))
        echo "Your actions increased the heat in this district."
		if (( RANDOM % 3 == 0 )); then skills[stealth]=$((stealth_skill + 1)); printf "Your \e[1;32mstealth\e[0m skill increased!\n"; fi
	else
		wanted_level=$((wanted_level + 1)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"
		local fine=$((RANDOM % 101 + 50 + wanted_level * 25)); cash=$((cash - fine)); (( cash < 0 )) && cash=0
		health=$((health - (RANDOM % 26 + 10 + wanted_level * 5))); clear_screen
		printf "\e[1;31mFailed!\e[0m Cops arrived quickly.\n"; printf "You were fined \$%d and took damage.\n" "$fine"
	fi
	check_health; read -r -p "Press Enter..."
}

burglary() {
    run_clock 4
	local stealth_skill=${skills[stealth]:-1}; local base_chance=$((5 + stealth_skill * 7))
	clear_screen; echo "--- Burglary ---"
    # ANIMATION INTEGRATION
    if command -v burglary_animation &> /dev/null; then burglary_animation; else echo "Looking for an entry point..."; sleep 1; fi
	play_sfx_mpg "burglary_stealth"
	local final_success_chance=$base_chance
	(( final_success_chance < 5 )) && final_success_chance=5; (( final_success_chance > 90 )) && final_success_chance=90
	echo "Assessing the risk... Final success chance: ${final_success_chance}%"; read -r -p "Press Enter..."
	if (( RANDOM % 100 < final_success_chance )); then
		local loot=$((RANDOM % 251 + 75 + stealth_skill * 15)); cash=$((cash + loot))
		health=$((health - (RANDOM % 11))); clear_screen
		printf "\e[1;32mSuccess!\e[0m You slipped in and out unseen, grabbing valuables worth \$%d.\n" "$loot"
		play_sfx_mpg "burglary_success"; award_respect $((RANDOM % 20 + 10)); district_heat["$location"]=$(( ${district_heat[$location]:-0} + 5 ))
		if (( RANDOM % 2 == 0 )); then skills[stealth]=$((stealth_skill + 1)); printf "Your \e[1;32mstealth\e[0m skill increased!\n"; fi
	else
		wanted_level=$((wanted_level + 1)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"
		local fine=$((RANDOM % 151 + 75 + wanted_level * 30)); cash=$((cash - fine)); (( cash < 0 )) && cash=0
		health=$((health - (RANDOM % 31 + 15 + wanted_level * 7))); clear_screen
		printf "\e[1;31mFailed!\e[0m You triggered an alarm or were spotted!\n"; printf "You were fined \$%d and took damage escaping.\n" "$fine"
		play_sfx_mpg "burglary_fail"
	fi
	check_health; read -r -p "Press Enter..."
}

heist() {
    run_clock 8
	local stealth_skill=${skills[stealth]:-1}; local base_chance=$((10 + stealth_skill * 6))
	clear_screen; echo "--- Plan Heist ---"
    # ANIMATION INTEGRATION
    if command -v heist_animation &> /dev/null; then heist_animation; else echo "Executing the plan..."; sleep 1; fi
	local final_success_chance=$(apply_gun_bonus "$base_chance" "heist")
	echo "Assessing security risks... Final success chance: ${final_success_chance}%"; read -r -p "Press Enter..."
	if (( RANDOM % 100 < final_success_chance )); then
		local loot=$((RANDOM % 501 + 250 + stealth_skill * 25)); cash=$((cash + loot))
		health=$((health - (RANDOM % 31 + 15))); clear_screen
		printf "\e[1;32m*** HEIST SUCCESSFUL! ***\e[0m\n You scored \$%d!\n" "$loot"; play_sfx_mpg "win_big"
        award_respect $((RANDOM % 100 + 50)); district_heat["$location"]=$(( ${district_heat[$location]:-0} + 15 ))
		if (( RANDOM % 2 == 0 )); then skills[stealth]=$((stealth_skill + 2)); printf "Your \e[1;32mstealth\e[0m skill increased significantly!\n"; fi
	else
		wanted_level=$((wanted_level + 2)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"
		local fine=$((RANDOM % 201 + 100 + wanted_level * 50)); cash=$((cash - fine)); (( cash < 0 )) && cash=0
		health=$((health - (RANDOM % 41 + 20 + wanted_level * 10))); clear_screen
		printf "\e[1;31m--- HEIST FAILED! ---\e[0m\n Security was too tight.\n"; printf "You lost \$%d and took damage.\n" "$fine"
		play_sfx_mpg "lose_big"
	fi
	check_health; read -r -p "Press Enter..."
}

carjack() {
    run_clock 1
	local driving_skill=${skills[driving]:-1}; local stealth_skill=${skills[stealth]:-1}
	local base_chance=$(( 20 + driving_skill * 2 + stealth_skill * 3 ))
	clear_screen; echo "--- Carjack ---"
    # ANIMATION INTEGRATION
    if command -v carjacking_animation &> /dev/null; then carjacking_animation; else echo "Spotting a target..."; sleep 1; fi
	local final_success_chance=$(apply_gun_bonus "$base_chance" "carjacking")
	echo "Choosing a target... Final success chance: ${final_success_chance}%"; read -r -p "Press Enter..."
	if (( RANDOM % 100 < final_success_chance )); then
		local possible_cars=("Sedan" "Truck" "Motorcycle")
		local stolen_car_type=${possible_cars[ RANDOM % ${#possible_cars[@]} ]}
		owned_vehicles+=("$stolen_car_type")
		cash=$((cash + (RANDOM % 51 + 20))); health=$((health - (RANDOM % 16 + 5))); clear_screen
		printf "\e[1;32mSuccess!\e[0m You boosted a \e[1;33m%s\e[0m!\n" "$stolen_car_type"
		play_sfx_mpg "car_start"; award_respect $((RANDOM % 5 + 1)); district_heat["$location"]=$(( ${district_heat[$location]:-0} + 1 ))
		if (( RANDOM % 4 == 0 )); then skills[driving]=$((driving_skill+1)); printf "Your \e[1;32mdriving\e[0m skill increased!\n"; fi
		if (( RANDOM % 4 == 0 )); then skills[stealth]=$((stealth_skill+1)); printf "Your \e[1;32mstealth\e[0m skill increased!\n"; fi
	else
		wanted_level=$((wanted_level + 1)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"
		local fine=$((RANDOM % 76 + 25 + wanted_level * 20)); cash=$((cash - fine)); (( cash < 0 )) && cash=0
		health=$((health - (RANDOM % 26 + 10 + wanted_level * 6))); clear_screen
		printf "\e[1;31mFailed!\e[0m The owner fought back.\n"; printf "You were fined \$%d and took damage.\n" "$fine"
	fi
	check_health; read -r -p "Press Enter..."
}

hospitalize_player() {
    run_clock 8
	local hospital_bill=200
	echo "The hospital patched you up. Bill: \$${hospital_bill}."
	if (( cash < hospital_bill )); then echo "They took all your cash (\$$cash)."; hospital_bill=$cash; fi
	cash=$((cash - hospital_bill)); health=50; body_armor_equipped=false
	if (( wanted_level > 0 )); then echo "The police lose interest. Wanted level cleared."; wanted_level=0; fi
	play_sfx_mpg "cash_register"; printf "You leave with \$%d cash and %d%% health.\n" "$cash" "$health"
	read -r -p "Press Enter..."
}

hire_hooker() {
    run_clock 1
	local charisma_skill=${skills[charisma]:-1}
	local cost_reduction=$((charisma_skill * 3))
	local min_cost=$((40 - cost_reduction)); (( min_cost < 15 )) && min_cost=15
	local max_cost=$((100 - cost_reduction)); (( max_cost <= min_cost )) && max_cost=$((min_cost + 20))
	local hooker_cost=$(( RANDOM % (max_cost - min_cost + 1) + min_cost ))
	clear_screen; echo "--- Seeking Company ---"; echo "You approach someone... They quote you \$$hooker_cost."
	if (( cash >= hooker_cost )); then
		read -r -p "Accept the offer? (y/n): " accept
		if [[ "$accept" == "y" || "$accept" == "Y" ]]; then
			play_sfx_mpg "cash_register"; cash=$(( cash - hooker_cost ))
            local health_gain=$(( RANDOM % 21 + 15 )); local previous_health=$health
			health=$(( health + health_gain ))
			local max_health=100; (( previous_health > 100 )) && max_health=$previous_health; (( health > max_health )) && health=$max_health
			local actual_gain=$((health - previous_health)); clear_screen; printf "You paid \$%d.\n" "$hooker_cost"
			if (( actual_gain > 0 )); then printf "Feeling refreshed, you gained \e[1;32m%d%%\e[0m health.\n" "$actual_gain"; fi
			play_sfx_mpg "hooker"
			if (( RANDOM % 5 == 0 )); then skills[charisma]=$((charisma_skill+1)); printf "Your \e[1;32mcharisma\e[0m skill increased!\n"; fi
		else echo "You decided against it and walked away."; fi
	else echo "You don't have enough cash (\$$hooker_cost needed)."; fi
	read -r -p "Press Enter to continue..."
}

update_market_conditions() {
	local event_chance=15
	market_conditions["crackdown_multiplier"]=1.0; market_conditions["demand_multiplier"]=1.0
	market_conditions["buy_multiplier"]=1.0; market_conditions["event_message"]=""
	if (( RANDOM % 100 < event_chance )); then
		if (( RANDOM % 2 == 0 )); then
			market_conditions["crackdown_multiplier"]=0.6; market_conditions["buy_multiplier"]=1.1
			market_conditions["event_message"]="Police Crackdown! Prices are unfavorable."; play_sfx_mpg "police_siren"
		else
			market_conditions["demand_multiplier"]=1.5; market_conditions["buy_multiplier"]=1.1
			market_conditions["event_message"]="High Demand! Good time to sell!"; play_sfx_mpg "cash_register"
		fi
	fi
}

drug_transaction() {
	local action="$1" drug_name="$2" base_price="$3" drug_amount="$4"
	local drug_dealer_skill=${skills[drug_dealer]:-1}
	if ! [[ "$drug_amount" =~ ^[1-9][0-9]*$ ]]; then echo "Invalid amount '$drug_amount'."; return 1; fi
	local price_fluctuation=$(( RANDOM % 21 - 10 ))
    local location_modifier=0
	### REFACTOR: Replaced confusing one-liner with a clear case statement.
    case "$location" in
        "Liberty City") location_modifier=15;;
        "Las Venturas") location_modifier=10;;
        "Vice City")    location_modifier=-15;;
    esac

	local current_market_price=$(( base_price + (base_price * (price_fluctuation + location_modifier) / 100) )); (( current_market_price < 1 )) && current_market_price=1
	local buy_multiplier=${market_conditions["buy_multiplier"]:-1.0}
	local sell_multiplier=${market_conditions["crackdown_multiplier"]:-1.0}
	if [[ -v market_conditions["demand_multiplier"] ]]; then sell_multiplier=$(echo "scale=2; $sell_multiplier * ${market_conditions["demand_multiplier"]}" | bc); fi
    
    # ANIMATION INTEGRATION
    if command -v drug_transaction_animation &> /dev/null; then drug_transaction_animation "$action"; fi

	if [[ "$action" == "buy" ]]; then
		local final_price=$(echo "scale=0; $current_market_price * $buy_multiplier / 1" | bc ); (( final_price < 1 )) && final_price=1
		local cost=$((final_price * drug_amount))
		if (( cash >= cost )); then
			cash=$((cash - cost)); drugs["$drug_name"]=$(( ${drugs[$drug_name]:-0} + drug_amount ))
			printf "Bought \e[1;33m%d\e[0m units of \e[1;33m%s\e[0m for \e[1;31m\$%d\e[0m.\n" "$drug_amount" "$drug_name" "$cost"
			play_sfx_mpg "cash_register" ; return 0
		else
			printf "Not enough cash. Need \$%d, you have \$%d.\n" "$cost" "$cash" ; return 1
		fi
	elif [[ "$action" == "sell" ]]; then
		local current_inventory=${drugs[$drug_name]:-0}
		if (( current_inventory >= drug_amount )); then
			local price_bonus_percent=$((drug_dealer_skill * 2))
			local skill_adjusted_price=$(( current_market_price + (current_market_price * price_bonus_percent / 100) ))
			local final_price=$(echo "scale=0; $skill_adjusted_price * $sell_multiplier / 1" | bc ); (( final_price < 1 )) && final_price=1
			local income=$((final_price * drug_amount))
			cash=$((cash + income)); drugs["$drug_name"]=$((current_inventory - drug_amount))
			printf "Sold \e[1;33m%d\e[0m units of \e[1;33m%s\e[0m for \e[1;32m\$%d\e[0m.\n" "$drug_amount" "$drug_name" "$income"
			play_sfx_mpg "cash_register"
			if (( RANDOM % 2 == 0 )); then skills[drug_dealer]=$((drug_dealer_skill + 1)); printf "Your \e[1;32mdrug dealing\e[0m skill increased!\n"; fi; return 0
		else
			printf "Not enough %s to sell. You have %d units.\n" "$drug_name" "$current_inventory" ; return 1
		fi
	fi
}

buy_drugs() {
    run_clock 1; update_market_conditions
	local drug_choice="" drug_amount=""; declare -A drug_prices=( ["Weed"]=10 ["Cocaine"]=50 ["Heroin"]=100 ["Meth"]=75 )
	local drug_names=("Weed" "Cocaine" "Heroin" "Meth")
	clear_screen; echo "--- Drug Dealer (Buy) ---"
	printf " Location: %-15s | Cash: \$%d\n" "$location" "$cash"
	if [[ -n "${market_conditions["event_message"]}" ]]; then printf " \e[1;36mMarket News: %s\e[0m\n" "${market_conditions["event_message"]}"; fi
	echo "---------------------------"; echo " Available Inventory (Approx Price/unit):"
	
	### REFACTOR: Replaced confusing one-liner with a clear case statement.
    local location_modifier=0
    case "$location" in
        "Liberty City") location_modifier=15;;
        "Las Venturas") location_modifier=10;;
        "Vice City")    location_modifier=-15;;
    esac

	local i=1
	for name in "${drug_names[@]}"; do
		local base_p=${drug_prices[$name]}
		local approx_p=$(( base_p + (base_p * location_modifier / 100) ))
		local buy_mult=${market_conditions["buy_multiplier"]:-1.0}
		if command -v bc &> /dev/null; then approx_p=$(echo "scale=0; $approx_p * $buy_mult / 1" | bc); fi
		(( approx_p < 1 )) && approx_p=1; printf " %d. %-10s (\~$%d/unit)\n" "$i" "$name" "$approx_p"; ((i++))
	done
	echo "---------------------------"; printf " %d. Leave\n" "$i"; echo "---------------------------"
	read -r -p "Choose drug to buy (number): " drug_choice
	if [[ "$drug_choice" == "$i" ]]; then return; fi
	if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#drug_names[@]} )); then echo "Invalid choice."; sleep 1; return; fi
	local chosen_drug_name="${drug_names[$((drug_choice - 1))]}"; local chosen_drug_price="${drug_prices[$chosen_drug_name]}"
	read -r -p "Enter amount of $chosen_drug_name to buy: " drug_amount
	drug_transaction "buy" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"; read -r -p "Press Enter..."
}

sell_drugs() {
    run_clock 1; update_market_conditions
	local drug_choice="" drug_amount=""; declare -A drug_sell_prices=( ["Weed"]=15 ["Cocaine"]=75 ["Heroin"]=150 ["Meth"]=100 )
	local drug_names=("Weed" "Cocaine" "Heroin" "Meth")
	clear_screen; echo "--- Drug Dealer (Sell) ---"; printf " Location: %-15s | Cash: \$%d\n" "$location" "$cash"
	if [[ -n "${market_conditions["event_message"]}" ]]; then printf " \e[1;36mMarket News: %s\e[0m\n" "${market_conditions["event_message"]}"; fi
	echo "--------------------------"; echo " Your Inventory (Approx Sell Value/unit):"
	
	### REFACTOR: Replaced confusing one-liner with a clear case statement.
    local location_modifier=0
    case "$location" in
        "Liberty City") location_modifier=15;;
        "Las Venturas") location_modifier=10;;
        "Vice City")    location_modifier=-15;;
    esac

	local i=1; local available_to_sell=()
	for name in "${drug_names[@]}"; do
		local inventory_amount=${drugs[$name]:-0}
		if (( inventory_amount > 0 )); then
			local base_p=${drug_sell_prices[$name]}; local dealer_skill=${skills[drug_dealer]:-1}; local skill_bonus_p=$(( dealer_skill * 2 ))
			local approx_p=$(( base_p + (base_p * ( location_modifier + skill_bonus_p ) / 100) ))
			local sell_mult=${market_conditions["crackdown_multiplier"]:-1.0}
			if [[ -v market_conditions["demand_multiplier"] ]]; then if command -v bc &> /dev/null; then sell_mult=$(echo "scale=2; $sell_mult * ${market_conditions["demand_multiplier"]}" | bc); fi; fi
			if command -v bc &> /dev/null; then approx_p=$(echo "scale=0; $approx_p * $sell_mult / 1" | bc); fi
			(( approx_p < 1 )) && approx_p=1; printf " %d. %-10s (%d units) ~\$%d/unit\n" "$i" "$name" "$inventory_amount" "$approx_p"
			available_to_sell+=("$name"); ((i++))
		fi
	done
	if (( ${#available_to_sell[@]} == 0 )); then echo "--------------------------"; echo "You have no drugs to sell."; read -r -p "Press Enter to leave..." ; return; fi
	echo "--------------------------"; printf " %d. Leave\n" "$i"; echo "--------------------------"
	read -r -p "Choose drug to sell (number): " drug_choice
	if [[ "$drug_choice" == "$i" ]]; then return; fi
	if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#available_to_sell[@]} )); then echo "Invalid choice."; sleep 1; return; fi
	local chosen_drug_name="${available_to_sell[$((drug_choice - 1))]}"; local chosen_drug_price="${drug_sell_prices[$chosen_drug_name]}"
	local current_inventory=${drugs[$chosen_drug_name]}
	read -r -p "Sell how many units of $chosen_drug_name? (Max: $current_inventory): " drug_amount
	drug_transaction "sell" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"; read -r -p "Press Enter..."
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


# --- Gang System Functions ---
set_initial_gang_relations() {
    gang_relations=(); for rival in "${!GANG_HOME_CITY[@]}"; do if [[ "$rival" != "$player_gang" ]]; then gang_relations["$rival"]="Hostile"; fi; done
    if [[ "$player_gang" == "Grove Street" ]]; then gang_relations["Ballas"]="War"; gang_relations["Vagos"]="War"; fi
}

apply_gang_upgrades() {
    local safe_house_level=${gang_upgrades[safe_house]:-0}; max_recruits=$(( 2 + safe_house_level * 2 ))
}

join_or_create_gang_menu() {
    while true; do
        clear_screen; echo "--- Faction Options ---"; echo "You're a free agent. What's your next move?"; echo "------------------------------------------"
        echo "1. Join an Existing Faction (in this city)"
        if (( player_respect >= GANG_CREATION_RESPECT_REQ )); then
            echo -e "2. Create Your Own Faction (Req: \e[1;32m${GANG_CREATION_RESPECT_REQ}\e[0m Respect)"
        else echo -e "2. Create Your Own Faction (\e[1;31mLocked\e[0m - Requires ${GANG_CREATION_RESPECT_REQ} Respect)"; fi
        echo "3. Back to Gang Menu"; echo "------------------------------------------"
        read -r -p "Enter your choice: " choice
        case "$choice" in
            1) join_gang_interface; if [[ "$player_gang" != "None" ]]; then break; fi;;
            2) if (( player_respect >= GANG_CREATION_RESPECT_REQ )); then create_own_gang; if [[ "$player_gang" != "None" ]]; then break; fi
               else echo "You don't have enough respect to start your own crew yet."; read -r -p "Press Enter..."; fi;;
            3) return;; *) echo "Invalid choice." && sleep 1;;
        esac
    done
}

show_gang_menu() {
    run_clock 0
    while true; do
        clear_screen; echo "--- Gang & Empire Management ---"
        echo "1. View Territory Map (Current City)"; echo "2. Manage Businesses"; echo "3. Initiate Gang War (in this city)"
        if [[ "$player_gang" == "None" ]]; then echo "4. Join or Create a Faction"
        else echo "4. Manage Recruits"; echo "5. Gang Upgrades"; echo "6. Diplomacy"; fi
        echo "B. Back to Main Menu"; read -r -p "Enter your choice: " choice
        case "$choice" in
            1) show_territory_map ;; 2) manage_businesses ;; 3) initiate_gang_war ;;
            4) if [[ "$player_gang" == "None" ]]; then join_or_create_gang_menu; else manage_recruits_menu; fi;;
            5) if [[ "$player_gang" != "None" ]]; then gang_upgrades_menu; else echo "Invalid choice." && sleep 1; fi;;
            6) if [[ "$player_gang" != "None" ]]; then diplomacy_menu; else echo "Invalid choice." && sleep 1; fi;;
            'b'|'B') return ;; *) echo "Invalid choice." && sleep 1;;
        esac
    done
}

show_territory_map() {
    run_clock 0; clear_screen; echo "--- ${location} Territory Map ---"; echo "---------------------------------"
    local territory_found=false
    for key in "${!territory_owner[@]}"; do
        local owner="${territory_owner[$key]}"; local city district; IFS='|' read -r city district <<< "$key"
        if [[ "$city" == "$location" ]]; then
            territory_found=true; local color="\e[0m"
            if [[ "$owner" == "$player_gang" && "$player_gang" != "None" ]]; then color="\e[1;36m"
            elif [[ "$owner" == "Grove Street" ]]; then color="\e[1;32m"
            elif [[ "$owner" == "Ballas" || "$owner" == "Leone Family" ]]; then color="\e[1;35m"
            elif [[ "$owner" == "Vagos" || "$owner" == "Triads" ]]; then color="\e[1;33m"
            elif [[ "$owner" == "Da Nang Boys" || "$owner" == "Sindacco Family" ]]; then color="\e[1;31m"
            elif [[ "$owner" != "Unaffiliated" ]]; then color="\e[1;37m"; fi
            printf "| %-20s | Owner: %b%s\e[0m\n" "$district" "$color" "$owner"
        fi
    done
    if ! $territory_found; then echo "No contested territories in this city."; fi
    echo "---------------------------------"; read -r -p "Press Enter to return..."
}

manage_businesses() {
    run_clock 1; clear_screen; echo "--- Business Management ---"
    echo "1. Buy New Property (in ${location})"; echo "2. Manage Owned Properties (Global)"; echo "B. Back"
    read -r -p "Choice: " choice
    case "$choice" in 1) buy_property ;; 2) manage_owned_property ;; 'b'|'B') return ;; *) echo "Invalid." && sleep 1;; esac
}
buy_property() {
    clear_screen; echo "--- Real Estate For Sale in ${location} ---"
    local i=1; local -a prop_keys=(); local -a prop_costs=(); local -a prop_types=()
    for prop_name in "${!available_properties[@]}"; do
        if [[ ! -v "owned_businesses[$prop_name]" ]]; then
            local prop_details="${available_properties[$prop_name]}"; local price prop_city prop_type
            IFS=':' read -r price prop_city prop_type <<< "$prop_details"
            if [[ "$prop_city" == "$location" ]]; then
                printf "%d. %-25s (\$%d) - [%s]\n" "$i" "$prop_name" "$price" "$prop_type"
                prop_keys+=("$prop_name"); prop_costs+=("$price"); prop_types+=("$prop_type"); ((i++))
            fi
        fi
    done
    if (( ${#prop_keys[@]} == 0 )); then echo "No properties are currently for sale in this city."; fi
    echo "----------------------------------------"; echo "B. Back"; read -r -p "Which property to buy? " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#prop_keys[@]} )); then
        local index=$((choice - 1)); local prop_to_buy="${prop_keys[$index]}"
        local prop_cost="${prop_costs[$index]}"; local prop_type="${prop_types[$index]}"
        if (( cash >= prop_cost )); then
            cash=$((cash - prop_cost)); owned_businesses["$prop_to_buy"]="type=$prop_type status=Idle"
            echo "You have purchased the $prop_to_buy for \$${prop_cost}!"; play_sfx_mpg "cash_register"
        else echo "Not enough cash."; fi
    elif [[ "$choice" != "b" && "$choice" != "B" ]]; then echo "Invalid selection."; fi
    read -r -p "Press Enter..."
}
manage_owned_property() {
    clear_screen; echo "--- Your Properties (Global) ---"
    if (( ${#owned_businesses[@]} == 0 )); then echo "You don't own any properties."; read -r -p "Press Enter..."; return; fi
    local i=1; local -a owned_prop_keys=()
    for prop in "${!owned_businesses[@]}"; do printf "%d. %-25s (%s)\n" "$i" "$prop" "${owned_businesses[$prop]}"; owned_prop_keys+=("$prop"); ((i++)); done
    echo "--------------------------------"; echo "B. Back"; read -r -p "Select property to manage: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#owned_prop_keys[@]} )); then
        local prop_to_manage="${owned_prop_keys[$((choice-1))]}"; echo "Managing $prop_to_manage..."
        echo "This feature (upgrading, production, selling) is under development."
    elif [[ "$choice" != "b" && "$choice" != "B" ]]; then echo "Invalid selection."; fi
    read -r -p "Press Enter..."
}
create_own_gang() {
    run_clock 1; clear_screen; echo "--- Found Your Own Gang ---"; echo "You've got the respect to lead. Now you need a name."
    read -r -p "Enter the name for your new gang: " new_gang_name
    if [[ -z "$new_gang_name" || "$new_gang_name" == "None" || "$new_gang_name" == "Unaffiliated" || -v "GANG_HOME_CITY[$new_gang_name]" ]]; then
        echo "Invalid or reserved name. A gang needs a unique title."; read -r -p "Press Enter..."; return
    fi
    player_gang="$new_gang_name"; player_gang_rank="Boss"; set_initial_gang_relations
    play_sfx_mpg "win_big"; echo -e "\nThe \e[1;36m${player_gang}\e[0m are now on the map!"
    echo "You are their leader, with the rank of ${player_gang_rank}."; echo "You have no territory yet. It's time to earn it."
    read -r -p "Press Enter..."
}
join_gang_interface() {
    run_clock 1
    if [[ "$player_gang" != "None" ]]; then echo "You are already in the $player_gang gang."; read -r -p "Press Enter..."; return; fi
    local i=1; local -a menu_options=(); clear_screen
    echo "--- Join a Faction in ${location} ---"; echo "Crews in this city are looking for fresh blood."; echo "------------------------------------------------"
    for gang in "${!GANG_HOME_CITY[@]}"; do
        if [[ "${GANG_HOME_CITY[$gang]}" == "$location" ]]; then
            printf " %d. Join the %s\n" "$i" "$gang"; menu_options+=("$gang"); ((i++))
        fi
    done
    if (( ${#menu_options[@]} == 0 )); then echo " No major gangs are looking for recruits here."; read -r -p "Press Enter..."; return; fi
    echo "------------------------------------------------"; local back_option_number=$i; printf " %d. Back\n" "$back_option_number"; echo "------------------------------------------------"
    read -r -p "Your choice: " choice
    if [[ "$choice" == "$back_option_number" ]]; then return
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#menu_options[@]} )); then
        local new_gang="${menu_options[$((choice-1))]}"; echo "You approach the ${new_gang} crew..."; sleep 2
        echo "'So you want to roll with us? You gotta prove yourself first.'"
        if (( cash >= 200 )); then
            echo "They ask for a \$200 'tribute' to show you're serious."; read -r -p "Pay the tribute? (y/n): " pay
            if [[ "$pay" == "y" ]]; then
                cash=$((cash-200)); player_gang="$new_gang"; player_gang_rank="Associate"; set_initial_gang_relations
                echo "You've paid your dues. Welcome to ${player_gang}."; award_respect 100
            else echo "You walked away. They won't be asking again."; fi
        else echo "You don't even have the cash to get their attention. Come back later."; fi
    else echo "Invalid choice."; fi
    read -r -p "Press Enter to continue..."
}
initiate_gang_war() {
    run_clock 3
    if [[ "$player_gang" == "None" || "$player_gang_rank" == "Outsider" ]]; then echo "You need to be part of a gang to start a war."; read -r -p "Press Enter..."; return; fi
    if (( ${#guns[@]} == 0 )); then echo "You need a weapon to start a gang war!"; read -r -p "Press Enter..."; return; fi
    local target_key=""; for key in "${!territory_owner[@]}"; do
        local city district; IFS='|' read -r city district <<< "$key"
        if [[ "$city" == "$location" && "${territory_owner[$key]}" != "$player_gang" && "${territory_owner[$key]}" != "Unaffiliated" ]]; then target_key="$key"; break; fi
    done
    if [[ -z "$target_key" ]]; then echo "There are no rival territories in ${location} to attack."; read -r -p "Press Enter..."; return; fi
    local rival_gang="${territory_owner[$target_key]}"; local target_district; IFS='|' read -r - target_district <<< "$target_key"
    clear_screen; echo -e "You are about to start a war for \e[1;33m${target_district}\e[0m in ${location}."
    echo -e "It's controlled by the \e[1;31m${rival_gang}\e[0m."; read -r -p "Are you ready to fight? (y/n) " confirm
    if [[ "$confirm" != "y" ]]; then echo "You back off for now."; read -r -p "Press Enter..."; return; fi
    local recruit_bonus=0; for recruit in "${player_recruits[@]}"; do local str; IFS=':' read -r - str - <<< "$recruit"; recruit_bonus=$((recruit_bonus + str)); done
    local locker_level=${gang_upgrades[weapon_locker]:-0}; local locker_bonus=$((locker_level * 2)); local total_bonus=$((recruit_bonus + locker_bonus))
    if (( total_bonus > 0 )); then echo "Your crew gives you an edge: Recruits (+${recruit_bonus}%) + Weapon Locker (+${locker_bonus}%) = \e[1;32m+${total_bonus}%\e[0m"; fi
    
    # ANIMATION INTEGRATION
    if command -v gang_war_animation &> /dev/null; then gang_war_animation; else echo "Bullets start flying!"; sleep 1; fi
    
    echo "The streets clear as the first wave of ${rival_gang} members arrive..."; sleep 2
    local wave=1; local success=true
    while (( wave <= 3 )); do
        echo "--- WAVE ${wave} ---"; local strength_skill=${skills[strength]:-1}
        local success_chance=$(( 60 + strength_skill*3 - wave*10 + total_bonus ))
        if (( RANDOM % 100 < success_chance )); then
            echo "You fought them off and secured the area! (Chance: ${success_chance}%)"
            local wave_damage=$(( RANDOM % (5 * wave) + 5)); health=$((health - wave_damage))
            echo "You took ${wave_damage}% damage."; if ! check_health; then success=false; break; fi
            ((wave++)); sleep 1
        else
            echo "You were overwhelmed by their numbers! (Chance: ${success_chance}%)"
            health=$((health - (RANDOM % 20 + 15))); success=false; break
        fi
        if (( RANDOM % 2 == 0 )); then
            wanted_level=$((wanted_level + 1))
            echo -e "\e[1;31mThe fight drew police attention! Wanted level increased!\e[0m"; play_sfx_mpg "police_siren"
            if (( wanted_level >= 3 )); then echo "SWAT is moving in! The war is over!"; success=false; break; fi
        fi
    done
    if $success; then
        clear_screen; echo -e "\e[1;32m*** VICTORY! ***\e[0m"
        echo "You have taken control of \e[1;33m${target_district}\e[0m for the ${player_gang}!"
        territory_owner["$target_key"]="$player_gang"; award_respect $((RANDOM % 150 + 100))
        district_heat["$location"]=$(( ${district_heat[$location]:-0} + 20 )); play_sfx_mpg "win_big"
    else
        clear_screen; echo -e "\e[1;31m--- DEFEAT! ---\e[0m"; echo "You were forced to retreat. The ${rival_gang} hold their turf."
        player_respect=$((player_respect - 50)); ((player_respect < 0)) && player_respect=0; echo "You lost 50 Respect."
        play_sfx_mpg "lose_big"
    fi
    check_health; read -r -p "Press Enter..."
}
manage_recruits_menu() {
    run_clock 1; local recruit_names=("Spike" "Knuckles" "Ghost" "Tiny" "Whisper" "Shadow" "Rico" "Vinnie")
    while true; do
        clear_screen; echo "--- Manage Recruits ---"; echo "Recruits: ${#player_recruits[@]} / ${max_recruits}"; echo "-----------------------------------"
        if (( ${#player_recruits[@]} == 0 )); then echo " You have no recruits."; else
            for recruit in "${player_recruits[@]}"; do
                local name str upkeep; IFS=':' read -r name str upkeep <<< "$recruit"
                printf " - %-10s (Strength: %d, Upkeep: \$%d/day)\n" "$name" "$str" "$upkeep"
            done
        fi
        echo "-----------------------------------"; echo "1. Hire New Recruit"; echo "2. Back to Gang Menu"; read -r -p "Choice: " choice
        case "$choice" in
            1)
                if (( ${#player_recruits[@]} < max_recruits )); then
                    local hire_cost=$((RANDOM % 501 + 500))
                    if (( cash >= hire_cost )); then
                        cash=$((cash - hire_cost)); local name=${recruit_names[RANDOM % ${#recruit_names[@]}]}
                        local str=$((RANDOM % 4 + 2)); local upkeep=$((str * 25))
                        player_recruits+=("${name}:${str}:${upkeep}")
                        echo "Hired ${name} for \$${hire_cost}. They look tough."; play_sfx_mpg "cash_register"
                    else echo "Not enough cash to hire anyone right now (cost ~$${hire_cost})."; fi
                else echo "You can't hire any more recruits. Upgrade your Safe House."; fi
                read -r -p "Press Enter...";;
            2) return ;; *) echo "Invalid choice." && sleep 1 ;;
        esac
    done
}
gang_upgrades_menu() {
    run_clock 1
    declare -A UPGRADE_COSTS=( ["safe_house"]="5000 15000 40000" ["weapon_locker"]="10000 25000 50000" ["smuggling_routes"]="20000 50000 100000" )
    declare -A UPGRADE_DESCS=( ["safe_house"]="Increases max recruits (+2 per level)" ["weapon_locker"]="Provides a passive bonus in gang wars (+2% per level)" ["smuggling_routes"]="Increases income from illegal businesses (+\$100/day per level)" )
    while true; do
        clear_screen; echo "--- Gang Upgrades ---"; echo "Spend cash to permanently improve your gang's operations."; echo "--------------------------------------------------------"
        local i=1; local -a upgrade_keys=("safe_house" "weapon_locker" "smuggling_routes")
        for key in "${upgrade_keys[@]}"; do
            local level=${gang_upgrades[$key]:-0}; local costs=(${UPGRADE_COSTS[$key]}); local desc=${UPGRADE_DESCS[$key]}
            printf " %d. %-20s (Level %d)\n" "$i" "$(tr '_' ' ' <<< "$key" | awk '{for(j=1;j<=NF;j++) $j=toupper(substr($j,1,1)) substr($j,2)} 1')" "$level"
            echo "    - ${desc}"; if (( level < ${#costs[@]} )); then printf "    - Next Level Cost: \e[1;31m\$%d\e[0m\n" "${costs[$level]}"; else echo -e "    - \e[1;32mMAX LEVEL\e[0m"; fi; ((i++))
        done
        echo "--------------------------------------------------------"; echo "$i. Back to Gang Menu"; read -r -p "Purchase upgrade (number): " choice
        if [[ "$choice" == "$i" ]]; then return
        elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice < i )); then
            local key="${upgrade_keys[$((choice-1))]}"; local level=${gang_upgrades[$key]:-0}; local costs=(${UPGRADE_COSTS[$key]})
            if (( level < ${#costs[@]} )); then
                local cost=${costs[$level]}
                if (( cash >= cost )); then
                    cash=$((cash - cost)); gang_upgrades[$key]=$((level + 1)); apply_gang_upgrades
                    echo "Upgrade purchased!"; play_sfx_mpg "cash_register"
                else echo "Not enough cash (\$$cost needed)."; fi
            else echo "This upgrade is already at its max level."; fi
            read -r -p "Press Enter..."
        else echo "Invalid choice." && sleep 1; fi
    done
}
diplomacy_menu() {
    run_clock 1
    while true; do
        clear_screen; echo "--- Diplomacy ---"; echo "Manage relations with other factions."; echo "-------------------------------------------------------------------"
        local i=1; local -a hostile_gangs=()
        for rival in "${!gang_relations[@]}"; do
            local status="${gang_relations[$rival]}"; local color="\e[0m"
            case "$status" in "War") color="\e[1;35m";; "Hostile") color="\e[1;31m";; "Neutral") color="\e[1;33m";; esac
            printf " - %-20s Status: %b%s\e[0m\n" "$rival" "$color" "$status"
        done
        echo "-------------------------------------------------------------------"; echo "Actions:"; local menu_idx=1
        for rival in "${!gang_relations[@]}"; do
            if [[ "${gang_relations[$rival]}" == "Hostile" ]]; then
                printf " %d. Offer Tribute to the %s\n" "$menu_idx" "$rival"; hostile_gangs+=("$rival"); ((menu_idx++))
            fi
        done
        if (( ${#hostile_gangs[@]} == 0 )); then echo " No active diplomatic actions available."; fi
        echo "-------------------------------------------------------------------"; echo "B. Back to Gang Menu"; read -r -p "Choice: " choice
        if [[ "$choice" == "B" || "$choice" == "b" ]]; then return
        elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#hostile_gangs[@]} )); then
            local target_gang="${hostile_gangs[$((choice-1))]}"; local tribute_cost=10000
            echo "Offering a tribute to the ${target_gang} will cost \$${tribute_cost}."; read -r -p "Are you sure? (y/n): " confirm
            if [[ "$confirm" == "y" && "$cash" -ge "$tribute_cost" ]]; then
                cash=$((cash - tribute_cost)); local charisma_skill=${skills[charisma]:-1}; local success_chance=$(( 30 + charisma_skill * 5 ))
                echo "You send the tribute. They consider your offer... (Chance: ${success_chance}%)"; sleep 2
                if (( RANDOM % 100 < success_chance )); then
                    echo -e "\e[1;32mSuccess!\e[0m Relations are now Neutral."; gang_relations["$target_gang"]="Neutral"
                else echo -e "\e[1;31mFailed!\e[0m They took your money and laughed."; fi
            elif [[ "$confirm" == "y" ]]; then echo "Not enough cash for the tribute."; else echo "Tribute cancelled."; fi
            read -r -p "Press Enter..."
        else echo "Invalid choice." && sleep 1; fi
    done
}

# --- Save/Load System (NEW) & Game Init ---
save_game() {
    run_clock 0
    local save_path="$BASEDIR/$SAVE_DIR"
    mkdir -p "$save_path" || { echo "Error: Could not create save directory '$save_path'."; return 1; }
    echo "Saving game state..."

    ### BUG FIX: Changed the save delimiter from ':' to '@@@' to prevent errors if a
    ### player name or other value contains a colon. This makes the save file more robust.
    (
        echo "name@@@$player_name"
        echo "location@@@$location"
        echo "cash@@@$cash"
        echo "health@@@$health"
        echo "armor@@@$body_armor_equipped"
        echo "wanted@@@$wanted_level"
        echo "gang@@@$player_gang"
        echo "rank@@@$player_gang_rank"
        echo "respect@@@$player_respect"
    ) > "$save_path/player.sav"

    (
        echo "day@@@$game_day"
        echo "hour@@@$game_hour"
    ) > "$save_path/time.sav"

    printf '%s\n' "${guns[@]}" > "$save_path/guns.sav"
    printf '%s\n' "${items[@]}" > "$save_path/items.sav"
    printf '%s\n' "${owned_vehicles[@]}" > "$save_path/vehicles.sav"
    printf '%s\n' "${player_recruits[@]}" > "$save_path/recruits.sav"
    
    save_assoc_array() { local file_path="$1"; shift; declare -n arr_ref="$1"; : > "$file_path"; for key in "${!arr_ref[@]}"; do printf "%s@@@%s\n" "$key" "${arr_ref[$key]}" >> "$file_path"; done; }
    save_assoc_array "$save_path/skills.sav" "skills"
    save_assoc_array "$save_path/drugs.sav" "drugs"
    save_assoc_array "$save_path/territory.sav" "territory_owner"
    save_assoc_array "$save_path/businesses.sav" "owned_businesses"
    save_assoc_array "$save_path/upgrades.sav" "gang_upgrades"
    save_assoc_array "$save_path/relations.sav" "gang_relations"

    echo "Game saved successfully." && read -r -p "Press Enter..."
}

load_game() {
    local save_path="$BASEDIR/$SAVE_DIR"; if [[ ! -f "$save_path/player.sav" ]]; then echo "Error: Save file not found."; return 1; fi
    echo "Attempting to load game..."; initialize_world_data

    ### BUG FIX: Changed the read delimiter from ':' to '@@@' to match the new,
    ### more robust save format.
    while IFS='@@@' read -r key value; do
        case "$key" in
            "name") player_name="$value";;
            "location") location="$value";;
            "cash") cash="$value";;
            "health") health="$value";;
            "armor") body_armor_equipped="$value";;
            "wanted") wanted_level="$value";;
            "gang") player_gang="$value";;
            "rank") player_gang_rank="$value";;
            "respect") player_respect="$value";;
        esac
    done < "$save_path/player.sav"

    if [[ -f "$save_path/time.sav" ]]; then
        while IFS='@@@' read -r key value; do
            case "$key" in
                "day") game_day="$value";;
                "hour") game_hour="$value";;
            esac
        done < "$save_path/time.sav"
    fi

    load_indexed_array() { local file_path="$1"; shift; declare -n arr_ref="$1"; arr_ref=(); if [[ -f "$file_path" ]]; then while IFS= read -r line; do [[ -n "$line" ]] && arr_ref+=("$line"); done < "$file_path"; fi; }
    load_indexed_array "$save_path/guns.sav" "guns"
    load_indexed_array "$save_path/items.sav" "items"
    load_indexed_array "$save_path/vehicles.sav" "owned_vehicles"
    load_indexed_array "$save_path/recruits.sav" "player_recruits"

    load_assoc_array() { local file_path="$1"; shift; declare -n arr_ref="$1"; arr_ref=(); if [[ -f "$file_path" ]]; then while IFS='@@@' read -r key value; do [[ -n "$key" ]] && arr_ref["$key"]="$value"; done < "$file_path"; fi; }
    load_assoc_array "$save_path/skills.sav" "skills"
    load_assoc_array "$save_path/drugs.sav" "drugs"
    load_assoc_array "$save_path/territory.sav" "territory_owner"
    load_assoc_array "$save_path/businesses.sav" "owned_businesses"
    load_assoc_array "$save_path/upgrades.sav" "gang_upgrades"
    load_assoc_array "$save_path/relations.sav" "gang_relations"

    apply_gang_upgrades
    echo "Game loaded successfully." && read -r -p "Press Enter..."
    return 0
}
remove_save_files() { rm -f "$BASEDIR/$SAVE_DIR"/*.sav; }
Game_variables() {
	clear_screen; read -r -p "Enter your player name: " player_name; [[ -z "$player_name" ]] && player_name="toolazytowritename"
	play_sfx_mpg "new_game"; location="Los Santos"; cash=500; health=100; guns=(); items=();
	owned_vehicles=(); wanted_level=0; body_armor_equipped=false
	declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${default_drugs[$key]}; done
	declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${default_skills[$key]}; done
    game_day=1; game_hour=8; player_gang="None"; player_gang_rank="Outsider"; player_respect=0
    initialize_world_data
	echo "Welcome to Bash Theft Auto, $player_name!"; if [ "$player_name" = "test" ]; then cash=999999; player_respect=5000; fi
	echo "Starting in $location with \$${cash} and ${health}% health."; read -r -p "Press Enter to begin..."
}
run_initial_menu() {
	while true; do
		clear_screen; echo "=== Bash Theft Auto ==="; echo "      Main Menu"; echo "---------------------"
		echo "1. New Game"; echo "2. Load Game"; echo "3. Exit Game"; echo "---------------------"
		stty echo; read -r -p "Enter your choice: " initial_choice
		case "$initial_choice" in
			1) read -r -p "Start new game? This deletes any existing save. (y/n): " confirm
				if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then remove_save_files; Game_variables; return 0
				else echo "New game cancelled."; sleep 1; fi ;;
			2) if load_game; then return 0; else sleep 1; fi ;;
			3) cleanup_and_exit ;; *) echo "Invalid choice."; sleep 1 ;;
		esac
	done
}

# --- Main Execution & Loop ---
if ! run_initial_menu; then echo "Exiting due to initial menu failure or user request."; exit 1; fi

while true; do
	update_world_state
	check_health && clear_screen || clear_screen
	echo "--- Actions ---"
	echo "1. Travel         | 7. Sell Drugs"
	echo "2. Buy Guns       | 8. Hire Hooker"
	echo "3. Buy Vehicle    | 9. Visit Hospital"
	echo "4. Inventory      | 10. Street Race"
	echo "5. Work (Legal)   | 11. Buy Drugs" 
	echo "6. Work (Crime)   | G. Gang & Empire Management"
	echo "------------------------------------------------------------"
	echo "S. Save Game     | L. Load Game"
	echo "M. Music Player  | A. About"
	echo "X. Exit Game     |"
	echo "------------------------------------------------------------"
	stty echo; read -r -p "Enter your choice: " choice; choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
	case "$choice_lower" in
		1) clear_screen; echo "--- Travel Agency ---"
			echo "1. Los Santos (\$50) | 2. San Fierro (\$75) | 3. Las Venturas (\$100)"; echo "4. Vice City (\$150) | 5. Liberty City (\$200) | 6. Stay Here"
			read -r -p "Enter choice: " city_choice
			case "$city_choice" in 1) travel_to 50 "Los Santos";; 2) travel_to 75 "San Fierro";; 3) travel_to 100 "Las Venturas";; 4) travel_to 150 "Vice City";; 5) travel_to 200 "Liberty City";; 6) ;; *) echo "Invalid." && sleep 1;; esac;;
		2) buy_guns;; 3) buy_vehicle;; 4) show_inventory;;
		5) clear_screen; echo "--- Honest Work ---"
			echo "1. Taxi Driver | 2. Delivery | 3. Mechanic | 4. Security | 5. Performer | 6. Bus Driver | 7. Back"
			read -r -p "Enter choice: " job_choice
			case "$job_choice" in 1) work_job "taxi";; 2) work_job "delivery";; 3) work_job "mechanic";; 4) work_job "security";; 5) work_job "performer";; 6) work_job "bus_driver";; 7) ;; *) echo "Invalid." && sleep 1;; esac;;
		6) clear_screen; echo "--- Criminal Activities ---"
			echo "1. Rob Store | 2. Carjack | 3. Burglary | 4. Heist | 5. Back"
			read -r -p "Enter choice: " criminal_choice
			case "$criminal_choice" in 1) rob_store;; 2) carjack;; 3) burglary;; 4) heist;; 5) ;; *) echo "Invalid." && sleep 1;; esac;;
		7) sell_drugs;; 8) hire_hooker;; 9) visit_hospital;; 10) street_race;; 11) buy_drugs;;
        'g') show_gang_menu;; 's') save_game;;
		'l') read -r -p "Load game? Unsaved progress will be lost. (y/n): " confirm
			 if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then load_game; fi ;;
		'm') play_music;; 'a') about_music_sfx;;
		'x') read -r -p "Are you sure you want to exit? (y/n): " confirm
			 if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then cleanup_and_exit; fi ;;
		*) echo "Invalid choice '$choice'."; sleep 1;;
	esac
done
cleanup_and_exit
