#ver 2.1.0
#Bash-Theft-Auto music © 2024 by stuffbymax - Martin Petik is licensed under CC BY 4.0
#https://creativecommons.org/licenses/by/4.0/
#!/bin/bash
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
declare -A market_conditions=() # Stores current event modifiers

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
player_gang_rank="Outsider"
player_respect=0
declare -a player_recruits=() # Format: "Name:Strength:Upkeep"
max_recruits=2
declare -A gang_upgrades=()
declare -A gang_relations=()

declare -A GANG_RANKS_RESPECT=( ["Outsider"]=0 ["Associate"]=100 ["Soldier"]=500 ["Enforcer"]=1500 ["Lieutenant"]=4000 ["Underboss"]=10000 ["Boss"]=25000 )
declare -a GANG_RANK_HIERARCHY=("Outsider" "Associate" "Soldier" "Enforcer" "Lieutenant" "Underboss" "Boss")
GANG_CREATION_RESPECT_REQ=1500
declare -A GANG_HOME_CITY

# --- World Data ---
declare -A territory_owner
declare -A district_heat
declare -A available_properties
declare -A owned_businesses

# BTA_FINISH: Initialize all world and gang data
initialize_world_data() {
    territory_owner=(
        ["Los Santos|Idlewood"]="Ballas" ["Los Santos|East Los Santos"]="Vagos" ["Los Santos|Verdant Bluffs"]="Grove Street" ["Los Santos|Downtown"]="Unaffiliated" ["Los Santos|Docks"]="Unaffiliated"
        ["San Fierro|Chinatown"]="Triads" ["San Fierro|Doherty"]="Unaffiliated" ["San Fierro|Easter Basin"]="Da Nang Boys" ["San Fierro|Downtown"]="Unaffiliated"
        ["Las Venturas|The Strip"]="Leone Family" ["Las Venturas|Roca Escalante"]="Sindacco Family" ["Las Venturas|Redsands East"]="Unaffiliated" ["Las Venturas|Old Venturas Strip"]="Unaffiliated"
        ["Liberty City|Broker"]="Unaffiliated" ["Vice City|Vice Point"]="Unaffiliated"
    )
    district_heat=( ["Los Santos"]=10 ["San Fierro"]=5 ["Las Venturas"]=15 ["Liberty City"]=20 ["Vice City"]=5 )
    available_properties=(
        ["LS Car Wash"]="15000:Los Santos:Legal" ["LS Warehouse"]="25000:Los Santos:IllegalFront"
        ["SF Pizza Shop"]="20000:San Fierro:Legal" ["SF Auto Repair"]="35000:San Fierro:Legal" ["SF Shipping Depot"]="60000:San Fierro:IllegalFront"
        ["LV Chapel"]="18000:Las Venturas:Legal" ["LV Casino Front"]="100000:Las Venturas:IllegalFront" ["LV Chop Shop"]="45000:Las Venturas:IllegalFront"
    )
    owned_businesses=()
    GANG_HOME_CITY=( ["Grove Street"]="Los Santos" ["Ballas"]="Los Santos" ["Vagos"]="Los Santos" ["Triads"]="San Fierro" ["Da Nang Boys"]="San Fierro" ["Leone Family"]="Las Venturas" ["Sindacco Family"]="Las Venturas" )
    player_recruits=()
    gang_upgrades=( ["safe_house"]=0 ["weapon_locker"]=0 ["smuggling_routes"]=0 )
    gang_relations=()
    apply_gang_upgrades # Set initial values like max_recruits
}

# --- Dependency Check ---
mpg123_available=true
if ! command -v mpg123 &> /dev/null; then
	echo "###########################################################" >&2
	echo "# Warning: 'mpg123' command not found. Music requires it. #" >&2
    echo "# On Debian/Ubuntu: sudo apt install mpg123               #" >&2
	echo "###########################################################" >&2
	read -r -p "Press Enter to continue without sound..."
	mpg123_available=false
fi
if ! command -v bc &> /dev/null; then
	echo "###########################################################" >&2
	echo "# Warning: 'bc' command not found. Market requires it.    #" >&2
	echo "# On Debian/Ubuntu: sudo apt install bc                   #" >&2
	echo "###########################################################" >&2
	read -r -p "Press Enter to continue..."
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


# --- Core Functions ---
clear_screen() {
	clear
	printf "\e[93m============================================================\e[0m\n"
	printf "\e[1;43m|                       Bash Theft Auto                      |\e[0m\n"
	printf "\e[93m============================================================\e[0m\n"
    printf " Day: %-10d Time: %02d:00\n" "$game_day" "$game_hour"
	printf " Player: %-15s Location: %s\n" "$player_name" "$location"
	printf " Cash: \$%-19d Health: %d%%\n" "$cash" "$health"
	if $body_armor_equipped; then printf " Armor: \e[1;32mEquipped\e[0m"; else printf " Armor: \e[1;31mNone\e[0m    "; fi
	local stars=""; for ((i=0; i<wanted_level; i++)); do stars+="*"; done; printf " | Wanted: \e[1;31m%-5s\e[0m\n" "$stars"
    local display_gang="${player_gang:-N/A}"; [[ "$player_gang" == "None" ]] && display_gang="N/A"
    local display_rank="${player_gang_rank:-N/A}"; [[ "$player_gang" == "None" ]] && display_rank="N/A"
	printf " Gang: %-20s Rank: %s\n" "$display_gang" "$display_rank"
    printf " Respect: %-16d District Heat: %s\n" "$player_respect" "${district_heat[$location]:-0}"
	printf "\e[1;34m============================================================\e[0m\n"
}

about_music_sfx() { # BTA_FINISH: Ported from old version
    run_clock 0
	clear_screen
	echo "Music © 2024 by stuffbymax - Martin Petik (CC BY 4.0)"
	echo "Game Code © 2024 stuffbymax (MIT License)"
    echo "Full details: https://github.com/stuffbymax/Bash-Theft-Auto"
	read -r -p "Press Enter to return..."
}

check_health() {
	if (( health <= 0 )); then
		health=0; clear_screen
		echo -e "\n      \e[1;31m W A S T E D \e[0m\n"; play_sfx_mpg "wasted"
		echo "You collapsed from your injuries..."
        local respect_loss=$((RANDOM % 50 + 25)); echo "You lost ${respect_loss} Respect for being taken down."
        player_respect=$((player_respect - respect_loss)); (( player_respect < 0 )) && player_respect=0
		read -r -p "Press Enter to go to the hospital..."; hospitalize_player; return 1
	fi; return 0
}

award_respect() {
    local amount=$1; player_respect=$((player_respect + amount))
    echo -e "You gained \e[1;32m${amount}\e[0m Respect."
    if [[ "$player_gang" != "None" ]]; then
        local current_rank_index=-1; for i in "${!GANG_RANK_HIERARCHY[@]}"; do if [[ "${GANG_RANK_HIERARCHY[$i]}" == "$player_gang_rank" ]]; then current_rank_index=$i; break; fi; done
        local next_rank_index=$((current_rank_index + 1))
        if (( next_rank_index < ${#GANG_RANK_HIERARCHY[@]} )); then
            local next_rank_name="${GANG_RANK_HIERARCHY[$next_rank_index]}"; local respect_needed=${GANG_RANKS_RESPECT[$next_rank_name]}
            if (( player_respect >= respect_needed )); then
                player_gang_rank="$next_rank_name"; play_sfx_mpg "win_big"
                echo -e "\n\e[1;32m*** RANK UP! ***\e[0m You have been promoted to \e[1;33m${player_gang_rank}\e[0m!"
            fi
        fi
    fi
}

hospitalize_player() { # BTA_FINISH: Ported from old version
    run_clock 6 # Recovery takes time
	local hospital_bill=200; echo "The hospital patched you up for \$${hospital_bill}."
	if (( cash < hospital_bill )); then echo "They took all your cash (\$$cash)."; hospital_bill=$cash; fi
	cash=$((cash - hospital_bill)); health=50; body_armor_equipped=false
	if (( wanted_level > 0 )); then echo "Wanted level cleared."; wanted_level=0; fi; play_sfx_mpg "cash_register"
	printf "You leave the hospital with \$%d cash and %d%% health.\n" "$cash" "$health"; read -r -p "Press Enter..."
}

# --- Clock & World State ---
calculate_and_apply_payouts() {
    clear_screen; echo "--- Daily Payouts (Day ${game_day}, 00:00) ---"
    local territory_income=0; local business_income=0; local upkeep_cost=0
    if [[ "$player_gang" != "None" ]]; then
        for key in "${!territory_owner[@]}"; do if [[ "${territory_owner[$key]}" == "$player_gang" ]]; then territory_income=$((territory_income + 50)); fi; done
    fi
    local smuggling_level=${gang_upgrades[smuggling_routes]:-0}; local smuggling_bonus=$((smuggling_level * 100))
    for prop in "${!owned_businesses[@]}"; do
        if [[ "${owned_businesses[$prop]}" == *"type=Legal"* ]]; then business_income=$((business_income + 200));
        elif [[ "${owned_businesses[$prop]}" == *"type=IllegalFront"* ]]; then business_income=$((business_income + 500 + smuggling_bonus)); fi
    done
    for recruit in "${player_recruits[@]}"; do local upkeep; IFS=':' read -r - - upkeep <<< "$recruit"; upkeep_cost=$((upkeep_cost + upkeep)); done
    local total_income=$((territory_income + business_income)); local net_change=$((total_income - upkeep_cost)); cash=$((cash + net_change))
    echo "Territory: \$${territory_income} | Business: \$${business_income} | Upkeep: -\$${upkeep_cost} | Net: \$${net_change}"
    for city_name in "${!district_heat[@]}"; do if (( ${district_heat[$city_name]} > 0 )); then district_heat[$city_name]=$(( ${district_heat[$city_name]} - 1 )); fi; done
    echo "The heat has cooled down slightly across the cities."; read -r -p "Press Enter to continue..."
}

run_clock() {
    local hours_to_pass=$1; game_hour=$((game_hour + hours_to_pass))
    while (( game_hour >= 24 )); do
        game_hour=$((game_hour - 24)); game_day=$((game_day + 1))
        # BTA_FINISH: Payday can happen at any hour of a new day, not just 00:00
        calculate_and_apply_payouts
    done
}

update_market_conditions() { # BTA_FINISH: Ported from old version
	market_conditions=(); local event_roll=$((RANDOM % 100))
	if (( event_roll < 15 )); then # 15% chance of event
		if (( RANDOM % 2 == 0 )); then
			market_conditions["crackdown_multiplier"]=0.6; market_conditions["buy_multiplier"]=1.1; market_conditions["event_message"]="Police Crackdown! Prices are unfavorable."
		else
			market_conditions["demand_multiplier"]=1.5; market_conditions["buy_multiplier"]=1.1; market_conditions["event_message"]="High Demand! Good time to sell!"
		fi
	fi
}

# --- Player Actions ---
travel_to() {
	local travel_cost="$1"; local new_location="$2"; local current_location="$location"; local use_own_vehicle=false
	if [[ "$new_location" == "$current_location" ]]; then echo "You are already in $new_location."; read -r -p "Press Enter..."; return; fi
	if (( ${#owned_vehicles[@]} > 0 )); then
		read -r -p "Use your own vehicle for free travel? (y/n): " use_vehicle_choice
		if [[ "$use_vehicle_choice" == "y" || "$use_vehicle_choice" == "Y" ]]; then use_own_vehicle=true; travel_cost=0; play_sfx_mpg "car_start"; fi
	fi
	if $use_own_vehicle || (( cash >= travel_cost )); then
		if ! $use_own_vehicle; then cash=$((cash - travel_cost)); fi
        run_clock 4; location="$new_location"; echo "You have arrived in $new_location."; read -r -p "Press Enter..."
	else echo "Not enough cash (\$$travel_cost needed)."; read -r -p "Press Enter..."; fi
}

buy_guns() {
    run_clock 1; local gun_choice=""; clear_screen
	echo "--- Ammu-Nation ---"; echo "1. Pistol(\$100) 2. Shotgun(\$250) 3. SMG(\$500) 4. Rifle(\$750) 5. Sniper(\$1000) 6. Leave"
	printf "Your Cash: \$%d\n" "$cash"; read -r -p "Enter your choice: " gun_choice
	[[ ! "$gun_choice" =~ ^[1-6]$ ]] && { echo "Invalid."; sleep 1; return; }
	case "$gun_choice" in 1) buy_gun "Pistol" 100;; 2) buy_gun "Shotgun" 250;; 3) buy_gun "SMG" 500;; 4) buy_gun "Rifle" 750;; 5) buy_gun "Sniper" 1000;; 6) return;; esac
}

buy_gun() { # BTA_FINISH: Ported from old version
	local gun_name="$1"; local gun_cost="$2"
	for owned_gun in "${guns[@]}"; do if [[ "$owned_gun" == "$gun_name" ]]; then echo "You already have a $gun_name."; read -r -p "Press Enter..."; return; fi; done
	if (( cash >= gun_cost )); then cash=$((cash - gun_cost)); guns+=("$gun_name"); echo "Purchased $gun_name for \$$gun_cost."; play_sfx_mpg "cash_register"; else echo "Not enough cash."; fi
    read -r -p "Press Enter...";
}

buy_vehicle() {
    run_clock 1; local i=1; local buyable_vehicles=(); clear_screen
    echo "--- Premium Deluxe Motorsport ---"; for type in "${!vehicle_types[@]}"; do printf " %d. %-12s (\$ %d)\n" "$i" "$type" "${vehicle_types[$type]}"; buyable_vehicles+=("$type"); ((i++)); done
    printf " %d. Leave\n" "$i"; printf "Your Cash: \$%d\n" "$cash"; read -r -p "Enter your choice: " choice
    if [[ "$choice" == "$i" ]]; then return; fi
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#buyable_vehicles[@]} )); then echo "Invalid choice."; sleep 1; buy_vehicle; return; fi
    local chosen_type="${buyable_vehicles[$((choice - 1))]}"; local chosen_price="${vehicle_types[$chosen_type]}"
    if (( cash >= chosen_price )); then
        cash=$((cash - chosen_price)); owned_vehicles+=("$chosen_type"); echo "Congratulations on your new $chosen_type!"; play_sfx_mpg "car_start"
    else echo "Sorry, you need \$${chosen_price}."; fi; read -r -p "Press Enter..."
}

visit_hospital() { # BTA_FINISH: Ported and completed
    run_clock 1; local choice="";
    while true; do
		clear_screen; echo "--- County General Hospital ---"; printf " Your Health: %d%% | Cash: \$%d\n" "$health" "$cash"
		echo "1. Basic Treatment (\$50) | 2. Advanced Scan (\$100) | 3. Buy Body Armor (\$75) | 4. Leave"; read -r -p "Choice: " choice
        case "$choice" in
            1) if ((cash >= 50)); then cash=$((cash-50)); health=100; echo "Health restored to 100%."; else echo "Not enough cash."; fi; read -r -p "..."..;;
            2) if ((cash >= 100)); then cash=$((cash-100)); health=110; echo "Health boosted to 110%!"; else echo "Not enough cash."; fi; read -r -p "..."..;;
            3) if $body_armor_equipped; then echo "Already equipped."; elif ((cash >= 75)); then cash=$((cash-75)); body_armor_equipped=true; echo "Body Armor equipped."; else echo "Not enough cash."; fi; read -r -p "..."..;;
            4) return;;
            *) echo "Invalid."; sleep 1;;
        esac
    done
}

work_job() {
    run_clock 4; local job_type="$1"; local base_earnings=0; local skill_bonus=0; local relevant_skill_name=""
    base_earnings=$((RANDOM % 41 + 20)); local relevant_skill_level=${skills[$relevant_skill_name]:-1}
	case "$job_type" in "taxi") relevant_skill_name="driving"; skill_bonus=$((relevant_skill_level * 3));; "delivery") relevant_skill_name="driving"; skill_bonus=$((relevant_skill_level * 4));; "mechanic") relevant_skill_name="strength"; skill_bonus=$((relevant_skill_level * 1));; "security") relevant_skill_name="strength"; skill_bonus=$((relevant_skill_level * 2));; "performer") relevant_skill_name="charisma"; skill_bonus=$((relevant_skill_level * 5));; esac
	local earnings=$((base_earnings + skill_bonus)); cash=$((cash + earnings)); clear_screen
	printf "Finished your shift as a %s. You earned \$%d.\n" "$job_type" "$earnings"
	if (( wanted_level > 0 && RANDOM % 4 == 0 )); then wanted_level=$((wanted_level - 1)); echo -e "\e[1;32mWanted Level Decreased!\e[0m"; fi
	if [[ -n "$relevant_skill_name" ]] && (( RANDOM % 5 == 0 )); then skills[$relevant_skill_name]=$((relevant_skill_level + 1)); printf "Your \e[1;32m%s\e[0m skill increased!\n" "$relevant_skill_name"; fi
	read -r -p "Press Enter..."
}

street_race() {
    run_clock 2; local driving_skill=${skills[driving]:-1}; local win_chance=$(( 40 + driving_skill * 5 )); (( win_chance > 90 )) && win_chance=90
	clear_screen; echo "--- Street Race --- Win Chance: ${win_chance}%"; read -r -p "Press Enter for results..."
	if (( RANDOM % 100 < win_chance )); then
		local winnings=$((RANDOM % 151 + 100 + driving_skill * 10)); cash=$((cash + winnings))
		local damage=$((RANDOM % 15 + 5)); if $body_armor_equipped; then damage=$((damage/2)); body_armor_equipped=false; fi; health=$((health - damage))
		clear_screen; printf "\e[1;32m*** YOU WON! ***\e[0m\nCollected \$%d. Took %d%% damage.\n" "$winnings" "$damage"
        award_respect $((RANDOM % 15 + 10)); if (( RANDOM % 3 == 0 )); then skills[driving]=$((driving_skill + 1)); printf "Your \e[1;32mdriving\e[0m skill increased!\n"; fi
	else
		local damage=$((RANDOM % 31 + 15)); if $body_armor_equipped; then damage=$((damage/2)); body_armor_equipped=false; fi; health=$((health - damage))
		clear_screen; printf "\e[1;31m--- YOU LOST! ---\e[0m\nCrashed and took %d%% damage.\n" "$damage"
        player_respect=$((player_respect - 5)); ((player_respect < 0)) && player_respect=0; echo "You lost 5 Respect."
	fi; check_health; read -r -p "Press Enter..."
}

hire_hooker() { # BTA_FINISH: Ported from old version
    run_clock 1; local charisma_skill=${skills[charisma]:-1}; local hooker_cost=$((RANDOM % 41 + 40 - charisma_skill * 3))
    echo "You're quoted \$${hooker_cost}."; read -r -p "Accept? (y/n): " accept
    if [[ "$accept" == "y" && "$cash" -ge "$hooker_cost" ]]; then
        cash=$((cash-hooker_cost)); local health_gain=$((RANDOM % 21 + 15)); health=$((health+health_gain)); ((health > 110)) && health=110
        echo "Transaction complete. You gained ${health_gain}% health."; if ((RANDOM % 5 == 0)); then skills[charisma]=$((charisma_skill+1)); echo "Charisma increased!"; fi
    elif [[ "$accept" == "y" ]]; then echo "Not enough cash."; else echo "You walk away."; fi; read -r -p "Press Enter..."
}

show_inventory() {
    run_clock 0; clear_screen
	echo "--- Inventory & Stats ---"; printf " Cash: \$%d | Health: %d%%\n" "$cash" "$health"
    if [[ "$player_gang" != "None" ]]; then printf " Gang: %s | Rank: %s | Respect: %d\n" "$player_gang" "$player_gang_rank" "$player_respect"; fi
	echo "Guns: ${guns[*]:-(None)} | Items: ${items[*]:-(None)} | Vehicles: ${owned_vehicles[*]:-(None)}"
	echo "--- Drugs ---"; for drug in "${!default_drugs[@]}"; do local amount=${drugs[$drug]:-0}; if (( amount > 0 )); then printf " %-10s: %d\n" "$drug" "$amount"; fi; done
	echo "--- Skills ---"; for skill in "${!default_skills[@]}"; do printf " %-12s: %d\n" "$skill" "${skills[$skill]:-0}"; done
	echo "--- Properties ---"; if (( ${#owned_businesses[@]} > 0 )); then for prop in "${!owned_businesses[@]}"; do printf " %-20s\n" "$prop"; done; else echo " (None)"; fi
	read -r -p "Press Enter..."
}

# --- Crime Functions ---
apply_gun_bonus() { # BTA_FINISH: Ported from old version
	local base_chance=$1; local action_message=$2; local current_chance=$base_chance; local gun_bonus=0; local chosen_gun=""
	if (( ${#guns[@]} == 0 )); then echo "No guns! Harder."; gun_bonus=-15; else
		read -r -p "Use a gun for this $action_message? (${guns[*]}) (y/n): " use_gun
		if [[ "$use_gun" == "y" ]]; then
			read -r -p "Which gun?: " chosen_gun
			local gun_found=false; for gun in "${guns[@]}"; do if [[ "$gun" == "$chosen_gun" ]]; then gun_found=true; break; fi; done
			if $gun_found; then
				eval "${gun_attributes[$chosen_gun]}"; gun_bonus=${success_bonus:-0}
                if (( gun_bonus > 0 )); then echo "$chosen_gun gives +${gun_bonus}% chance."; fi
			else echo "You don't own '$chosen_gun'!"; fi
		else gun_bonus=-5; fi
	fi
	current_chance=$((current_chance + gun_bonus)); (( current_chance < 5 )) && current_chance=5; (( current_chance > 95 )) && current_chance=95
	echo "$current_chance"
}

rob_store() {
    run_clock 2; local stealth_skill=${skills[stealth]:-1}; local base_chance=$((15 + stealth_skill * 5)); clear_screen; echo "--- Rob Store ---"
	local final_success_chance=$(apply_gun_bonus "$base_chance" "robbery"); echo "Final success chance: ${final_success_chance}%"; read -r -p "Attempt robbery..."
	if (( RANDOM % 100 < final_success_chance )); then
		local loot=$((RANDOM % 151 + 50 + stealth_skill * 10)); cash=$((cash + loot)); local damage=$((RANDOM % 16 + 5)); health=$((health-damage))
		clear_screen; printf "\e[1;32mSuccess!\e[0m Grabbed \$%d. Took %d%% damage.\n" "$loot" "$damage"; play_sfx_mpg "cash_register"
        award_respect $((RANDOM % 10 + 5)); district_heat["$location"]=$(( ${district_heat[$location]:-0} + 2 )); echo "District heat increased."
		if (( RANDOM % 3 == 0 )); then skills[stealth]=$((stealth_skill + 1)); printf "Your \e[1;32mstealth\e[0m skill increased!\n"; fi
	else
		wanted_level=$((wanted_level + 1)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"
		local fine=$((RANDOM % 101 + 50 + wanted_level * 25)); cash=$((cash - fine)); (( cash < 0 )) && cash=0
		local damage=$((RANDOM % 26 + 10 + wanted_level * 5)); health=$((health - damage))
		clear_screen; printf "\e[1;31mFailed!\e[0m Fined \$%d and took %d%% damage.\n" "$fine" "$damage"
	fi; check_health; read -r -p "Press Enter..."
}

carjack() { # BTA_FINISH: Ported from old version
    run_clock 1; local driving_skill=${skills[driving]:-1}; local stealth_skill=${skills[stealth]:-1}; local base_chance=$(( 20 + driving_skill * 2 + stealth_skill * 3 ))
    clear_screen; echo "--- Carjack ---"
    local final_success_chance=$(apply_gun_bonus "$base_chance" "carjacking"); echo "Success chance: ${final_success_chance}%"; read -r -p "Make your move..."
    if (( RANDOM % 100 < final_success_chance )); then
        local possible_cars=("Sedan" "Truck" "Motorcycle"); local stolen_car=${possible_cars[RANDOM % ${#possible_cars[@]}]}
        owned_vehicles+=("$stolen_car"); local loot=$((RANDOM % 51 + 20)); cash=$((cash + loot)); local damage=$((RANDOM % 16 + 5)); health=$((health - damage))
        clear_screen; printf "\e[1;32mSuccess!\e[0m Boosted a %s and got \$%d.\n" "$stolen_car" "$loot"; play_sfx_mpg "car_start"
        award_respect $((RANDOM % 5 + 1)); district_heat["$location"]=$(( ${district_heat[$location]:-0} + 1 ))
        if (( RANDOM % 4 == 0 )); then skills[driving]=$((driving_skill+1)); echo "Driving skill increased!"; fi
    else
        wanted_level=$((wanted_level + 1)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"
        local fine=$((RANDOM % 76 + 25 + wanted_level * 20)); cash=$((cash-fine)); local damage=$((RANDOM % 26 + 10 + wanted_level * 6)); health=$((health-damage))
        clear_screen; printf "\e[1;31mFailed!\e[0m Fined \$%d and took %d%% damage.\n" "$fine" "$damage"
    fi; check_health; read -r -p "Press Enter..."
}

burglary() { # BTA_FINISH: Ported from old version
    run_clock 3; local stealth_skill=${skills[stealth]:-1}; local base_chance=$((5 + stealth_skill * 7)); (( base_chance > 90 )) && base_chance=90
    clear_screen; echo "--- Burglary --- Success chance: ${base_chance}%"; read -r -p "Attempt burglary..."
    if (( RANDOM % 100 < base_chance )); then
        local loot=$((RANDOM % 251 + 75 + stealth_skill * 15)); cash=$((cash + loot)); local damage=$((RANDOM % 11)); health=$((health-damage))
        clear_screen; printf "\e[1;32mSuccess!\e[0m Slipped out with \$%d worth of valuables.\n" "$loot"; play_sfx_mpg "burglary_success"
        award_respect $((RANDOM % 15 + 10)); district_heat["$location"]=$(( ${district_heat[$location]:-0} + 5 ))
        if (( RANDOM % 2 == 0 )); then skills[stealth]=$((stealth_skill + 1)); echo "Stealth skill increased!"; fi
    else
        wanted_level=$((wanted_level + 1)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"
        local fine=$((RANDOM % 151 + 75 + wanted_level * 30)); cash=$((cash-fine)); local damage=$((RANDOM % 31 + 15 + wanted_level * 7)); health=$((health-damage))
        clear_screen; printf "\e[1;31mFailed!\e[0m Spotted! Fined \$%d, took %d%% damage.\n" "$fine" "$damage"; play_sfx_mpg "burglary_fail"
    fi; check_health; read -r -p "Press Enter..."
}

heist() { # BTA_FINISH: Ported from old version
    run_clock 6; local stealth_skill=${skills[stealth]:-1}; local base_chance=$((10 + stealth_skill * 6)); clear_screen; echo "--- Plan Heist ---"
    local final_success_chance=$(apply_gun_bonus "$base_chance" "heist"); echo "Final success chance: ${final_success_chance}%"; read -r -p "Execute the heist..."
    if (( RANDOM % 100 < final_success_chance )); then
        local loot=$((RANDOM % 501 + 250 + stealth_skill * 25)); cash=$((cash + loot)); local damage=$((RANDOM % 31 + 15)); if $body_armor_equipped; then damage=$((damage/2)); body_armor_equipped=false; fi; health=$((health - damage))
        clear_screen; printf "\e[1;32m*** HEIST SUCCESSFUL! ***\e[0m\nScored \$%d! Took %d%% damage.\n" "$loot" "$damage"; play_sfx_mpg "win_big"
        award_respect $((RANDOM % 75 + 50)); district_heat["$location"]=$(( ${district_heat[$location]:-0} + 15 ))
        if (( RANDOM % 2 == 0 )); then skills[stealth]=$((stealth_skill + 2)); echo "Stealth skill increased significantly!"; fi
    else
        wanted_level=$((wanted_level + 2)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"
        local fine=$((RANDOM % 201 + 100 + wanted_level * 50)); cash=$((cash-fine)); local damage=$((RANDOM % 41 + 20 + wanted_level * 10)); if $body_armor_equipped; then damage=$((damage/2)); body_armor_equipped=false; fi; health=$((health - damage))
        clear_screen; printf "\e[1;31m--- HEIST FAILED! ---\e[0m\nLost \$%d and took %d%% damage.\n" "$fine" "$damage"; play_sfx_mpg "lose_big"
    fi; check_health; read -r -p "Press Enter..."
}

# --- Drug Market Functions ---
# BTA_FINISH: These are all ported from v2.0.8, with run_clock added where appropriate
drug_transaction() {
	local action="$1" drug_name="$2" base_price="$3" drug_amount="$4"; local cost=0 final_price=0
	if ! [[ "$drug_amount" =~ ^[1-9][0-9]*$ ]]; then echo "Invalid amount."; return 1; fi
    local price_fluctuation=$((RANDOM % 21 - 10)); local location_modifier=0
	case "$location" in "Liberty City") location_modifier=15;; "Vice City") location_modifier=-15;; esac
	local current_market_price=$((base_price + (base_price * (price_fluctuation + location_modifier) / 100))); ((current_market_price < 1)) && current_market_price=1
    local buy_mult=${market_conditions["buy_multiplier"]:-1.0}; local sell_mult=${market_conditions["crackdown_multiplier"]:-1.0}; if [[ -v market_conditions["demand_multiplier"] ]]; then sell_mult=$(bc <<< "scale=2; $sell_mult * ${market_conditions["demand_multiplier"]}"); fi
	if [[ "$action" == "buy" ]]; then
        final_price=$(bc <<< "scale=0; $current_market_price * $buy_mult / 1"); cost=$((final_price * drug_amount))
		if (( cash >= cost )); then cash=$((cash-cost)); drugs["$drug_name"]=$(( ${drugs[$drug_name]:-0} + drug_amount )); printf "Bought %d %s for \$%d.\n" "$drug_amount" "$drug_name" "$cost";
		else printf "Not enough cash. Need \$%d.\n" "$cost"; fi
	elif [[ "$action" == "sell" ]]; then
		if (( ${drugs[$drug_name]:-0} >= drug_amount )); then
			local dealer_skill=${skills[drug_dealer]:-1}; local skill_adjusted_price=$((current_market_price + (current_market_price * dealer_skill * 2 / 100)))
            final_price=$(bc <<< "scale=0; $skill_adjusted_price * $sell_mult / 1"); local income=$((final_price * drug_amount))
            cash=$((cash+income)); drugs["$drug_name"]=$(( ${drugs[$drug_name]} - drug_amount )); printf "Sold %d %s for \$%d.\n" "$drug_amount" "$drug_name" "$income"
            if ((RANDOM % 2 == 0)); then skills[drug_dealer]=$((dealer_skill+1)); echo "Drug dealing skill increased!"; fi
		else printf "Not enough %s to sell.\n" "$drug_name"; fi
	fi
}
buy_drugs() {
    run_clock 1; local drug_names=("Weed" "Cocaine" "Heroin" "Meth"); declare -A drug_prices=(["Weed"]=10 ["Cocaine"]=50 ["Heroin"]=100 ["Meth"]=75)
    clear_screen; echo "--- Buy Drugs ---"; if [[ -n "${market_conditions["event_message"]}" ]]; then printf " \e[1;36mMarket News: %s\e[0m\n" "${market_conditions["event_message"]}"; fi
    local i=1; for name in "${drug_names[@]}"; do printf " %d. %s\n" "$i" "$name"; ((i++)); done; printf " %d. Back\n" "$i"; read -r -p "Choice: " choice
    if ((choice == i)); then return; fi; local chosen_drug="${drug_names[$((choice-1))]}"; read -r -p "Amount: " amount
    drug_transaction "buy" "$chosen_drug" "${drug_prices[$chosen_drug]}" "$amount"; read -r -p "Press Enter..."
}
sell_drugs() {
    run_clock 1; local available_to_sell=(); declare -A drug_sell_prices=(["Weed"]=15 ["Cocaine"]=75 ["Heroin"]=150 ["Meth"]=100)
    clear_screen; echo "--- Sell Drugs ---"; if [[ -n "${market_conditions["event_message"]}" ]]; then printf " \e[1;36mMarket News: %s\e[0m\n" "${market_conditions["event_message"]}"; fi
    local i=1; for name in "${!default_drugs[@]}"; do if (( ${drugs[$name]:-0} > 0 )); then printf " %d. %s (%d units)\n" "$i" "$name" "${drugs[$name]}"; available_to_sell+=("$name"); ((i++)); fi; done
    if (( ${#available_to_sell[@]} == 0 )); then echo "Nothing to sell."; read -r -p "..."; return; fi
    printf " %d. Back\n" "$i"; read -r -p "Choice: " choice
    if ((choice == i)); then return; fi; local chosen_drug="${available_to_sell[$((choice-1))]}"; read -r -p "Amount: " amount
    drug_transaction "sell" "$chosen_drug" "${drug_sell_prices[$chosen_drug]}" "$amount"; read -r -p "Press Enter..."
}

# BTA_FINISH: The music player is ported directly from v2.0.8
play_music() {
    run_clock 0
	if ! $mpg123_available; then echo "mpg123 not found."; read -r -p "..."; return; fi
	local music_dir="$BASEDIR/music"; if [[ ! -d "$music_dir" ]]; then echo "Music dir not found."; read -r -p "..."; return; fi
	local -a music_files; while IFS= read -r -d $'\0' file; do music_files+=("$file"); done < <(find "$music_dir" -maxdepth 1 -type f -name "*.mp3" -print0 2>/dev/null)
	if (( ${#music_files[@]} == 0 )); then echo "No .mp3 files found."; read -r -p "..."; return; fi
	clear_screen; echo "--- Music Player ---"; for i in "${!music_files[@]}"; do printf " %d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"; done
	echo "-------------------"; echo "s. Stop | b. Back"; read -r -p "Choice: " choice
	case "$choice" in
		's') if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then kill "$music_pid" &>/dev/null; music_pid=""; echo "Music stopped."; fi; sleep 1;;
		'b') return;;
		*) if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#music_files[@]} )); then
				if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then kill "$music_pid" &>/dev/null; fi
				mpg123 -q "${music_files[$((choice-1))]}" & music_pid=$!; echo "Playing..."
		   else echo "Invalid choice."; fi; sleep 1;;
	esac
}

# --- Gang System Functions ---
# BTA_FINISH: These are the completed implementations of your new gang system stubs
set_initial_gang_relations() {
    gang_relations=(); for rival in "${!GANG_HOME_CITY[@]}"; do if [[ "$rival" != "$player_gang" ]]; then gang_relations["$rival"]="Hostile"; fi; done
    if [[ "$player_gang" == "Grove Street" ]]; then gang_relations["Ballas"]="War"; gang_relations["Vagos"]="War"; fi
}
apply_gang_upgrades() { local safe_house_level=${gang_upgrades[safe_house]:-0}; max_recruits=$(( 2 + safe_house_level * 2 )); }
show_gang_menu() {
    run_clock 0; while true; do
        clear_screen; echo "--- Gang & Empire Management ---"
        echo "1. View Territory Map | 2. Manage Businesses | 3. Initiate Gang War"
        if [[ "$player_gang" == "None" ]]; then
            echo "4. Join a Faction"; if (( player_respect >= GANG_CREATION_RESPECT_REQ )); then echo "5. Create a Faction (Req: ${GANG_CREATION_RESPECT_REQ} Respect)"; fi
        else echo "4. Manage Recruits | 5. Gang Upgrades | 6. Diplomacy"; fi
        echo "B. Back"; read -r -p "Choice: " choice
        case "$choice" in 1) show_territory_map;; 2) manage_businesses;; 3) initiate_gang_war;;
            4) if [[ "$player_gang" == "None" ]]; then join_gang_interface; else manage_recruits_menu; fi;;
            5) if [[ "$player_gang" == "None" ]]; then if (( player_respect >= GANG_CREATION_RESPECT_REQ )); then create_own_gang; fi; else gang_upgrades_menu; fi;;
            6) if [[ "$player_gang" != "None" ]]; then diplomacy_menu; fi;;
            'b'|'B') return;; *) echo "Invalid."; sleep 1;;
        esac
    done
}
show_territory_map() {
    run_clock 0; clear_screen; echo "--- ${location} Territory Map ---"
    for key in "${!territory_owner[@]}"; do
        local owner="${territory_owner[$key]}"; local city district; IFS='|' read -r city district <<< "$key"
        if [[ "$city" == "$location" ]]; then printf "| %-20s | Owner: %s\n" "$district" "$owner"; fi
    done; read -r -p "Press Enter...";
}
manage_businesses() { run_clock 1; clear_screen; echo "--- Business Management ---"; echo "1. Buy Property | 2. Manage Owned | B. Back"; read -r -p "Choice: " choice; case "$choice" in 1) buy_property;; 2) manage_owned_property;; *) return;; esac; }
buy_property() {
    clear_screen; echo "--- Real Estate in ${location} ---"; local i=1; local -a prop_keys=(); local -a prop_costs=(); local -a prop_types=()
    for prop_name in "${!available_properties[@]}"; do if [[ ! -v "owned_businesses[$prop_name]" ]]; then
        local prop_details="${available_properties[$prop_name]}"; local price prop_city prop_type; IFS=':' read -r price prop_city prop_type <<< "$prop_details"
        if [[ "$prop_city" == "$location" ]]; then printf "%d. %-25s (\$%d) - [%s]\n" "$i" "$prop_name" "$price" "$prop_type"; prop_keys+=("$prop_name"); prop_costs+=("$price"); prop_types+=("$prop_type"); ((i++)); fi; fi
    done
    read -r -p "Buy which property? (B to back): " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#prop_keys[@]} )); then
        local index=$((choice - 1)); local prop_to_buy="${prop_keys[$index]}"; local prop_cost="${prop_costs[$index]}"; local prop_type="${prop_types[$index]}"
        if (( cash >= prop_cost )); then cash=$((cash - prop_cost)); owned_businesses["$prop_to_buy"]="type=$prop_type"; echo "Purchased $prop_to_buy!"; else echo "Not enough cash."; fi
    fi; read -r -p "Press Enter...";
}
manage_owned_property() { echo "This feature is under development."; read -r -p "Press Enter..."; }
create_own_gang() {
    run_clock 1; clear_screen; read -r -p "Enter name for your new gang: " new_gang_name
    if [[ -z "$new_gang_name" || "$new_gang_name" == "None" || -v "GANG_HOME_CITY[$new_gang_name]" ]]; then echo "Invalid or reserved name."; read -r -p "..."; return; fi
    player_gang="$new_gang_name"; player_gang_rank="Soldier"; set_initial_gang_relations; play_sfx_mpg "win_big"
    echo -e "The \e[1;36m${player_gang}\e[0m are now on the map!"; read -r -p "Press Enter...";
}
join_gang_interface() {
    run_clock 1; local i=1; local -a menu_options=(); clear_screen; echo "--- Join a Faction in ${location} ---"
    for gang in "${!GANG_HOME_CITY[@]}"; do if [[ "${GANG_HOME_CITY[$gang]}" == "$location" ]]; then printf " %d. Join the %s\n" "$i" "$gang"; menu_options+=("$gang"); ((i++)); fi; done
    if (( ${#menu_options[@]} == 0 )); then echo " No major gangs are recruiting here."; read -r -p "..."; return; fi
    read -r -p "Your choice: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#menu_options[@]} )); then
        local new_gang="${menu_options[$((choice-1))]}"; echo "They ask for a \$200 tribute."; read -r -p "Pay? (y/n): " pay
        if [[ "$pay" == "y" && "$cash" -ge 200 ]]; then cash=$((cash-200)); player_gang="$new_gang"; player_gang_rank="Associate"; set_initial_gang_relations; echo "Welcome to ${player_gang}."; award_respect 100;
        elif [[ "$pay" == "y" ]]; then echo "Not enough cash."; fi
    fi; read -r -p "Press Enter...";
}
initiate_gang_war() {
    run_clock 3
    if [[ "$player_gang" == "None" || "$player_gang_rank" == "Outsider" || ${#guns[@]} == 0 ]]; then echo "You need to be in a gang and armed to start a war."; read -r -p "..."; return; fi
    local -a attackable_territories=(); local -a rival_gangs=()
    for key in "${!territory_owner[@]}"; do local city; IFS='|' read -r city - <<< "$key"; if [[ "$city" == "$location" && "${territory_owner[$key]}" != "$player_gang" && "${territory_owner[$key]}" != "Unaffiliated" ]]; then attackable_territories+=("$key"); rival_gangs+=("${territory_owner[$key]}"); fi; done
    if (( ${#attackable_territories[@]} == 0 )); then echo "No rival territories to attack here."; read -r -p "..."; return; fi
    clear_screen; echo "--- Initiate Gang War ---"; local i=1; for territory in "${attackable_territories[@]}"; do local district; IFS='|' read -r - district <<< "$territory"; printf "%d. Attack %s (owned by %s)\n" "$i" "$district" "${rival_gangs[$((i-1))]}"; ((i++)); done; read -r -p "Choose target (B to back): " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#attackable_territories[@]} )); then return; fi
    local target_key="${attackable_territories[$((choice-1))]}"
    local recruit_bonus=0; for recruit in "${player_recruits[@]}"; do local str; IFS=':' read -r - str - <<< "$recruit"; recruit_bonus=$((recruit_bonus + str)); done
    local locker_bonus=$(( ${gang_upgrades[weapon_locker]:-0} * 2 )); local total_bonus=$((recruit_bonus + locker_bonus))
    local wave=1; local success=true; while (( wave <= 3 )); do
        echo "--- WAVE ${wave} ---"; local success_chance=$(( 60 + ${skills[strength]:-1}*3 - wave*10 + total_bonus ))
        if (( RANDOM % 100 < success_chance )); then
            echo "Wave ${wave} defeated! (Chance: ${success_chance}%)"; local wave_damage=$(( RANDOM % (5 * wave) + 5)); health=$((health - wave_damage)); if ! check_health; then success=false; break; fi; ((wave++)); sleep 1
        else echo "Overwhelmed! (Chance: ${success_chance}%)"; health=$((health - 25)); success=false; break; fi
    done
    if $success; then echo -e "\e[1;32m*** VICTORY! ***\e[0m"; territory_owner["$target_key"]="$player_gang"; award_respect 150; district_heat["$location"]=$(( ${district_heat[$location]:-0} + 20 ));
    else echo -e "\e[1;31m--- DEFEAT! ---"; player_respect=$((player_respect - 50)); ((player_respect < 0)) && player_respect=0; fi; check_health; read -r -p "Press Enter...";
}
manage_recruits_menu() {
    run_clock 1; local recruit_names=("Spike" "Knuckles" "Ghost" "Tiny" "Whisper" "Shadow");
    while true; do clear_screen; echo "--- Manage Recruits (${#player_recruits[@]} / ${max_recruits}) ---"
        if (( ${#player_recruits[@]} > 0 )); then for recruit in "${player_recruits[@]}"; do echo " - $recruit"; done; fi
        echo "1. Hire New Recruit | 2. Back"; read -r -p "Choice: " choice
        case "$choice" in 1) if (( ${#player_recruits[@]} < max_recruits )); then
                local hire_cost=$((RANDOM % 501 + 500)); if (( cash >= hire_cost )); then cash=$((cash-hire_cost)); local name=${recruit_names[RANDOM % ${#recruit_names[@]}]}; local str=$((RANDOM%4+2)); local upkeep=$((str*25)); player_recruits+=("${name}:${str}:${upkeep}"); echo "Hired ${name}."; else echo "Not enough cash."; fi; else echo "Can't hire more recruits."; fi; read -r -p "...";; 2) return;; esac; done
}
gang_upgrades_menu() {
    run_clock 1; declare -A C=([sh]="5000 15000" [wl]="10000 25000" [sr]="20000 50000"); declare -a K=("safe_house" "weapon_locker" "smuggling_routes"); declare -a A=("sh" "wl" "sr")
    clear_screen; echo "--- Gang Upgrades ---"; local i=0; for key in "${K[@]}"; do local lvl=${gang_upgrades[$key]:-0}; local costs=(${C[${A[$i]}]}); printf "%d. %s (Lvl %d)" $((i+1)) "$key" "$lvl"; if ((lvl<${#costs[@]})); then printf " - Cost: \$%d\n" "${costs[$lvl]}"; else echo " - MAX"; fi; ((i++)); done; echo "4. Back"; read -r -p "Choice: " choice
    if [[ "$choice" =~ ^[1-3]$ ]]; then local key="${K[$((choice-1))]}"; local lvl=${gang_upgrades[$key]:-0}; local costs=(${C[${A[$((choice-1))]}]}); if ((lvl<${#costs[@]})); then local cost=${costs[$lvl]}; if ((cash>=cost)); then cash=$((cash-cost)); gang_upgrades[$key]=$((lvl+1)); apply_gang_upgrades; echo "Upgraded!"; else echo "No cash."; fi; else echo "Max level."; fi; fi; read -r -p "...";
}
diplomacy_menu() {
    run_clock 1; clear_screen; echo "--- Diplomacy ---"
    for rival in "${!gang_relations[@]}"; do local status="${gang_relations[$rival]}"; echo " - ${rival}: ${status}"; done; echo "Tribute to a Hostile gang costs \$10000 to attempt peace."; read -r -p "Offer tribute to which gang? (or B to back) " target_gang
    if [[ -v "gang_relations[$target_gang]" && "${gang_relations[$target_gang]}" == "Hostile" ]]; then
        if ((cash >= 10000)); then cash=$((cash-10000)); local success_chance=$((30+${skills[charisma]:-1}*5)); echo "Chance: ${success_chance}%"; if ((RANDOM%100<success_chance)); then echo "Success! They are now Neutral."; gang_relations["$target_gang"]="Neutral"; else echo "Failed! They took the cash."; fi
        else echo "Not enough cash."; fi
    elif [[ "$target_gang" != "b" && "$target_gang" != "B" ]]; then echo "Invalid target."; fi; read -r -p "...";
}

# --- Save/Load System ---
# BTA_FINISH: Fully updated save/load system for all new variables.
save_atomic() { printf '%s\n' "$1" > "$2.tmp" && mv "$2.tmp" "$2"; }
save_indexed_array() { local file_path="$1"; shift; declare -n arr_ref="$1"; printf '%s\n' "${arr_ref[@]}" > "$file_path"; }
save_assoc_array() { local file_path="$1"; shift; declare -n arr_ref="$1"; : > "$file_path"; for key in "${!arr_ref[@]}"; do printf "%s@@@%s\n" "$key" "${arr_ref[$key]}" >> "$file_path"; done; }
save_game() {
    run_clock 0; local save_path="$BASEDIR/$SAVE_DIR"; mkdir -p "$save_path"; echo "Saving game...";
    save_atomic "$player_name" "$save_path/player.sav"; save_atomic "$location" "$save_path/location.sav"; save_atomic "$cash" "$save_path/cash.sav"; save_atomic "$health" "$save_path/health.sav"; save_atomic "$body_armor_equipped" "$save_path/armor.sav"; save_atomic "$wanted_level" "$save_path/wanted.sav"
    save_atomic "$game_day" "$save_path/day.sav"; save_atomic "$game_hour" "$save_path/hour.sav"
    save_atomic "$player_gang" "$save_path/p_gang.sav"; save_atomic "$player_gang_rank" "$save_path/p_rank.sav"; save_atomic "$player_respect" "$save_path/p_respect.sav"
    save_indexed_array "$save_path/guns.sav" "guns"; save_indexed_array "$save_path/items.sav" "items"; save_indexed_array "$save_path/vehicles.sav" "owned_vehicles"; save_indexed_array "$save_path/recruits.sav" "player_recruits"
    save_assoc_array "$save_path/drugs.sav" "drugs"; save_assoc_array "$save_path/skills.sav" "skills"; save_assoc_array "$save_path/territory.sav" "territory_owner"; save_assoc_array "$save_path/heat.sav" "district_heat"; save_assoc_array "$save_path/business.sav" "owned_businesses"; save_assoc_array "$save_path/upgrades.sav" "gang_upgrades"; save_assoc_array "$save_path/relations.sav" "gang_relations"
	echo "Game saved successfully."; read -r -p "Press Enter...";
}
load_atomic() { if [[ -f "$2" ]]; then read -r "$1" < "$2"; fi; }
load_indexed_array() { local file_path="$1"; shift; declare -n arr_ref="$1"; arr_ref=(); if [[ -f "$file_path" ]]; then while IFS= read -r line; do [[ -n "$line" ]] && arr_ref+=("$line"); done < "$file_path"; fi; }
load_assoc_array() { local file_path="$1"; shift; declare -n arr_ref="$1"; arr_ref=(); if [[ -f "$file_path" ]]; then while IFS='@@@' read -r key value; do [[ -n "$key" ]] && arr_ref["$key"]="$value"; done < "$file_path"; fi; }
load_game() {
	local save_path="$BASEDIR/$SAVE_DIR"; if [[ ! -d "$save_path" ]]; then echo "Save directory not found."; read -r -p "..."; return 1; fi; echo "Loading game...";
    initialize_world_data # Reset world to default before loading specifics
    load_atomic player_name "$save_path/player.sav"; load_atomic location "$save_path/location.sav"; load_atomic cash "$save_path/cash.sav"; load_atomic health "$save_path/health.sav"; load_atomic body_armor_equipped "$save_path/armor.sav"; load_atomic wanted_level "$save_path/wanted.sav"
    load_atomic game_day "$save_path/day.sav"; load_atomic game_hour "$save_path/hour.sav"
    load_atomic player_gang "$save_path/p_gang.sav"; load_atomic player_gang_rank "$save_path/p_rank.sav"; load_atomic player_respect "$save_path/p_respect.sav"
    load_indexed_array "$save_path/guns.sav" "guns"; load_indexed_array "$save_path/items.sav" "items"; load_indexed_array "$save_path/vehicles.sav" "owned_vehicles"; load_indexed_array "$save_path/recruits.sav" "player_recruits"
    load_assoc_array "$save_path/drugs.sav" "drugs"; load_assoc_array "$save_path/skills.sav" "skills"; load_assoc_array "$save_path/territory.sav" "territory_owner"; load_assoc_array "$save_path/heat.sav" "district_heat"; load_assoc_array "$save_path/business.sav" "owned_businesses"; load_assoc_array "$save_path/upgrades.sav" "gang_upgrades"; load_assoc_array "$save_path/relations.sav" "gang_relations"
    apply_gang_upgrades; echo "Game loaded."; read -r -p "Press Enter..."; return 0;
}
remove_save_files() { local save_path="$BASEDIR/$SAVE_DIR"; if [[ -d "$save_path" ]]; then echo "Deleting old save..."; rm -f "$save_path"/*.sav; fi; }

# --- Game Initialization & Main Loop ---
Game_variables() {
	clear_screen; read -r -p "Enter your player name: " player_name; [[ -z "$player_name" ]] && player_name="Wanderer"
	play_sfx_mpg "new_game"; location="Los Santos"; cash=500; health=100; guns=(); items=(); owned_vehicles=(); wanted_level=0;
	declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${default_drugs[$key]}; done; declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${default_skills[$key]}; done
	body_armor_equipped=false; game_day=1; game_hour=8; player_gang="None"; player_gang_rank="Outsider"; player_respect=0; initialize_world_data
    if [[ "$player_name" == "test" ]]; then cash=999999; player_respect=5000; fi
	echo "Welcome, $player_name!"; read -r -p "Press Enter to begin..."
}
run_initial_menu() {
	while true; do clear_screen; echo "1. New Game | 2. Load Game | 3. Exit"; read -r -p "Choice: " choice
		case "$choice" in
			1) read -r -p "Start new? Deletes old save. (y/n): " confirm; if [[ "$confirm" == "y" ]]; then remove_save_files; Game_variables; return 0; fi;;
			2) if load_game; then return 0; fi;; 3) cleanup_and_exit;; *) echo "Invalid."; sleep 1;;
		esac; done
}

# --- Main Execution ---
if ! run_initial_menu; then echo "Exiting."; stty echo; exit 1; fi
while true; do
	update_market_conditions; if ! check_health; then clear_screen; fi; clear_screen
	echo "--- Actions ---"
	echo "1. Travel        | 7. Sell Drugs   | G. Gang & Empire"
	echo "2. Buy Guns      | 8. Hire Hooker  | S. Save Game"
	echo "3. Buy Vehicle   | 9. Hospital     | L. Load Game"
	echo "4. Inventory     | 10. Street Race | M. Music Player"
	echo "5. Work (Legal)  | 11. Buy Drugs   | A. About"
	echo "6. Work (Crime)  |                 | X. Exit Game"
	echo "------------------------------------------------------------"
	read -r -p "Enter your choice: " choice; choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
	case "$choice_lower" in
		1) clear_screen; echo "1. Los Santos | 2. San Fierro | 3. Las Venturas | 4. Vice City | 5. Liberty City | 6. Back"; read -r -p "Go to: " c; case "$c" in 1) travel_to 50 "Los Santos";; 2) travel_to 75 "San Fierro";; 3) travel_to 100 "Las Venturas";; 4) travel_to 150 "Vice City";; 5) travel_to 200 "Liberty City";; esac;;
		2) buy_guns;; 3) buy_vehicle;; 4) show_inventory;;
		5) clear_screen; echo "1. Taxi | 2. Delivery | 3. Mechanic | 4. Security | 5. Performer | 6. Back"; read -r -p "Job: " j; case "$j" in 1) work_job "taxi";; 2) work_job "delivery";; 3) work_job "mechanic";; 4) work_job "security";; 5) work_job "performer";; esac;;
		6) clear_screen; echo "1. Rob Store | 2. Carjack | 3. Burglary | 4. Heist | 5. Back"; read -r -p "Crime: " c; case "$c" in 1) rob_store;; 2) carjack;; 3) burglary;; 4) heist;; esac;;
		7) sell_drugs;; 8) hire_hooker;; 9) visit_hospital;; 10) street_race;; 11) buy_drugs;;
        'g') show_gang_menu;;
		's') save_game;; 'l') read -r -p "Load game? (y/n): " c; if [[ "$c" == "y" ]]; then load_game; fi;;
		'm') play_music;; 'a') about_music_sfx;; 'x') read -r -p "Exit? (y/n): " c; if [[ "$c" == "y" ]]; then cleanup_and_exit; fi;;
		*) echo "Invalid choice."; run_clock 0; sleep 1;;
	esac
done
cleanup_and_exit
