#ver 2.0.8
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

# --- Dependency Check ---
mpg123_available=true
if ! command -v mpg123 &> /dev/null; then
	echo "###########################################################"
	echo "# Warning: 'mpg123' command not found.                    #"
	echo "# Sound effects and music require mpg123.                 #"
	echo "# Please install it for the full experience.              #"
	echo "#---------------------------------------------------------#"
	echo "# On Debian/Ubuntu: sudo apt install mpg123               #"
	echo "# On Fedora:        sudo dnf install mpg123               #"
	echo "# On Arch Linux:    sudo pacman -S mpg123                 #"
	echo "# On macOS (Homebrew): brew install mpg123                #"
	echo "###########################################################"
	read -r -p "Press Enter to continue without sound..."
	mpg123_available=false
fi
# Check for bc command (needed for market mechanics)
if ! command -v bc &> /dev/null; then
	echo "############################################################"
	echo "# Warning: 'bc' command not found.                         #"
	echo "# Advanced drug market calculations require bc.            #"
	echo "# Please install it for the full experience.               #"
	echo "#----------------------------------------------------------#"
	echo "# On Debian/Ubuntu: sudo apt update && sudo apt install bc #"
	echo "# On Fedora:        sudo dnf install bc                    #"
	echo "# On Arch Linux:    sudo pacman -S bc                      #"
	echo "# On macOS (Homebrew): brew install bc                     #"
	echo "############################################################"
	read -r -p "Press Enter to continue with basic market calculations..."
	# Optionally, you could implement fallback logic here if bc is missing
fi


# --- Sound Effects Setup ---
sfx_dir="sfx"

play_sfx_mpg() {
	if ! $mpg123_available; then
		return 1
	fi
	local sound_name="$1"
	local sound_file="$BASEDIR/$sfx_dir/${sound_name}.mp3"
	if [[ -f "$sound_file" ]]; then
		if command -v mpg123 &> /dev/null; then
			 mpg123 -q "$sound_file" &>/dev/null &
			return 0
		fi
	else
		return 1
	fi
	return 1
}

# --- Plugin Loading ---
plugin_dir="plugins"

if [[ -d "$BASEDIR/$plugin_dir" ]]; then
	while IFS= read -r -d $'\0' plugin_script; do
		if [[ -f "$plugin_script" ]]; then
			source "$plugin_script"
		fi
	done < <(find "$BASEDIR/$plugin_dir" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)
else
	echo "Info: Plugin directory '$BASEDIR/$plugin_dir' not found. Skipping plugin load."
fi

# --- Functions ---

clear_screen() {
	clear
	printf "\e[93m=========================================\e[0m\n"
	printf "\e[1;43m|        Bash Theft Auto                |\e[0m\n"
	printf "\e[93m=========================================\e[0m\n"
	printf " Player: %-15s Location: %s\n" "$player_name" "$location"
	printf " Cash: \$%-16d Health: %d%%\n" "$cash" "$health"
	if $body_armor_equipped; then
		printf " Armor: \e[1;32mEquipped\e[0m"
	else
		printf " Armor: \e[1;31mNone\e[0m    "
	fi
	# Display Wanted Level
	local stars=""
	for ((i=0; i<wanted_level; i++)); do stars+="*"; done
	printf " | Wanted: \e[1;31m%-5s\e[0m\n" "$stars"
	printf "\e[1;34m=========================================\e[0m\n"

  printf "\e[44m new update is coming soon\e[0m\n "
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
		echo "You wake up later..."
		read -r -p "Press Enter to go to the hospital..."
		hospitalize_player
		return 1
	fi
	return 0
}

travel_to() {
	local travel_cost="$1"
	local new_location="$2"
	local current_location="$location"
	local use_own_vehicle=false

	if [[ "$new_location" == "$current_location" ]]; then
		echo "You are already in $new_location."
		read -r -p "Press Enter..."
		return
	fi

	# Option to use own vehicle
	if (( ${#owned_vehicles[@]} > 0 )); then
		echo "You have vehicles available: (${owned_vehicles[*]})."
		read -r -p "Use your own vehicle for free travel? (y/n): " use_vehicle_choice
		if [[ "$use_vehicle_choice" == "y" || "$use_vehicle_choice" == "Y" ]]; then
			use_own_vehicle=true
			travel_cost=0 # Free travel
			echo "You hop into one of your vehicles."
			play_sfx_mpg "car_start"
		fi
	fi

	if $use_own_vehicle || (( cash >= travel_cost )); then
		if $use_own_vehicle; then
			 printf "Driving from %s to %s...\n" "$current_location" "$new_location"
		else
			 printf "Traveling from %s to %s (\$%d)...\n" "$current_location" "$new_location" "$travel_cost"
			 play_sfx_mpg "air" # Only play plane sound if paying
		fi

		if command -v air_travel_animation &> /dev/null; then
			 # Maybe use a different animation for driving?
			 if $use_own_vehicle && command -v drive_animation &> /dev/null; then
				 drive_animation "$current_location" "$new_location"
			 else
				air_travel_animation "$current_location" "$new_location" # Fallback
			 fi
		else
			echo -n "["
			for _ in {1..20}; do echo -n "="; sleep 0.05; done
			echo ">]"
		fi

		# Only subtract cash if not using own vehicle
		if ! $use_own_vehicle; then
			cash=$((cash - travel_cost))
		fi

		location="$new_location"
		echo "You have arrived safely in $new_location."
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
		1) buy_gun "Pistol" 100;;
		2) buy_gun "Shotgun" 250;;
		3) buy_gun "SMG" 500;;
		4) buy_gun "Rifle" 750;;
		5) buy_gun "Sniper" 1000;;
		6) echo "Come back anytime!"; sleep 1; return;;
		*) echo "Invalid choice."; read -r -p "Press Enter...";;
	esac
}

buy_gun() {
	local gun_name="$1"
	local gun_cost="$2"
	local owned=false

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

	if (( cash >= gun_cost )); then
		play_sfx_mpg "cash_register"
		if command -v buy_animation &> /dev/null; then
			buy_animation "$gun_name"
		fi

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
	local buyable_vehicles=() # Array to map menu choice to vehicle name

	while true; do
		clear_screen
		echo "--- Premium Deluxe Motorsport ---"
		echo "Top quality vehicles! Mostly legal!"
		echo "---------------------------------"
		buyable_vehicles=() # Reset for menu display
		i=1
		for type in "${!vehicle_types[@]}"; do
			local price=${vehicle_types[$type]}
			printf " %d. %-12s (\$ %d)\n" "$i" "$type" "$price"
			buyable_vehicles+=("$type") # Store type corresponding to index i-1
			((i++))
		done
		echo "---------------------------------"
		printf " %d. Leave\n" "$i"
		echo "---------------------------------"
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
		printf "  - %s\n" "${items[@]}"
	else
		echo "  (None)"
	fi
	echo "--------------------------"
	echo " Drugs:"
	local drug_found=false
	for drug in "${!default_drugs[@]}"; do
		local amount=${drugs[$drug]:-0}
		if (( amount > 0 )); then
			printf "  - %-10s: %d units\n" "$drug" "$amount"
			drug_found=true
		fi
	done
	if ! $drug_found; then echo "  (None)"; fi
	echo "--------------------------"
	# Show Vehicles
	echo " Vehicles:"
	if (( ${#owned_vehicles[@]} > 0 )); then
		printf "  - %s\n" "${owned_vehicles[@]}"
	else
		echo "  (None)"
	fi
	echo "--------------------------"
	echo " Skills:"
	for skill in "${!default_skills[@]}"; do
		printf "  - %-12s: %d\n" "$skill" "${skills[$skill]:-0}"
	done
	echo "--------------------------"
	read -r -p "Press Enter to return..."
}

work_job() {
	local job_type="$1"
	local earnings=0 base_earnings=0 skill_bonus=0
	local min_earnings=0 max_earnings=0
	local relevant_skill_level=1 relevant_skill_name=""

	case "$location" in
		"Los Santos")   min_earnings=20; max_earnings=60;;
		"San Fierro")   min_earnings=25; max_earnings=70;;
		"Las Venturas") min_earnings=30; max_earnings=90;;
		"Vice City")    min_earnings=15; max_earnings=50;;
		"Liberty City") min_earnings=35; max_earnings=100;;
		*)              min_earnings=10; max_earnings=40;;
	esac
	base_earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings))

	case "$job_type" in
		"taxi"|"delivery")
			relevant_skill_name="driving"
			relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$((relevant_skill_level * (job_type == "delivery" ? 4 : 3) ))
			[[ "$job_type" == "delivery" ]] && base_earnings=$((base_earnings + 10))
			play_sfx_mpg "taxi"
			;;
		"mechanic")
			relevant_skill_name="strength"
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
			base_earnings=$((base_earnings - 10))
			base_earnings=$(( base_earnings < 5 ? 5 : base_earnings ))
			play_sfx_mpg "street_performer"
			;;
		"bus_driver")
			relevant_skill_name="driving"
			relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$((relevant_skill_level * 2))
			base_earnings=$((base_earnings + 25))
			play_sfx_mpg "bus_driving"
			;;
		*) echo "Internal Error: Invalid Job Type '$job_type'"; return;;
	esac

	earnings=$((base_earnings + skill_bonus))
	(( earnings < 0 )) && earnings=0

	if command -v working_animation &> /dev/null; then
		working_animation "$job_type"
	else
		echo "Working as a $job_type..."
		sleep 2
	fi

	cash=$((cash + earnings))
	clear_screen
	printf "Finished your shift as a %s in %s.\n" "$job_type" "$location"
	printf "You earned \$%d (Base: \$%d, Skill Bonus: \$%d).\n" "$earnings" "$base_earnings" "$skill_bonus"
	printf "You now have \$%d.\n" "$cash"

	# Chance to decrease wanted level with legal work
	if (( wanted_level > 0 )); then
		local decrease_chance=25 # 25% chance per job
		if (( RANDOM % 100 < decrease_chance )); then
			wanted_level=$((wanted_level - 1))
			echo -e "\e[1;32mLaying low seems to have worked. Wanted Level Decreased!\e[0m"
		fi
	fi

	if [[ -n "$relevant_skill_name" ]]; then
		local skill_increase_chance=20
		if [[ "$job_type" == "bus_driver" ]]; then skill_increase_chance=15; fi
		if (( RANDOM % 100 < skill_increase_chance )); then
			skills[$relevant_skill_name]=$((relevant_skill_level + 1))
			printf "Your \e[1;32m%s\e[0m skill increased!\n" "$relevant_skill_name"
		fi
	fi

	read -r -p "Press Enter to continue..."
}

street_race() {
	local driving_skill=${skills[driving]:-1}
	local base_win_chance=40
	local win_chance=$(( base_win_chance + driving_skill * 5 ))
	(( win_chance > 90 )) && win_chance=90
	(( win_chance < 10 )) && win_chance=10

	clear_screen
	echo "--- Street Race ---"
	echo "Joining an illegal street race in $location..."
	echo "Driving Skill: $driving_skill | Win Chance: ${win_chance}%"
	sleep 1

	if command -v race_animation &> /dev/null; then
		race_animation
	elif command -v working_animation &> /dev/null; then
		working_animation "street_race"
	else
		echo "Get ready..." ; sleep 1; echo "3... 2... 1... GO!"; sleep 1
	fi

	read -r -p "Press Enter for the race results..."

	local winnings=0 damage=0

	if (( RANDOM % 100 < win_chance )); then
		winnings=$((RANDOM % 151 + 100 + driving_skill * 10))
		cash=$((cash + winnings))
		damage=$((RANDOM % 15 + 5))

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
		if (( RANDOM % 3 == 0 )); then
			skills[driving]=$((driving_skill + 1))
			printf "Your \e[1;32mdriving\e[0m skill increased!\n"
		fi
	else
		# --- Lose --- Street race loss doesn't increase wanted level (usually) ---
		winnings=0
		damage=$((RANDOM % 31 + 15))
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
		play_sfx_mpg "lose"
	fi

	printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"

	check_health
	read -r -p "Press Enter to continue..."
}

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

apply_gun_bonus() {
	local base_chance=$1
	local action_message=$2
	local current_chance=$base_chance
	local gun_bonus=0
	local chosen_gun=""
	local gun_found=false
	local success_bonus=0

	if (( ${#guns[@]} == 0 )); then
		echo "You have no guns! This will be significantly harder."
		gun_bonus=-15
	else
		echo "Available guns: ${guns[*]}"
		read -r -p "Use a gun for this $action_message? (y/n): " use_gun

		if [[ "$use_gun" == "y" || "$use_gun" == "Y" ]]; then
			read -r -p "Which gun? (Enter exact name): " chosen_gun

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

				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}"
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
			gun_bonus=-5
		fi
	fi

	current_chance=$((current_chance + gun_bonus))

	(( current_chance < 5 )) && current_chance=5
	(( current_chance > 95 )) && current_chance=95

	echo "$current_chance"
}

visit_hospital() {
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
					cash=$((cash + item_cost))
					play_sfx_mpg "error"
				else
					body_armor_equipped=true
					echo "Body Armor purchased and equipped."
					play_sfx_mpg "item_equip"
				fi
				;;
			*)
				echo "Internal Error: Unknown hospital item type '$item_type'"
				cash=$((cash + item_cost))
				;;
		esac
		read -r -p "Press Enter..."
	else
		echo "Not enough cash for $item_type (\$$item_cost needed)."
		read -r -p "Press Enter..."
	fi
}

rob_store() {
	local stealth_skill=${skills[stealth]:-1}
	local base_chance=$((15 + stealth_skill * 5))
	local loot=0 damage=0 fine=0

	clear_screen
	echo "--- Rob Store ---"
	echo "Scoping out a convenience store in $location..."
	sleep 1

	if command -v robbing_animation &> /dev/null; then robbing_animation; else echo "Making your move..."; sleep 1; fi

	local final_success_chance=$(apply_gun_bonus "$base_chance" "robbery")

	echo "Calculating odds... Final success chance: ${final_success_chance}%"
	read -r -p "Press Enter to attempt the robbery..."

	if (( RANDOM % 100 < final_success_chance )); then
		loot=$((RANDOM % 151 + 50 + stealth_skill * 10))
		cash=$((cash + loot))
		damage=$((RANDOM % 16 + 5))

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
		if (( RANDOM % 3 == 0 )); then
			skills[stealth]=$((stealth_skill + 1))
			printf "Your \e[1;32mstealth\e[0m skill increased!\n"
		fi
	else
		# Failure
		loot=0
		local previous_wanted=$wanted_level
		wanted_level=$((wanted_level + 1)) # Increase Wanted Level
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_level > previous_wanted )); then
			echo -e "\e[1;31mWanted Level Increased!\e[0m"
			play_sfx_mpg "police_siren"
		fi

		local base_fine=$((RANDOM % 101 + 50))
		local base_damage=$((RANDOM % 26 + 10))
		fine=$(( base_fine + wanted_level * 25 )) # Scale fine
		damage=$(( base_damage + wanted_level * 5 )) # Scale damage

		cash=$((cash - fine))
		(( cash < 0 )) && cash=0

		 if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Body armor protected you from \e[1;31m${armor_reduction}%%\e[0m damage during the arrest!"
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
		printf "\e[1;31mFailed!\e[0m The silent alarm tripped, cops arrived quickly.\n"
		printf "You were fined \$%d and took %d%% damage.\n" "$fine" "$damage"
	fi

	printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"
	check_health
	read -r -p "Press Enter to continue..."
}

burglary() {
	local stealth_skill=${skills[stealth]:-1}
	local base_chance=$((5 + stealth_skill * 7))
	local loot=0 damage=0 fine=0

	clear_screen
	echo "--- Burglary ---"
	echo "Scoping out a residence in $location..."
	sleep 1
	play_sfx_mpg "burglary_stealth"

	if command -v burglary_animation &> /dev/null; then burglary_animation; else echo "Looking for an entry point..."; sleep 1; fi

	local final_success_chance=$base_chance
	(( final_success_chance < 5 )) && final_success_chance=5
	(( final_success_chance > 90 )) && final_success_chance=90

	echo "Assessing the risk... Final success chance: ${final_success_chance}% (Stealth: ${stealth_skill})"
	read -r -p "Press Enter to attempt the burglary..."

	if (( RANDOM % 100 < final_success_chance )); then
		loot=$((RANDOM % 251 + 75 + stealth_skill * 15))
		cash=$((cash + loot))
		damage=$((RANDOM % 11 + 0))

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			if (( armor_reduction > 0 )); then
				echo "Body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage from a clumsy move!"
				body_armor_equipped=false
			fi
		fi
		health=$((health - damage))

		clear_screen
		printf "\e[1;32mSuccess!\e[0m You slipped in and out unseen, grabbing valuables worth \$%d.\n" "$loot"
		if (( damage > 0 )); then
			printf "Got slightly scratched up (-%d%% health).\n" "$damage"
		else
			echo "Clean getaway!"
		fi
		play_sfx_mpg "burglary_success"

		if (( RANDOM % 2 == 0 )); then
			skills[stealth]=$((stealth_skill + 1))
			printf "Your \e[1;32mstealth\e[0m skill increased!\n"
		fi
	else
		# Failure
		loot=0
		local previous_wanted=$wanted_level
		wanted_level=$((wanted_level + 1)) # Increase Wanted Level
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_level > previous_wanted )); then
			echo -e "\e[1;31mWanted Level Increased!\e[0m"
			play_sfx_mpg "police_siren"
		fi

		local base_fine=$((RANDOM % 151 + 75))
		local base_damage=$((RANDOM % 31 + 15))
		fine=$(( base_fine + wanted_level * 30 )) # Scale fine
		damage=$(( base_damage + wanted_level * 7 )) # Scale damage

		cash=$((cash - fine))
		(( cash < 0 )) && cash=0

		 if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Body armor protected you from \e[1;31m${armor_reduction}%%\e[0m damage when confronted!"
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
		printf "\e[1;31mFailed!\e[0m You triggered an alarm or were spotted!\n"
		printf "You were fined \$%d and took %d%% damage escaping.\n" "$fine" "$damage"
		play_sfx_mpg "burglary_fail"
	fi

	printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"
	check_health
	read -r -p "Press Enter to continue..."
}

heist() {
	local stealth_skill=${skills[stealth]:-1}
	local base_chance=$((10 + stealth_skill * 6))
	local loot=0 damage=0 fine=0

	clear_screen
	echo "--- Plan Heist ---"
	echo "Planning a high-stakes job in $location..."
	sleep 1

	if command -v heist_animation &> /dev/null; then heist_animation; else echo "Executing the plan..."; sleep 1; fi

	local final_success_chance=$(apply_gun_bonus "$base_chance" "heist")

	echo "Assessing security risks... Final success chance: ${final_success_chance}%"
	read -r -p "Press Enter to execute the heist..."

	if (( RANDOM % 100 < final_success_chance )); then
		loot=$((RANDOM % 501 + 250 + stealth_skill * 25))
		cash=$((cash + loot))
		damage=$((RANDOM % 31 + 15))

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
		if (( RANDOM % 2 == 0 )); then
			skills[stealth]=$((stealth_skill + 2))
			printf "Your \e[1;32mstealth\e[0m skill increased significantly!\n"
		fi
	else
		# Failure
		loot=0
		local previous_wanted=$wanted_level
		wanted_level=$((wanted_level + 2)) # Increase Wanted Level significantly
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_level > previous_wanted )); then
			echo -e "\e[1;31mWanted Level Increased!\e[0m"
			play_sfx_mpg "police_siren"
		fi

		local base_fine=$((RANDOM % 201 + 100))
		local base_damage=$((RANDOM % 41 + 20))
		fine=$(( base_fine + wanted_level * 50 )) # Scale fine heavily
		damage=$(( base_damage + wanted_level * 10 )) # Scale damage heavily

		cash=$((cash - fine))
		(( cash < 0 )) && cash=0

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

	if command -v gang_war_animation &> /dev/null; then gang_war_animation; else echo "Bullets start flying!"; sleep 1; fi

	local final_success_chance=$(apply_gun_bonus "$base_chance" "gang war")

	echo "Assessing rival strength... Final success chance: ${final_success_chance}%"
	read -r -p "Press Enter to start the fight..."

	if (( RANDOM % 100 < final_success_chance )); then
		loot=$((RANDOM % 201 + 100 + strength_skill * 15))
		cash=$((cash + loot))
		damage=$((RANDOM % 41 + 20))

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
		if (( RANDOM % 2 == 0 )); then
			skills[strength]=$((strength_skill + 1))
			printf "Your \e[1;32mstrength\e[0m skill increased!\n"
		fi
	else
		# Failure
		loot=0
		local previous_wanted=$wanted_level
		wanted_level=$((wanted_level + 2)) # Increase Wanted Level significantly
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_level > previous_wanted )); then
			echo -e "\e[1;31mWanted Level Increased!\e[0m"
			play_sfx_mpg "police_siren"
		fi

		local base_fine=$((RANDOM % 151 + 75))
		local base_damage=$((RANDOM % 51 + 25))
		fine=$(( base_fine + wanted_level * 40 )) # Scale fine
		damage=$(( base_damage + wanted_level * 12 )) # Scale damage

		cash=$((cash - fine))
		(( cash < 0 )) && cash=0

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

carjack() {
	local driving_skill=${skills[driving]:-1}
	local stealth_skill=${skills[stealth]:-1}
	local base_chance=$(( 20 + driving_skill * 2 + stealth_skill * 3 ))
	local loot=0 damage=0 fine=0

	clear_screen
	echo "--- Carjack ---"
	echo "Looking for a vehicle to 'borrow' in $location..."
	sleep 1

	if command -v carjacking_animation &> /dev/null; then carjacking_animation; else echo "Spotting a target..."; sleep 1; fi

	local final_success_chance=$(apply_gun_bonus "$base_chance" "carjacking")

	echo "Choosing a target... Final success chance: ${final_success_chance}%"
	read -r -p "Press Enter to make your move..."

	if (( RANDOM % 100 < final_success_chance )); then
		# Success - Grant Vehicle
		local possible_cars=("Sedan" "Truck" "Motorcycle")
		local stolen_car_type=${possible_cars[ RANDOM % ${#possible_cars[@]} ]}
		owned_vehicles+=("$stolen_car_type") # Add to owned list

		loot=$((RANDOM % 51 + 20)) # Smaller cash reward
		cash=$((cash + loot))
		damage=$((RANDOM % 16 + 5))

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			if (( armor_reduction > 0 )); then
				echo "Body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage during the getaway!"
				body_armor_equipped=false
			fi
		fi
		health=$((health - damage))

		clear_screen
		printf "\e[1;32mSuccess!\e[0m You boosted a \e[1;33m%s\e[0m!\n" "$stolen_car_type"
		printf "Fenced some minor items inside for \$%d.\n" "$loot"
		printf "Got slightly banged up (-%d%% health).\n" "$damage"
		play_sfx_mpg "car_start"
		if (( RANDOM % 4 == 0 )); then skills[driving]=$((driving_skill+1)); printf "Your \e[1;32mdriving\e[0m skill increased!\n"; fi
		if (( RANDOM % 4 == 0 )); then skills[stealth]=$((stealth_skill+1)); printf "Your \e[1;32mstealth\e[0m skill increased!\n"; fi
	else
		# Failure
		loot=0
		local previous_wanted=$wanted_level
		wanted_level=$((wanted_level + 1)) # Increase Wanted Level
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_level > previous_wanted )); then
			echo -e "\e[1;31mWanted Level Increased!\e[0m"
			play_sfx_mpg "police_siren"
		fi

		local base_fine=$((RANDOM % 76 + 25))
		local base_damage=$((RANDOM % 26 + 10))
		fine=$(( base_fine + wanted_level * 20 )) # Scale fine
		damage=$(( base_damage + wanted_level * 6 )) # Scale damage

		cash=$((cash - fine))
		(( cash < 0 )) && cash=0

		if $body_armor_equipped; then
			local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction))
			echo "Body armor took \e[1;31m${armor_reduction}%%\e[0m damage when the owner fought back!"
			body_armor_equipped=false
		fi
		health=$((health - damage))

		clear_screen
		printf "\e[1;31mFailed!\e[0m Alarm blared / Owner resisted / Cops nearby.\n"
		printf "You were fined \$%d and took %d%% damage.\n" "$fine" "$damage"
	fi

	printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"
	check_health
	read -r -p "Press Enter to continue..."
}

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
	health=50
	body_armor_equipped=false
	# Reset Wanted Level on death
	if (( wanted_level > 0 )); then
		echo "The police lose interest while you're recovering. Wanted level cleared."
		wanted_level=0
	fi
	play_sfx_mpg "cash_register"

	printf "You leave the hospital with \$%d cash and %d%% health.\n" "$cash" "$health"
	read -r -p "Press Enter to continue..."
}

hire_hooker() {
	local charisma_skill=${skills[charisma]:-1}
	local base_min_cost=40 base_max_cost=100
	local cost_reduction=$((charisma_skill * 3))
	local min_cost=$((base_min_cost - cost_reduction))
	local max_cost=$((base_max_cost - cost_reduction))
	(( min_cost < 15 )) && min_cost=15
	(( max_cost <= min_cost )) && max_cost=$((min_cost + 20))

	local hooker_cost=$(( RANDOM % (max_cost - min_cost + 1) + min_cost ))
	local health_gain=$(( RANDOM % 21 + 15 ))
	local max_health=100
	(( health > 100 )) && max_health=110

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
			(( health > max_health )) && health=$max_health
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

update_market_conditions() {
	local event_chance=15 # 15% chance of an event happening each time this runs
	local event_roll=$((RANDOM % 100))

	# Reset previous conditions
	market_conditions["crackdown_multiplier"]=1.0 # 1.0 means no effect
	market_conditions["demand_multiplier"]=1.0
	market_conditions["event_message"]="" # Clear message

	if (( event_roll < event_chance )); then
		local event_type=$((RANDOM % 2)) # 0 for crackdown, 1 for high demand

		if (( event_type == 0 )); then
			# Police Crackdown
			market_conditions["crackdown_multiplier"]=0.6 # Sell prices * 0.6
			market_conditions["demand_multiplier"]=1.1   # Buy prices * 1.1 (harder to buy)
			market_conditions["event_message"]="Police Crackdown! Prices are unfavorable."
			play_sfx_mpg "police_siren"
		else
			# High Demand
			market_conditions["crackdown_multiplier"]=1.0 # No crackdown effect
			market_conditions["demand_multiplier"]=1.5   # Sell prices * 1.5 (Demand impacts sell price more)
														  # Buy prices could also be slightly higher due to demand
			market_conditions["buy_multiplier"]=1.1       # Let's make buying slightly pricier too
			market_conditions["event_message"]="High Demand! Good time to sell!"
			play_sfx_mpg "cash_register"
		fi
	else
	    # No event this time, ensure buy multiplier is reset if it was set previously
	    market_conditions["buy_multiplier"]=1.0
	fi
}


drug_transaction() {
	local action="$1" base_price="$3" drug_amount="$4"
	local drug_name="$2"
	local cost=0 income=0 final_price=0
	local drug_dealer_skill=${skills[drug_dealer]:-1}

	if ! [[ "$drug_amount" =~ ^[1-9][0-9]*$ ]]; then
		echo "Invalid amount '$drug_amount'. Please enter a number greater than 0."
		return 1
	fi

	if ! command -v bc &> /dev/null; then
		echo "Warning: 'bc' command not found. Market fluctuations disabled for this transaction."
		market_conditions["buy_multiplier"]=1.0
		market_conditions["sell_multiplier"]=1.0
	fi

	local price_fluctuation=$(( RANDOM % 21 - 10 ))
	local location_modifier=0
	case "$location" in
		"Liberty City") location_modifier=15;; "Las Venturas") location_modifier=10;;
		"Vice City")    location_modifier=-15;; *) location_modifier=0;;
	esac
	local current_market_price=$(( base_price + (base_price * (price_fluctuation + location_modifier) / 100) ))
	(( current_market_price < 1 )) && current_market_price=1

	# Apply Market Condition Multipliers
	local buy_multiplier=${market_conditions["buy_multiplier"]:-1.0}
	local sell_multiplier=${market_conditions["crackdown_multiplier"]:-1.0}
	# Adjust sell price also by demand (stacking effect) if demand multiplier is set
	if [[ -v market_conditions["demand_multiplier"] ]]; then
		sell_multiplier=$(echo "scale=2; $sell_multiplier * ${market_conditions["demand_multiplier"]}" | bc)
	fi


	if [[ "$action" == "buy" ]]; then
		# Apply buy multiplier
		if command -v bc &> /dev/null; then
			final_price=$(echo "scale=0; $current_market_price * $buy_multiplier / 1" | bc )
		else
			final_price=$current_market_price # Fallback if bc not found
		fi
		(( final_price < 1 )) && final_price=1
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
			local skill_adjusted_price=$(( current_market_price + (current_market_price * price_bonus_percent / 100) ))

			# Apply sell multiplier
			if command -v bc &> /dev/null; then
				final_price=$(echo "scale=0; $skill_adjusted_price * $sell_multiplier / 1" | bc )
			else
				final_price=$skill_adjusted_price # Fallback if bc not found
			fi
			(( final_price < 1 )) && final_price=1

			income=$((final_price * drug_amount))

			if command -v drug_transaction_animation &> /dev/null; then drug_transaction_animation "sell"; fi
			cash=$((cash + income))
			drugs["$drug_name"]=$((current_inventory - drug_amount))

			printf "Sold \e[1;33m%d\e[0m units of \e[1;33m%s\e[0m for \e[1;32m\$%d\e[0m (\$%d/unit, skill +%d%%).\n" \
				   "$drug_amount" "$drug_name" "$income" "$final_price" "$price_bonus_percent"
			play_sfx_mpg "cash_register"
			if (( RANDOM % 2 == 0 )); then
				skills[drug_dealer]=$((drug_dealer_skill + 1))
				printf "Your \e[1;32mdrug dealing\e[0m skill increased!\n"
			fi ; return 0
		else
			printf "Not enough %s to sell. You have %d units, tried to sell %d.\n" \
				   "$drug_name" "$current_inventory" "$drug_amount" ; return 1
		fi
	else
		echo "Internal Error: Invalid action '$action' in drug_transaction." ; return 1
	fi
}

buy_drugs() {
	local drug_choice="" drug_amount=""
	declare -A drug_prices=( ["Weed"]=10 ["Cocaine"]=50 ["Heroin"]=100 ["Meth"]=75 )
	local drug_names=("Weed" "Cocaine" "Heroin" "Meth")

	while true; do
		clear_screen
		echo "--- Drug Dealer (Buy) ---"
		printf " Location: %-15s | Cash: \$%d\n" "$location" "$cash"
		# Display Market Event
		if [[ -n "${market_conditions["event_message"]}" ]]; then
			printf " \e[1;36mMarket News: %s\e[0m\n" "${market_conditions["event_message"]}"
		fi
		echo "---------------------------"
		echo " Available Inventory (Approx Price/unit):"
		local i=1
		for name in "${drug_names[@]}"; do
			local base_p=${drug_prices[$name]}
			local approx_p=$(( base_p + (base_p * ( $( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0) ) / 100) ))
			# Apply market conditions for display estimate
			local buy_mult=${market_conditions["buy_multiplier"]:-1.0}
			if command -v bc &> /dev/null; then
				approx_p=$(echo "scale=0; $approx_p * $buy_mult / 1" | bc)
			fi
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

		drug_transaction "buy" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"
		read -r -p "Press Enter..."
	done
}

sell_drugs() {
	local drug_choice="" drug_amount=""
	declare -A drug_sell_prices=( ["Weed"]=15 ["Cocaine"]=75 ["Heroin"]=150 ["Meth"]=100 )
	local drug_names=("Weed" "Cocaine" "Heroin" "Meth")

	while true; do
		clear_screen
		echo "--- Drug Dealer (Sell) ---"
		printf " Location: %-15s | Cash: \$%d\n" "$location" "$cash"
		# Display Market Event
		if [[ -n "${market_conditions["event_message"]}" ]]; then
			printf " \e[1;36mMarket News: %s\e[0m\n" "${market_conditions["event_message"]}"
		fi
		echo "--------------------------"
		echo " Your Inventory (Approx Sell Value/unit):"
		local i=1
		local available_to_sell=()
		for name in "${drug_names[@]}"; do
			local inventory_amount=${drugs[$name]:-0}
			if (( inventory_amount > 0 )); then
				local base_p=${drug_sell_prices[$name]}
				local dealer_skill=${skills[drug_dealer]:-1}
				local skill_bonus_p=$(( dealer_skill * 2 ))
				local location_modifier_val=$( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0)
				local approx_p=$(( base_p + (base_p * ( location_modifier_val + skill_bonus_p ) / 100) ))
				# Apply market conditions for display estimate
				local sell_mult=${market_conditions["crackdown_multiplier"]:-1.0}
				if [[ -v market_conditions["demand_multiplier"] ]]; then
					if command -v bc &> /dev/null; then
						sell_mult=$(echo "scale=2; $sell_mult * ${market_conditions["demand_multiplier"]}" | bc)
					fi
				fi
				if command -v bc &> /dev/null; then
					approx_p=$(echo "scale=0; $approx_p * $sell_mult / 1" | bc)
				fi
				(( approx_p < 1 )) && approx_p=1
				printf " %d. %-10s (%d units) ~\$%d/unit\n" "$i" "$name" "$inventory_amount" "$approx_p"
				available_to_sell+=("$name")
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

		drug_transaction "sell" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"
		read -r -p "Press Enter..."
	done
}

play_music() {
	if ! $mpg123_available; then
		echo "Music playback disabled: 'mpg123' command not found."; read -r -p "Press Enter..."; return 1;
	fi

	local music_dir="$BASEDIR/music"
	local music_files=()
	local original_ifs="$IFS"

	if [[ ! -d "$music_dir" ]]; then
		echo "Error: Music directory '$music_dir' not found!"; read -r -p "Press Enter..."; return 1;
	fi

	while IFS= read -r -d $'\0' file; do
		music_files+=("$file")
	done < <(find "$music_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.MP3" \) -print0 2>/dev/null)
	IFS="$original_ifs"

	if (( ${#music_files[@]} == 0 )); then
		echo "No .mp3 files found in '$music_dir'."; read -r -p "Press Enter..."; return 1;
	fi

	local choice_stop="s" choice_back="b" music_choice=""
	local mpg123_log="/tmp/bta_mpg123_errors.$$.log"

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
			[[ -n "$music_pid" ]] && music_pid=""
			current_status="Stopped"
		fi
		echo " Status: $current_status"
		echo "----------------------------------------"
		echo " Available Tracks:"
		for i in "${!music_files[@]}"; do printf " %d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"; done
		echo "----------------------------------------"
		printf " [%s] Stop Music | [%s] Back to Game\n" "$choice_stop" "$choice_back"
		echo "----------------------------------------"

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
				stty echo
				sleep 1
				;;
			"$choice_back" | "b")
				echo "Returning to game..."; sleep 1; break
				;;
			*)
				if [[ "$music_choice" =~ ^[0-9]+$ ]] && (( music_choice >= 1 && music_choice <= ${#music_files[@]} )); then
					local selected_track="${music_files[$((music_choice - 1))]}"
					if [[ ! -f "$selected_track" ]]; then echo "Error: File '$selected_track' not found!"; sleep 2; continue; fi

					if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
						echo "Stopping previous track..."; kill "$music_pid" &>/dev/null; wait "$music_pid" 2>/dev/null; music_pid=""; sleep 0.2;
					fi

					echo "Attempting to play: $(basename "$selected_track")"

					echo "--- BTA Log $(date) --- Playing: $selected_track" >> "$mpg123_log"
					mpg123 -q "$selected_track" 2>> "$mpg123_log" &

					local new_pid=$!
					sleep 0.5

					if kill -0 "$new_pid" 2>/dev/null; then
						music_pid=$new_pid; echo "Playback started (PID: $music_pid)."
					else
						echo "Error: Failed to start mpg123 process for $(basename "$selected_track")."
						echo "       Check log for errors (if any): $mpg123_log"
						if [[ -f "$mpg123_log" ]]; then
							echo "--- Last lines of log ---"; tail -n 5 "$mpg123_log"; echo "-------------------------"
						fi
						music_pid=""; read -r -p "Press Enter..."
					fi
				else
					echo "Invalid choice '$music_choice'."
					sleep 1
				fi;;
		esac
	done
}

save_game() {
	local save_path="$BASEDIR/$SAVE_DIR"
	mkdir -p "$save_path" || { echo "Error: Could not create save directory '$save_path'."; read -r -p "Press Enter..."; return 1; }

	echo "Saving game state..."
	local player_file="$save_path/player_name.sav"
	local loc_file="$save_path/location.sav"
	local cash_file="$save_path/cash.sav"
	local health_file="$save_path/health.sav"
	local armor_file="$save_path/body_armor_equipped.sav"
	local guns_file="$save_path/guns.sav"
	local items_file="$save_path/items.sav"
	local drugs_file="$save_path/drugs.sav"
	local skills_file="$save_path/skills.sav"
	local wanted_file="$save_path/wanted_level.sav" # New save file
	local vehicles_file="$save_path/vehicles.sav" # New save file
	local temp_ext=".tmp$$"

	save_atomic() {
		local content="$1" file_path="$2" temp_file="${file_path}${temp_ext}"
		printf '%s\n' "$content" > "$temp_file" && mv "$temp_file" "$file_path" || {
			echo "Error saving file: $file_path"; rm -f "$temp_file"; return 1;
		}
		return 0
	}

	# Save Simple Variables
	save_atomic "$player_name" "$player_file" || return 1
	save_atomic "$location" "$loc_file" || return 1
	save_atomic "$cash" "$cash_file" || return 1
	save_atomic "$health" "$health_file" || return 1
	save_atomic "$body_armor_equipped" "$armor_file" || return 1
	save_atomic "$wanted_level" "$wanted_file" || return 1 # Save wanted level

	# Save Indexed Arrays
	printf '%s\n' "${guns[@]}" > "$guns_file$temp_ext" && mv "$guns_file$temp_ext" "$guns_file" || { echo "Error saving guns."; rm -f "$guns_file$temp_ext"; return 1; }
	printf '%s\n' "${items[@]}" > "$items_file$temp_ext" && mv "$items_file$temp_ext" "$items_file" || { echo "Error saving items."; rm -f "$items_file$temp_ext"; return 1; }
	printf '%s\n' "${owned_vehicles[@]}" > "$vehicles_file$temp_ext" && mv "$vehicles_file$temp_ext" "$vehicles_file" || { echo "Error saving vehicles."; rm -f "$vehicles_file$temp_ext"; return 1; } # Save vehicles

	# Save Associative Arrays
	: > "$drugs_file$temp_ext"
	for key in "${!drugs[@]}"; do printf "%s %s\n" "$key" "${drugs[$key]}" >> "$drugs_file$temp_ext"; done
	if [[ -f "$drugs_file$temp_ext" ]]; then mv "$drugs_file$temp_ext" "$drugs_file"; else echo "Error writing drugs temp file."; return 1; fi

	: > "$skills_file$temp_ext"
	for key in "${!skills[@]}"; do printf "%s %s\n" "$key" "${skills[$key]}" >> "$skills_file$temp_ext"; done
	if [[ -f "$skills_file$temp_ext" ]]; then mv "$skills_file$temp_ext" "$skills_file"; else echo "Error writing skills temp file."; return 1; fi

	echo "Game saved successfully to '$save_path'."
	read -r -p "Press Enter to continue..."
	return 0
}

load_game() {
	local load_success=true
	local original_ifs="$IFS"
	local key="" value="" line="" save_file=""
	local save_path="$BASEDIR/$SAVE_DIR"

	echo "Attempting to load game from '$save_path'..."

	if [[ ! -d "$save_path" ]]; then
		echo "Error: Save directory '$save_path' not found."; read -r -p "Press Enter..."; return 1;
	fi

	# Load Simple Variables
	save_file="$save_path/player_name.sav"; [[ -f "$save_file" ]] && { read -r player_name < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; player_name="Unknown"; load_success=false; }
	save_file="$save_path/location.sav"; [[ -f "$save_file" ]] && { read -r location < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; location="Los Santos"; load_success=false; }
	save_file="$save_path/cash.sav"; [[ -f "$save_file" ]] && { read -r cash < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; cash=0; load_success=false; }
	[[ ! "$cash" =~ ^-?[0-9]+$ ]] && { >&2 echo "Warn: Invalid cash '$cash'"; cash=0; load_success=false; }
	save_file="$save_path/health.sav"; [[ -f "$save_file" ]] && { read -r health < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; health=100; load_success=false; }
	[[ ! "$health" =~ ^[0-9]+$ ]] && { >&2 echo "Warn: Invalid health '$health'"; health=100; load_success=false; }
	(( health <= 0 && load_success )) && { >&2 echo "Warn: Loaded health <= 0"; health=50; }
	save_file="$save_path/body_armor_equipped.sav"; [[ -f "$save_file" ]] && { read -r body_armor_equipped < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; body_armor_equipped=false; load_success=false; }
	[[ "$body_armor_equipped" != "true" && "$body_armor_equipped" != "false" ]] && { >&2 echo "Warn: Invalid armor '$body_armor_equipped'"; body_armor_equipped=false; load_success=false; }
	save_file="$save_path/wanted_level.sav"; [[ -f "$save_file" ]] && { read -r wanted_level < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; wanted_level=0; load_success=false; } # Load wanted level
	[[ ! "$wanted_level" =~ ^[0-9]+$ ]] && { >&2 echo "Warn: Invalid wanted level '$wanted_level'"; wanted_level=0; load_success=false; }

	# Load Indexed Arrays
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

	owned_vehicles=(); save_file="$save_path/vehicles.sav" # Load vehicles
	if [[ -f "$save_file" ]]; then
		 if command -v readarray &> /dev/null; then readarray -t owned_vehicles < "$save_file";
		 else IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do owned_vehicles+=("$line"); done < "$save_file"; IFS="$original_ifs"; fi
	else >&2 echo "Warn: $save_file missing"; fi


	# Load Associative Arrays
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

	IFS="$original_ifs"
	if $load_success; then echo "Game loaded successfully."; else
		echo "Warning: Game loaded with missing/invalid data. Defaults used."; fi
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
	owned_vehicles=() # Reset vehicles for new game
	wanted_level=0    # Reset wanted level for new game
	declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${default_drugs[$key]}; done
	declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${default_skills[$key]}; done
	body_armor_equipped=false
	echo "Welcome to Bash Theft Auto, $player_name!"
if [ "$player_name" = "test" ]; then
    cash=999999
fi

	echo "Starting in $location with \$${cash} and ${health}% health."
	read -r -p "Press Enter to begin..."
}

remove_save_files() {
	local save_path="$BASEDIR/$SAVE_DIR"
	if [[ -d "$save_path" ]]; then
		echo "Deleting previous save files in '$save_path'..."
		local found_files=$(find "$save_path" -maxdepth 1 -type f -name '*.sav' -print -delete)
		if [[ -n "$found_files" ]]; then echo "Old save files deleted successfully."; else echo "No '.sav' files found to delete."; fi
	else
		echo "Info: No previous save directory found at '$save_path'."
	fi
	sleep 1
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
	# Update Market Conditions at start of loop
	update_market_conditions

	if check_health; then
		clear_screen
	else
		# Player was hospitalized, screen already handled.
		clear_screen # Show status after hospital before menu
	fi

	echo "--- Actions ---"
	echo "1. Travel         | 7. Sell Drugs"
	echo "2. Buy Guns       | 8. Hire Hooker"
	echo "3. Buy Vehicle    | 9. Visit Hospital"
	echo "4. Inventory      | 10. Street Race"
	echo "5. Work (Legal)   | 11. Buy Drugs" 
	echo "6. Work (Crime)   |" 
	echo "-----------------------------------------"
	echo "S. Save Game     | L. Load Game"
	echo "M. Music Player  | A. About"
	echo "X. Exit Game     |"
	echo "-----------------------------------------"

	stty echo
	read -r -p "Enter your choice: " choice
	choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

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
		3) buy_vehicle;;
		4) show_inventory;;
		5) # Legal Work Menu
			clear_screen; echo "--- Honest Work ---"
			echo "1. Taxi Driver | 2. Delivery | 3. Mechanic | 4. Security | 5. Performer | 6. Bus Driver | 7. Back";
			read -r -p "Enter choice: " job_choice
			[[ ! "$job_choice" =~ ^[1-7]$ ]] && { echo "Invalid choice."; sleep 1; continue; }
			case "$job_choice" in
				1) work_job "taxi";; 2) work_job "delivery";; 3) work_job "mechanic";;
				4) work_job "security";; 5) work_job "performer";; 6) work_job "bus_driver";; 7) ;;
			esac;;
		6) # Criminal Activity Menu
			clear_screen; echo "--- Criminal Activities ---"
			echo "1. Rob Store | 2. Carjack | 3. Gang War | 4. Heist | 5. Burglary | 6. Back";
			read -r -p "Enter choice: " criminal_choice
			[[ ! "$criminal_choice" =~ ^[1-6]$ ]] && { echo "Invalid choice."; sleep 1; continue; }
			case "$criminal_choice" in
				1) rob_store;; 2) carjack;; 3) gang_war;; 4) heist;; 5) burglary;; 6) ;;
			esac;;
		7) sell_drugs;;
		8) hire_hooker;; 
		9) visit_hospital;;
		10) street_race;;
		11) buy_drugs;;
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
		*) echo "Invalid choice '$choice'."; sleep 1;;
	esac
done

cleanup_and_exit
