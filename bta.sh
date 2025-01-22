#!/bin/bash

# --- 0. Global Variables ---
	player_name=""
	location=""
	cash=0
	health=0
	declare -a guns
	declare -a items
	declare -A drugs
	body_armor_equipped=false

# --- 1. Plugin Loading ---
	plugin_dir="plugins"

	if [[ -d "$plugin_dir" ]]; then
		while IFS= read -r -d $'\0' plugin; do
			[[ -f "$plugin" ]] && source "$plugin"
		done < <(find "$plugin_dir" -maxdepth 1 -name "*.sh" -print0)
	else
		echo "Warning: Plugin directory '$plugin_dir' not found."
	fi

# --- 2. Loading Animation ---
	start_loading_animation

# --- 3. Functions ---

# Function to clear the screen and display game info
	clear_screen() {
		clear
		printf "\e[1;34m-----------------------------------------\e[0m\n"
		printf "\e[1;43m|        Bash theaft auto               |\e[0m\n"
		printf "\e[1;34m-----------------------------------------\e[0m\n"
		printf "Player: %s   Location: %s\n" "$player_name" "$location"
		printf "Cash: %d dollars      Health: %d%%\n" "$cash" "$health"
		printf "\e[1;34m-----------------------------------------\e[0m\n"
		printf "\e[1;44m|        made by stuffbymax             |\e[0m\n"
		printf "\e[1;34m-----------------------------------------\e[0m\n"
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
			cash=$((cash - travel_cost))
			read -r -p "Press Enter to continue..."
			location="$new_location"
			clear_screen
			echo "You have arrived at $location."
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
		echo "5. Back to main menu"
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
			5) clear_screen;;
			*) echo "Invalid choice.";;
		esac
	}

# Helper function for buying items
	buy_item() {
		local item_name="$1"
		local item_cost="$2"

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
		echo "Guns: ${guns[*]}"
		echo "Items: ${items[*]}"
		echo "Drugs: "
		for drug in "${!drugs[@]}"; do
			printf "  - %s: %s\n" "$drug" "${drugs[$drug]}"
		done
		read -r -p "Press Enter to return to main menu."
	}

# Function for working (simplified logic)
	work_job() {
		local job_type="$1"
		local earnings
		local min_earnings max_earnings

		case "$location" in
			"Los Santos") min_earnings=20; max_earnings=60;;
			"San Fierro") min_earnings=25; max_earnings=70;;
			"Las Venturas") min_earnings=30; max_earnings=90;;
			"Vice City") min_earnings=15; max_earnings=50;;
			"Liberty City") min_earnings=35; max_earnings=100;;
			*) min_earnings=10; max_earnings=40;; # Default values
		esac

		case "$job_type" in
			"taxi")
			   earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings))
			   ;;
			"delivery")
				 earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings + 10))
			   ;;
			"mechanic")
			   earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings + 20))
			   ;;
			"security")
			   earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings + 30))
			   ;;
			"performer")
			  earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings - 20))
			   ;;
			"race") # Different logic for race
				work_race
				return;
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
	work_race() {
		echo "You are participating in a street race in $location..."
		read -r -p "Press Enter to continue..."
		local winnings
		local damage

		if (( RANDOM % 2 == 0 )); then
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
			read -r -p "Press Enter to continue..."
		fi
	}


# Function to use guns for jobs
	use_guns() {
		if [[ " ${guns[*]} " == *" $1 "* ]]; then
			echo "You used your $1 for this job."
			read -r -p "Press Enter to continue..."
		else
			echo "You don't have a $1. Job failed."
			read -r -p "Press Enter to continue..."
		fi
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
			  read -r -p "Press Enter to continue..."
			  ;;
		  "advanced_treatment")
			   health=$((health + 10))
			   (( health > 100 )) && health=100
			   echo "You received advanced treatment and are fully healed with a health boost."
			   read -r -p "Press Enter to continue..."
			   ;;
		   "health_pack")
			   items+=("Health Pack")
			   echo "You bought a Health Pack."
			   read -r -p "Press Enter to continue..."
			   ;;
		  "body_armor")
			   body_armor_equipped=true
			   echo "You bought Body Armor."
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
		echo "Attempting to rob a store in $location..."
			read -r -p "Press Enter to continue..."
		local loot
		local damage
		local fine

		if (( RANDOM % 2 == 0 )); then
			loot=$((RANDOM % 201 + 100))
			cash=$((cash + loot))
			 if $body_armor_equipped; then
				   damage=$((damage / 2))
				   echo "Your body armor reduced the damage!"
				   body_armor_equipped=false
			   fi
			damage=$((RANDOM % 31 + 10))
			health=$((health - damage))
			check_health
			clear_screen
		   printf "You successfully robbed the store and got %d dollars, but lost %d%% health. You now have %d dollars and %d%% health.\n" "$loot" "$damage" "$cash" "$health"
			 read -r -p "Press Enter to continue..."
		else
			fine=$((RANDOM % 51 + 25))
			cash=$((cash - fine))
			clear_screen
			printf "You got caught and fined %d dollars. You now have %d dollars.\n" "$fine" "$cash"
			  read -r -p "Press Enter to continue..."
		fi
	}

# Function for participating in a heist
	heist() {
		echo "Planning a heist in $location..."
		read -r -p "Press Enter to continue..."
		local loot
		local damage
		local fine

		if (( RANDOM % 3 == 0 )); then
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
			  read -r -p "Press Enter to continue..."
		fi
	}

# Function for gang wars
	gang_war() {
		echo "Starting a gang war in $location..."
			 read -r -p "Press Enter to continue..."
		local loot
		local damage
		local fine

		if (( RANDOM % 3 == 0 )); then
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
			   read -r -p "Press Enter to continue..."
		fi
	}

# Function for carjacking
	carjack() {
		echo "Attempting to carjack a vehicle in $location..."
		   read -r -p "Press Enter to continue..."
		local loot
		local damage
		local fine

		if (( RANDOM % 2 == 0 )); then
			loot=$((RANDOM % 201 + 50))
			cash=$((cash + loot))
			if $body_armor_equipped; then
				   damage=$((damage / 2))
				   echo "Your body armor reduced the damage!"
				   body_armor_equipped=false
			   fi
			damage=$((RANDOM % 21 + 10))
			health=$((health - damage))
			check_health
			clear_screen
			printf "You successfully carjacked a vehicle and got %d dollars, but lost %d%% health. You now have %d dollars and %d%% health.\n" "$loot" "$damage" "$cash" "$health"
			read -r -p "Press Enter to continue..."
		else
			fine=$((RANDOM % 76 + 25))
			cash=$((cash - fine))
			clear_screen
			printf "You got caught and fined %d dollars. You now have %d dollars.\n" "$fine" "$cash"
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
		hooker_cost=$((RANDOM % 101 + 50))
		health_gain=$((RANDOM % 21 + 10))
		if (( cash >= hooker_cost )); then
			cash=$((cash - hooker_cost))
			health=$((health + health_gain))
			(( health > 100 )) && health=100
			clear_screen
		   printf "You hired a hooker for %d dollars and gained %d%% health. You now have %d dollars and %d%% health.\n" "$hooker_cost" "$health_gain" "$cash" "$health"
			 read -r -p "Press Enter to continue..."
		else
			clear_screen
			echo "Not enough cash to hire a hooker."
				read -r -p "Press Enter to continue..."
		fi
		clear_screen
	}

# Function to buy drugs
	buy_drugs() {
		local drug_choice drug_amount cost
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
			1) buy_drug "Weed" 10 "$drug_amount";;
			2) buy_drug "Cocaine" 50 "$drug_amount";;
			3) buy_drug "Heroin" 100 "$drug_amount";;
			4) buy_drug "Meth" 75 "$drug_amount";;
			5) clear_screen;;
			*) echo "Invalid choice.";;
		esac
		clear_screen
	}

# Helper function for buying drugs
	buy_drug() {
		local drug_name="$1"
		local drug_price="$2"
		local drug_amount="$3"
		local cost=$((drug_price * drug_amount))

		if (( cash >= cost )); then
			cash=$((cash - cost))
			drugs["$drug_name"]=$((drugs["$drug_name"] + drug_amount))
		   printf "You bought %s units of %s.\n" "$drug_amount" "$drug_name"
		   read -r -p "Press Enter to continue..."
		else
			echo "Not enough cash to buy $drug_name."
		  read -r -p "Press Enter to continue..."
		fi
	}

# Function to sell drugs
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
			1) sell_drug "Weed" 15 "$drug_amount";;
			2) sell_drug "Cocaine" 75 "$drug_amount";;
			3) sell_drug "Heroin" 150 "$drug_amount";;
			4) sell_drug "Meth" 100 "$drug_amount";;
			5) clear_screen;;
			*) echo "Invalid choice.";;
		esac
		clear_screen
	}

# Helper function for selling drugs
	sell_drug() {
	   local drug_name="$1"
	   local drug_price="$2"
	   local drug_amount="$3"

		if [[ -v "drugs[$drug_name]" ]] && (( drugs["$drug_name"] >= drug_amount )); then
			cash=$((cash + drug_price * drug_amount))
			drugs["$drug_name"]=$((drugs["$drug_name"] - drug_amount))
			 printf "You sold %s units of %s.\n" "$drug_amount" "$drug_name"
			   read -r -p "Press Enter to continue..."
		else
			echo "Not enough $drug_name to sell."
		   read -r -p "Press Enter to continue..."
		fi
	}

# Function to play music
	play_music() {
	  local music_files=(
		"music/platforma.mp3"
		"music/the_loading_screen.mp3"
		"music/doom.mp3"
		"music/Jal.mp3"
	  )
	  
		while true; do
			clear_screen
			echo "Choose a song to play:"
			for i in "${!music_files[@]}"; do
				printf "%d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"
			done
		   echo "press q to Stop Music"
		   printf "%d. Back to Main menu\n" $(( ${#music_files[@]} + 1 ))
			read -r music_choice
			if ! [[ "$music_choice" =~ ^[0-9]+$ ]]; then
				echo "Invalid input. Please enter a number."
				sleep 2
				continue # Go back to music player menu
			fi

			if (( music_choice <= ${#music_files[@]} )); then
				local selected_track="${music_files[$((music_choice - 1))]}"
				if [[ -f "$selected_track" ]]; then
				  echo "Playing: $(basename "$selected_track")"
				   mpg123 -q "$selected_track"
				else
					echo "Error: Music file '$selected_track' not found."
				sleep 2

				fi

			elif (( music_choice == ${#music_files[@]} + 1 )); then
				 pkill mpg123
				clear_screen
				 break  # Exit the music player menu
			 else
				echo "Invalid choice."
				sleep 2
			fi
		done
	}

# Save the game state to a file
	save_game() {
		echo "$player_name" > saves/player_name.sav
		echo "$location" > saves/location.sav
		echo "$cash" > saves/cash.sav
		echo "$health" > saves/health.sav
		printf '%s\n' "${guns[@]}" > saves/guns.sav
		printf '%s\n' "${items[@]}" > saves/items.sav

		> saves/drugs.sav
		for key in "${!drugs[@]}"; do
			printf "%s %s\n" "$key" "${drugs[$key]}" >> saves/drugs.sav
		done
		 echo "$body_armor_equipped" > saves/body_armor_equipped.sav
		echo "Game saved successfully."
		read -r -p "Press Enter to continue..."
	}

# Load the game state from a file
	load_game() {
		if [[ -f saves/player_name.sav && -f saves/location.sav && -f saves/cash.sav && -f saves/health.sav && -f saves/guns.sav && -f saves/items.sav && -f saves/body_armor_equipped.sav ]]; then
			read -r player_name < saves/player_name.sav
			read -r location < saves/location.sav
			read -r cash < saves/cash.sav
			read -r health < saves/health.sav
			read -r -a guns < saves/guns.sav
			read -r -a items < saves/items.sav
			 read -r body_armor_equipped < saves/body_armor_equipped.sav

			declare -A drugs
		   while IFS=$'\n' read -r line; do
				if [[ -n "$line" ]]; then
					IFS=$' ' read -r key value <<< "$line"
					drugs["$key"]="$value"
				fi
			done < saves/drugs.sav

			echo "Game loaded successfully."
			 read -r -p "Press Enter to continue..."
		else
			echo "No saved game found."
			 read -r -p "Press Enter to continue..."
		fi
	}

# --- 4. Game Initialization and Loop ---

# Function to initialize game variables
	Game_variables() {
		clear_screen
		read -r -p "Enter your player name: " player_name
		location="Los Santos"
		cash=500
		health=100
		guns=()
		items=()
		declare -A drugs
		drugs=( ["Weed"]=0 ["Cocaine"]=0 ["Heroin"]=0 ["Meth"]=0 )
		clear_screen
	}

# Start game loop
	Game_variables # Initialize the game

	while true; do
		clear_screen
		echo "Choose an action:"
		echo "1. Travel to another city"
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
		
		read -r -p "Enter your choice: " choice
		[[ ! "$choice" =~ ^[0-9]+$ ]] && {
		   echo "Invalid input. Please enter a number."
		   sleep 2
		   continue 
		}

		case "$choice" in
			1)  clear
				echo "Choose a city to travel to:"
				echo "1. Los Santos (50$)"
				echo "2. San Fierro (75$)"
				echo "3. Las Venturas (100$)"5
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
			4)  clear
				echo "Choose a job:"
				echo "1. Taxi Driver"
				echo "2. Delivery Driver"
				echo "3. Mechanic"
				echo "4. Security Guard"
				echo "5. Street Performer"
				echo "6. Street Racing"
				echo "7. Back to main menu"
				local job_choice
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
					6) work_job "race";;
					7) clear_screen;;
					*) echo "Invalid choice.";;
				esac;;
			5)  clear
				echo "Choose a criminal activity:"
				echo "1. Heist"
				echo "2. Gang war"
				echo "3. Carjack"
				echo "4. Back to main menu"
				local criminal_choice
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
					4) clear_screen;;
					*) echo "Invalid choice.";;
			   esac;;
			6) buy_drugs;;
			7) sell_drugs;;
			8) hire_hooker ;;
			9) visit_hospital;;
			10) exit;;
			11) save_game;;
			12) load_game;;
			13) play_music;;
			*) echo "Invalid choice.";;
		esac
	done
