#Bash-Theft-Auto music and sfx © 2024 by stuffbymax - Martin Petik is licensed under CC BY 4.0
#https://creativecommons.org/licenses/by/4.0/
#ver 2.0.2 bugfix
#!/bin/bash
# Set BASEDIR to the directory
BASEDIR="$(dirname "$(realpath "$0")")"

# --- 0. Global Variables ---
player_name=""
location=""
cash=0
health=0
declare -a guns
declare -a items
declare -A drugs
declare -A skills
body_armor_equipped=false
SAVE_DIR="saves"
declare -A gun_attributes

gun_attributes=(
	["Pistol"]="success_bonus=5"
	["Shotgun"]="success_bonus=10"
	["SMG"]="success_bonus=15"
	["Rifle"]="success_bonus=20"
	["Sniper"]="success_bonus=25"
)

# --- Sound Effects Setup ---
sfx_dir="sfx"  # Directory for sound effects

#mpg123
# Function to play sound effects (using mpg123)
play_sfx_mpg() {
	local sound_file="$sfx_dir/$1.mp3"
	if [[ -f "$sound_file" ]]; then
		mpg123 -q "$sound_file" &
		return 0  # Indicate success
	else
		echo "Sound file '$sound_file' not found!"
		return 1  # Indicate failure
	fi
}

# --- 1. Plugin Loading ---
plugin_dir="plugins"

if [[ -d "$plugin_dir" ]]; then
	while IFS= read -r -d $'\0' plugin; do
		[[ -f "$plugin" ]] && source "$plugin"
	done < <(find "$plugin_dir" -maxdepth 1 -name "*.sh" -print0)
else
	echo "Warning: Plugin directory '$plugin_dir' not found."
fi

# --- 3. Functions ---

# Clear the screen and display game information
clear_screen() {
clear
printf "\e[93m=========================================\e[0m\n"
printf "\e[1;43m|        Bash theaft auto               |\e[0m\n"
printf "\e[93m=========================================\e[0m\n"
printf "Player: %s   Location: %s\n" "$player_name" "$location"
printf "Cash: %d dollars      Health: %d%%\n" "$cash" "$health"
printf "\e[1;34m=========================================\e[0m\n"
printf "\e[1;44m|        made by stuffbymax             |\e[0m\n"
printf "\e[1;34m=========================================\e[0m\n"
}

# --- About ---
about_music_sfx() {
	clear_screen
	echo -e "-----------------------------------------"
	echo "|  About the Music and Sound Effects    |"
	echo "-----------------------------------------"
	echo ""
	echo "The music and some sound effects in this game"
	echo "were created by stuffbymax - Martin Petik."
	echo ""
	echo "They are licensed under the Creative"
	echo "Commons Attribution 4.0 International"
	echo "(CC BY 4.0) license:"
	echo "https://creativecommons.org/licenses/by/4.0/"
	echo ""
	echo "This means you are free to use them in"
	echo "your own projects, even commercially,"
	echo "as long as you provide appropriate credit."
	echo ""
	echo "Please attribute the music and sound"
	echo "effects with the following statement:"
	echo ""
	echo "'Music and sound effects © 2024 by"
	echo "stuffbymax - Martin Petik, licensed under"
	echo "CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/)'"
	echo ""
	echo "For more information about stuffbymax -"
	echo "Martin Petik and my work, please visit:"
	echo "https://stuffbymax.me/ or https://stuffbymax.me/wiki-blogs"
	echo ""
	echo "-----------------------------------------"
	echo "|  Code License                         |"
	echo "-----------------------------------------"
	echo ""
	echo "The code for this game is licensed underthe MIT License."
	echo "Copyright (c) 2024 stuffbymax"
	echo "You are free to use, modify, and distribute it"
	echo "with proper attribution."
	echo ""
	echo "For the full license text, visit:"
	echo "https://github.com/stuffbymax/Bash-Theft-Auto/blob/main/LICENSE"
	echo ""
	echo "Thank you for playing!"
	read -r -p "Press Enter to return to main menu..."
}

# Function to check if the player is alive
check_health() {
	if (( health <= 0 )); then
		echo "You have no health left! Transporting to hospital..."
		read -r -p "Press Enter to continue..."
		hospitalize_player
	fi
}

# Function for traveling to a new location
travel_to() {
	local travel_cost="$1"
	local new_location="$2"

	if (( cash >= travel_cost )); then
		echo "Traveling to $new_location..."
		play_sfx_mpg "air"

		# --- Air Travel Animation (Plugin Call) ---
		air_travel_animation # Call the function in animation.sh
		# --- End Air Travel Animation ---

		cash=$((cash - travel_cost))
		# Remove the press enter prompt here, it is unnessecary with the animation

		location="$new_location"
		clear_screen
		echo "You have arrived at $new_location."
	else
		echo "Not enough cash to travel to $new_location."
		read -r -p "Press Enter to continue..."
		clear_screen
	fi
}

# Function for buying guns
buy_guns() {
	local gun_choice
	clear_screen
	echo "Gun Store - Choose a gun to buy:"
	echo "1. Pistol (100$)"
	echo "2. Shotgun (250$)"
	echo "3. SMG (500$)"
	echo "4. Rifle (750$)"
	echo "5. Sniper (1000$)"
	echo "6. Back to main menu"
	read -r -p "Enter your choice (number): " gun_choice

	[[ ! "$gun_choice" =~ ^[0-9]+$ ]] && {
		echo "Invalid input. Please enter a number from the menu."
		read -r -p "Press Enter to continue..."
		return
	}

	case "$gun_choice" in
		1) buy_item "Pistol" 100;;
		2) buy_item "Shotgun" 250;;
		3) buy_item "SMG" 500;;
		4) buy_item "Rifle" 750;;
		5) buy_item "Sniper" 1000;;
		6) clear_screen;;
		*) echo "Invalid choice.";;
	esac
}

# Helper function for buying items
buy_item() {
	local item_name="$1"
	local item_cost="$2"
	play_sfx_mpg "cash_register"
	buy_animation

	if (( cash >= item_cost )); then
		cash=$((cash - item_cost))
		guns+=("$item_name")
		echo "You bought a $item_name."
		read -r -p "Press Enter to continue..."
	else
		echo "Not enough cash to buy a $item_name."
		read -r -p "Press Enter to continue..."
	fi
}

# Function to show inventory
show_inventory() {
	clear_screen
	echo "Your Inventory:"
	printf "Cash: %d dollars\n" "$cash"
	printf "Health: %d%%\n" "$health"
	printf "Guns: %s\n" "${guns[*]}"
	printf "Items: %s\n" "${items[*]}"
	echo "Drugs: "
	local IFS=$'\n'
	for drug in "${!drugs[@]}"; do
		printf "  - %s: %s\n" "$drug" "${drugs[$drug]}"
	done
	IFS=$' \t\n' # Restore IFS

	echo "Skills:"
	local IFS=$'\n'
	for skill in "${!skills[@]}"; do
		printf "  - %s: %s\n" "$skill" "${skills[$skill]}"
	done
	IFS=$' \t\n' # Restore IFS
	read -r -p "Press Enter to return to main menu."
}

# Function for working (simplified logic)
work_job() {
	local job_type="$1"
	local earnings
	local min_earnings max_earnings
	local driving_skill=$((skills["driving"] * 5)) #Example of using skills

	case "$location" in
		"Los Santos") min_earnings=20; max_earnings=$((60 + driving_skill));;
		"San Fierro") min_earnings=25; max_earnings=$((70 + driving_skill));;
		"Las Venturas") min_earnings=30; max_earnings=$((90 + driving_skill));;
		"Vice City") min_earnings=15; max_earnings=$((50 + driving_skill));;
		"Liberty City") min_earnings=35; max_earnings=$((100 + driving_skill));;
		*) min_earnings=10; max_earnings=$((40 + driving_skill));; # Default values
	esac

	case "$job_type" in
		"taxi")
			earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings))
			play_sfx_mpg "taxi"
			working_animation
			;;
		"delivery")
			earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings + 10))
			play_sfx_mpg "taxi"
			working_animation
			;;
		"mechanic")
			earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings + 20))
			play_sfx_mpg "mechanic"
			working_animation
			;;
		"security")
			earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings + 30))
			play_sfx_mpg "security"
			working_animation
			;;
		"performer")
			earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings - 20))
			play_sfx_mpg "street_performer"
			working_animation
			;;
		*) echo "Invalid Job"; return;;
	esac

	echo "You are working as a $job_type driver in $location..."
	read -r -p "Press Enter to continue..."

	cash=$((cash + earnings))
	clear_screen
	printf "You earned %d dollars. You now have %d dollars.\n" "$earnings" "$cash"
	read -r -p "Press Enter to continue..."
}

# Function for street racing (separate function)
street_race() {
	working_animation
	echo "You are participating in a street race in $location..."
	read -r -p "Press Enter to continue..."
	local winnings
	local damage
	local driving_skill=$((skills["driving"] * 5))
	local win_chance=$((50 + driving_skill)) # Influence win chance

	if (( RANDOM % 100 < win_chance )); then
		winnings=$((RANDOM % 201 + 100))
		cash=$((cash + winnings))
		damage=$((RANDOM % 21 + 10))
		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Your body armor reduced the damage!"
			body_armor_equipped=false
		fi
		health=$((health - damage))
		check_health
		clear_screen
		printf "You won the street race and got %d dollars, but lost %d%% health. You now have %d dollars and %d%% health.\n" "$winnings" "$damage" "$cash" "$health"
		play_sfx_mpg "win" # Play a winning sound
		read -r -p "Press Enter to continue..."
	else
		damage=$((RANDOM % 41 + 20))
		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Your body armor reduced the damage!"
			body_armor_equipped=false
		fi
		health=$((health - damage))
		check_health
		clear_screen
		printf "You lost the street race and took %d%% damage. You now have %d%% health.\n" "$damage" "$health"
		play_sfx_mpg "lose" # Play a losing sound
		read -r -p "Press Enter to continue..."
	fi
}

# Function to use guns for jobs - currently not used in jobs, but kept for potential future use.
use_guns() {
	if [[ " ${guns[*]} " == *" $1 "* ]]; then
		echo "You used your $1 for this job."
		play_sfx_mpg "gun_shot"
		read -r -p "Press Enter to continue..."
	else
		echo "You don't have a $1. Job failed."
		read -r -p "Press Enter to continue..."
	fi
}


# Helper function to handle gun selection and apply bonus
# Usage: local final_chance=$(apply_gun_bonus <base_success_chance> <skill_type_message>)
# Returns the *modified* success chance
apply_gun_bonus() {
    local base_chance=$1
    local action_message=$2 # e.g., "robbery", "heist", "gang war", "carjacking"
    local current_chance=$base_chance
    local gun_bonus=0
    local chosen_gun=""
    local gun_found=false

    if (( ${#guns[@]} > 0 )); then
        echo "You have guns: ${guns[*]}"
        read -r -p "Do you want to use a gun for this $action_message? (y/n): " use_gun

        if [[ "$use_gun" == "y" || "$use_gun" == "Y" ]]; then
            read -r -p "Which gun do you want to use? (Enter the exact name): " chosen_gun

            # Check if the player owns the chosen gun
            for gun in "${guns[@]}"; do
                if [[ "$gun" == "$chosen_gun" ]]; then
                    gun_found=true
                    break
                fi
            done

            if $gun_found; then
                echo "You draw your $chosen_gun!"
                play_sfx_mpg "gun_cock" # Or a relevant sound

                # Apply Gun Bonus
                if [[ -v "gun_attributes[$chosen_gun]" ]]; then
                    eval "${gun_attributes[$chosen_gun]}" # Sets success_bonus variable locally
                    gun_bonus=${success_bonus:-0} # Use the bonus, default to 0 if unset
                    if (( gun_bonus > 0 )); then
                        echo "The $chosen_gun gives you a +${gun_bonus}% success chance."
                        play_sfx_mpg "gun_shot" # Play sound effect for using it
                    else
                        echo "The $chosen_gun doesn't provide a success bonus for this action."
                    fi
                else
                    echo "Warning: No attributes defined for $chosen_gun in gun_attributes array."
                    gun_bonus=0
                fi
            else
                echo "You don't have '$chosen_gun'! Proceeding without a gun bonus."
                gun_bonus=0 # No bonus if they don't own the typed gun
            fi
        else
            echo "Proceeding without using a gun."
            gun_bonus=0 # No bonus if they choose not to use one
        fi
    else
        echo "You don't have any guns! This might be harder."
        gun_bonus=0 # No bonus if they have no guns
        # Optionally add a penalty here if desired: gun_bonus=-10
    fi

    current_chance=$((current_chance + gun_bonus))

    # Optional: Clamp the success chance between reasonable limits (e.g., 5% to 95%)
    (( current_chance < 5 )) && current_chance=5
    (( current_chance > 95 )) && current_chance=95

    echo "$current_chance" # Return the final calculated chance
}

# Function for visiting the hospital
visit_hospital() {
	local hospital_choice
	clear_screen
	echo "Hospital Services:"
	echo "1. Basic Treatment (50$) - Full heal"
	echo "2. Advanced Treatment (100$) - Full heal + 10% health boost"
	echo "3. Buy Health Pack (30$) - Heal 25% health"
	echo "4. Buy Body Armor (75$) - Reduce damage by 50% in next encounter"
	echo "5. Back to main menu"
	read -r -p "Enter your choice (number): " hospital_choice

	[[ ! "$hospital_choice" =~ ^[0-9]+$ ]] && {
		echo "Invalid input. Please enter a number from the menu."
		read -r -p "Press Enter to continue..."
		return
	}

	case "$hospital_choice" in
		1) buy_hospital_item 50 "basic_treatment";;
		2) buy_hospital_item 100 "advanced_treatment";;
		3) buy_hospital_item 30 "health_pack";;
		4) buy_hospital_item 75 "body_armor";;
		5) clear_screen;;
		*) echo "Invalid choice.";;
	esac
}

# Helper function for buying hospital items
buy_hospital_item() {
	local item_cost="$1"
	local item_type="$2"

	if (( cash >= item_cost )); then
		cash=$((cash - item_cost))
		case "$item_type" in
			"basic_treatment")
				health=100
				echo "You received basic treatment and are fully healed."
				play_sfx_mpg "heal" # Play a healing sound
				read -r -p "Press Enter to continue..."
				;;
			"advanced_treatment")
				health=$((health + 10))
				(( health > 100 )) && health=100
				echo "You received advanced treatment and are fully healed with a health boost."
				play_sfx_mpg "heal" # Play a healing sound
				read -r -p "Press Enter to continue..."
				;;
			"health_pack")
				items+=("Health Pack")
				echo "You bought a Health Pack."
				play_sfx_mpg "item_buy" # Play an item buying sound
				read -r -p "Press Enter to continue..."
				;;
			"body_armor")
				body_armor_equipped=true
				echo "You bought Body Armor."
				play_sfx_mpg "item_buy" # Play an item buying sound
				read -r -p "Press Enter to continue..."
				;;
		esac
	else
		echo "Not enough cash for $item_type."
		read -r -p "Press Enter to continue..."
	fi
}

# Function for robbing a store
rob_store() {
    robbing_animation # Assume this exists from plugins
    echo "Attempting to rob a store in $location..."

    local base_stealth_chance=$((skills["stealth"] * 5)) # Base chance from skill
    local final_success_chance=$(apply_gun_bonus "$base_stealth_chance" "robbery") # Get chance after gun logic

    echo "Calculating odds... Your final success chance: ${final_success_chance}%"
    read -r -p "Press Enter to proceed with the robbery..."

    local loot damage fine
    if (( RANDOM % 100 < final_success_chance )); then
        # Success
        loot=$((RANDOM % 201 + 100)) # Random loot between 100 and 300
        cash=$((cash + loot))
        damage=$((RANDOM % 21 + 5)) # Less damage on success: 5-25%

        if $body_armor_equipped; then
            damage=$((damage / 2))
            echo "Your body armor absorbed some of the struggle!"
            body_armor_equipped=false # Armor is used up
        fi

        health=$((health - damage))
        check_health # Check if player survived the damage

        clear_screen
        printf "Success! You robbed the store and grabbed %d dollars.\nYou got slightly injured (-%d%% health).\n" "$loot" "$damage"
        printf "You now have %d dollars and %d%% health.\n" "$cash" "$health"
        play_sfx_mpg "cash_register"
        # Increase stealth skill slightly on success?
        # skills["stealth"]=$((skills["stealth"] + 1))
        # echo "Your stealth skill increased!"
        read -r -p "Press Enter to continue..."
    else
        # Failure
        fine=$((RANDOM % 101 + 50)) # Fine between 50 and 150
        cash=$((cash - fine))
        (( cash < 0 )) && cash=0 # Don't go into negative cash
        damage=$((RANDOM % 31 + 15)) # More damage on failure: 15-45%

         if $body_armor_equipped; then
            damage=$((damage / 2))
            echo "Your body armor protected you during the capture!"
            body_armor_equipped=false # Armor is used up
        fi
        health=$((health - damage))
        check_health # Check if player survived the damage

        clear_screen
        printf "Failed! You got caught trying to rob the store.\nYou were fined %d dollars and took %d%% damage.\n" "$fine" "$damage"
        printf "You now have %d dollars and %d%% health.\n" "$cash" "$health"
        play_sfx_mpg "police_siren" # Or a "lose" sound
        read -r -p "Press Enter to continue..."
    fi
}
# Function for participating in a heist
heist() {
	heist_animation
	echo "Planning a heist in $location..."

	local stealth_skill=$((skills["stealth"] * 5)) # Base stealth skill
	local gun_bonus=0 # Initialize gun bonus

	if (( ${#guns[@]} > 0 )); then
		echo "Do you want to use a gun? (y/n)"
		read -r use_gun

		if [[ "$use_gun" == "y" || "$use_gun" == "Y" ]]; then
			echo "Which gun do you want to use? (Enter the gun name)"
			echo "Available guns: ${guns[*]}"
			read -r chosen_gun
			# Check if the player has that gun
			gun_found=false
			for gun in "${guns[@]}"; do
				if [[ "$gun" == "$chosen_gun" ]]; then
					gun_found=true
					break
				fi
			done

			if $gun_found; then
				echo "You used the $chosen_gun!"
				play_sfx_mpg "gun_shot"  # Play a gunshot sound

				# --- Gun Bonus Logic ---
				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}"
					gun_bonus=$success_bonus
					stealth_skill=$((stealth_skill + gun_bonus))
					echo "The $chosen_gun gives you a +${gun_bonus}% success chance."
				else
					echo "No attributes defined for $chosen_gun (This is a script error)."
				fi
				# --- End Gun Bonus Logic ---

			else
				echo "You don't have that gun!"
			fi
		else
			echo "Proceeding without a gun."
		fi
	else
		echo "You don't have any guns!"
	fi

	read -r -p "Press Enter to continue..."

	local loot
	local damage
	local fine
	if (( RANDOM % 100 < stealth_skill )); then
		loot=$((RANDOM % 501 + 200))
		cash=$((cash + loot))

		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Your body armor reduced the damage!"
			body_armor_equipped=false
		fi

		damage=$((RANDOM % 51 + 20))
		health=$((health - damage))
		check_health
		clear_screen
		printf "The heist was successful! You got %d dollars, but lost %d%% health. You now have %d dollars and %d%% health.\n" "$loot" "$damage" "$cash" "$health"
		read -r -p "Press Enter to continue..."
	else
		fine=$((RANDOM % 101 + 50))
		cash=$((cash - fine))

		clear_screen
		printf "The heist failed and you got caught, losing %d dollars. You now have %d dollars.\n" "$fine" "$cash"
		play_sfx_mpg "lose"  # Play a losing sound
		read -r -p "Press Enter to continue..."
	fi
}

# Function for gang wars
gang_war() {
	# Check if the player has any guns
	if (( ${#guns[@]} == 0 )); then
		echo "You can't start a gang war without a gun!"
		read -r -p "Press Enter to continue..."
		return
	fi

	gang_war_animation
	echo "Starting a gang war in $location..."

	local strength_skill=$((skills["strength"] * 5)) # Base strength skill
	local gun_bonus=0 # Initialize gun bonus

	if (( ${#guns[@]} > 0 )); then
		echo "Do you want to use a gun? (y/n)"
		read -r use_gun

		if [[ "$use_gun" == "y" || "$use_gun" == "Y" ]]; then
			echo "Which gun do you want to use? (Enter the gun name)"
			echo "Available guns: ${guns[*]}"
			read -r chosen_gun

			# Check if the player has that gun
			gun_found=false
			for gun in "${guns[@]}"; do
				if [[ "$gun" == "$chosen_gun" ]]; then
					gun_found=true
					break
				fi
			done

			if $gun_found; then
				echo "You used the $chosen_gun!"
				play_sfx_mpg "gun_shot"  # Play a gunshot sound

				# --- Gun Bonus Logic ---
				if [[ -v "gun_attributes[$chosen_gun]" ]]; then
					eval "${gun_attributes[$chosen_gun]}"
					gun_bonus=$success_bonus
					strength_skill=$((strength_skill + gun_bonus)) # Use strength_skill here
					echo "The $chosen_gun gives you a +${gun_bonus}% success chance."
				else
					echo "No attributes defined for $chosen_gun (This is a script error)."
				fi
				# --- End Gun Bonus Logic ---

			else
				echo "You don't have that gun!"
			fi
		else
			echo "Proceeding without a gun."
		fi
	else
		echo "You don't have any guns!"
	fi

	read -r -p "Press Enter to continue..."

	local loot
	local damage
	local fine

	if (( RANDOM % 100 < strength_skill )); then
		loot=$((RANDOM % 301 + 100))
		cash=$((cash + loot))

		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Your body armor reduced the damage!"
			body_armor_equipped=false
		fi

		damage=$((RANDOM % 51 + 30))
		health=$((health - damage))
		check_health
		clear_screen
		printf "You won the gang war and got %d dollars, but lost %d%% health. You now have %d dollars and %d%% health.\n" "$loot" "$damage" "$cash" "$health"
		play_sfx_mpg "win" # Play a gang war sound
		read -r -p "Press Enter to continue..."
	else
		fine=$((RANDOM % 151 + 50))
		cash=$((cash - fine))
		damage=$((RANDOM % 41 + 20))

		if $body_armor_equipped; then
			damage=$((damage / 2))
			echo "Your body armor reduced the damage!"
			body_armor_equipped=false
		fi

		health=$((health - damage))
		check_health
		clear_screen
		printf "You lost the gang war, got fined %d dollars, and lost %d%% health. You now have %d dollars and %d%% health.\n" "$fine" "$damage" "$cash" "$health"
		play_sfx_mpg "lose"  # Play a losing sound
		read -r -p "Press Enter to continue..."
	fi
}

# Function for carjacking
carjack() {
    # Calculate base skills relevant to carjacking
    local driving_skill_bonus=$((skills["driving"] * 3)) # Driving helps escape/control
    local stealth_skill_bonus=$((skills["stealth"] * 3)) # Stealth helps approach
    local base_success_chance=$(( 20 + driving_skill_bonus + stealth_skill_bonus )) # Base 20% + skills

    # Call the helper function to potentially add gun bonus
    local final_success_chance=$(apply_gun_bonus "$base_success_chance" "carjacking")

    # Start the animation and prompt after calculating chance
    carjacking_animation # Assume this exists from plugins
    echo "Attempting to carjack a vehicle in $location..."
    echo "Calculating odds... Your final success chance: ${final_success_chance}%"
    read -r -p "Press Enter to make your move..."

    local loot damage fine

    if (( RANDOM % 100 < final_success_chance )); then
        # Success
        loot=$((RANDOM % 151 + 50)) # Car value: 50 - 200
        cash=$((cash + loot))
        damage=$((RANDOM % 21 + 5)) # Minor damage: 5-25%

        if $body_armor_equipped; then
            damage=$((damage / 2))
            echo "Your body armor absorbed some impact during the getaway!"
            body_armor_equipped=false
        fi
        health=$((health - damage))
        check_health

        clear_screen
        printf "Success! You hotwired the vehicle and sold it for %d dollars.\nGot slightly banged up (-%d%% health).\n" "$loot" "$damage"
        printf "You now have %d dollars and %d%% health.\n" "$cash" "$health"
        play_sfx_mpg "car_start"
        # Increase driving/stealth skill?
        read -r -p "Press Enter to continue..."
    else
        # Failure
        fine=$((RANDOM % 76 + 25)) # Fine 25-100
        cash=$((cash - fine))
        (( cash < 0 )) && cash=0
        damage=$((RANDOM % 31 + 10)) # Failure damage: 10-40%

        if $body_armor_equipped; then
            damage=$((damage / 2))
            echo "Your body armor took the brunt of the failed attempt!"
            body_armor_equipped=false
        fi
        health=$((health - damage))
        check_health

        clear_screen
        printf "Failed! The car alarm blared, and you got caught.\nYou were fined %d dollars and took %d%% damage.\n" "$fine" "$damage"
        printf "You now have %d dollars and %d%% health.\n" "$cash" "$health"
        play_sfx_mpg "police_siren" # Or "lose"
        read -r -p "Press Enter to continue..."
    fi
}
# Function to handle hospital visit after death
hospitalize_player() {
	clear_screen
	echo "You have been hospitalized and are being treated..."
	read -r -p "Press Enter to continue..."
	health=100
	clear_screen
	echo "You are fully healed but lost $200 for the treatment."
	cash=$((cash - 200))
	(( cash < 0 )) && cash=0
	read -r -p "Press Enter to continue..."
	clear_screen
}

# Function to hire a hooker
hire_hooker() {
	echo "You are looking for a hooker in $location..."
	read -r -p "Press Enter to continue..."
	local hooker_cost
	local health_gain
	local charisma_skill=$(( skills["charisma"] * 2 ))  # Influence price
	# Ensure charisma_skill is within a reasonable range
	(( charisma_skill > 99 )) && charisma_skill=99
	# Ensure RANDOM range is positive
	local min_cost=$(( 50 - charisma_skill ))
	local max_cost=$(( 101 - charisma_skill ))
	(( min_cost < 1 )) && min_cost=1
	(( max_cost <= min_cost )) && max_cost=$(( min_cost + 10 ))  # Ensure valid range
	hooker_cost=$(( RANDOM % (max_cost - min_cost + 1) + min_cost ))
	# Ensure a minimum cost
	(( hooker_cost < 10 )) && hooker_cost=10
	health_gain=$(( RANDOM % 21 + 10 ))
	if (( cash >= hooker_cost )); then
	cash=$(( cash - hooker_cost ))
	health=$(( health + health_gain ))
	(( health > 100 )) && health=100
	clear_screen
	printf "You hired a hooker for %d dollars and gained %d%% health.\nYou now have %d dollars and %d%% health.\n" \
	"$hooker_cost" "$health_gain" "$cash" "$health"
	play_sfx_mpg "hooker"  # Play a hooker sound
	read -r -p "Press Enter to continue..."
else
	clear_screen
	echo "Not enough cash to hire a hooker."
	read -r -p "Press Enter to continue..."
	fi

clear_screen
}


# Centralized Drug Transaction Function
drug_transaction() {
	local action="$1" # "buy" or "sell"
	local drug_name="$2"
	local drug_price="$3"
	local drug_amount="$4"
	local cost income selling_price
	local drug_dealer_skill=$((skills["drug_dealer"]))

	if [[ "$action" == "buy" ]]; then
		cost=$((drug_price * drug_amount))
		if (( cash >= cost )); then
			drug_transaction_animation
			cash=$((cash - cost))
			drugs["$drug_name"]=$((drugs["$drug_name"] + drug_amount))
			printf "You bought %s units of %s.\n" "$drug_amount" "$drug_name"
			play_sfx_mpg "cash_register"
			return 0
		else
			echo "Not enough cash to buy $drug_name."
			return 1
		fi
	elif [[ "$action" == "sell" ]]; then
		if [[ -v "drugs[$drug_name]" ]] && (( drugs["$drug_name"] >= drug_amount )); then
			drug_transaction_animation

			# Adjust selling price based on skill
			local price_modifier=$((drug_dealer_skill * 2)) # Example: 2% increase per skill point
			local adjusted_price=$((drug_price + (drug_price * price_modifier / 100)))

			income=$((adjusted_price * drug_amount))
			cash=$((cash + income))
			drugs["$drug_name"]=$((drugs["$drug_name"] - drug_amount))

			printf "You sold %s units of %s for %d dollars (adjusted for your drug dealing skill).\n" "$drug_amount" "$drug_name" "$income"
			play_sfx_mpg "cash_register"
			# Increase drug dealer skill
			skills["drug_dealer"]=$((drug_dealer_skill + 1)) # Simple increase
			echo "Your drug dealing skill has increased!"
			return 0
		else
			echo "Not enough $drug_name to sell."
			return 1
		fi
	else
		echo "Invalid action: $action"
		return 1
	fi

}

buy_drugs() {
	local drug_choice drug_amount

	clear_screen
	echo "Drug Dealer - Choose a drug to buy:"
	echo "1. Weed (10$/unit)"
	echo "2. Cocaine (50$/unit)"
	echo "3. Heroin (100$/unit)"
	echo "4. Meth (75$/unit)"
	echo "5. Back to main menu"
	read -r -p "Enter your choice (number): " drug_choice

	[[ ! "$drug_choice" =~ ^[0-9]+$ ]] && {
		echo "Invalid input. Please enter a number from the menu."
		read -r -p "Press Enter to continue..."
		return
	}
	read -r -p "Enter the amount you want to buy: " drug_amount
	[[ ! "$drug_amount" =~ ^[0-9]+$ ]] && {
		echo "Invalid input. Please enter a number."
		read -r -p "Press Enter to continue..."
		return
	}
	case "$drug_choice" in
		1) drug_transaction "buy" "Weed" 10 "$drug_amount";;
		2) drug_transaction "buy" "Cocaine" 50 "$drug_amount";;
		3) drug_transaction "buy" "Heroin" 100 "$drug_amount";;
		4) drug_transaction "buy" "Meth" 75 "$drug_amount";;
		5) clear_screen; return;;
		*) echo "Invalid choice."; return;;
	esac
	read -r -p "Press Enter to continue..."
}

sell_drugs() {
	local drug_choice drug_amount
	clear_screen
	echo "Drug Dealer - Choose a drug to sell:"
	echo "1. Weed"
	echo "2. Cocaine"
	echo "3. Heroin"
	echo "4. Meth"
	echo "5. Back to main menu"
	read -r -p "Enter your choice (number): " drug_choice
	[[ ! "$drug_choice" =~ ^[0-9]+$ ]] && {
		echo "Invalid input. Please enter a number from the menu."
		read -r -p "Press Enter to continue..."
		return
	}
	read -r -p "Enter the amount you want to sell: " drug_amount
	[[ ! "$drug_amount" =~ ^[0-9]+$ ]] && {
		echo "Invalid input. Please enter a number."
		read -r -p "Press Enter to continue..."
		return
	}
	case "$drug_choice" in
		1) drug_transaction "sell" "Weed" 15 "$drug_amount";;
		2) drug_transaction "sell" "Cocaine" 75 "$drug_amount";;
		3) drug_transaction "sell" "Heroin" 150 "$drug_amount";;
		4) drug_transaction "sell" "Meth" 100 "$drug_amount";;
		5) clear_screen; return;;
		*) echo "Invalid choice."; return;;
	esac
	read -r -p "Press Enter to continue..."
}

# --- Global Music PID (Ensure this is declared globally, near the top) ---
music_pid=""

# Function to play music
play_music() {
    # 1. Check Prerequisite: mpg123 command
    if ! command -v mpg123 &> /dev/null; then
        echo "###########################################################"
        echo "# Error: 'mpg123' command not found.                    #"
        echo "# Music playback requires mpg123. Install it first.       #"
        echo "###########################################################"
        read -r -p "Press Enter to return..."
        return 1
    fi

    # 2. Define Music Directory and Find Files
    local music_dir="$BASEDIR/music"
    local music_files=()
    local original_ifs="$IFS" # Save IFS

    # --- Debugging ---
    # echo "[Debug] Music directory: $music_dir"
    # --- End Debugging ---

    if [[ ! -d "$music_dir" ]]; then
        echo "Error: Music directory '$music_dir' not found!"
        read -r -p "Press Enter to return..."
        return 1
    fi

    # Use find and process substitution for safer file handling
    while IFS= read -r -d $'\0' file; do
        music_files+=("$file")
    done < <(find "$music_dir" -maxdepth 1 -type f -name "*.mp3" -print0) # Use null delimiter

    IFS="$original_ifs" # Restore IFS

    if (( ${#music_files[@]} == 0 )); then
        echo "No .mp3 files found in the '$music_dir' directory."
        read -r -p "Press Enter to return..."
        return 1
    fi

    # 3. Music Player Loop
    local choice_stop="s"
    local choice_back="b"
    local music_choice

    while true; do
        clear_screen
        echo "--- Music Player ---"
        echo "Location: $music_dir"
        echo "--------------------"

        # Check current status more reliably
        local current_status="Stopped"
        local current_song_name=""
        if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
            # Try to get the filename from the process command line (may be imperfect)
            current_song_name=$(ps -p "$music_pid" -o args= | sed 's/.*mpg123 [-q]* //; s/ *$//')
            if [[ -z "$current_song_name" ]]; then
                 current_song_name="Unknown Track"
            fi
            current_status="Playing: $(basename "$current_song_name") (PID: $music_pid)"
        else
            # If PID exists but process doesn't, clear the PID
            if [[ -n "$music_pid" ]]; then
                # echo "[Debug] Process $music_pid seems to have ended. Clearing PID."
                music_pid=""
            fi
            current_status="Stopped"
        fi
        echo "Status: $current_status"
        echo "--------------------"

        # Display Track List
        echo "Available Tracks:"
        for i in "${!music_files[@]}"; do
            printf "%d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"
        done
        echo "--------------------"
        printf "[%s] Stop Current Track\n" "$choice_stop"
        printf "[%s] Back to Main Menu\n" "$choice_back"
        echo "--------------------"
        read -r -p "Enter choice (number, s, b): " music_choice

        # Handle Choices
        case "$music_choice" in
            "$choice_stop")
                if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
                    echo "Stopping music (PID: $music_pid)..."
                    kill "$music_pid"
                    # Give it a moment, then check if it stopped
                    sleep 0.5
                    if kill -0 "$music_pid" 2>/dev/null; then
                         echo "Process didn't stop immediately, trying harder..."
                         kill -9 "$music_pid" 2>/dev/null # Force kill if necessary
                    fi
                    wait "$music_pid" 2>/dev/null # Clean up zombie process if any
                    music_pid="" # Clear the PID
                    echo "Music stopped."
                else
                    echo "No music is currently playing."
                fi
                sleep 1
                ;;

            "$choice_back")
                echo "Returning to main menu..."
                # Decide if music should stop on exit
                # if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then kill "$music_pid"; music_pid=""; fi
                clear_screen
                break # Exit the while loop
                ;;

            *)
                # Check if it's a valid number choice
                if [[ "$music_choice" =~ ^[0-9]+$ ]] && (( music_choice >= 1 && music_choice <= ${#music_files[@]} )); then
                    local selected_track_index=$((music_choice - 1))
                    local selected_track="${music_files[$selected_track_index]}"

                    if [[ ! -f "$selected_track" ]]; then
                        echo "Error: File '$selected_track' not found or is not a file!"
                        sleep 2
                        continue # Go back to menu
                    fi

                    # Stop previous track if playing
                    if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
                        echo "Stopping previous track (PID: $music_pid)..."
                        kill "$music_pid"
                        wait "$music_pid" 2>/dev/null
                        music_pid=""
                        sleep 0.2 # Brief pause before starting next
                    fi

                    echo "Attempting to play: $(basename "$selected_track")"

                    # === Play Command - Remove '-q' temporarily for debugging ===
                    # (mpg123 -q "$selected_track" &) # Original quiet version
                    (mpg123 "$selected_track" &) # Verbose version for debugging
                    # ============================================================

                    new_pid=$! # Capture the PID

                    # Verify if the process started successfully
                    sleep 0.5 # Give it a moment to potentially fail
                    if kill -0 "$new_pid" 2>/dev/null; then
                        music_pid=$new_pid # Store the PID only if process is running
                        echo "Playback started (PID: $music_pid)."
                        # Optional: Add the track name to a variable for better display next loop?
                    else
                        echo "Error: Failed to start mpg123 process for the selected track."
                        echo "Check if mpg123 can play the file directly from the command line:"
                        echo "mpg123 \"$selected_track\""
                        music_pid="" # Ensure PID is cleared if start failed
                        sleep 3
                    fi

                else
                    echo "Invalid choice. Please enter a number from the list, '$choice_stop', or '$choice_back'."
                    sleep 2
                fi
                ;;
        esac
    done
}
# Save the game state to a file
save_game() {
	echo "$player_name" > "$SAVE_DIR/player_name.sav"
	echo "$location" > "$SAVE_DIR/location.sav"
	echo "$cash" > "$SAVE_DIR/cash.sav"
	echo "$health" > "$SAVE_DIR/health.sav"
	printf '%s\n' "${guns[@]}" > "$SAVE_DIR/guns.sav"
	printf '%s\n' "${items[@]}" > "$SAVE_DIR/items.sav"
	> "$SAVE_DIR/drugs.sav"
	for key in "${!drugs[@]}"; do
		printf "%s %s\n" "$key" "${drugs[$key]}" >> "$SAVE_DIR/drugs.sav"
	done
	echo "$body_armor_equipped" > "$SAVE_DIR/body_armor_equipped.sav"

	# Save skills
	> "$SAVE_DIR/skills.sav" # Clear the file first
	for key in "${!skills[@]}"; do
		printf "%s %s\n" "$key" "${skills[$key]}" >> "$SAVE_DIR/skills.sav"
	done

	echo "Game saved successfully."
	read -r -p "Press Enter to continue..."
}

# Load the game state from a file
load_game() {
	local IFS=$'\n'
	if [[ -f "$SAVE_DIR/player_name.sav" && -f "$SAVE_DIR/location.sav" && -f "$SAVE_DIR/cash.sav" && -f "$SAVE_DIR/health.sav" && -f "$SAVE_DIR/guns.sav" && -f "$SAVE_DIR/items.sav" && -f "$SAVE_DIR/body_armor_equipped.sav" && -f "$SAVE_DIR/skills.sav" ]]; then
		read -r player_name < "$SAVE_DIR/player_name.sav"
		read -r location < "$SAVE_DIR/location.sav"
		read -r cash < "$SAVE_DIR/cash.sav"
		read -r health < "$SAVE_DIR/health.sav"
		read -r -a guns < "$SAVE_DIR/guns.sav"
		read -r -a items < "$SAVE_DIR/items.sav"
		read -r body_armor_equipped < "$SAVE_DIR/body_armor_equipped.sav"
		declare -A drugs
		while IFS=$'\n' read -r line; do
			if [[ -n "$line" ]]; then
				IFS=$' ' read -r key value <<< "$line"
				drugs["$key"]="$value"
			fi
		done < "$SAVE_DIR/drugs.sav"

		# Load skills
		declare -A skills
		while IFS=$'\n' read -r line; do
			if [[ -n "$line" ]]; then
				IFS=$' ' read -r key value <<< "$line"
				skills["$key"]="$value"
			fi
		done < "$SAVE_DIR/skills.sav"

		echo "Game loaded successfully."
		read -r -p "Press Enter to continue..."
		IFS=$' \t\n' # Restore IFS
		return 0 # Indicate successful load
	else
		echo "No saved game found."
		read -r -p "Press Enter to continue..."
		IFS=$' \t\n' # Restore IFS
		return 1 # Indicate load failure
	fi
}

# --- 4. Game Initialization and Loop ---

# Function to initialize game variables
Game_variables() {
	clear_screen
	read -r -p "Enter your player name: " player_name
	play_sfx_mpg "new_game" # Play a New Game sound
	location="Los Santos"
	cash=500
	health=100
	guns=()
	items=()
	declare -A drugs
	drugs=( ["Weed"]=0 ["Cocaine"]=0 ["Heroin"]=0 ["Meth"]=0 )
	# Initialize skills
	declare -A skills
	skills=( ["driving"]=1 ["strength"]=1 ["charisma"]=1 ["stealth"]=1 ["drug_dealer"]=1 )
	clear_screen
}

# Function to remove save files
remove_save_files() {
	rm -f "$SAVE_DIR/player_name.sav"
	rm -f "$SAVE_DIR/location.sav"
	rm -f "$SAVE_DIR/cash.sav"
	rm -f "$SAVE_DIR/health.sav"
	rm -f "$SAVE_DIR/guns.sav"
	rm -f "$SAVE_DIR/items.sav"
	rm -f "$SAVE_DIR/drugs.sav"
	rm -f "$SAVE_DIR/body_armor_equipped.sav"
	rm -f "$SAVE_DIR/skills.sav" # Remove skills save file

	if [[ ! -d "$SAVE_DIR" ]]; then
		echo "No saved game found."
	else
		echo "Old save deleted!"
	fi
}

# Initial game menu
while true; do
	clear_screen
	echo "Welcome to Bash Theft Auto"
	echo "Choose an option:"
	echo "1. New Game"
	echo "2. Load Game"
	echo "3. Exit Game"
	read -r -p "Enter your choice: " initial_choice
	[[ ! "$initial_choice" =~ ^[0-9]+$ ]] && {
		echo "Invalid input. Please enter a number."
		sleep 2
		continue
	}
	case "$initial_choice" in
		1) remove_save_files; Game_variables; break;;
		2) if [[ -d "$SAVE_DIR" ]] && load_game; then break; else continue; fi;;
		3) exit;;
		*) echo "Invalid choice.";;
	esac
done

while true; do
clear_screen
echo "Choose an action:"
echo "1. Travel to another State"
echo "2. Buy guns"
echo "3. Show inventory"
echo "4. Work (earn money)"
echo "5. Work (criminal activity)"
echo "6. Buy drugs"
echo "7. Sell drugs"
echo "8. Hire hooker"
echo "9. Visit hospital"
echo "10. Exit Game"
echo "11. Save Game"
echo "12. Load Game"
echo "13. Play music"
echo "14. About"
read -r -p "Enter your choice: " choice
[[ ! "$choice" =~ ^[0-9]+$ ]] && {
	echo "Invalid input. Please enter a number."
	sleep 2
	continue
}
case "$choice" in
	1) clear
	echo "Choose a State to travel to:"
	echo "1. Los Santos (50$)"
	echo "2. San Fierro (75$)"
	echo "3. Las Venturas (100$)"
	echo "4. Vice City (150$)"
	echo "5. Liberty City (200$)"
	echo "6. Back to main menu"
	read -r -p "Enter your choice: " city_choice
	[[ ! "$city_choice" =~ ^[0-9]+$ ]] && {
		echo "Invalid input. Please enter a number."
		sleep 2
		continue
	}
	case "$city_choice" in
		1) travel_to 50 "Los Santos";;
		2) travel_to 75 "San Fierro";;
		3) travel_to 100 "Las Venturas";;
		4) travel_to 150 "Vice City";;
		5) travel_to 200 "Liberty City";;
		6) clear_screen;;
		*) echo "Invalid choice.";;
	esac;;
	2) buy_guns;;
	3) show_inventory;;
	4) clear
	echo "Choose a job:"
	echo "1. Taxi Driver"
	echo "2. Delivery Driver"
	echo "3. Mechanic"
	echo "4. Security Guard"
	echo "5. Street Performer"
	echo "6. Back to main menu"
	read -r -p "Enter your choice: " job_choice
	[[ ! "$job_choice" =~ ^[0-9]+$ ]] && {
		echo "Invalid input. Please enter a number."
		sleep 2
		continue
	}
	case "$job_choice" in
		1) work_job "taxi";;
		2) work_job "delivery";;
		3) work_job "mechanic";;
		4) work_job "security";;
		5) work_job "performer";;
		6) clear_screen;;
		*) echo "Invalid choice.";;
	esac;;
	5) clear
	echo "Choose a criminal activity:"
	echo "1. Heist"
	echo "2. Gang war"
	echo "3. Carjack"
	echo "4. Rob a store"
    echo "5. Street Racing"
	echo "6. Back to main menu"
	read -r -p "Enter your choice: " criminal_choice
	[[ ! "$criminal_choice" =~ ^[0-9]+$ ]] && {
		echo "Invalid input. Please enter a number."
		sleep 2
		continue
	}
	case "$criminal_choice" in
		1) heist;;
		2) gang_war;;
		3) carjack;;
		4) rob_store;;
		5) street_race;;
		6) clear_screen;;
		*) echo "Invalid choice.";;
	esac;;
	6) buy_drugs;;
	7) sell_drugs;;
	8) hire_hooker;;
	9) visit_hospital;;
	10) exit;;
	11) save_game;;
	12) load_game;;
	13) play_music;;
	14) about_music_sfx;;
	*) echo "Invalid choice.";;
	esac
done
