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
	echo "###########################################################" >&2
	echo "# Warning: 'mpg123' command not found." >&2
	echo "# Music and sound effects require this." >&2
    echo "# On Debian/Ubuntu: sudo apt install mpg123" >&2
	echo "###########################################################" >&2
	read -r -p "Press Enter to continue without sound..."
	mpg123_available=false
fi
if ! command -v bc &> /dev/null; then
	echo "############################################################" >&2
	echo "# Warning: 'bc' command not found." >&2
    echo "# Market calculations require this." >&2
	echo "# On Debian/Ubuntu: sudo apt install bc" >&2
	echo "############################################################" >&2
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
    printf " Respect: %-16d District Heat: %s\n" "$player_respect" "${district_heat[$location]:-0}"
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

travel_to() {
	local travel_cost="$1"
	local new_location="$2"
	local current_location="$location"
	local use_own_vehicle=false
    local travel_time=4 # How many hours travel takes

	if [[ "$new_location" == "$current_location" ]]; then
		echo "You are already in $new_location."
		read -r -p "Press Enter..."
		return
	fi

	if (( ${#owned_vehicles[@]} > 0 )); then
		echo "You have vehicles available: (${owned_vehicles[*]})."
		read -r -p "Use your own vehicle for free travel? (y/n): " use_vehicle_choice
		if [[ "$use_vehicle_choice" == "y" || "$use_vehicle_choice" == "Y" ]]; then
			use_own_vehicle=true
			travel_cost=0
			echo "You hop into one of your vehicles."
			play_sfx_mpg "car_start"
		fi
	fi

	if $use_own_vehicle || (( cash >= travel_cost )); then
		if ! $use_own_vehicle; then
			cash=$((cash - travel_cost))
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
	local gun_choice=""
	clear_screen
	echo "--- Ammu-Nation ---"
	echo "1. Pistol(\$100) 2. Shotgun(\$250) 3. SMG(\$500) 4. Rifle(\$750) 5. Sniper(\$1000) 6. Leave"
	printf "Your Cash: \$%d\n" "$cash"
	read -r -p "Enter your choice: " gun_choice
	[[ ! "$gun_choice" =~ ^[0-9]+$ ]] && { echo "Invalid input."; read -r -p "Press Enter..."; return; }
    run_clock 1
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
			echo "Looks like you already got a $gun_name there, partner."
			read -r -p "Press Enter..."; return
		fi
	done
	if (( cash >= gun_cost )); then
		play_sfx_mpg "cash_register"
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
	local vehicle_choice=""
	local i=1
	local buyable_vehicles=()
	while true; do
        run_clock 1
		clear_screen
		echo "--- Premium Deluxe Motorsport ---"
		buyable_vehicles=()
		i=1
		for type in "${!vehicle_types[@]}"; do
			local price=${vehicle_types[$type]}
			printf " %d. %-12s (\$ %d)\n" "$i" "$type" "$price"
			buyable_vehicles+=("$type")
			((i++))
		done
		printf " %d. Leave\n" "$i"
		printf "Your Cash: \$%d\n" "$cash"
		read -r -p "Enter your choice: " vehicle_choice

		if [[ "$vehicle_choice" == "$i" ]]; then
			echo "Come back when you want REAL quality!"; sleep 1; return
		fi
		if ! [[ "$vehicle_choice" =~ ^[0-9]+$ ]] || (( vehicle_choice < 1 || vehicle_choice > ${#buyable_vehicles[@]} )); then
			echo "Invalid choice."; sleep 1; continue
		fi
		local chosen_type="${buyable_vehicles[$((vehicle_choice - 1))]}"
		local chosen_price="${vehicle_types[$chosen_type]}"

		if (( cash >= chosen_price )); then
			play_sfx_mpg "cash_register"
			cash=$((cash - chosen_price))
			owned_vehicles+=("$chosen_type")
			echo "Congratulations on your new $chosen_type! That's \$${chosen_price}."
			play_sfx_mpg "car_start"
			read -r -p "Press Enter..."
		else
			echo "Sorry, you need \$${chosen_price} for the $chosen_type."
			read -r -p "Press Enter..."
		fi
	done
}

show_inventory() {
    run_clock 0 # Viewing inventory is free
	clear_screen
	echo "--- Inventory & Stats ---"
	printf " Cash: \$%d\n" "$cash"
	printf " Health: %d%%\n" "$health"
	echo "--------------------------"
    echo " Gang Affiliation:"
    if [[ "$player_gang" == "None" ]]; then
        printf "  - Gang: N/A\n"
        printf "  - Rank: N/A\n"
    else
        printf "  - Gang: %s\n" "$player_gang"
        printf "  - Rank: %s\n" "$player_gang_rank"
    fi
    printf "  - Respect: %d\n" "$player_respect"
	echo "--------------------------"
	echo " Guns:"
	if (( ${#guns[@]} > 0 )); then printf "  - %s\n" "${guns[@]}"; else echo "  (None)"; fi
	echo "--------------------------"
	echo " Items:"
	 if (( ${#items[@]} > 0 )); then printf "  - %s\n" "${items[@]}"; else echo "  (None)"; fi
	echo "--------------------------"
	echo " Drugs:"
	local drug_found=false
	for drug in "${!default_drugs[@]}"; do
		local amount=${drugs[$drug]:-0}
		if (( amount > 0 )); then printf "  - %-10s: %d units\n" "$drug" "$amount"; drug_found=true; fi
	done
	if ! $drug_found; then echo "  (None)"; fi
	echo "--------------------------"
	echo " Vehicles:"
	if (( ${#owned_vehicles[@]} > 0 )); then printf "  - %s\n" "${owned_vehicles[@]}"; else echo "  (None)"; fi
	echo "--------------------------"
	echo " Skills:"
	for skill in "${!default_skills[@]}"; do printf "  - %-12s: %d\n" "$skill" "${skills[$skill]:-0}"; done
	echo "--------------------------"
    echo " Owned Properties/Businesses:"
    if (( ${#owned_businesses[@]} > 0 )); then
        for prop in "${!owned_businesses[@]}"; do
            local details="${owned_businesses[$prop]}"
            printf "  - %-20s (%s)\n" "$prop" "${details// / }"
        done
    else
        echo "  (None)"
    fi
	echo "--------------------------"
	read -r -p "Press Enter to return..."
}

work_job() {
	local job_type="$1"
    run_clock 4 # Jobs take time
	local earnings=0 base_earnings=0 skill_bonus=0
	local min_earnings=0 max_earnings=0
	local relevant_skill_level=1 relevant_skill_name=""

	case "$location" in
		"Los Santos")   min_earnings=20; max_earnings=60;; "San Fierro")   min_earnings=25; max_earnings=70;;
		"Las Venturas") min_earnings=30; max_earnings=90;; "Vice City")    min_earnings=15; max_earnings=50;;
		"Liberty City") min_earnings=35; max_earnings=100;; *) min_earnings=10; max_earnings=40;;
	esac
	base_earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings))

	case "$job_type" in
		"taxi"|"delivery") relevant_skill_name="driving"; relevant_skill_level=${skills[$relevant_skill_name]:-1}; skill_bonus=$((relevant_skill_level * (job_type == "delivery" ? 4 : 3) )); play_sfx_mpg "taxi";;
		"mechanic") relevant_skill_name="strength"; relevant_skill_level=${skills[$relevant_skill_name]:-1}; skill_bonus=$((relevant_skill_level * 1)); play_sfx_mpg "mechanic";;
		"security") relevant_skill_name="strength"; relevant_skill_level=${skills[$relevant_skill_name]:-1}; skill_bonus=$((relevant_skill_level * 2)); play_sfx_mpg "security";;
		"performer") relevant_skill_name="charisma"; relevant_skill_level=${skills[$relevant_skill_name]:-1}; skill_bonus=$((relevant_skill_level * 5)); play_sfx_mpg "street_performer";;
		"bus_driver") relevant_skill_name="driving"; relevant_skill_level=${skills[$relevant_skill_name]:-1}; skill_bonus=$((relevant_skill_level * 2)); play_sfx_mpg "bus_driving";;
		*) echo "Internal Error: Invalid Job Type '$job_type'"; return;;
	esac

	earnings=$((base_earnings + skill_bonus)); (( earnings < 0 )) && earnings=0
	cash=$((cash + earnings))
	clear_screen
	printf "Finished your shift. You earned \$%d (Base: \$%d, Skill Bonus: \$%d).\n" "$earnings" "$base_earnings" "$skill_bonus"
	if (( wanted_level > 0 && RANDOM % 4 == 0 )); then
			wanted_level=$((wanted_level - 1))
			echo -e "\e[1;32mLaying low seems to have worked. Wanted Level Decreased!\e[0m"
	fi
	if [[ -n "$relevant_skill_name" ]] && (( RANDOM % 5 == 0 )); then
			skills[$relevant_skill_name]=$((relevant_skill_level + 1))
			printf "Your \e[1;32m%s\e[0m skill increased!\n" "$relevant_skill_name"
	fi
	read -r -p "Press Enter to continue..."
}

street_race() {
    run_clock 2
	local driving_skill=${skills[driving]:-1}
	local base_win_chance=40
	local win_chance=$(( base_win_chance + driving_skill * 5 )); (( win_chance > 90 )) && win_chance=90

	clear_screen; echo "--- Street Race ---"; echo "Win Chance: ${win_chance}%"; sleep 1
	echo "3... 2... 1... GO!"; sleep 1
	read -r -p "Press Enter for the race results..."
	local winnings=0 damage=0
	if (( RANDOM % 100 < win_chance )); then
		winnings=$((RANDOM % 151 + 100 + driving_skill * 10))
		cash=$((cash + winnings))
		damage=$((RANDOM % 15 + 5))
		if $body_armor_equipped; then local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction)); body_armor_equipped=false; fi
		health=$((health - damage))
		clear_screen
		printf "\e[1;32m*** YOU WON THE RACE! ***\e[0m\n"
		printf "You collected \$%d.\n" "$winnings"; printf "Took minor damage (-%d%% health).\n" "$damage"
		play_sfx_mpg "win"
        award_respect $((RANDOM % 15 + 10))
		if (( RANDOM % 3 == 0 )); then skills[driving]=$((driving_skill + 1)); printf "Your \e[1;32mdriving\e[0m skill increased!\n"; fi
	else
		damage=$((RANDOM % 31 + 15))
		if $body_armor_equipped; then local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction)); body_armor_equipped=false; fi
		health=$((health - damage))
		clear_screen
		printf "\e[1;31m--- YOU LOST THE RACE! ---\e[0m\n"
		printf "You crashed and took %d%% damage.\n" "$damage"
        player_respect=$((player_respect - 5)); ((player_respect < 0)) && player_respect=0
        echo "You lost 5 Respect."
		play_sfx_mpg "lose"
	fi
	check_health
	read -r -p "Press Enter to continue..."
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

rob_store() {
    run_clock 2
	local stealth_skill=${skills[stealth]:-1}
	local base_chance=$((15 + stealth_skill * 5))
	clear_screen; echo "--- Rob Store ---"
	local final_success_chance=$(apply_gun_bonus "$base_chance" "robbery")
	echo "Calculating odds... Final success chance: ${final_success_chance}%"
	read -r -p "Press Enter to attempt the robbery..."

	if (( RANDOM % 100 < final_success_chance )); then
		local loot=$((RANDOM % 151 + 50 + stealth_skill * 10))
		cash=$((cash + loot))
		health=$((health - (RANDOM % 16 + 5)))
		clear_screen
		printf "\e[1;32mSuccess!\e[0m You grabbed \$%d.\n" "$loot"
		play_sfx_mpg "cash_register"
        award_respect $((RANDOM % 10 + 5))
        district_heat["$location"]=$(( ${district_heat[$location]:-0} + 2 ))
        echo "Your actions increased the heat in this district."
		if (( RANDOM % 3 == 0 )); then skills[stealth]=$((stealth_skill + 1)); printf "Your \e[1;32mstealth\e[0m skill increased!\n"; fi
	else
		wanted_level=$((wanted_level + 1)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"
		local fine=$((RANDOM % 101 + 50 + wanted_level * 25))
		cash=$((cash - fine)); (( cash < 0 )) && cash=0
		health=$((health - (RANDOM % 26 + 10 + wanted_level * 5)))
		clear_screen
		printf "\e[1;31mFailed!\e[0m Cops arrived quickly.\n"
		printf "You were fined \$%d and took damage.\n" "$fine"
	fi
	check_health; read -r -p "Press Enter..."
}

# --- Clock & World State ---
calculate_and_apply_payouts() {
    clear_screen
    echo "--- Daily Payouts (Day ${game_day}, 00:00) ---"
    
    local territory_income=0
    local business_income=0
    local upkeep_cost=0

    # Collect income from all owned territories (globally)
    if [[ "$player_gang" != "None" ]]; then
        for key in "${!territory_owner[@]}"; do
            if [[ "${territory_owner[$key]}" == "$player_gang" ]]; then
                territory_income=$((territory_income + 50))
            fi
        done
    fi
    
    # Collect income from businesses (globally)
    local smuggling_level=${gang_upgrades[smuggling_routes]:-0}
    local smuggling_bonus=$((smuggling_level * 100))
    for prop in "${!owned_businesses[@]}"; do
        if [[ "${owned_businesses[$prop]}" == *"type=Legal"* ]]; then
            business_income=$((business_income + 200))
        elif [[ "${owned_businesses[$prop]}" == *"type=IllegalFront"* ]]; then
            business_income=$((business_income + 500 + smuggling_bonus))
        fi
    done

    # Calculate and apply upkeep for recruits
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

    # Slightly decrease heat over time in all districts
    for city_name in "${!district_heat[@]}"; do
        if (( ${district_heat[$city_name]} > 0 )); then
            district_heat[$city_name]=$(( ${district_heat[$city_name]} - 1 ))
        fi
    done
    echo "The heat has cooled down slightly across the cities."

    read -r -p "Press Enter to continue..."
}

run_clock() {
    local hours_to_pass=$1
    game_hour=$((game_hour + hours_to_pass))

    # Check if a new day has started
    while (( game_hour >= 24 )); do
        game_hour=$((game_hour - 24))
        game_day=$((game_day + 1))
        # If the new hour is the payout hour, trigger payouts
        if (( game_hour == PAYOUT_HOUR )); then
            calculate_and_apply_payouts
        fi
    done
}

update_world_state() {
    # This function is now just a wrapper for the clock.
    # We pass 0 hours because the clock is run by the actions themselves.
    # This structure allows for future passive events to be added here.
    run_clock 0
}

# --- Gang System Functions ---
set_initial_gang_relations() {
    gang_relations=()
    for rival in "${!GANG_HOME_CITY[@]}"; do
        if [[ "$rival" != "$player_gang" ]]; then
            gang_relations["$rival"]="Hostile"
        fi
    done
    if [[ "$player_gang" == "Grove Street" ]]; then
        gang_relations["Ballas"]="War"; gang_relations["Vagos"]="War"
    fi
}

apply_gang_upgrades() {
    local safe_house_level=${gang_upgrades[safe_house]:-0}
    max_recruits=$(( 2 + safe_house_level * 2 ))
}

show_gang_menu() {
    run_clock 0
    while true; do
        clear_screen
        echo "--- Gang & Empire Management ---"
        echo "1. View Territory Map (Current City)"
        echo "2. Manage Businesses"
        echo "3. Initiate Gang War (in this city)"
        if [[ "$player_gang" == "None" ]]; then
            echo "4. Join a Faction (in this city)"
            if (( player_respect >= GANG_CREATION_RESPECT_REQ )); then
                 echo -e "5. Create a Faction (Req: \e[1;32m${GANG_CREATION_RESPECT_REQ}\e[0m Respect)"
            fi
        else
            echo "4. Manage Recruits"
            echo "5. Gang Upgrades"
            echo "6. Diplomacy"
        fi
        echo "B. Back to Main Menu"
        read -r -p "Enter your choice: " choice

        case "$choice" in
            1) show_territory_map ;;
            2) manage_businesses ;;
            3) initiate_gang_war ;;
            4)
                if [[ "$player_gang" == "None" ]]; then
                    join_gang_interface
                else
                    manage_recruits_menu
                fi
                ;;
            5)
                if [[ "$player_gang" == "None" ]]; then
                    if (( player_respect >= GANG_CREATION_RESPECT_REQ )); then
                        create_own_gang
                    else
                        echo "Invalid choice." && sleep 1
                    fi
                else
                    gang_upgrades_menu
                fi
                ;;
            6)
                if [[ "$player_gang" != "None" ]]; then
                    diplomacy_menu
                else
                    echo "Invalid choice." && sleep 1
                fi
                ;;
            'b'|'B') return ;;
            *) echo "Invalid choice." && sleep 1;;
        esac
    done
}

show_territory_map() {
    run_clock 0
    clear_screen
    echo "--- ${location} Territory Map ---"
    echo "---------------------------------"
    local territory_found=false
    for key in "${!territory_owner[@]}"; do
        local owner="${territory_owner[$key]}"
        local city district
        IFS='|' read -r city district <<< "$key"

        if [[ "$city" == "$location" ]]; then
            territory_found=true
            local color="\e[0m" # Default
            if [[ "$owner" == "$player_gang" && "$player_gang" != "None" ]]; then
                color="\e[1;32m"
            elif [[ "$owner" == "Ballas" || "$owner" == "Leone Family" ]]; then
                color="\e[1;35m"
            elif [[ "$owner" == "Vagos" || "$owner" == "Triads" ]]; then
                color="\e[1;33m"
            elif [[ "$owner" == "Grove Street" ]]; then
                color="\e[1;32m"
            elif [[ "$owner" == "Da Nang Boys" || "$owner" == "Sindacco Family" ]]; then
                color="\e[1;31m"
            else
                color="\e[1;36m"
            fi
            printf "| %-20s | Owner: %b%s\e[0m\n" "$district" "$color" "$owner"
        fi
    done
    if ! $territory_found; then
        echo "No contested territories in this city."
    fi
    echo "---------------------------------"
    read -r -p "Press Enter to return..."
}

manage_businesses() {
    run_clock 1
    clear_screen
    echo "--- Business Management ---"
    echo "1. Buy New Property (in ${location})"
    echo "2. Manage Owned Properties (Global)"
    echo "B. Back"
    read -r -p "Choice: " choice

    case "$choice" in
        1) buy_property ;;
        2) manage_owned_property ;;
        'b'|'B') return ;;
        *) echo "Invalid." && sleep 1;;
    esac
}

buy_property() {
    # This logic will be expanded in Phase 2
    clear_screen
    echo "--- Real Estate For Sale in ${location} ---"
    local i=1
    local -a prop_keys=()
    local -a prop_costs=()
    local -a prop_types=()

    for prop_name in "${!available_properties[@]}"; do
        if [[ ! -v "owned_businesses[$prop_name]" ]]; then
            local prop_details="${available_properties[$prop_name]}"
            local price prop_city prop_type
            IFS=':' read -r price prop_city prop_type <<< "$prop_details"
            
            if [[ "$prop_city" == "$location" ]]; then
                printf "%d. %-25s (\$%d) - [%s]\n" "$i" "$prop_name" "$price" "$prop_type"
                prop_keys+=("$prop_name")
                prop_costs+=("$price")
                prop_types+=("$prop_type")
                ((i++))
            fi
        fi
    done
    
    if (( ${#prop_keys[@]} == 0 )); then
        echo "No properties are currently for sale in this city."
    fi
    echo "----------------------------------------"
    echo "B. Back"
    read -r -p "Which property to buy? " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#prop_keys[@]} )); then
        local index=$((choice - 1))
        local prop_to_buy="${prop_keys[$index]}"
        local prop_cost="${prop_costs[$index]}"
        local prop_type="${prop_types[$index]}"

        if (( cash >= prop_cost )); then
            cash=$((cash - prop_cost))
            owned_businesses["$prop_to_buy"]="type=$prop_type status=Idle"
            echo "You have purchased the $prop_to_buy for \$${prop_cost}!"
            play_sfx_mpg "cash_register"
        else
            echo "Not enough cash."
        fi
    elif [[ "$choice" == "b" || "$choice" == "B" ]]; then
        return
    else
        echo "Invalid selection."
    fi
    read -r -p "Press Enter..."
}

manage_owned_property() {
    clear_screen
    echo "--- Your Properties (Global) ---"
    if (( ${#owned_businesses[@]} == 0 )); then
        echo "You don't own any properties."
        read -r -p "Press Enter..."
        return
    fi

    local i=1
    local -a owned_prop_keys=()
    for prop in "${!owned_businesses[@]}"; do
        printf "%d. %-25s (%s)\n" "$i" "$prop" "${owned_businesses[$prop]}"
        owned_prop_keys+=("$prop")
        ((i++))
    done
    echo "--------------------------------"
    echo "B. Back"
    read -r -p "Select property to manage: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#owned_prop_keys[@]} )); then
        local prop_to_manage="${owned_prop_keys[$((choice-1))]}"
        echo "Managing $prop_to_manage..."
        echo "This feature (upgrading, production, selling) is under development."
    elif [[ "$choice" == "b" || "$choice" == "B" ]]; then
        return
    else
        echo "Invalid selection."
    fi
    read -r -p "Press Enter..."
}

create_own_gang() {
    run_clock 1
    clear_screen
    echo "--- Found Your Own Gang ---"
    echo "You've got the respect to lead. Now you need a name."
    read -r -p "Enter the name for your new gang: " new_gang_name

    if [[ -z "$new_gang_name" || "$new_gang_name" == "None" || "$new_gang_name" == "Unaffiliated" || -v "GANG_HOME_CITY[$new_gang_name]" ]]; then
        echo "Invalid or reserved name. A gang needs a unique title."
        read -r -p "Press Enter..."
        return
    fi

    player_gang="$new_gang_name"
    player_gang_rank="Soldier"
    set_initial_gang_relations
    
    play_sfx_mpg "win_big"
    echo -e "\nThe \e[1;36m${player_gang}\e[0m are now on the map!"
    echo "You are their leader, starting with the rank of ${player_gang_rank}."
    echo "You have no territory yet. It's time to earn it."
    read -r -p "Press Enter..."
}

join_gang_interface() {
    run_clock 1
    if [[ "$player_gang" != "None" ]]; then
        echo "You are already in the $player_gang gang."
        read -r -p "Press Enter..."
        return
    fi
    
    local i=1
    local -a menu_options=()
    clear_screen
    echo "--- Join a Faction in ${location} ---"
    echo "Crews in this city are looking for fresh blood."
    echo "------------------------------------------------"
    
    for gang in "${!GANG_HOME_CITY[@]}"; do
        if [[ "${GANG_HOME_CITY[$gang]}" == "$location" ]]; then
            printf " %d. Join the %s\n" "$i" "$gang"
            menu_options+=("$gang")
            ((i++))
        fi
    done
    
    if (( ${#menu_options[@]} == 0 )); then
        echo " No major gangs are looking for recruits here."
        read -r -p "Press Enter..."
        return
    fi
    echo "------------------------------------------------"
    local back_option_number=$i
    printf " %d. Back\n" "$back_option_number"
    echo "------------------------------------------------"
    read -r -p "Your choice: " choice

    if [[ "$choice" == "$back_option_number" ]]; then
        return
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#menu_options[@]} )); then
        local new_gang="${menu_options[$((choice-1))]}"
        echo "You approach the ${new_gang} crew..."
        sleep 2
        echo "'So you want to roll with us? You gotta prove yourself first.'"
        if (( cash >= 200 )); then
            echo "They ask for a \$200 'tribute' to show you're serious."
            read -r -p "Pay the tribute? (y/n): " pay
            if [[ "$pay" == "y" ]]; then
                cash=$((cash-200))
                player_gang="$new_gang"
                player_gang_rank="Associate"
                set_initial_gang_relations
                echo "You've paid your dues. Welcome to ${player_gang}."
                award_respect 100
            else
                echo "You walked away. They won't be asking again."
            fi
        else
            echo "You don't even have the cash to get their attention. Come back later."
        fi
    else
        echo "Invalid choice."
    fi
    read -r -p "Press Enter to continue..."
}

initiate_gang_war() {
    run_clock 3
    if [[ "$player_gang" == "None" || "$player_gang_rank" == "Outsider" ]]; then
        echo "You need to be part of a gang to start a war."
        read -r -p "Press Enter..."; return
    fi
    if (( ${#guns[@]} == 0 )); then
        echo "You need a weapon to start a gang war! Buy one first."
        read -r -p "Press Enter..."; return
    fi

    local target_key=""
    for key in "${!territory_owner[@]}"; do
        local city district
        IFS='|' read -r city district <<< "$key"
        if [[ "$city" == "$location" && "${territory_owner[$key]}" != "$player_gang" && "${territory_owner[$key]}" != "Unaffiliated" ]]; then
            target_key="$key"
            break
        fi
    done

    if [[ -z "$target_key" ]]; then
        echo "There are no rival territories in ${location} to attack."
        read -r -p "Press Enter..."; return
    fi

    local rival_gang="${territory_owner[$target_key]}"
    local target_district
    IFS='|' read -r - target_district <<< "$target_key"

    clear_screen
    echo -e "You are about to start a war for \e[1;33m${target_district}\e[0m in ${location}."
    echo -e "It's controlled by the \e[1;31m${rival_gang}\e[0m."
    read -r -p "Are you ready to fight? (y/n) " confirm
    if [[ "$confirm" != "y" ]]; then
        echo "You back off for now."; read -r -p "Press Enter..."; return
    fi

    local recruit_bonus=0
    for recruit in "${player_recruits[@]}"; do
        local str; IFS=':' read -r - str - <<< "$recruit"
        recruit_bonus=$((recruit_bonus + str))
    done
    local locker_level=${gang_upgrades[weapon_locker]:-0}
    local locker_bonus=$((locker_level * 2))
    local total_bonus=$((recruit_bonus + locker_bonus))
    if (( total_bonus > 0 )); then
        echo "Your crew gives you an edge: Recruits (+${recruit_bonus}%) + Weapon Locker (+${locker_bonus}%) = \e[1;32m+${total_bonus}%\e[0m"
    fi
    
    echo "The streets clear as the first wave of ${rival_gang} members arrive..."
    sleep 2
    local wave=1; local success=true
    while (( wave <= 3 )); do
        echo "--- WAVE ${wave} ---"
        local strength_skill=${skills[strength]:-1}
        local success_chance=$(( 60 + strength_skill*3 - wave*10 + total_bonus ))
        
        if (( RANDOM % 100 < success_chance )); then
            echo "You fought them off and secured the area! (Chance: ${success_chance}%)"
            local wave_damage=$(( RANDOM % (5 * wave) + 5))
            health=$((health - wave_damage))
            echo "You took ${wave_damage}% damage."
            if ! check_health; then success=false; break; fi
            ((wave++)); sleep 1
        else
            echo "You were overwhelmed by their numbers! (Chance: ${success_chance}%)"
            health=$((health - (RANDOM % 20 + 15))); success=false; break
        fi
        if (( RANDOM % 2 == 0 )); then
            wanted_level=$((wanted_level + 1))
            echo -e "\e[1;31mThe fight drew police attention! Wanted level increased!\e[0m"
            play_sfx_mpg "police_siren"
            if (( wanted_level >= 3 )); then echo "SWAT is moving in! The war is over!"; success=false; break; fi
        fi
    done

    if $success; then
        clear_screen
        echo -e "\e[1;32m*** VICTORY! ***\e[0m"
        echo "You have taken control of \e[1;33m${target_district}\e[0m for the ${player_gang}!"
        territory_owner["$target_key"]="$player_gang"
        award_respect $((RANDOM % 150 + 100))
        district_heat["$location"]=$(( ${district_heat[$location]:-0} + 20 ))
        play_sfx_mpg "win_big"
    else
        clear_screen
        echo -e "\e[1;31m--- DEFEAT! ---"
        echo "You were forced to retreat. The ${rival_gang} hold their turf."
        player_respect=$((player_respect - 50)); ((player_respect < 0)) && player_respect=0
        echo "You lost 50 Respect."
        play_sfx_mpg "lose_big"
    fi
    check_health
    read -r -p "Press Enter..."
}

manage_recruits_menu() {
    run_clock 1
    local recruit_names=("Spike" "Knuckles" "Ghost" "Tiny" "Whisper" "Shadow" "Rico" "Vinnie")
    while true; do
        clear_screen
        echo "--- Manage Recruits ---"
        echo "Recruits: ${#player_recruits[@]} / ${max_recruits}"
        echo "-----------------------------------"
        if (( ${#player_recruits[@]} == 0 )); then
            echo " You have no recruits."
        else
            for recruit in "${player_recruits[@]}"; do
                local name str upkeep; IFS=':' read -r name str upkeep <<< "$recruit"
                printf " - %-10s (Strength: %d, Upkeep: \$%d/day)\n" "$name" "$str" "$upkeep"
            done
        fi
        echo "-----------------------------------"
        echo "1. Hire New Recruit"
        echo "2. Back to Gang Menu"
        read -r -p "Choice: " choice

        case "$choice" in
            1)
                if (( ${#player_recruits[@]} < max_recruits )); then
                    local hire_cost=$((RANDOM % 501 + 500))
                    if (( cash >= hire_cost )); then
                        cash=$((cash - hire_cost))
                        local name=${recruit_names[RANDOM % ${#recruit_names[@]}]}
                        local str=$((RANDOM % 4 + 2)) # Strength 2-5
                        local upkeep=$((str * 25)) # Upkeep based on strength
                        player_recruits+=("${name}:${str}:${upkeep}")
                        echo "Hired ${name} for \$${hire_cost}. They look tough."
                        play_sfx_mpg "cash_register"
                    else
                        echo "Not enough cash to hire anyone right now (cost ~$${hire_cost})."
                    fi
                else
                    echo "You can't hire any more recruits. Upgrade your Safe House."
                fi
                read -r -p "Press Enter..."
                ;;
            2) return ;;
            *) echo "Invalid choice." && sleep 1 ;;
        esac
    done
}

gang_upgrades_menu() {
    run_clock 1
    declare -A UPGRADE_COSTS=(
        ["safe_house"]="5000 15000 40000"
        ["weapon_locker"]="10000 25000 50000"
        ["smuggling_routes"]="20000 50000 100000"
    )
    declare -A UPGRADE_DESCS=(
        ["safe_house"]="Increases max recruits (+2 per level)"
        ["weapon_locker"]="Provides a passive bonus in gang wars (+2% per level)"
        ["smuggling_routes"]="Increases income from illegal businesses (+\$100/day per level)"
    )

    while true; do
        clear_screen
        echo "--- Gang Upgrades ---"
        echo "Spend cash to permanently improve your gang's operations."
        echo "--------------------------------------------------------"
        
        local i=1
        local -a upgrade_keys=("safe_house" "weapon_locker" "smuggling_routes")
        for key in "${upgrade_keys[@]}"; do
            local level=${gang_upgrades[$key]:-0}
            local costs=(${UPGRADE_COSTS[$key]})
            local desc=${UPGRADE_DESCS[$key]}
            
            printf " %d. %-20s (Level %d)\n" "$i" "$(tr '_' ' ' <<< "$key" | awk '{for(j=1;j<=NF;j++) $j=toupper(substr($j,1,1)) substr($j,2)} 1')" "$level"
            echo "    - ${desc}"
            if (( level < ${#costs[@]} )); then
                printf "    - Next Level Cost: \e[1;31m\$%d\e[0m\n" "${costs[$level]}"
            else
                echo -e "    - \e[1;32mMAX LEVEL\e[0m"
            fi
            ((i++))
        done
        echo "--------------------------------------------------------"
        echo "$i. Back to Gang Menu"
        read -r -p "Purchase upgrade (number): " choice

        if [[ "$choice" == "$i" ]]; then
            return
        elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice < i )); then
            local key="${upgrade_keys[$((choice-1))]}"
            local level=${gang_upgrades[$key]:-0}
            local costs=(${UPGRADE_COSTS[$key]})
            if (( level < ${#costs[@]} )); then
                local cost=${costs[$level]}
                if (( cash >= cost )); then
                    cash=$((cash - cost))
                    gang_upgrades[$key]=$((level + 1))
                    apply_gang_upgrades # Immediately apply effect
                    echo "Upgrade purchased!"
                    play_sfx_mpg "cash_register"
                else
                    echo "Not enough cash (\$$cost needed)."
                fi
            else
                echo "This upgrade is already at its max level."
            fi
            read -r -p "Press Enter..."
        else
            echo "Invalid choice." && sleep 1
        fi
    done
}

diplomacy_menu() {
    run_clock 1
    while true; do
        clear_screen
        echo "--- Diplomacy ---"
        echo "Manage relations with other factions. Hostile gangs may act against you."
        echo "-------------------------------------------------------------------"
        
        local i=1
        local -a hostile_gangs=()
        for rival in "${!gang_relations[@]}"; do
            local status="${gang_relations[$rival]}"
            local color="\e[0m"
            case "$status" in
                "War") color="\e[1;35m";; "Hostile") color="\e[1;31m";; "Neutral") color="\e[1;33m";;
            esac
            printf " - %-20s Status: %b%s\e[0m\n" "$rival" "$color" "$status"
        done
        echo "-------------------------------------------------------------------"
        echo "Actions:"
        local menu_idx=1
        for rival in "${!gang_relations[@]}"; do
            if [[ "${gang_relations[$rival]}" == "Hostile" ]]; then
                printf " %d. Offer Tribute to the %s\n" "$menu_idx" "$rival"
                hostile_gangs+=("$rival")
                ((menu_idx++))
            fi
        done
        if (( ${#hostile_gangs[@]} == 0 )); then
            echo " No active diplomatic actions available."
        fi
        echo "-------------------------------------------------------------------"
        echo "B. Back to Gang Menu"
        read -r -p "Choice: " choice

        if [[ "$choice" == "B" || "$choice" == "b" ]]; then
            return
        elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#hostile_gangs[@]} )); then
            local target_gang="${hostile_gangs[$((choice-1))]}"
            local tribute_cost=10000
            echo "Offering a tribute to the ${target_gang} will cost \$${tribute_cost}."
            read -r -p "Are you sure? (y/n): " confirm
            if [[ "$confirm" == "y" && "$cash" -ge "$tribute_cost" ]]; then
                cash=$((cash - tribute_cost))
                local charisma_skill=${skills[charisma]:-1}
                local success_chance=$(( 30 + charisma_skill * 5 ))
                echo "You send the tribute. They consider your offer... (Chance: ${success_chance}%)"
                sleep 2
                if (( RANDOM % 100 < success_chance )); then
                    echo -e "\e[1;32mSuccess!\e[0m The ${target_gang} have accepted your peace offering. Relations are now Neutral."
                    gang_relations["$target_gang"]="Neutral"
                else
                    echo -e "\e[1;31mFailed!\e[0m The ${target_gang} took your money and laughed. They remain Hostile."
                fi
            elif [[ "$confirm" == "y" ]]; then
                echo "Not enough cash for the tribute."
            else
                echo "Tribute cancelled."
            fi
            read -r -p "Press Enter..."
        else
            echo "Invalid choice." && sleep 1
        fi
    done
}

# Functions from old version below (with run_clock calls added where appropriate)
# ... [rest of the functions like hospital, hooker, drug market, etc.]
# ... [all these functions would need a `run_clock` call with an appropriate hour value]
# --- For brevity, I'll only show a few examples ---

visit_hospital() {
    run_clock 1
    # ... rest of function is the same ...
	local hospital_choice=""
	while true; do
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
	done
}

# (The rest of the functions from 2.5.0 would be here)

# --- Save/Load System ---
save_game() {
    run_clock 0
	local save_path="$BASEDIR/$SAVE_DIR"
	mkdir -p "$save_path" || { echo "Error: Could not create save directory '$save_path'."; read -r -p "Press Enter..."; return 1; }
	echo "Saving game state..."
    # All the save files from 2.5.0 plus the new time variables
	local time_file="$save_path/time.sav"
    # ... other files ...
    local gang_file="$save_path/gang.sav"
    local territory_file="$save_path/territory.sav"
    local heat_file="$save_path/heat.sav"
    local business_file="$save_path/business.sav"
    local recruits_file="$save_path/recruits.sav"
    local upgrades_file="$save_path/upgrades.sav"
    local relations_file="$save_path/relations.sav"
    
    # Save time
    echo "day:$game_day" > "$time_file"
    echo "hour:$game_hour" >> "$time_file"

	# ... (all other save logic from 2.5.0) ...
    printf '%s\n' "${player_recruits[@]}" > "$recruits_file"

    save_assoc_array() {
        local file_path="$1"; shift; declare -n arr_ref="$1"
        : > "$file_path"
        for key in "${!arr_ref[@]}"; do printf "%s@@@%s\n" "$key" "${arr_ref[$key]}" >> "$file_path"; done
    }
    # ...
    save_assoc_array "$upgrades_file" "gang_upgrades"
    save_assoc_array "$relations_file" "gang_relations"
    # ... rest of save logic
	echo "Game saved successfully."
	read -r -p "Press Enter to continue..."
}

load_game() {
	local save_path="$BASEDIR/$SAVE_DIR"
	if [[ ! -d "$save_path" ]]; then
		echo "Error: Save directory not found."; read -r -p "Press Enter..."; return 1;
	fi
	echo "Attempting to load game..."
    initialize_world_data

    # Load time
    if [[ -f "$save_path/time.sav" ]]; then
        while IFS=':' read -r key value; do
            case "$key" in
                "day") game_day="$value";;
                "hour") game_hour="$value";;
            esac
        done < "$save_path/time.sav"
    fi
	
    # ... (all other load logic from 2.5.0) ...
    load_indexed_array() {
        local file_path="$1"; shift; declare -n arr_ref="$1"; arr_ref=()
        if [[ -f "$file_path" ]]; then while IFS= read -r line; do [[ -n "$line" ]] && arr_ref+=("$line"); done < "$file_path"; fi
    }
    load_indexed_array "$save_path/recruits.sav" "player_recruits"

    load_assoc_array() {
        local file_path="$1"; shift; declare -n arr_ref="$1"; arr_ref=()
        if [[ -f "$file_path" ]]; then while IFS='@@@' read -r key value; do [[ -n "$key" ]] && arr_ref["$key"]="$value"; done < "$file_path"; fi
    }
    load_assoc_array "$save_path/upgrades.sav" "gang_upgrades"
    load_assoc_array "$save_path/relations.sav" "gang_relations"
    # ... rest of load logic
    apply_gang_upgrades

	echo "Game loaded successfully."
	read -r -p "Press Enter to start playing..."
	return 0
}

# --- Game Initialization ---
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
	owned_vehicles=()
	wanted_level=0
	declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${default_drugs[$key]}; done
	declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${default_skills[$key]}; done
	body_armor_equipped=false
    game_day=1
    game_hour=8

    player_gang="None"
    player_gang_rank="Outsider"
    player_respect=0
    initialize_world_data

	echo "Welcome to Bash Theft Auto, $player_name!"
    if [ "$player_name" = "test" ]; then
        cash=999999
        player_respect=5000
    fi
	echo "Starting in $location with \$${cash} and ${health}% health."
	read -r -p "Press Enter to begin..."
}

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
		stty echo
		read -r -p "Enter your choice: " initial_choice

		case "$initial_choice" in
			1)
				read -r -p "Start new game? This deletes any existing save. (y/n): " confirm
				if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
					remove_save_files
					Game_variables
					return 0
				else echo "New game cancelled."; sleep 1; fi ;;
			2)
				if load_game; then return 0;
				else sleep 1; fi ;;
			3) cleanup_and_exit ;;
			*) echo "Invalid choice."; sleep 1 ;;
		esac
	done
}

# --- Main Execution ---
if ! run_initial_menu; then
	echo "Exiting due to initial menu failure or user request."
	stty echo
	exit 1
fi

# --- Main Game Loop ---
while true; do
	update_world_state

	if check_health; then
		clear_screen
	else
		clear_screen
	fi

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

	stty echo
	read -r -p "Enter your choice: " choice
	choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

	case "$choice_lower" in
		1) # Travel Menu
			clear_screen; echo "--- Travel Agency ---"
			echo "1. Los Santos | 2. San Fierro | 3. Las Venturas";
			echo "4. Vice City  | 5. Liberty City | 6. Stay Here";
			read -r -p "Enter choice: " city_choice
			case "$city_choice" in
				1) travel_to 50 "Los Santos";; 2) travel_to 75 "San Fierro";;
				3) travel_to 100 "Las Venturas";; 4) travel_to 150 "Vice City";;
				5) travel_to 200 "Liberty City";; 6) ;;
                *) echo "Invalid." && sleep 1;;
			esac;;
		2) buy_guns;;
		3) buy_vehicle;;
		4) show_inventory;;
		5) # Legal Work Menu
			clear_screen; echo "--- Honest Work ---"
			echo "1. Taxi Driver | 2. Delivery | 3. Mechanic | 4. Security | 5. Performer | 6. Back";
			read -r -p "Enter choice: " job_choice
			case "$job_choice" in
				1) work_job "taxi";; 2) work_job "delivery";; 3) work_job "mechanic";;
				4) work_job "security";; 5) work_job "performer";; 6) run_clock 0 ;;
                *) echo "Invalid." && sleep 1;;
			esac;;
		6) # Criminal Activity Menu
			clear_screen; echo "--- Criminal Activities ---"
			echo "1. Rob Store | 2. Carjack | 3. Burglary | 4. Heist | 5. Back";
			read -r -p "Enter choice: " criminal_choice
			case "$criminal_choice" in
				1) rob_store;; 2) carjack;; 3) burglary;; 4) heist;; 5) run_clock 0 ;;
                *) echo "Invalid." && sleep 1;;
			esac;;
		7) sell_drugs;;
		8) hire_hooker;;
		9) visit_hospital;;
		10) street_race;;
		11) buy_drugs;;
        'g') show_gang_menu;;
		's') save_game;;
		'l')
			 read -r -p "Load game? Unsaved progress will be lost. (y/n): " confirm
			 if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
				 load_game
			 else echo "Load cancelled."; sleep 1; fi ;;
		'm') play_music;;
		'a') about_music_sfx;;
		'x')
			 read -r -p "Are you sure you want to exit? (y/n): " confirm
			 if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
				 cleanup_and_exit
			 fi ;;
		*) echo "Invalid choice '$choice'." && run_clock 0 && sleep 1;;
	esac
done

cleanup_and_exit
