#ver 2.0.10 beta - Time, Travel Overhaul, Minigame Hook
#Bash-Theft-Auto music and sfx © 2024 by stuffbymax - Martin Petik is licensed under CC BY 4.0
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
declare -A vehicle_health=() # Stores current health % for each owned vehicle type
declare -A vehicle_types=( # Name=Price
	["Sedan"]=2000
	["Motorcycle"]=1500
	["Truck"]=2500
	["Sports Car"]=5000
	["Van"]=2200
	["OffRoad"]=3500
	["Limo"]=7000
	["shitbox"]=1000
)
declare -A market_conditions=() # Stores current event modifiers ["crackdown_multiplier", "demand_multiplier", "event_message"]
game_time=0 # Hours elapsed since game start

gun_attributes=(
	["Pistol"]="success_bonus=5"
	["Shotgun"]="success_bonus=10"
	["SMG"]="success_bonus=15"
	["Rifle"]="success_bonus=20"
	["Sniper"]="success_bonus=25"
)

# Define vehicle roles/bonuses (can be expanded)
# travel_speed_modifier: Mod > 1.0 is slower, Mod < 1.0 is faster
declare -A vehicle_attributes=(
	["Sedan"]="race_bonus=0;crime_bonus=0;delivery_bonus=0;travel_speed_modifier=1.0"
	["shitbo"]="race_bonus=0;crime_bonus=0;delivery_bonus=0;travel_speed_modifier=0.1"
	["Motorcycle"]="race_bonus=10;crime_bonus=-5;delivery_bonus=-5;travel_speed_modifier=1.1"
	["Truck"]="race_bonus=-15;crime_bonus=5;delivery_bonus=10;travel_speed_modifier=1.5"
	["Sports Car"]="race_bonus=15;crime_bonus=5;delivery_bonus=-10;travel_speed_modifier=0.7"
	["Van"]="race_bonus=-20;crime_bonus=10;delivery_bonus=15;travel_speed_modifier=1.2"
	["OffRoad"]="race_bonus=-5;crime_bonus=5;delivery_bonus=5;travel_speed_modifier=1.1"
	["Limo"]="race_bonus=-25;crime_bonus=-10;delivery_bonus=-15;travel_speed_modifier=1.4"
)

declare -A default_skills=( ["driving"]=1 ["strength"]=1 ["charisma"]=1 ["stealth"]=1 ["drug_dealer"]=1 )
declare -A default_drugs=( ["Weed"]=0 ["Cocaine"]=0 ["Heroin"]=0 ["Meth"]=0 )

# Base driving time (hours) between cities (adjust as needed)
declare -A city_distances=(
	["Los Santos-San Fierro"]=4 ["San Fierro-Los Santos"]=4
	["Los Santos-Las Venturas"]=3 ["Las Venturas-Los Santos"]=3
	["Los Santos-Vice City"]=10 ["Vice City-Los Santos"]=10
	["Los Santos-Liberty City"]=12 ["Liberty City-Los Santos"]=12
	["San Fierro-Las Venturas"]=2 ["Las Venturas-San Fierro"]=2
	["San Fierro-Vice City"]=11 ["Vice City-San Fierro"]=11
	["San Fierro-Liberty City"]=13 ["Liberty City-San Fierro"]=13
	["Las Venturas-Vice City"]=9 ["Vice City-Las Venturas"]=9
	["Las Venturas-Liberty City"]=11 ["Liberty City-Las Venturas"]=11
	["Vice City-Liberty City"]=2 ["Liberty City-Vice City"]=2
)


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
	echo "# Advanced calculations (drugs, travel time) require bc.   #"
	echo "# Please install it for the full experience.               #"
	echo "#----------------------------------------------------------#"
	echo "# On Debian/Ubuntu: sudo apt update && sudo apt install bc #"
	echo "# On Fedora:        sudo dnf install bc                    #"
	echo "# On Arch Linux:    sudo pacman -S bc                      #"
	echo "# On macOS (Homebrew): brew install bc                     #"
	echo "############################################################"
	read -r -p "Press Enter to continue with basic calculations..."
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
		# Check command again just in case it was installed mid-session? Unlikely but safe.
		if command -v mpg123 &> /dev/null; then
			 mpg123 -q "$sound_file" &>/dev/null &
			 return 0
		fi
	else
		# Log missing sfx only in a debug mode?
		# echo "Debug: SFX not found '$sound_file'" >&2
		return 1
	fi
	return 1 # Return failure if mpg123 check fails or file missing
}

# --- Plugin Loading ---
plugin_dir="plugins"

if [[ -d "$BASEDIR/$plugin_dir" ]]; then
	# Find and source all *.sh files in the plugin directory
	while IFS= read -r -d $'\0' plugin_script; do
		if [[ -f "$plugin_script" ]]; then
			# echo "Loading plugin: $plugin_script" # Optional debug message
			source "$plugin_script"
		fi
	done < <(find "$BASEDIR/$plugin_dir" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)
else
	echo "Info: Plugin directory '$BASEDIR/$plugin_dir' not found. Skipping plugin load."
fi

# --- Functions ---

clear_screen() {
	clear
	local day=$(( game_time / 24 + 1 ))
	local hour=$(( game_time % 24 ))
	printf "\e[93m=========================================\e[0m\n"
	printf "\e[1;43m|        Bash Theft Auto                |\e[0m\n"
	printf "\e[93m=========================================\e[0m\n"
	printf " \e[36mDay %-4d %02d:00\e[0m\n" "$day" "$hour" # Show Time
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
		health=0 # Ensure health doesn't go negative on display
		clear_screen
		echo -e "\n      \e[1;31m W A S T E D \e[0m\n"
		play_sfx_mpg "wasted"
		echo "You collapsed from your injuries..."
		sleep 1
		echo "You wake up later..."
		read -r -p "Press Enter to go to the hospital..."
		hospitalize_player
		return 1 # Indicate player was wasted
	fi
	return 0 # Indicate player is alive
}

travel_to() {
	local travel_cost="$1" # This is now the FLYING cost
	local new_location="$2"
	local current_location="$location"

	if [[ "$new_location" == "$current_location" ]]; then
		echo "You are already in $new_location."
		read -r -p "Press Enter..."
		return
	fi

	clear_screen
	echo "--- Travel Options ---"
	echo "Travel from $current_location to $new_location:"
	echo ""
	echo "1. Fly (\$$travel_cost) - Fast, direct (2 hours)."
	echo "2. Drive (Requires own vehicle) - Slower, potential risks/rewards."
	echo "3. Cancel"
	echo "----------------------"
	read -r -p "Choose travel mode: " travel_mode

	case "$travel_mode" in
		1) # --- Fly ---
			if (( cash >= travel_cost )); then
				printf "Purchasing flight ticket to %s (\$%d)...\n" "$new_location" "$travel_cost"
				cash=$((cash - travel_cost))
				play_sfx_mpg "cash_register"
				sleep 0.5
				play_sfx_mpg "air"
				echo "Boarding the plane..."

				local flight_time=2 # Fixed short time for flights
				if command -v air_travel_animation &> /dev/null; then
					air_travel_animation "$current_location" "$new_location"
				else
					# Simple fallback animation
					echo -n "Flying ["
					for _ in $(seq 1 $flight_time); do echo -n "✈"; sleep 0.5; done
					echo ">]"
				fi

				game_time=$(( game_time + flight_time )) # Add flight time
				location="$new_location"
				echo "You have landed safely in $new_location after ${flight_time} hours."
				read -r -p "Press Enter..."
			else
				echo "Not enough cash (\$$travel_cost needed) to fly to $new_location."
				read -r -p "Press Enter..."
			fi
			;;

		2) # --- Drive ---
			local chosen_vehicle=$(choose_vehicle_for_job "Select vehicle to drive:" ".*") # Allow any owned, healthy vehicle
			if [[ "$chosen_vehicle" == "None" || "$?" -ne 0 ]]; then
				# Message already shown by choose_vehicle_for_job if none suitable
				echo "You need a working vehicle to drive between cities!"
				read -r -p "Press Enter..."
				return
			fi

			# --- Calculate Drive Time ---
			local distance_key="${current_location}-${new_location}"
			local base_time=${city_distances[$distance_key]:-8} # Default time if distance not found
			local speed_mod=1.0 # Default speed modifier
			if [[ -v vehicle_attributes["$chosen_vehicle"] ]]; then
				# Extract modifier using eval safely
				local attrs="${vehicle_attributes[$chosen_vehicle]}"
				eval "$attrs" # Sets travel_speed_modifier variable locally
				speed_mod=${travel_speed_modifier:-1.0}
			fi

			local drive_time=0
			if command -v bc &> /dev/null; then
				# Use bc for potentially more accurate float multiplication
				drive_time=$(echo "scale=0; $base_time * $speed_mod / 1" | bc)
			else
				# Integer approximation if bc is missing
				local speed_mod_int=${speed_mod%.*} # Integer part
				local speed_mod_frac="0.${speed_mod#*.}" # Fractional part
				drive_time=$(( base_time * speed_mod_int ))
				# Add fractional part contribution (rough)
				local frac_time=$(echo "scale=0; $base_time * $speed_mod_frac / 1" | bc 2>/dev/null || echo 0)
				drive_time=$(( drive_time + frac_time ))
			fi
			(( drive_time < 1 )) && drive_time=1 # Minimum 1 hour drive

			printf "Preparing to drive your \e[1;33m%s\e[0m from %s to %s.\n" "$chosen_vehicle" "$current_location" "$new_location"
			printf "Estimated time: %d hours (Base: %d, Mod: %.1fx)\n" "$drive_time" "$base_time" "$speed_mod"
			play_sfx_mpg "taxi" # Use taxi SFX for long drive start
			sleep 1

			# --- Minigame Hook & Execution ---
			local minigame_result=0 # 0 = success, 1 = major problem, 2 = minor problem
			local extra_damage=0
			local penalty_time=0
			local arrival_message="You arrive in $new_location after a long drive."

			if command -v run_driving_minigame &> /dev/null; then
				echo "Starting the drive..."
				# Execute the plugin function. It should handle its own output.
				run_driving_minigame "$current_location" "$new_location" "$chosen_vehicle" "$drive_time"
				minigame_result=$? # Capture the return code
			else
				# Fallback animation if no plugin
				echo -n "Driving ["
				for i in $(seq 1 $drive_time); do
					# Check if vehicle still exists (important for long drives)
					if ! [[ " ${owned_vehicles[*]} " =~ " ${chosen_vehicle} " ]]; then
						echo "!VEHICLE LOST!]"
						arrival_message="\nYour drive was cut short! Your $chosen_vehicle is gone!"
						drive_time=$i # Adjust time passed
						minigame_result=1 # Treat as major problem if vehicle disappears
						break
					fi
					echo -n "-"; sleep 0.3;
				done
				# Finish progress bar only if loop completed without break
				[[ $minigame_result -eq 0 ]] && echo ">]"
			fi

			# --- Process Outcome ---
			local base_wear_tear=$(( drive_time * (RANDOM % 2 + 1) )) # 1-2% damage per hour

			if [[ $minigame_result -eq 1 ]]; then # Major Problem
				echo -e "\n\e[1;31mYour trip encountered major problems!\e[0m"
				extra_damage=$(( RANDOM % 25 + 15 ))
				penalty_time=$(( RANDOM % (drive_time / 2 + 1) + 1 ))
				arrival_message="You finally limp into $new_location after a disastrous drive (took ${drive_time}h + ${penalty_time}h delay!)."
				play_sfx_mpg "crash"
			elif [[ $minigame_result -eq 2 ]]; then # Minor Problem
				echo -e "\n\e[1;33mYour trip had some minor issues.\e[0m"
				extra_damage=$(( RANDOM % 10 + 5 ))
				penalty_time=$(( RANDOM % (drive_time / 4 + 1) ))
				arrival_message="You arrive in $new_location after a slightly troubled drive (took ${drive_time}h + ${penalty_time}h delay)."
				play_sfx_mpg "mechanic" # Sound of car trouble?
			fi

			# --- Finalize Drive ---
			# Verify vehicle still exists before applying damage and finalizing location/time
			if [[ " ${owned_vehicles[*]} " =~ " ${chosen_vehicle} " ]]; then
				local total_damage=$(( base_wear_tear + extra_damage ))
				apply_vehicle_damage "$chosen_vehicle" "$total_damage"
				local total_time=$(( drive_time + penalty_time ))
				game_time=$(( game_time + total_time ))
				location="$new_location"
				echo "$arrival_message"
			else
				# Vehicle was lost/destroyed
				echo "$arrival_message" # Use message set during loop/plugin
				location="$new_location" # Player still arrives
				game_time=$(( game_time + drive_time + penalty_time )) # Time still passes
			fi

			read -r -p "Press Enter..."
			;;

		3) # --- Cancel ---
			echo "Travel cancelled."
			sleep 1
			;;
		*) # --- Invalid Choice ---
			echo "Invalid choice."
			sleep 1
			;;
	esac
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

	# Check if gun is already owned
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

	# Check cash and process purchase
	if (( cash >= gun_cost )); then
		play_sfx_mpg "cash_register"
		if command -v buy_animation &> /dev/null; then
			buy_animation "$gun_name"
		fi

		cash=$((cash - gun_cost))
		guns+=("$gun_name") # Add gun to array
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
		local found_buyable=false
		# List only vehicles the player doesn't already own
		for type in "${!vehicle_types[@]}"; do
			local already_owned=false
			for v in "${owned_vehicles[@]}"; do [[ "$v" == "$type" ]] && already_owned=true && break; done
			if ! $already_owned; then
				found_buyable=true
				local price=${vehicle_types[$type]}
				printf " %d. %-12s (\$ %d)\n" "$i" "$type" "$price"
				buyable_vehicles+=("$type") # Store type corresponding to index i-1
				((i++))
			fi
		done

		if ! $found_buyable; then
			echo "Looks like we're sold out of anything you don't already own!"
			sleep 1
		fi
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
			vehicle_health["$chosen_type"]=100 # Initialize health
			echo "Congratulations on your new $chosen_type! That's \$${chosen_price}."
			play_sfx_mpg "car_start"
			read -r -p "Press Enter..."
			# Exit menu after purchase
			return
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
	# Show Vehicles with Health
	echo " Vehicles:"
	if (( ${#owned_vehicles[@]} > 0 )); then
		local health_color=""
		for vehicle_type in "${owned_vehicles[@]}"; do
			local current_health=${vehicle_health[$vehicle_type]:-100} # Default to 100 if somehow missing
			if (( current_health > 70 )); then health_color="\e[1;32m"; # Green
			elif (( current_health > 30 )); then health_color="\e[1;33m"; # Yellow
			else health_color="\e[1;31m"; fi # Red
			printf "  - %-12s (Health: %b%3d%%\e[0m)\n" "$vehicle_type" "$health_color" "$current_health"
		done
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
	local chosen_vehicle="None" # Default vehicle used
	local job_time=0 # Hours the job takes

	# Ask for vehicle only for relevant jobs
	if [[ "$job_type" == "delivery" || "$job_type" == "taxi" ]]; then
		# Allow more vehicles for taxi?
		local allowed_vehicles="Van|Truck|Sedan|OffRoad"
		[[ "$job_type" == "taxi" ]] && allowed_vehicles+="|Limo" # Limo taxi? :)
		chosen_vehicle=$(choose_vehicle_for_job "Choose a vehicle for the $job_type job?" "$allowed_vehicles")
		if [[ "$?" -ne 0 && "$chosen_vehicle" == "None" ]]; then
			 echo "This job might be less efficient without a suitable vehicle."
			 sleep 1
		fi
	fi

	# Location based base earnings
	case "$location" in
		"Los Santos")   min_earnings=20; max_earnings=60;;
		"San Fierro")   min_earnings=25; max_earnings=70;;
		"Las Venturas") min_earnings=30; max_earnings=90;;
		"Vice City")    min_earnings=15; max_earnings=50;;
		"Liberty City") min_earnings=35; max_earnings=100;;
		*)              min_earnings=10; max_earnings=40;;
	esac
	base_earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings))

	# Job specific logic, skill bonus, vehicle bonus, and time cost
	case "$job_type" in
		"taxi"|"delivery")
			relevant_skill_name="driving"
			relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$((relevant_skill_level * (job_type == "delivery" ? 4 : 3) ))
			[[ "$job_type" == "delivery" ]] && base_earnings=$((base_earnings + 10))
			play_sfx_mpg "taxi"
			job_time=6 # Takes 6 hours

			# Apply vehicle bonus
			if [[ "$chosen_vehicle" != "None" ]]; then
				local vehicle_bonus=$(get_vehicle_bonus "$chosen_vehicle" "delivery_bonus") # Use delivery bonus for both for now
				if (( vehicle_bonus != 0 )); then
					local bonus_amount=$(( base_earnings * vehicle_bonus / 100 ))
					base_earnings=$(( base_earnings + bonus_amount ))
					printf "Vehicle Bonus (\e[1;33m%s\e[0m): \$%d\n" "$chosen_vehicle" "$bonus_amount"
				fi
			fi
			;;
		"mechanic")
			relevant_skill_name="strength" # Or maybe a new "mechanics" skill?
			relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$((relevant_skill_level * 1))
			base_earnings=$((base_earnings + 20))
			play_sfx_mpg "mechanic"
			job_time=8
			;;
		"security")
			relevant_skill_name="strength"
			relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$((relevant_skill_level * 2))
			base_earnings=$((base_earnings + 30))
			play_sfx_mpg "security"
			job_time=10 # Long shift
			;;
		"performer")
			relevant_skill_name="charisma"
			relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$((relevant_skill_level * 5))
			base_earnings=$((base_earnings - 10))
			base_earnings=$(( base_earnings < 5 ? 5 : base_earnings ))
			play_sfx_mpg "street_performer"
			job_time=4
			;;
		"bus_driver")
			relevant_skill_name="driving"
			relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$((relevant_skill_level * 2))
			base_earnings=$((base_earnings + 25))
			play_sfx_mpg "bus_driving"
			job_time=8
			;;
		*) echo "Internal Error: Invalid Job Type '$job_type'"; return;;
	esac

	earnings=$((base_earnings + skill_bonus))
	(( earnings < 0 )) && earnings=0

	# Working Animation
	if command -v working_animation &> /dev/null; then
		working_animation "$job_type" "$job_time" # Pass time to animation?
	else
		echo "Working as a $job_type for $job_time hours..."
		sleep 2 # Simple delay
	fi

	# Update game state
	cash=$((cash + earnings))
	game_time=$(( game_time + job_time )) # Add job time

	clear_screen # Refresh screen after time passes
	printf "Finished your shift as a %s in %s (took %d hours).\n" "$job_type" "$location" "$job_time"
	printf "You earned \$%d (Base: \$%d, Skill Bonus: \$%d).\n" "$earnings" "$base_earnings" "$skill_bonus"
	printf "You now have \$%d.\n" "$cash"

	# Apply wear and tear if vehicle was used
	if [[ "$chosen_vehicle" != "None" ]]; then
		local wear_tear=$(( job_time / 2 )) # Damage scales with job time
		(( wear_tear < 1 )) && wear_tear=1
		apply_vehicle_damage "$chosen_vehicle" "$wear_tear"
	fi

	# Chance to decrease wanted level
	if (( wanted_level > 0 )); then
		local decrease_chance=25
		if (( RANDOM % 100 < decrease_chance )); then
			wanted_level=$((wanted_level - 1))
			echo -e "\e[1;32mLaying low seems to have worked. Wanted Level Decreased!\e[0m"
		fi
	fi

	# Skill Increase Logic
	if [[ -n "$relevant_skill_name" ]]; then
		local skill_increase_chance=20
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
	local race_time=2 # Hours the race takes

	clear_screen
	echo "--- Street Race ---"

	# Street race REQUIRES a vehicle
	local allowed_race_vehicles="Sports Car|Motorcycle|Sedan|Truck|Van|OffRoad|Limo"
	local chosen_vehicle=$(choose_vehicle_for_job "Choose your racer:" "$allowed_race_vehicles")

	if [[ "$chosen_vehicle" == "None" || "$?" -ne 0 ]]; then
		 echo "You need a vehicle to participate in a street race!"
		 read -r -p "Press Enter..."
		 return
	fi

	local race_bonus=$(get_vehicle_bonus "$chosen_vehicle" "race_bonus")
	local vehicle_health_factor=$(( ${vehicle_health[$chosen_vehicle]} / 20 )) # Bonus for good health

	local win_chance=$(( base_win_chance + driving_skill * 5 + race_bonus + vehicle_health_factor ))
	(( win_chance > 95 )) && win_chance=95
	(( win_chance < 5 )) && win_chance=5

	echo "Joining an illegal street race in $location (will take ${race_time} hours)..."
	printf "Vehicle: \e[1;33m%s\e[0m | Driving Skill: %d | Health: %d%%\n" "$chosen_vehicle" "$driving_skill" "${vehicle_health[$chosen_vehicle]}"
	printf "Bonuses -> Vehicle: %+d%% | Health: %+d%%\n" "$race_bonus" "$vehicle_health_factor"
	printf "Final Win Chance: \e[1;32m%d%%\e[0m\n" "$win_chance"
	sleep 1

	# Race animation
	if command -v race_animation &> /dev/null; then
		race_animation "$race_time"
	else
		echo "Get ready..." ; sleep 1; echo "3... 2... 1... GO!"; sleep 1
	fi

	read -r -p "Press Enter for the race results..."

	# Add race time regardless of outcome
	game_time=$(( game_time + race_time ))

	local winnings=0 damage_player=0 damage_vehicle=0

	if (( RANDOM % 100 < win_chance )); then
		# --- WIN ---
		winnings=$((RANDOM % 151 + 100 + driving_skill * 10 + race_bonus * 5 ))
		(( winnings < 50 )) && winnings=50
		cash=$((cash + winnings))
		damage_player=$((RANDOM % 10 + 1))
		damage_vehicle=$((RANDOM % 15 + 5 )) # Races damage cars

		if $body_armor_equipped; then
			local armor_reduction=$((damage_player / 2))
			damage_player=$((damage_player - armor_reduction))
			echo "Your body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage!"
			body_armor_equipped=false
		fi
		health=$((health - damage_player))

		clear_screen # Refresh after time passes
		printf "\e[1;32m*** YOU WON THE RACE! ***\e[0m (%d hours passed)\n" "$race_time"
		printf "You collected \$%d in prize money.\n" "$winnings"
		printf "Took minor damage (-%d%% health).\n" "$damage_player"
		apply_vehicle_damage "$chosen_vehicle" "$damage_vehicle"
		play_sfx_mpg "win"
		if (( RANDOM % 3 == 0 )); then
			skills[driving]=$((driving_skill + 1))
			printf "Your \e[1;32mdriving\e[0m skill increased!\n"
		fi
	else
		# --- LOSE ---
		winnings=0
		damage_player=$((RANDOM % 25 + 10))
		damage_vehicle=$((RANDOM % 30 + 15 )) # Losing often means crashing harder

		if $body_armor_equipped; then
			local armor_reduction=$((damage_player / 2))
			damage_player=$((damage_player - armor_reduction))
			echo "Your body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage in the crash!"
			body_armor_equipped=false
		fi
		health=$((health - damage_player))

		clear_screen # Refresh after time passes
		printf "\e[1;31m--- YOU LOST THE RACE! ---\e[0m (%d hours passed)\n" "$race_time"
		printf "You crashed and took %d%% damage.\n" "$damage_player"
		apply_vehicle_damage "$chosen_vehicle" "$damage_vehicle"
		play_sfx_mpg "lose"
	fi

	printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"

	check_health # Check player health immediately
	read -r -p "Press Enter to continue..."
}

apply_gun_bonus() {
	local base_chance=$1
	local action_message=$2
	local current_chance=$base_chance
	local gun_bonus=0
	local chosen_gun=""
	local gun_found=false
	local success_bonus=0 # This will be set by eval

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
				# Case-insensitive comparison? Let's keep it exact for now.
				if [[ "$gun" == "$chosen_gun" ]]; then
					gun_found=true
					break
				fi
			done

			if $gun_found; then
				echo "You draw your $chosen_gun!"
				play_sfx_mpg "gun_cock"

				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}" # Safely evaluate defined attributes
					gun_bonus=${success_bonus:-0}
					if (( gun_bonus > 0 )); then
						echo "The $chosen_gun gives a \e[1;32m+${gun_bonus}%%\e[0m success chance."
						play_sfx_mpg "gun_shot"
					else
						echo "The $chosen_gun provides no specific advantage here."
					fi
				else
					# This case should ideally not happen if gun_attributes is maintained
					echo "Warning: No bonus attributes defined for '$chosen_gun'."
					gun_bonus=0
				fi
			else
				echo "You don't own '$chosen_gun'! Proceeding without a gun bonus."
				gun_bonus=0
			fi
		else
			echo "Proceeding without using a gun."
			gun_bonus=-5 # Small penalty for not using available gun
		fi
	fi

	current_chance=$((current_chance + gun_bonus))

	# Clamp the chance between 5% and 95%
	(( current_chance < 5 )) && current_chance=5
	(( current_chance > 95 )) && current_chance=95

	echo "$current_chance" # Return the modified chance
}

visit_hospital() {
	local hospital_choice=""
	while true; do
		clear_screen
		echo "--- County General Hospital ---"
		printf " Your Health: %d%% | Cash: \$%d\n" "$health" "$cash"
		echo "-------------------------------"
		echo " Services:"
		echo " 1. Basic Treatment (\$50)  - Heal to 100% (1 hour)"
		echo " 2. Advanced Scan (\$100) - Heal to 110% (2 hours, Temporary Max)"
		echo " 3. Buy Health Pack (\$30) - Add 'Health Pack' to Items (Not usable yet)"
		echo " 4. Buy Body Armor (\$75)  - Equip Armor (One time use)"
		echo "-------------------------------"
		echo " 5. Leave Hospital"
		echo "-------------------------------"
		read -r -p "Enter your choice: " hospital_choice

		[[ ! "$hospital_choice" =~ ^[0-9]+$ ]] && {
			echo "Invalid input."; sleep 1; continue
		}

		case "$hospital_choice" in
			1) buy_hospital_item 50 "basic_treatment" 1 ;; # Pass time cost
			2) buy_hospital_item 100 "advanced_treatment" 2 ;;
			3) buy_hospital_item 30 "health_pack" 0 ;; # Buying items takes no time
			4) buy_hospital_item 75 "body_armor" 0 ;;
			5) echo "Leaving the hospital..."; sleep 1; return;;
			*) echo "Invalid choice."; sleep 1;;
		esac
		# Break after one action or allow multiple? Let's break for simplicity.
		break
	done
}

buy_hospital_item() {
	local item_cost="$1"
	local item_type="$2"
	local time_cost="$3" # Time cost for treatment

	if (( cash >= item_cost )); then
		play_sfx_mpg "cash_register"
		cash=$((cash - item_cost))
		local action_taken=false
		case "$item_type" in
			"basic_treatment")
				if (( health < 100 )); then
					health=100
					game_time=$(( game_time + time_cost ))
					echo "Received basic treatment. Health fully restored to 100%. (${time_cost}h passed)"
					play_sfx_mpg "heal"
					action_taken=true
				else
					echo "Your health is already 100% or more."
					cash=$((cash + item_cost)) # Refund
				fi
				;;
			"advanced_treatment")
				if (( health < 110 )); then
					health=110
					game_time=$(( game_time + time_cost ))
					echo "Advanced scan complete. Health boosted to 110%! (${time_cost}h passed)"
					echo "(Note: Max health cap is 110)"
					play_sfx_mpg "heal_adv"
					action_taken=true
				else
					echo "Your health is already at the maximum boost!"
					cash=$((cash + item_cost)) # Refund
				fi
				;;
			"health_pack")
				items+=("Health Pack")
				echo "You bought a Health Pack. (Item usage not yet implemented)"
				play_sfx_mpg "item_buy"
				action_taken=true
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
					action_taken=true
				fi
				;;
			*)
				echo "Internal Error: Unknown hospital item type '$item_type'"
				cash=$((cash + item_cost)) # Refund
				;;
		esac
		# Only pause if an action was actually taken or message displayed
		if $action_taken; then
			read -r -p "Press Enter..."
		else
			# If no action (e.g., already healthy), pause briefly after message
			read -r -p "Press Enter..."
		fi

	else
		echo "Not enough cash for $item_type (\$$item_cost needed)."
		read -r -p "Press Enter..."
	fi
}

# --- Crime Functions (Integrating Vehicle/Time) ---
rob_store() {
	local stealth_skill=${skills[stealth]:-1}
	local base_chance=$((15 + stealth_skill * 5))
	local loot=0 damage_player=0 damage_vehicle=0 fine=0
	local chosen_vehicle="None"
	local crime_time=1 # Hours the robbery + getaway takes

	clear_screen
	echo "--- Rob Store ---"
	echo "Scoping out a convenience store in $location..."
	chosen_vehicle=$(choose_vehicle_for_job "Select a getaway vehicle?" "Sedan|Sports Car|Motorcycle|Van|OffRoad")
	sleep 1

	if command -v robbing_animation &> /dev/null; then robbing_animation; else echo "Making your move..."; sleep 1; fi

	local gun_bonus_chance=$(apply_gun_bonus "$base_chance" "robbery")
	local vehicle_bonus=$(get_vehicle_bonus "$chosen_vehicle" "crime_bonus")
	local final_success_chance=$(( gun_bonus_chance + vehicle_bonus ))
	(( final_success_chance < 5 )) && final_success_chance=5
	(( final_success_chance > 95 )) && final_success_chance=95

	printf "Calculating odds... Base: %d%% | Gun Mod: %+d%% | Vehicle (\e[1;33m%s\e[0m): %+d%%\n" \
		 "$base_chance" "$((gun_bonus_chance - base_chance - vehicle_bonus))" "$chosen_vehicle" "$vehicle_bonus"
	printf "Final success chance: \e[1;32m%d%%\e[0m\n" "$final_success_chance"
	read -r -p "Press Enter to attempt the robbery..."

	game_time=$(( game_time + crime_time )) # Add crime time

	if (( RANDOM % 100 < final_success_chance )); then
		# Success
		loot=$((RANDOM % 151 + 50 + stealth_skill * 10))
		cash=$((cash + loot))
		damage_player=$((RANDOM % 10 + 1))
		damage_vehicle=$((RANDOM % 8 + 3))

		if $body_armor_equipped; then
			local armor_reduction=$((damage_player / 2)); damage_player=$((damage_player - armor_reduction))
			echo "Body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage during the getaway!"
			body_armor_equipped=false
		fi
		health=$((health - damage_player))

		clear_screen # Refresh after time pass
		printf "\e[1;32mSuccess!\e[0m You intimidated the clerk and grabbed \$%d. (%dh passed)\n" "$loot" "$crime_time"
		printf "Got slightly roughed up (-%d%% health).\n" "$damage_player"
		apply_vehicle_damage "$chosen_vehicle" "$damage_vehicle"
		play_sfx_mpg "cash_register"
		if (( RANDOM % 3 == 0 )); then
			skills[stealth]=$((stealth_skill + 1))
			printf "Your \e[1;32mstealth\e[0m skill increased!\n"
		fi
	else
		# Failure
		loot=0
		local previous_wanted=$wanted_level
		wanted_level=$((wanted_level + 1))
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_level > previous_wanted )); then
			echo -e "\e[1;31mWanted Level Increased!\e[0m"
			play_sfx_mpg "police_siren"
		fi

		local base_fine=$((RANDOM % 101 + 50))
		local base_damage_player=$((RANDOM % 26 + 10))
		fine=$(( base_fine + wanted_level * 25 ))
		damage_player=$(( base_damage_player + wanted_level * 5 ))
		damage_vehicle=$((RANDOM % 15 + 5))

		cash=$((cash - fine))
		(( cash < 0 )) && cash=0

		 if $body_armor_equipped; then
			local armor_reduction=$((damage_player / 2)); damage_player=$((damage_player - armor_reduction))
			echo "Body armor protected you from \e[1;31m${armor_reduction}%%\e[0m damage during the arrest!"
			body_armor_equipped=false
		fi
		health=$((health - damage_player))

		clear_screen # Refresh after time pass
		printf "\e[1;31mFailed!\e[0m The silent alarm tripped. (%dh passed)\n" "$crime_time"
		printf "You were fined \$%d and took %d%% damage.\n" "$fine" "$damage_player"
		apply_vehicle_damage "$chosen_vehicle" "$damage_vehicle"
	fi

	printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"
	check_health
	read -r -p "Press Enter to continue..."
}

burglary() {
	local stealth_skill=${skills[stealth]:-1}
	local base_chance=$((5 + stealth_skill * 7))
	local loot=0 damage_player=0 damage_vehicle=0 fine=0
	local chosen_vehicle="None"
	local crime_time=3 # Burglary takes longer

	clear_screen
	echo "--- Burglary ---"
	echo "Scoping out a residence in $location..."
	chosen_vehicle=$(choose_vehicle_for_job "Use a vehicle for approach/getaway?" "Sedan|Motorcycle|Van|OffRoad")
	sleep 1
	play_sfx_mpg "burglary_stealth"

	if command -v burglary_animation &> /dev/null; then burglary_animation; else echo "Looking for an entry point..."; sleep 1; fi

	local vehicle_bonus=$(get_vehicle_bonus "$chosen_vehicle" "crime_bonus")
	local final_success_chance=$(( base_chance + vehicle_bonus ))
	(( final_success_chance < 5 )) && final_success_chance=5
	(( final_success_chance > 90 )) && final_success_chance=90

	printf "Assessing the risk... Base: %d%% | Vehicle (\e[1;33m%s\e[0m): %+d%%\n" \
		"$base_chance" "$chosen_vehicle" "$vehicle_bonus"
	printf "Final success chance: \e[1;32m%d%%\e[0m (Stealth: %d)\n" "$final_success_chance" "$stealth_skill"
	read -r -p "Press Enter to attempt the burglary..."

	game_time=$(( game_time + crime_time )) # Add crime time

	if (( RANDOM % 100 < final_success_chance )); then
		# Success
		loot=$((RANDOM % 251 + 75 + stealth_skill * 15))
		cash=$((cash + loot))
		damage_player=$((RANDOM % 8 + 0))
		damage_vehicle=$((RANDOM % 5 + 1))

		if $body_armor_equipped && (( damage_player > 0 )); then
			local armor_reduction=$((damage_player / 2)); damage_player=$((damage_player - armor_reduction))
			echo "Body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage from a clumsy move!"
			body_armor_equipped=false
		fi
		health=$((health - damage_player))

		clear_screen # Refresh after time pass
		printf "\e[1;32mSuccess!\e[0m Slipped in and out unseen, grabbing valuables worth \$%d. (%dh passed)\n" "$loot" "$crime_time"
		if (( damage_player > 0 )); then
			printf "Got slightly scratched up (-%d%% health).\n" "$damage_player"
		else
			echo "Clean getaway!"
		fi
		apply_vehicle_damage "$chosen_vehicle" "$damage_vehicle"
		play_sfx_mpg "burglary_success"

		if (( RANDOM % 2 == 0 )); then
			skills[stealth]=$((stealth_skill + 1))
			printf "Your \e[1;32mstealth\e[0m skill increased!\n"
		fi
	else
		# Failure
		loot=0
		local previous_wanted=$wanted_level
		wanted_level=$((wanted_level + 1))
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_level > previous_wanted )); then
			echo -e "\e[1;31mWanted Level Increased!\e[0m"
			play_sfx_mpg "police_siren"
		fi

		local base_fine=$((RANDOM % 151 + 75))
		local base_damage_player=$((RANDOM % 31 + 15))
		fine=$(( base_fine + wanted_level * 30 ))
		damage_player=$(( base_damage_player + wanted_level * 7 ))
		damage_vehicle=$((RANDOM % 20 + 10))

		cash=$((cash - fine))
		(( cash < 0 )) && cash=0

		 if $body_armor_equipped; then
			local armor_reduction=$((damage_player / 2)); damage_player=$((damage_player - armor_reduction))
			echo "Body armor protected you from \e[1;31m${armor_reduction}%%\e[0m damage when confronted!"
			body_armor_equipped=false
		fi
		health=$((health - damage_player))

		clear_screen # Refresh after time pass
		printf "\e[1;31mFailed!\e[0m Triggered an alarm or were spotted! (%dh passed)\n" "$crime_time"
		printf "You were fined \$%d and took %d%% damage escaping.\n" "$fine" "$damage_player"
		apply_vehicle_damage "$chosen_vehicle" "$damage_vehicle"
		play_sfx_mpg "burglary_fail"
	fi

	printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"
	check_health
	read -r -p "Press Enter to continue..."
}

heist() {
	local stealth_skill=${skills[stealth]:-1}
	local base_chance=$((10 + stealth_skill * 6))
	local loot=0 damage_player=0 damage_vehicle=0 fine=0
	local chosen_vehicle="None"
	local crime_time=6 # Heists take significant time

	clear_screen
	echo "--- Plan Heist ---"
	echo "Planning a high-stakes job in $location..."
	chosen_vehicle=$(choose_vehicle_for_job "Select a crucial getaway vehicle:" "Van|Sports Car|Sedan|OffRoad")
	if [[ "$chosen_vehicle" == "None" || "$?" -ne 0 ]]; then
		 echo "A heist without a reliable getaway vehicle is suicide! Plan aborted."
		 read -r -p "Press Enter..."
		 return
	fi
	sleep 1

	if command -v heist_animation &> /dev/null; then heist_animation; else echo "Executing the plan..."; sleep 1; fi

	local gun_bonus_chance=$(apply_gun_bonus "$base_chance" "heist")
	local vehicle_bonus=$(get_vehicle_bonus "$chosen_vehicle" "crime_bonus")
	local final_success_chance=$(( gun_bonus_chance + vehicle_bonus ))
	(( final_success_chance < 5 )) && final_success_chance=5
	(( final_success_chance > 90 )) && final_success_chance=90

	printf "Assessing risks... Base: %d%% | Gun Mod: %+d%% | Vehicle (\e[1;33m%s\e[0m): %+d%%\n" \
		"$base_chance" "$((gun_bonus_chance - base_chance - vehicle_bonus))" "$chosen_vehicle" "$vehicle_bonus"
	printf "Final success chance: \e[1;32m%d%%\e[0m\n" "$final_success_chance"
	read -r -p "Press Enter to execute the heist..."

	game_time=$(( game_time + crime_time )) # Add crime time

	if (( RANDOM % 100 < final_success_chance )); then
		# Success
		loot=$((RANDOM % 501 + 250 + stealth_skill * 25 + vehicle_bonus * 10 ))
		cash=$((cash + loot))
		damage_player=$((RANDOM % 25 + 10))
		damage_vehicle=$((RANDOM % 30 + 15))

		if $body_armor_equipped; then
			local armor_reduction=$((damage_player / 2)); damage_player=$((damage_player - armor_reduction))
			echo "Body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage during the firefight!"
			body_armor_equipped=false
		fi
		health=$((health - damage_player))

		clear_screen # Refresh after time pass
		printf "\e[1;32m*** HEIST SUCCESSFUL! ***\e[0m (%dh passed)\n You scored \$%d!\n" "$crime_time" "$loot"
		printf "Escaped with significant injuries (-%d%% health).\n" "$damage_player"
		apply_vehicle_damage "$chosen_vehicle" "$damage_vehicle"
		play_sfx_mpg "win_big"
		if (( RANDOM % 2 == 0 )); then
			skills[stealth]=$((stealth_skill + 2))
			printf "Your \e[1;32mstealth\e[0m skill increased significantly!\n"
		fi
	else
		# Failure
		loot=0
		local previous_wanted=$wanted_level
		wanted_level=$((wanted_level + 2))
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_level > previous_wanted )); then
			echo -e "\e[1;31mWanted Level Increased!\e[0m"
			play_sfx_mpg "police_siren"
		fi

		local base_fine=$((RANDOM % 201 + 100))
		local base_damage_player=$((RANDOM % 41 + 20))
		fine=$(( base_fine + wanted_level * 50 ))
		damage_player=$(( base_damage_player + wanted_level * 10 ))
		damage_vehicle=$((RANDOM % 50 + 25))

		cash=$((cash - fine))
		(( cash < 0 )) && cash=0

		if $body_armor_equipped; then
			local armor_reduction=$((damage_player / 2)); damage_player=$((damage_player - armor_reduction))
			echo "Body armor saved your life from \e[1;31m${armor_reduction}%%\e[0m damage!"
			body_armor_equipped=false
		fi
		health=$((health - damage_player))

		clear_screen # Refresh after time pass
		printf "\e[1;31m--- HEIST FAILED! ---\e[0m (%dh passed)\n Security was too tight.\n" "$crime_time"
		printf "You lost \$%d and took %d%% damage.\n" "$fine" "$damage_player"
		apply_vehicle_damage "$chosen_vehicle" "$damage_vehicle"
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
	local loot=0 damage_player=0 damage_vehicle=0 fine=0
	local chosen_vehicle="None"
	local crime_time=4 # Gang wars are intense but maybe quicker than heist

	clear_screen
	echo "--- Gang War ---"
	echo "Rolling up on rival territory in $location..."
	chosen_vehicle=$(choose_vehicle_for_job "Choose a vehicle for the assault?" "Sedan|Truck|Van|OffRoad|Sports Car")
	sleep 1

	if command -v gang_war_animation &> /dev/null; then gang_war_animation; else echo "Bullets start flying!"; sleep 1; fi

	local gun_bonus_chance=$(apply_gun_bonus "$base_chance" "gang war")
	local vehicle_bonus=$(get_vehicle_bonus "$chosen_vehicle" "crime_bonus")
	local final_success_chance=$(( gun_bonus_chance + vehicle_bonus ))
	(( final_success_chance < 10 )) && final_success_chance=10
	(( final_success_chance > 90 )) && final_success_chance=90

	printf "Assessing rival strength... Base: %d%% | Gun Mod: %+d%% | Vehicle (\e[1;33m%s\e[0m): %+d%%\n" \
		"$base_chance" "$((gun_bonus_chance - base_chance - vehicle_bonus))" "$chosen_vehicle" "$vehicle_bonus"
	printf "Final success chance: \e[1;32m%d%%\e[0m\n" "$final_success_chance"
	read -r -p "Press Enter to start the fight..."

	game_time=$(( game_time + crime_time )) # Add crime time

	if (( RANDOM % 100 < final_success_chance )); then
		# Success
		loot=$((RANDOM % 201 + 100 + strength_skill * 15))
		cash=$((cash + loot))
		damage_player=$((RANDOM % 35 + 15))
		damage_vehicle=$((RANDOM % 40 + 20))

		if $body_armor_equipped; then
			local armor_reduction=$((damage_player / 2)); damage_player=$((damage_player - armor_reduction))
			echo "Body armor took \e[1;31m${armor_reduction}%%\e[0m damage from bullets!"
			body_armor_equipped=false
		fi
		health=$((health - damage_player))

		clear_screen # Refresh after time pass
		printf "\e[1;32m*** GANG WAR WON! ***\e[0m (%dh passed)\n You claimed the turf and \$%d spoils.\n" "$crime_time" "$loot"
		printf "Suffered heavy damage (-%d%% health).\n" "$damage_player"
		apply_vehicle_damage "$chosen_vehicle" "$damage_vehicle"
		play_sfx_mpg "win"
		if (( RANDOM % 2 == 0 )); then
			skills[strength]=$((strength_skill + 1))
			printf "Your \e[1;32mstrength\e[0m skill increased!\n"
		fi
	else
		# Failure
		loot=0
		local previous_wanted=$wanted_level
		wanted_level=$((wanted_level + 2))
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_level > previous_wanted )); then
			echo -e "\e[1;31mWanted Level Increased!\e[0m"
			play_sfx_mpg "police_siren"
		fi

		local base_fine=$((RANDOM % 151 + 75))
		local base_damage_player=$((RANDOM % 51 + 25))
		fine=$(( base_fine + wanted_level * 40 ))
		damage_player=$(( base_damage_player + wanted_level * 12 ))
		damage_vehicle=$((RANDOM % 60 + 30))

		cash=$((cash - fine))
		(( cash < 0 )) && cash=0

		if $body_armor_equipped; then
			local armor_reduction=$((damage_player / 2)); damage_player=$((damage_player - armor_reduction))
			echo "Body armor prevented \e[1;31m${armor_reduction}%%\e[0m fatal damage!"
			body_armor_equipped=false
		fi
		health=$((health - damage_player))

		clear_screen # Refresh after time pass
		printf "\e[1;31m--- GANG WAR LOST! ---\e[0m (%dh passed)\n You were overrun.\n" "$crime_time"
		printf "You lost \$%d and took %d%% damage.\n" "$fine" "$damage_player"
		apply_vehicle_damage "$chosen_vehicle" "$damage_vehicle"
		play_sfx_mpg "lose"
	fi

	printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"
	check_health
	read -r -p "Press Enter to continue..."
}

carjack() {
	local driving_skill=${skills[driving]:-1}
	local stealth_skill=${skills[stealth]:-1}
	local base_chance=$(( 25 + driving_skill * 2 + stealth_skill * 3 ))
	local loot=0 damage_player=0 fine=0
	local crime_time=1 # Carjacking is quick

	clear_screen
	echo "--- Carjack ---"
	echo "Looking for a vehicle to 'borrow' in $location..."
	sleep 1

	if command -v carjacking_animation &> /dev/null; then carjacking_animation; else echo "Spotting a target..."; sleep 1; fi

	local final_success_chance=$(apply_gun_bonus "$base_chance" "carjacking")
	(( final_success_chance < 10 )) && final_success_chance=10
	(( final_success_chance > 95 )) && final_success_chance=95

	printf "Choosing a target... Base: %d%% | Gun Mod: %+d%%\n" \
		"$base_chance" "$((final_success_chance - base_chance))"
	printf "Final success chance: \e[1;32m%d%%\e[0m\n" "$final_success_chance"
	read -r -p "Press Enter to make your move..."

	game_time=$(( game_time + crime_time )) # Add crime time

	if (( RANDOM % 100 < final_success_chance )); then
		# Success - Grant Vehicle
		local possible_cars_common=("Sedan" "Truck" "Motorcycle" "Van")
		local possible_cars_rare=("Sports Car" "OffRoad" "Limo")
		local stolen_car_type=""
		local rarity_roll=$((RANDOM % 100))
		if (( rarity_roll < 20 )); then
			stolen_car_type=${possible_cars_rare[ RANDOM % ${#possible_cars_rare[@]} ]}
		else
			stolen_car_type=${possible_cars_common[ RANDOM % ${#possible_cars_common[@]} ]}
		fi

		local already_owned=false
		for v in "${owned_vehicles[@]}"; do [[ "$v" == "$stolen_car_type" ]] && already_owned=true && break; done

		if $already_owned; then
			 clear_screen # Refresh after time pass
			 echo "You spot a $stolen_car_type, but already have one. (%dh passed)" "$crime_time"
			 sleep 1
		else
			owned_vehicles+=("$stolen_car_type")
			vehicle_health["$stolen_car_type"]=$((RANDOM % 31 + 70)) # 70-100% health
			loot=$((RANDOM % 51 + 20))
			cash=$((cash + loot))
			damage_player=$((RANDOM % 10 + 1))

			if $body_armor_equipped; then
				local armor_reduction=$((damage_player / 2)); damage_player=$((damage_player - armor_reduction))
				if (( armor_reduction > 0 )); then
					echo "Body armor absorbed \e[1;31m${armor_reduction}%%\e[0m damage during the scuffle!"
					body_armor_equipped=false
				fi
			fi
			health=$((health - damage_player))

			clear_screen # Refresh after time pass
			printf "\e[1;32mSuccess!\e[0m You boosted a \e[1;33m%s\e[0m (Health: %d%%)! (%dh passed)\n" "$stolen_car_type" "${vehicle_health[$stolen_car_type]}" "$crime_time"
			printf "Fenced some minor items inside for \$%d.\n" "$loot"
			printf "Got slightly banged up (-%d%% health).\n" "$damage_player"
			play_sfx_mpg "car_start"
			if (( RANDOM % 4 == 0 )); then skills[driving]=$((driving_skill+1)); printf "Your \e[1;32mdriving\e[0m skill increased!\n"; fi
			if (( RANDOM % 4 == 0 )); then skills[stealth]=$((stealth_skill+1)); printf "Your \e[1;32mstealth\e[0m skill increased!\n"; fi
		fi
	else
		# Failure
		loot=0
		local previous_wanted=$wanted_level
		wanted_level=$((wanted_level + 1))
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_level > previous_wanted )); then
			echo -e "\e[1;31mWanted Level Increased!\e[0m"
			play_sfx_mpg "police_siren"
		fi

		local base_fine=$((RANDOM % 76 + 25))
		local base_damage_player=$((RANDOM % 26 + 10))
		fine=$(( base_fine + wanted_level * 20 ))
		damage_player=$(( base_damage_player + wanted_level * 6 ))

		cash=$((cash - fine))
		(( cash < 0 )) && cash=0

		if $body_armor_equipped; then
			local armor_reduction=$((damage_player / 2)); damage_player=$((damage_player - armor_reduction))
			echo "Body armor took \e[1;31m${armor_reduction}%%\e[0m damage when the owner fought back!"
			body_armor_equipped=false
		fi
		health=$((health - damage_player))

		clear_screen # Refresh after time pass
		printf "\e[1;31mFailed!\e[0m Alarm blared / Owner resisted / Cops nearby. (%dh passed)\n" "$crime_time"
		printf "You were fined \$%d and took %d%% damage.\n" "$fine" "$damage_player"
	fi

	printf "Current Status -> Cash: \$%d | Health: %d%%\n" "$cash" "$health"
	check_health
	read -r -p "Press Enter to continue..."
}

# --- Player Wasted/Hospitalization ---
hospitalize_player() {
	local hospital_bill=200
	echo "The hospital patched you up."
	sleep 1
	echo "Unfortunately, medical care isn't free. Bill: \$${hospital_bill}."

	if (( cash < hospital_bill )); then
		echo "You couldn't afford the full bill (\$$hospital_bill). They took all your cash (\$$cash)."
		hospital_bill=$cash
	else
		echo "You paid the \$${hospital_bill} bill."
	fi

	cash=$((cash - hospital_bill))
	health=50 # Restore health to 50%
	body_armor_equipped=false # Lose armor
	# Reset Wanted Level
	if (( wanted_level > 0 )); then
		echo "The police lose interest while you're recovering. Wanted level cleared."
		wanted_level=0
	fi
	play_sfx_mpg "cash_register"

	# Time passes while recovering
	local recovery_time=$((RANDOM % 6 + 6)) # 6-11 hours
	game_time=$(( game_time + recovery_time ))
	printf "You spent %d hours recovering.\n" "$recovery_time"

	printf "You leave the hospital with \$%d cash and %d%% health.\n" "$cash" "$health"
	# No pause here, check_health in main loop will handle screen update
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
	[[ -v health && $health -gt 100 ]] && max_health=110 # Allow healing up to boosted max

	local interaction_time=1 # Takes 1 hour

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
			game_time=$(( game_time + interaction_time )) # Add interaction time
			local previous_health=$health
			health=$(( health + health_gain ))
			(( health > max_health )) && health=$max_health
			local actual_gain=$((health - previous_health))

			clear_screen # Refresh after time passed
			echo "--- Transaction Complete --- (%dh passed)" "$interaction_time"
			printf "You paid \$%d.\n" "$hooker_cost"
			if (( actual_gain > 0 )); then
				 printf "Feeling refreshed, you gained \e[1;32m%d%%\e[0m health (Now: %d%%).\n" "$actual_gain" "$health"
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

# --- Market/Drugs (No changes needed for time/vehicle focus) ---
update_market_conditions() {
	local event_chance=15
	local event_roll=$((RANDOM % 100))

	market_conditions=() # Clear the array
	market_conditions["crackdown_multiplier"]=1.0
	market_conditions["demand_multiplier"]=1.0
	market_conditions["buy_multiplier"]=1.0
	market_conditions["event_message"]=""

	if (( event_roll < event_chance )); then
		local event_type=$((RANDOM % 2))
		if (( event_type == 0 )); then # Police Crackdown
			market_conditions["crackdown_multiplier"]=0.6
			market_conditions["buy_multiplier"]=1.1
			market_conditions["event_message"]="Police Crackdown! Prices are unfavorable."
			play_sfx_mpg "police_siren"
		else # High Demand
			market_conditions["demand_multiplier"]=1.5
			market_conditions["buy_multiplier"]=1.1
			market_conditions["event_message"]="High Demand! Good time to sell!"
			play_sfx_mpg "cash_register"
		fi
	fi
}

drug_transaction() {
	local action="$1" base_price="$3" drug_amount_str="$4"
	local drug_name="$2"
	local cost=0 income=0 final_price=0
	local drug_dealer_skill=${skills[drug_dealer]:-1}
	local drug_amount=0

	if ! [[ "$drug_amount_str" =~ ^[1-9][0-9]*$ ]]; then
		echo "Invalid amount '$drug_amount_str'. Please enter a positive number."
		read -r -p "Press Enter..."
		return 1
	fi
	drug_amount=$((drug_amount_str))

	local use_bc=false
	command -v bc &> /dev/null && use_bc=true

	local price_fluctuation=$(( RANDOM % 21 - 10 ))
	local location_modifier=0
	case "$location" in
		"Liberty City") location_modifier=15;; "Las Venturas") location_modifier=10;;
		"Vice City")    location_modifier=-15;; *) location_modifier=0;;
	esac
	local current_market_price=$(( base_price + (base_price * (price_fluctuation + location_modifier) / 100) ))
	(( current_market_price < 1 )) && current_market_price=1

	local buy_multiplier=${market_conditions["buy_multiplier"]:-1.0}
	local sell_multiplier=${market_conditions["crackdown_multiplier"]:-1.0}
	local demand_multiplier=${market_conditions["demand_multiplier"]:-1.0} # Fetch demand multiplier

	if $use_bc; then
		sell_multiplier=$(echo "scale=2; $sell_multiplier * $demand_multiplier" | bc)
	else
		sell_multiplier=$(( ${sell_multiplier%.*} * ${demand_multiplier%.*} )) # Integer approx
	fi

	if [[ "$action" == "buy" ]]; then
		if $use_bc; then
			final_price=$(echo "scale=0; $current_market_price * $buy_multiplier / 1" | bc)
		else
			final_price=$(( current_market_price * ${buy_multiplier%.*} ))
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
			printf "Not enough cash. Need \$%d, you have \$%d.\n" "$cost" "$cash"
			read -r -p "Press Enter..."
			return 1
		fi

	elif [[ "$action" == "sell" ]]; then
		local current_inventory=${drugs[$drug_name]:-0}
		if (( current_inventory >= drug_amount )); then
			local price_bonus_percent=$((drug_dealer_skill * 2))
			local skill_adjusted_price=$(( current_market_price + (current_market_price * price_bonus_percent / 100) ))

			if $use_bc; then
				final_price=$(echo "scale=0; $skill_adjusted_price * $sell_multiplier / 1" | bc)
			else
				final_price=$(( skill_adjusted_price * ${sell_multiplier%.*} ))
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
			fi
			return 0
		else
			printf "Not enough %s to sell. You have %d units, tried to sell %d.\n" \
				   "$drug_name" "$current_inventory" "$drug_amount"
			read -r -p "Press Enter..."
			return 1
		fi
	else
		echo "Internal Error: Invalid action '$action' in drug_transaction." ; return 1
	fi
}

buy_drugs() {
	local drug_choice="" drug_amount=""
	declare -A drug_prices=( ["Weed"]=10 ["Cocaine"]=50 ["Heroin"]=100 ["Meth"]=75 )
	local drug_names=("Weed" "Cocaine" "Heroin" "Meth")
	local use_bc=false
	command -v bc &> /dev/null && use_bc=true

	while true; do
		clear_screen
		echo "--- Drug Dealer (Buy) ---"
		printf " Location: %-15s | Cash: \$%d\n" "$location" "$cash"
		if [[ -n "${market_conditions["event_message"]}" ]]; then
			printf " \e[1;36mMarket News: %s\e[0m\n" "${market_conditions["event_message"]}"
		fi
		echo "---------------------------"
		echo " Available Inventory (Approx Price/unit):"
		local i=1
		for name in "${drug_names[@]}"; do
			local base_p=${drug_prices[$name]}
			local loc_mod_val=$( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0)
			local approx_p=$(( base_p + (base_p * loc_mod_val / 100) ))
			local buy_mult=${market_conditions["buy_multiplier"]:-1.0}
			if $use_bc; then
				approx_p=$(echo "scale=0; $approx_p * $buy_mult / 1" | bc)
			else
				approx_p=$(( approx_p * ${buy_mult%.*} ))
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
		# Transaction function handles pause
	done
}

sell_drugs() {
	local drug_choice="" drug_amount=""
	declare -A drug_sell_prices=( ["Weed"]=15 ["Cocaine"]=75 ["Heroin"]=150 ["Meth"]=100 )
	local drug_names=("Weed" "Cocaine" "Heroin" "Meth")
	local use_bc=false
	command -v bc &> /dev/null && use_bc=true

	while true; do
		clear_screen
		echo "--- Drug Dealer (Sell) ---"
		printf " Location: %-15s | Cash: \$%d\n" "$location" "$cash"
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
				local loc_mod_val=$( [[ "$location" == "Liberty City" ]] && echo 15 || [[ "$location" == "Las Venturas" ]] && echo 10 || [[ "$location" == "Vice City" ]] && echo -15 || echo 0)
				local approx_p=$(( base_p + (base_p * ( loc_mod_val + skill_bonus_p ) / 100) ))

				local sell_mult=${market_conditions["crackdown_multiplier"]:-1.0}
				local demand_mult=${market_conditions["demand_multiplier"]:-1.0}
				local combined_mult=1.0
				if $use_bc; then
					combined_mult=$(echo "scale=2; $sell_mult * $demand_mult" | bc)
					approx_p=$(echo "scale=0; $approx_p * $combined_mult / 1" | bc)
				else
					approx_p=$(( approx_p * ${sell_mult%.*} * ${demand_mult%.*} ))
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
		# Transaction function handles pause
	done
}

# --- Music Player ---
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
	while IFS= read -r -d $'\0' file; do music_files+=("$file"); done < <(find "$music_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.MP3" \) -print0 2>/dev/null)
	IFS="$original_ifs"
	if (( ${#music_files[@]} == 0 )); then
		echo "No .mp3 files found in '$music_dir'."; read -r -p "Press Enter..."; return 1;
	fi
	local choice_stop="s" choice_back="b" music_choice=""
	local mpg123_log="/tmp/bta_mpg123_errors.$$.log"
	while true; do
		clear_screen
		echo "--- Music Player ---"; echo " Music Directory: $music_dir"; echo "----------------------------------------"
		local current_status="Stopped" current_song_name=""
		if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
			current_song_name=$(ps -p "$music_pid" -o args= 2>/dev/null | sed 's/.*mpg123 [-q]* //; s/ *$//' || echo "Playing Track")
			[[ -z "$current_song_name" ]] && current_song_name="Playing Track"
			current_status="Playing: $(basename "$current_song_name") (PID: $music_pid)"
		else
			[[ -n "$music_pid" ]] && music_pid=""
			current_status="Stopped"
		fi
		echo " Status: $current_status"; echo "----------------------------------------"; echo " Available Tracks:"
		for i in "${!music_files[@]}"; do printf " %d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"; done
		echo "----------------------------------------"; printf " [%s] Stop Music | [%s] Back to Game\n" "$choice_stop" "$choice_back"; echo "----------------------------------------"
		stty echo; read -r -p "Enter choice (number, s, b): " music_choice
		case "$music_choice" in
			"$choice_stop" | "s" | "S")
				if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
					echo "Stopping music (PID: $music_pid)..."; kill "$music_pid" &>/dev/null; sleep 0.2
					if kill -0 "$music_pid" &>/dev/null; then kill -9 "$music_pid" &>/dev/null; fi
					wait "$music_pid" 2>/dev/null; music_pid=""; echo "Music stopped."
				else echo "No music is currently playing."; fi
				sleep 1;;
			"$choice_back" | "b" | "B") echo "Returning to game..."; sleep 1; break;;
			*)
				if [[ "$music_choice" =~ ^[0-9]+$ ]] && (( music_choice >= 1 && music_choice <= ${#music_files[@]} )); then
					local selected_track="${music_files[$((music_choice - 1))]}"
					if [[ ! -f "$selected_track" ]]; then echo "Error: File '$selected_track' not found!"; sleep 2; continue; fi
					if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
						echo "Stopping previous track..."; kill "$music_pid" &>/dev/null; wait "$music_pid" 2>/dev/null; music_pid=""; sleep 0.2; fi
					echo "Attempting to play: $(basename "$selected_track")"
					echo "--- BTA Log $(date) --- Playing: $selected_track" >> "$mpg123_log"
					mpg123 -q "$selected_track" 2>> "$mpg123_log" &
					local new_pid=$!; sleep 0.5
					if kill -0 "$new_pid" 2>/dev/null; then music_pid=$new_pid; echo "Playback started (PID: $music_pid)."
					else
						echo "Error: Failed to start mpg123 process for $(basename "$selected_track")."; echo "       Check log: $mpg123_log"
						if [[ -f "$mpg123_log" ]]; then echo "--- Last lines of log ---"; tail -n 5 "$mpg123_log"; echo "-------------------------"; fi
						music_pid=""; read -r -p "Press Enter..."; fi
				else echo "Invalid choice '$music_choice'."; sleep 1; fi;;
		esac
	done
}

# --- Save/Load Functions ---
save_atomic() {
	# Local helper for save_game
	local content="$1" file_path="$2" temp_file="${file_path}.tmp$$"
	printf '%s\n' "$content" > "$temp_file" && mv "$temp_file" "$file_path" || {
		echo "Error saving file: $file_path"; rm -f "$temp_file"; return 1;
	}
	return 0
}

save_game() {
	local save_path="$BASEDIR/$SAVE_DIR"
	mkdir -p "$save_path" || { echo "Error: Could not create save directory '$save_path'."; read -r -p "Press Enter..."; return 1; }
	echo "Saving game state..."
	local temp_ext=".tmp$$" # Temporary extension for atomic saves

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
	local wanted_file="$save_path/wanted_level.sav"
	local vehicles_file="$save_path/vehicles.sav"
	local vehicle_health_file="$save_path/vehicle_health.sav"
	local time_file="$save_path/game_time.sav"

	# Save Simple Variables
	save_atomic "$player_name" "$player_file" || return 1
	save_atomic "$location" "$loc_file" || return 1
	save_atomic "$cash" "$cash_file" || return 1
	save_atomic "$health" "$health_file" || return 1
	save_atomic "$body_armor_equipped" "$armor_file" || return 1
	save_atomic "$wanted_level" "$wanted_file" || return 1
	save_atomic "$game_time" "$time_file" || return 1

	# Save Indexed Arrays
	printf '%s\n' "${guns[@]}" > "$guns_file$temp_ext" && mv "$guns_file$temp_ext" "$guns_file" || { echo "Error saving guns."; rm -f "$guns_file$temp_ext"; return 1; }
	printf '%s\n' "${items[@]}" > "$items_file$temp_ext" && mv "$items_file$temp_ext" "$items_file" || { echo "Error saving items."; rm -f "$items_file$temp_ext"; return 1; }
	printf '%s\n' "${owned_vehicles[@]}" > "$vehicles_file$temp_ext" && mv "$vehicles_file$temp_ext" "$vehicles_file" || { echo "Error saving vehicles."; rm -f "$vehicles_file$temp_ext"; return 1; }

	# Save Associative Arrays (Drugs)
	: > "$drugs_file$temp_ext"
	for key in "${!drugs[@]}"; do [[ ${drugs[$key]} -gt 0 ]] && printf "%s %s\n" "$key" "${drugs[$key]}" >> "$drugs_file$temp_ext"; done
	if [[ -f "$drugs_file$temp_ext" ]]; then mv "$drugs_file$temp_ext" "$drugs_file" || { echo "Error finalizing drugs save."; rm -f "$drugs_file$temp_ext"; return 1; }; else rm -f "$drugs_file"; fi

	# Save Associative Arrays (Skills)
	: > "$skills_file$temp_ext"
	for key in "${!skills[@]}"; do printf "%s %s\n" "$key" "${skills[$key]}" >> "$skills_file$temp_ext"; done
	if [[ -f "$skills_file$temp_ext" ]]; then mv "$skills_file$temp_ext" "$skills_file"; else echo "Error writing skills temp file."; return 1; fi

	# Save Associative Arrays (Vehicle Health)
	: > "$vehicle_health_file$temp_ext"
	for key in "${!vehicle_health[@]}"; do
		local found=false; for owned_v in "${owned_vehicles[@]}"; do [[ "$owned_v" == "$key" ]] && found=true && break; done
		if $found; then printf "%s %s\n" "$key" "${vehicle_health[$key]}" >> "$vehicle_health_file$temp_ext"; fi
	done
	if [[ -f "$vehicle_health_file$temp_ext" ]]; then mv "$vehicle_health_file$temp_ext" "$vehicle_health_file" || { echo "Error finalizing vehicle health save."; rm -f "$vehicle_health_file$temp_ext"; return 1; }; else rm -f "$vehicle_health_file"; fi

	echo "Game saved successfully to '$save_path'."
	read -r -p "Press Enter to continue..."
	return 0
}

load_game() {
	local load_success=true; local original_ifs="$IFS"; local key value line save_file;
	local save_path="$BASEDIR/$SAVE_DIR"
	echo "Attempting to load game from '$save_path'..."
	if [[ ! -d "$save_path" ]]; then echo "Error: Save directory '$save_path' not found."; read -r -p "Press Enter..."; return 1; fi

	# --- Load Simple Variables ---
	save_file="$save_path/player_name.sav"; [[ -f "$save_file" ]] && { read -r player_name < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; player_name="Unknown"; load_success=false; }
	save_file="$save_path/location.sav"; [[ -f "$save_file" ]] && { read -r location < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; location="Los Santos"; load_success=false; }
	save_file="$save_path/cash.sav"; [[ -f "$save_file" ]] && { read -r cash < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; cash=0; load_success=false; }
	[[ ! "$cash" =~ ^-?[0-9]+$ ]] && { >&2 echo "Warn: Invalid cash '$cash', resetting."; cash=0; load_success=false; }
	save_file="$save_path/health.sav"; [[ -f "$save_file" ]] && { read -r health < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; health=100; load_success=false; }
	[[ ! "$health" =~ ^[0-9]+$ ]] && { >&2 echo "Warn: Invalid health '$health', resetting."; health=100; load_success=false; }
	(( health <= 0 && load_success )) && { >&2 echo "Warn: Loaded health <= 0, setting to 50."; health=50; load_success=false;}
	save_file="$save_path/body_armor_equipped.sav"; [[ -f "$save_file" ]] && { read -r body_armor_equipped < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; body_armor_equipped=false; load_success=false; }
	[[ "$body_armor_equipped" != "true" && "$body_armor_equipped" != "false" ]] && { >&2 echo "Warn: Invalid armor status '$body_armor_equipped', resetting."; body_armor_equipped=false; load_success=false; }
	save_file="$save_path/wanted_level.sav"; [[ -f "$save_file" ]] && { read -r wanted_level < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; wanted_level=0; load_success=false; }
	[[ ! "$wanted_level" =~ ^[0-9]+$ ]] && { >&2 echo "Warn: Invalid wanted level '$wanted_level', resetting."; wanted_level=0; load_success=false; }
	(( wanted_level > MAX_WANTED_LEVEL )) && { >&2 echo "Warn: Loaded wanted level > max, capping."; wanted_level=$MAX_WANTED_LEVEL; load_success=false;}
	save_file="$save_path/game_time.sav"; [[ -f "$save_file" ]] && { read -r game_time < "$save_file" || { >&2 echo "Error reading $save_file"; load_success=false; }; } || { >&2 echo "Warn: $save_file missing"; game_time=0; load_success=false; }
	[[ ! "$game_time" =~ ^[0-9]+$ ]] && { >&2 echo "Warn: Invalid game time '$game_time', resetting."; game_time=0; load_success=false; }

	# --- Load Indexed Arrays ---
	guns=(); save_file="$save_path/guns.sav"; if [[ -f "$save_file" ]]; then mapfile -t guns < "$save_file" 2>/dev/null || { IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do guns+=("$line"); done < "$save_file"; IFS="$original_ifs"; }; else >&2 echo "Warn: $save_file missing"; fi
	items=(); save_file="$save_path/items.sav"; if [[ -f "$save_file" ]]; then mapfile -t items < "$save_file" 2>/dev/null || { IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do items+=("$line"); done < "$save_file"; IFS="$original_ifs"; }; else >&2 echo "Warn: $save_file missing"; fi
	owned_vehicles=(); save_file="$save_path/vehicles.sav"; if [[ -f "$save_file" ]]; then mapfile -t owned_vehicles < "$save_file" 2>/dev/null || { IFS=$'\n'; while read -r line || [[ -n "$line" ]]; do owned_vehicles+=("$line"); done < "$save_file"; IFS="$original_ifs"; }; local valid_vehicles=(); for v in "${owned_vehicles[@]}"; do [[ -v "vehicle_types[$v]" ]] && valid_vehicles+=("$v") || >&2 echo "Warn: Discarding unknown vehicle '$v'"; done; owned_vehicles=("${valid_vehicles[@]}"); else >&2 echo "Warn: $save_file missing"; load_success=false; fi

	# --- Load Associative Arrays ---
	declare -A drugs_loaded=(); save_file="$save_path/drugs.sav"; if [[ -f "$save_file" ]]; then while IFS=' ' read -r key value || [[ -n "$key" ]]; do if [[ -n "$key" && -v "default_drugs[$key]" ]]; then if [[ "$value" =~ ^[0-9]+$ ]]; then drugs_loaded["$key"]="$value"; else >&2 echo "Warn: Invalid drug amount '$key'='$value'"; drugs_loaded["$key"]=0; load_success=false; fi; elif [[ -n "$key" ]]; then >&2 echo "Warn: Skipping unknown drug '$key'"; fi; done < "$save_file"; else >&2 echo "Warn: $save_file missing"; load_success=false; fi
	declare -gA drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${drugs_loaded[$key]:-${default_drugs[$key]}}; done

	declare -A skills_loaded=(); save_file="$save_path/skills.sav"; if [[ -f "$save_file" ]]; then while IFS=' ' read -r key value || [[ -n "$key" ]]; do if [[ -n "$key" && -v "default_skills[$key]" ]]; then if [[ "$value" =~ ^[0-9]+$ && $value -ge 1 ]]; then skills_loaded["$key"]="$value"; else >&2 echo "Warn: Invalid skill level '$key'='$value'"; skills_loaded["$key"]=1; load_success=false; fi; elif [[ -n "$key" ]]; then >&2 echo "Warn: Skipping unknown skill '$key'"; fi; done < "$save_file"; else >&2 echo "Warn: $save_file missing"; load_success=false; fi
	declare -gA skills; for key in "${!default_skills[@]}"; do skills["$key"]=${skills_loaded[$key]:-${default_skills[$key]}}; done

	declare -gA vehicle_health; vehicle_health=(); save_file="$save_path/vehicle_health.sav"; if [[ -f "$save_file" ]]; then while IFS=' ' read -r key value || [[ -n "$key" ]]; do local found_in_owned=false; for owned_v in "${owned_vehicles[@]}"; do [[ "$owned_v" == "$key" ]] && found_in_owned=true && break; done; if $found_in_owned; then if [[ "$value" =~ ^[0-9]+$ && $value -ge 0 && $value -le 100 ]]; then vehicle_health["$key"]="$value"; else >&2 echo "Warn: Invalid vehicle health '$key'='$value'"; vehicle_health["$key"]=100; load_success=false; fi; elif [[ -n "$key" ]]; then >&2 echo "Warn: Skipping health for unowned vehicle '$key'"; fi; done < "$save_file"; else >&2 echo "Warn: $save_file missing (vehicle_health)"; load_success=false; fi
	for owned_v in "${owned_vehicles[@]}"; do if [[ ! -v vehicle_health["$owned_v"] ]]; then >&2 echo "Warn: Missing health for '$owned_v', setting to 100."; vehicle_health["$owned_v"]=100; load_success=false; fi; done

	# --- Finalize ---
	IFS="$original_ifs"
	if $load_success; then echo "Game loaded successfully."; else echo "Warning: Game loaded with missing/invalid data."; fi
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
	cash=500; health=100; game_time=0; body_armor_equipped=false; wanted_level=0
	guns=(); items=(); owned_vehicles=(); vehicle_health=()
	declare -gA drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${default_drugs[$key]}; done
	declare -gA skills; for key in "${!default_skills[@]}"; do skills["$key"]=${default_skills[$key]}; done
	echo "Welcome to Bash Theft Auto, $player_name!"
	echo "Starting in $location with \$${cash} and ${health}% health."
	read -r -p "Press Enter to begin..."
}

remove_save_files() {
	local save_path="$BASEDIR/$SAVE_DIR"
	if [[ -d "$save_path" ]]; then
		echo "Deleting previous save files in '$save_path'..."
		local found_files=$(find "$save_path" -maxdepth 1 -type f -name '*.sav' -print -delete)
		if [[ -n "$found_files" ]]; then echo "Old save files deleted."; else echo "No '.sav' files found."; fi
	else
		echo "Info: No previous save directory found."
	fi
	sleep 1
}

run_initial_menu() {
	while true; do
		clear_screen
		echo "=== Bash Theft Auto ==="; echo "      Main Menu"; echo "---------------------"
		echo "1. New Game"; echo "2. Load Game"; echo "3. Exit Game"; echo "---------------------"
		stty echo; read -r -p "Enter your choice: " initial_choice
		case "$initial_choice" in
			1) read -r -p "Start new game? This deletes any existing save. (y/n): " confirm
			   if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then remove_save_files; Game_variables; return 0;
			   else echo "New game cancelled."; sleep 1; fi ;;
			2) if load_game; then return 0; else sleep 1; fi ;;
			3) cleanup_and_exit ;;
			*) echo "Invalid choice."; sleep 1 ;;
		esac
	done
}

# --- Vehicle Helper Functions ---
apply_vehicle_damage() {
	local vehicle_type="$1"; local damage_amount="$2"
	[[ -z "$vehicle_type" || "$vehicle_type" == "None" ]] && return
	if [[ ! -v vehicle_health["$vehicle_type"] ]]; then echo "Warning: Cannot damage missing vehicle '$vehicle_type'." >&2; return; fi
	local current_health=${vehicle_health["$vehicle_type"]}
	local new_health=$(( current_health - damage_amount ))
	if (( new_health <= 0 )); then
		echo -e "\e[1;31mYour $vehicle_type took critical damage ($damage_amount%) and was destroyed!\e[0m"; play_sfx_mpg "explosion"
		local temp_vehicles=(); for v in "${owned_vehicles[@]}"; do [[ "$v" != "$vehicle_type" ]] && temp_vehicles+=("$v"); done
		owned_vehicles=("${temp_vehicles[@]}"); unset vehicle_health["$vehicle_type"]
	else
		vehicle_health["$vehicle_type"]=$new_health
		printf "Your \e[1;33m%s\e[0m took \e[1;31m%d%%\e[0m damage. Current health: %d%%\n" "$vehicle_type" "$damage_amount" "$new_health"; play_sfx_mpg "crash"
	fi
}

choose_vehicle_for_job() {
	local prompt_message="$1"; local allowed_types_pattern="${2:-.*}"
	local available_vehicles=(); local vehicle_display_list=(); local index=1
	for v_type in "${owned_vehicles[@]}"; do
		local v_health=${vehicle_health[$v_type]:-0}
		if [[ "$v_type" =~ ^($allowed_types_pattern)$ && $v_health -gt 0 ]]; then
			available_vehicles+=("$v_type"); vehicle_display_list+=(" $index. $v_type (${v_health}%)"); ((index++))
		fi
	done
	if (( ${#available_vehicles[@]} == 0 )); then echo "None"; return 1; fi
	echo "$prompt_message"; printf "%s\n" "${vehicle_display_list[@]}"; printf " %d. None\n" "$index"; echo "--------------------------"
	read -r -p "Enter choice (number): " choice
	local chosen_vehicle="None"
	if [[ "$choice" =~ ^[0-9]+$ ]]; then
		if (( choice == index )); then echo "Proceeding without a vehicle."
		elif (( choice >= 1 && choice <= ${#available_vehicles[@]} )); then chosen_vehicle="${available_vehicles[$((choice - 1))]}"; echo "Using your $chosen_vehicle."
		else echo "Invalid choice. Proceeding without a vehicle."; fi
	else echo "Invalid input. Proceeding without a vehicle."; fi
	echo "$chosen_vehicle"; return 0
}

get_vehicle_bonus() {
	local vehicle_type="$1"; local attribute_name="$2"; local bonus=0
	if [[ -n "$vehicle_type" && "$vehicle_type" != "None" && -v vehicle_attributes["$vehicle_type"] ]]; then
		eval "${vehicle_attributes[$vehicle_type]}"
		case "$attribute_name" in
			"race_bonus") bonus=${race_bonus:-0} ;; "crime_bonus") bonus=${crime_bonus:-0} ;;
			"delivery_bonus") bonus=${delivery_bonus:-0} ;; *) bonus=0 ;;
		esac
		local v_health=${vehicle_health[$vehicle_type]:-100}
		if (( v_health < 50 && bonus > 0 )); then bonus=$(( bonus / 2 )); elif (( v_health < 25 && bonus > 0 )); then bonus=0; fi
	fi
	echo "$bonus"
}

repair_vehicle() {
	clear_screen; echo "--- Pay 'n' Spray / Auto Repair ---"; printf " Cash: \$%d\n" "$cash"; echo "-------------------------------------"; echo " Your Damaged Vehicles:"
	local repairable_vehicles=(); local vehicle_display_list=(); local repair_costs=(); local index=1
	for v_type in "${owned_vehicles[@]}"; do
		local v_health=${vehicle_health[$v_type]:-100}
		if (( v_health < 100 )); then
			repairable_vehicles+=("$v_type"); local base_price=${vehicle_types[$v_type]:-1000}
			local repair_cost=$(( (100 - v_health) * base_price / 100 )); (( repair_cost < 20 )) && repair_cost=20
			repair_costs+=("$repair_cost"); vehicle_display_list+=(" $index. $v_type (${v_health}%) - Repair Cost: \$$repair_cost"); ((index++))
		fi
	done
	if (( ${#repairable_vehicles[@]} == 0 )); then echo "All your vehicles are in perfect condition!"; read -r -p "Press Enter..."; return; fi
	printf "%s\n" "${vehicle_display_list[@]}"; printf " %d. Leave\n" "$index"; echo "-------------------------------------"; read -r -p "Choose vehicle to repair (number): " choice
	if [[ ! "$choice" =~ ^[0-9]+$ ]]; then echo "Invalid input."; sleep 1; return; fi
	if (( choice == index )); then echo "Leaving the repair shop..."; sleep 1; return
	elif (( choice >= 1 && choice <= ${#repairable_vehicles[@]} )); then
		local chosen_index=$((choice - 1)); local chosen_vehicle="${repairable_vehicles[$chosen_index]}"; local repair_cost="${repair_costs[$chosen_index]}"
		if (( cash >= repair_cost )); then
			cash=$(( cash - repair_cost )); vehicle_health["$chosen_vehicle"]=100; play_sfx_mpg "mechanic"
			printf "Your %s has been fully repaired for \$%d.\n" "$chosen_vehicle" "$repair_cost"
		else printf "Not enough cash to repair the %s (\$%d needed).\n" "$chosen_vehicle" "$repair_cost"; play_sfx_mpg "error"; fi
	else echo "Invalid choice."; sleep 1; fi
	read -r -p "Press Enter..."
}

sell_vehicle() {
	clear_screen; echo "--- Used Cars / Chop Shop ---"; printf " Cash: \$%d\n" "$cash"; echo "-------------------------------------"; echo " Your Vehicles for Sale:"
	local sellable_vehicles=(); local vehicle_display_list=(); local sell_values=(); local index=1
	if (( ${#owned_vehicles[@]} == 0 )); then echo "You don't own any vehicles to sell."; read -r -p "Press Enter..."; return; fi
	for v_type in "${owned_vehicles[@]}"; do
		local v_health=${vehicle_health[$v_type]:-100}; local base_price=${vehicle_types[$v_type]:-1000}
		local sell_value_base=$(( base_price * (RANDOM % 21 + 40) / 100 )); local sell_value=$(( sell_value_base * v_health / 100 )); (( sell_value < 10 )) && sell_value=10
		sellable_vehicles+=("$v_type"); sell_values+=("$sell_value"); vehicle_display_list+=(" $index. $v_type (${v_health}%) - Offer: \$$sell_value"); ((index++))
	done
	printf "%s\n" "${vehicle_display_list[@]}"; printf " %d. Leave\n" "$index"; echo "-------------------------------------"; read -r -p "Choose vehicle to sell (number): " choice
	 if [[ ! "$choice" =~ ^[0-9]+$ ]]; then echo "Invalid input."; sleep 1; return; fi
	if (( choice == index )); then echo "Decided not to sell anything today."; sleep 1; return
	elif (( choice >= 1 && choice <= ${#sellable_vehicles[@]} )); then
		local chosen_index=$((choice - 1)); local chosen_vehicle="${sellable_vehicles[$chosen_index]}"; local sell_value="${sell_values[$chosen_index]}"; local v_health=${vehicle_health[$chosen_vehicle]:-??}
		read -r -p "Sell your $chosen_vehicle (${v_health}%) for \$${sell_value}? (y/n): " confirm
		if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
			 cash=$(( cash + sell_value )); play_sfx_mpg "cash_register"
			 local temp_vehicles=(); for v in "${owned_vehicles[@]}"; do [[ "$v" != "$chosen_vehicle" ]] && temp_vehicles+=("$v"); done
			 owned_vehicles=("${temp_vehicles[@]}"); unset vehicle_health["$chosen_vehicle"]
			 printf "Sold the %s for \$%d.\n" "$chosen_vehicle" "$sell_value"
		else echo "Sale cancelled."; fi
	else echo "Invalid choice."; sleep 1; fi
	read -r -p "Press Enter..."
}

# --- Main Execution ---
stty echo # Ensure echo is on at start, in case previous run was interrupted
if ! run_initial_menu; then
	echo "Exiting due to initial menu failure or user request."
	stty echo; exit 1
fi

# --- Main Game Loop ---
while true; do
	update_market_conditions
	if check_health; then clear_screen; else clear_screen; fi # Refresh screen after potential hospitalization

	echo "--- Actions ---"
	echo "1. Travel          | 8. Hire Hooker"
	echo "2. Buy Guns        | 9. Visit Hospital"
	echo "3. Buy Vehicle     | 10. Street Race"
	echo "4. Inventory       | 11. Buy Drugs"
	echo "5. Work (Legal)    | 12. Sell Drugs"
	echo "6. Work (Crime)    | 13. Repair Vehicle"
	echo "7. Sell Vehicle    | 14. ---"
	echo "-----------------------------------------"
	echo "S. Save Game      | L. Load Game"
	echo "M. Music Player   | A. About"
	echo "X. Exit Game      |"
	echo "-----------------------------------------"

	stty echo; read -r -p "Enter your choice: " choice
	choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

	case "$choice_lower" in
		1) # Travel Menu
			clear_screen; echo "--- Travel Agency ---"; echo "Where to? Current: $location"
			echo "1. Los Santos (\$50) | 2. San Fierro (\$75) | 3. Las Venturas (\$100)";
			echo "4. Vice City (\$150) | 5. Liberty City (\$200) | 6. Stay Here";
			read -r -p "Enter choice: " city_choice
			case "$city_choice" in
				1) travel_to 50 "Los Santos";; 2) travel_to 75 "San Fierro";;
				3) travel_to 100 "Las Venturas";; 4) travel_to 150 "Vice City";;
				5) travel_to 200 "Liberty City";; 6) ;; # Stay here
				*) echo "Invalid choice."; sleep 1;;
			esac;;
		2) buy_guns;;
		3) buy_vehicle;;
		4) show_inventory;;
		5) # Legal Work Menu
			clear_screen; echo "--- Honest Work ---"
			echo "1. Taxi Driver | 2. Delivery | 3. Mechanic | 4. Security | 5. Performer | 6. Bus Driver | 7. Back";
			read -r -p "Enter choice: " job_choice
			case "$job_choice" in
				1) work_job "taxi";; 2) work_job "delivery";; 3) work_job "mechanic";;
				4) work_job "security";; 5) work_job "performer";; 6) work_job "bus_driver";;
				7) ;; # Back
				*) echo "Invalid choice."; sleep 1;;
			esac;;
		6) # Criminal Activity Menu
			clear_screen; echo "--- Criminal Activities ---"
			echo "1. Rob Store | 2. Carjack | 3. Gang War | 4. Heist | 5. Burglary | 6. Back";
			read -r -p "Enter choice: " criminal_choice
			case "$criminal_choice" in
				1) rob_store;; 2) carjack;; 3) gang_war;; 4) heist;; 5) burglary;;
				6) ;; # Back
				*) echo "Invalid choice."; sleep 1;;
			esac;;
		7) sell_vehicle;;
		8) hire_hooker;;
		9) visit_hospital;;
		10) street_race;;
		11) buy_drugs;;
		12) sell_drugs;;
		13) repair_vehicle;;
		14) echo "Nothing here yet!"; sleep 1;;
		's') save_game;;
		'l') read -r -p "Load game? Unsaved progress will be lost. (y/n): " confirm
			 if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then load_game || sleep 1;
			 else echo "Load cancelled."; sleep 1; fi ;;
		'm') play_music;;
		'a') about_music_sfx;;
		'x') read -r -p "Are you sure you want to exit? (y/n): " confirm
			 if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then cleanup_and_exit; fi ;;
		*) echo "Invalid choice '$choice'."; sleep 1;;
	esac
done

# Fallback exit if loop somehow terminates unexpectedly
cleanup_and_exit
