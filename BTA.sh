#!/bin/bash

# --- 0. Global Variables ---
player_name=""
location=""
cash=0
health=0
declare -a guns
declare -a items
declare -A drugs
declare body_armor_equipped=false

# --- 1. Plugin Loading ---
# Load external functions from plugin files
plugin_dir="plugins" # Sets a variable for the plugins directory

if [[ -d "$plugin_dir" ]]; then #Check if the directory exists, prevent errors
    find "$plugin_dir" -maxdepth 1 -name "*.sh" -print0 | while IFS= read -r -d $'\0' plugin; do
       if [[ -f "$plugin" ]]; then #Check that it is a file and not a directory
         source "$plugin"
       fi
    done
else
    echo "Warning: Plugin directory '$plugin_dir' not found."
fi

# --- 2. Loading Animation ---
start_loading_animation # this function exists in a plugin

# --- 3. Functions ---

# Function to clear the screen and display game info
clear_screen() {
    clear
    echo -e "\e[1;34m-----------------------------------------\e[0m"
    echo -e "\e[1;43m|        Bash theaft auto               |\e[0m"
    echo -e "\e[1;34m-----------------------------------------\e[0m"
    echo "Player: $player_name   Location: $location"
    echo "Cash: $cash dollars      Health: $health%"
    echo -e "\e[1;34m-----------------------------------------\e[0m"
    echo -e "\e[1;44m|        made by styffbymax             |\e[0m"
    echo -e "\e[1;34m-----------------------------------------\e[0m"
}

# Function to check if the player is alive
check_health() {
    if (( health <= 0 )); then
        echo "You have no health left! Transporting to hospital..."
        read -p "Press Enter to continue..."
        hospitalize_player
    fi
}

# Function for traveling to a new location
travel_to() {
    local travel_cost="$1"  # Use local variables
    local new_location="$2"

    if (( cash >= travel_cost )); then
        echo "Traveling to $new_location..."
        cash=$((cash - travel_cost))
        read -p "Press Enter to continue..."
        location="$new_location"
        clear_screen
        echo "You have arrived at $location."
    else
        echo "Not enough cash to travel to $new_location."
         read -p "Press Enter to continue..."
        clear_screen
    fi
}

# Function for buying guns
buy_guns() {
    clear_screen
    echo "Gun Store - Choose a gun to buy:"
    echo "1. Pistol (100$)"
    echo "2. Shotgun (250$)"
    echo "3. SMG (500$)"
    echo "4. Rifle (750$)"
    echo "5. Back to main menu"
    read -p "Enter your choice (number): " gun_choice
    if ! [[ "$gun_choice" =~ ^[0-9]+$ ]]; then
           echo "Invalid input. Please enter a number from the menu."
            read -p "Press Enter to continue..."
           return  # Go back to menu
        fi
    case $gun_choice in
        1) if (( cash >= 100 )); then
               cash=$((cash - 100))
               guns+=("Pistol")
               echo "You bought a Pistol."
                read -p "Press Enter to continue..."
           else
               echo "Not enough cash to buy a Pistol."
               read -p "Press Enter to continue..."
           fi;;
        2) if (( cash >= 250 )); then
               cash=$((cash - 250))
               guns+=("Shotgun")
               echo "You bought a Shotgun."
                read -p "Press Enter to continue..."
           else
               echo "Not enough cash to buy a Shotgun."
                read -p "Press Enter to continue..."
           fi;;
        3) if (( cash >= 500 )); then
               cash=$((cash - 500))
               guns+=("SMG")
               echo "You bought an SMG."
                read -p "Press Enter to continue..."
           else
               echo "Not enough cash to buy an SMG."
                read -p "Press Enter to continue..."
           fi;;
        4) if (( cash >= 750 )); then
               cash=$((cash - 750))
               guns+=("Rifle")
               echo "You bought a Rifle."
                read -p "Press Enter to continue..."
           else
               echo "Not enough cash to buy a Rifle."
                read -p "Press Enter to continue..."
           fi;;
        5) clear_screen;;
        *) echo "Invalid choice.";;
    esac

}

# Function to show inventory
show_inventory() {
    clear_screen
    echo "Your Inventory:"
    echo "Cash: $cash dollars"
    echo "Health: $health%"
    echo "Guns: ${guns[*]}"
    echo "Items: ${items[*]}"
    echo "Drugs: "
    for drug in "${!drugs[@]}"; do
     echo "  - $drug: ${drugs[$drug]}"
    done
    read -p "Press Enter to return to main menu."
}

# Function for working as a taxi driver
work_taxi() {
    echo "You are working as a taxi driver in $location..."
      read -p "Press Enter to continue..."
    local earnings #Use local variables
    case $location in
        "Los Santos")
            earnings=$((RANDOM % 30 + 20))  # Random earnings between $20 to $50
            ;;
        "San Fierro")
            earnings=$((RANDOM % 35 + 25))  # Random earnings between $25 to $60
            ;;
        "Las Venturas")
            earnings=$((RANDOM % 40 + 30))  # Random earnings between $30 to $70
            ;;
        "Vice City")
            earnings=$((RANDOM % 25 + 15))  # Random earnings between $15 to $40
            ;;
        "Liberty City")
            earnings=$((RANDOM % 45 + 35))  # Random earnings between $35 to $80
            ;;
    esac
    cash=$((cash + earnings))
    clear_screen
    echo "You earned $earnings dollars. You now have $cash dollars."
    read -p "Press Enter to continue..."
}

# Function for working as a delivery driver
work_delivery() {
    echo "You are working as a delivery driver in $location..."
       read -p "Press Enter to continue..."
    local earnings #Use local variables
    case $location in
        "Los Santos")
            earnings=$((RANDOM % 40 + 30))  # Random earnings between $30 to $70
            ;;
        "San Fierro")
            earnings=$((RANDOM % 45 + 35))  # Random earnings between $35 to $80
            ;;
        "Las Venturas")
            earnings=$((RANDOM % 50 + 40))  # Random earnings between $40 to $90
            ;;
        "Vice City")
            earnings=$((RANDOM % 35 + 25))  # Random earnings between $25 to $60
            ;;
        "Liberty City")
            earnings=$((RANDOM % 30 + 20))  # Random earnings between $20 to $50
            ;;
    esac
    cash=$((cash + earnings))
    clear_screen
    echo "You earned $earnings dollars. You now have $cash dollars."
      read -p "Press Enter to continue..."
}


# Function for working as a mechanic
work_mechanic() {
    echo "You are working as a mechanic in $location..."
       read -p "Press Enter to continue..."
    local earnings #Use local variables
    case $location in
        "Los Santos")
            earnings=$((RANDOM % 50 + 40))  # Random earnings between $40 to $90
            ;;
        "San Fierro")
            earnings=$((RANDOM % 55 + 45))  # Random earnings between $45 to $100
            ;;
        "Las Venturas")
            earnings=$((RANDOM % 60 + 50))  # Random earnings between $50 to $110
            ;;
        "Vice City")
            earnings=$((RANDOM % 45 + 35))  # Random earnings between $35 to $80
            ;;
        "Liberty City")
            earnings=$((RANDOM % 55 + 45))  # Random earnings between $45 to $100
            ;;
    esac
    cash=$((cash + earnings))
    clear_screen
    echo "You earned $earnings dollars. You now have $cash dollars."
       read -p "Press Enter to continue..."
}

# Function for working as a security guard
work_security() {
    echo "You are working as a security guard in $location..."
        read -p "Press Enter to continue..."
    local earnings #Use local variables
    case $location in
        "Los Santos")
            earnings=$((RANDOM % 60 + 50))  # Random earnings between $50 to $110
            ;;
        "San Fierro")
            earnings=$((RANDOM % 65 + 55))  # Random earnings between $55 to $120
            ;;
        "Las Venturas")
            earnings=$((RANDOM % 70 + 60))  # Random earnings between $60 to $130
            ;;
        "Vice City")
            earnings=$((RANDOM % 55 + 45))  # Random earnings between $45 to $100
            ;;
        "Liberty City")
            earnings=$((RANDOM % 65 + 55))  # Random earnings between $55 to $120
            ;;
    esac
    cash=$((cash + earnings))
    clear_screen
    echo "You earned $earnings dollars. You now have $cash dollars."
      read -p "Press Enter to continue..."
}

# Function for working as a street performer
work_performer() {
    echo "You are working as a street performer in $location..."
         read -p "Press Enter to continue..."
    local earnings #Use local variables
    case $location in
        "Los Santos")
            earnings=$((RANDOM % 20 + 10))  # Random earnings between $10 to $30
            ;;
        "San Fierro")
            earnings=$((RANDOM % 25 + 15))  # Random earnings between $15 to $40
            ;;
        "Las Venturas")
            earnings=$((RANDOM % 30 + 20))  # Random earnings between $20 to $50
            ;;
        "Vice City")
            earnings=$((RANDOM % 15 + 5))   # Random earnings between $5 to $20
            ;;
        "Liberty City")
            earnings=$((RANDOM % 25 + 15))  # Random earnings between $15 to $40
            ;;
    esac
    cash=$((cash + earnings))
    clear_screen
    echo "You earned $earnings dollars. You now have $cash dollars."
       read -p "Press Enter to continue..."
}

# Function for street racing
work_race() {
    echo "You are participating in a street race in $location..."
        read -p "Press Enter to continue..."
    local winnings #Use local variables
    local damage #Use local variables
    if (( RANDOM % 2 == 0 )); then
        winnings=$((RANDOM % 200 + 100))  # Random winnings between $100 to $300
        cash=$((cash + winnings))
        damage=$((RANDOM % 20 + 10))  # Random damage between 10% to 30%
        if $body_armor_equipped; then
               damage=$((damage / 2)) #reduce damage
               echo "Your body armor reduced the damage!"
               body_armor_equipped=false #Use it once then it disappears
           fi
        health=$((health - damage))
        check_health
        clear_screen
        echo "You won the street race and got $winnings dollars, but lost $damage% health. You now have $cash dollars and $health% health."
            read -p "Press Enter to continue..."
    else
        damage=$((RANDOM % 40 + 20))  # Random damage between 20% to 60%
         if $body_armor_equipped; then
               damage=$((damage / 2)) #reduce damage
               echo "Your body armor reduced the damage!"
               body_armor_equipped=false #Use it once then it disappears
           fi
        health=$((health - damage))
        check_health
        clear_screen
        echo "You lost the street race and took $damage% damage. You now have $health% health."
           read -p "Press Enter to continue..."
    fi
}

# Function to use guns for jobs
use_guns() {
    if [[ " ${guns[*]} " == *" $1 "* ]]; then
        echo "You used your $1 for this job."
        read -p "Press Enter to continue..."
    else
        echo "You don't have a $1. Job failed."
        read -p "Press Enter to continue..."
    fi
}

# Function for visiting the hospital
visit_hospital() {
    clear_screen
    echo "Hospital Services:"
    echo "1. Basic Treatment (50$) - Full heal"
    echo "2. Advanced Treatment (100$) - Full heal + 10% health boost"
    echo "3. Buy Health Pack (30$) - Heal 25% health"
    echo "4. Buy Body Armor (75$) - Reduce damage by 50% in next encounter"
    echo "5. Back to main menu"
    read -p "Enter your choice (number): " hospital_choice
     if ! [[ "$hospital_choice" =~ ^[0-9]+$ ]]; then
           echo "Invalid input. Please enter a number from the menu."
            read -p "Press Enter to continue..."
           return  # Go back to menu
        fi
    case $hospital_choice in
        1) if (( cash >= 50 )); then
               cash=$((cash - 50))
               health=100
               echo "You received basic treatment and are fully healed."
                read -p "Press Enter to continue..."
           else
               echo "Not enough cash for basic treatment."
                read -p "Press Enter to continue..."
           fi;;
        2) if (( cash >= 100 )); then
               cash=$((cash - 100))
               health=$((health + 10))
               if (( health > 100 )); then
                 health=100
               fi
               echo "You received advanced treatment and are fully healed with a health boost."
                read -p "Press Enter to continue..."
           else
               echo "Not enough cash for advanced treatment."
               read -p "Press Enter to continue..."
           fi;;
        3) if (( cash >= 30 )); then
               cash=$((cash - 30))
               items+=("Health Pack")
               echo "You bought a Health Pack."
                read -p "Press Enter to continue..."
           else
               echo "Not enough cash to buy a Health Pack."
                read -p "Press Enter to continue..."
           fi;;
        4) if (( cash >= 75 )); then
               cash=$((cash - 75))
               body_armor_equipped=true
               echo "You bought Body Armor."
                read -p "Press Enter to continue..."
           else
               echo "Not enough cash to buy Body Armor."
                read -p "Press Enter to continue..."
           fi;;
        5) clear_screen;;
        *) echo "Invalid choice.";;
    esac
}

# Function for robbing a store
rob_store() {
    echo "Attempting to rob a store in $location..."
        read -p "Press Enter to continue..."
    local loot #Use local variables
    local damage #Use local variables
    local fine #Use local variables
    if (( RANDOM % 2 == 0 )); then
        loot=$((RANDOM % 200 + 100))  # Random loot between $100 to $300
        cash=$((cash + loot))
         if $body_armor_equipped; then
               damage=$((damage / 2)) #reduce damage
               echo "Your body armor reduced the damage!"
               body_armor_equipped=false #Use it once then it disappears
           fi
        damage=$((RANDOM % 30 + 10))  # Random damage between 10% to 40%
        health=$((health - damage))
        check_health
        clear_screen
        echo "You successfully robbed the store and got $loot dollars, but lost $damage% health. You now have $cash dollars and $health% health."
         read -p "Press Enter to continue..."
    else
        fine=$((RANDOM % 50 + 25))  # Random fine between $25 to $75
        cash=$((cash - fine))
        clear_screen
        echo "You got caught and fined $fine dollars. You now have $cash dollars."
          read -p "Press Enter to continue..."
    fi
}

# Function for participating in a heist
heist() {
    echo "Planning a heist in $location..."
    read -p "Press Enter to continue..."
    local loot #Use local variables
    local damage #Use local variables
    local fine #Use local variables
    if (( RANDOM % 3 == 0 )); then
        loot=$((RANDOM % 500 + 200))  # Random loot between $200 to $700
        cash=$((cash + loot))
        damage=$((RANDOM % 50 + 20))  # Random damage between 20% to 70%
         if $body_armor_equipped; then
               damage=$((damage / 2)) #reduce damage
               echo "Your body armor reduced the damage!"
               body_armor_equipped=false #Use it once then it disappears
           fi
        health=$((health - damage))
        check_health
        clear_screen
        echo "The heist was successful! You got $loot dollars, but lost $damage% health. You now have $cash dollars and $health% health."
          read -p "Press Enter to continue..."
    else
        fine=$((RANDOM % 100 + 50))  # Random fine between $50 to $150
        cash=$((cash - fine))
        clear_screen
        echo "The heist failed and you got caught, losing $fine dollars. You now have $cash dollars."
          read -p "Press Enter to continue..."
    fi
}

# Function for gang wars
gang_war() {
    echo "Starting a gang war in $location..."
         read -p "Press Enter to continue..."
    local loot #Use local variables
    local damage #Use local variables
    local fine #Use local variables
    if (( RANDOM % 3 == 0 )); then
        loot=$((RANDOM % 300 + 100))  # Random loot between $100 to $400
        cash=$((cash + loot))
         if $body_armor_equipped; then
               damage=$((damage / 2)) #reduce damage
               echo "Your body armor reduced the damage!"
               body_armor_equipped=false #Use it once then it disappears
           fi
        damage=$((RANDOM % 50 + 30))  # Random damage between 30% to 80%
        health=$((health - damage))
        check_health
        clear_screen
        echo "You won the gang war and got $loot dollars, but lost $damage% health. You now have $cash dollars and $health% health."
          read -p "Press Enter to continue..."
    else
        fine=$((RANDOM % 150 + 50))  # Random fine between $50 to $200
        cash=$((cash - fine))
        damage=$((RANDOM % 40 + 20))  # Random damage between 20% to 60%
         if $body_armor_equipped; then
               damage=$((damage / 2)) #reduce damage
               echo "Your body armor reduced the damage!"
               body_armor_equipped=false #Use it once then it disappears
           fi
        health=$((health - damage))
        check_health
        clear_screen
        echo "You lost the gang war, got fined $fine dollars, and lost $damage% health. You now have $cash dollars and $health% health."
           read -p "Press Enter to continue..."
    fi
}

# Function for carjacking
carjack() {
    echo "Attempting to carjack a vehicle in $location..."
       read -p "Press Enter to continue..."
    local loot #Use local variables
    local damage #Use local variables
    local fine #Use local variables
    if (( RANDOM % 2 == 0 )); then
        loot=$((RANDOM % 200 + 50))  # Random loot between $50 to $250
        cash=$((cash + loot))
         if $body_armor_equipped; then
               damage=$((damage / 2)) #reduce damage
               echo "Your body armor reduced the damage!"
               body_armor_equipped=false #Use it once then it disappears
           fi
        damage=$((RANDOM % 20 + 10))  # Random damage between 10% to 30%
        health=$((health - damage))
        check_health
        clear_screen
        echo "You successfully carjacked a vehicle and got $loot dollars, but lost $damage% health. You now have $cash dollars and $health% health."
        read -p "Press Enter to continue..."
    else
        fine=$((RANDOM % 75 + 25))  # Random fine between $25 to $100
        cash=$((cash - fine))
        clear_screen
        echo "You got caught and fined $fine dollars. You now have $cash dollars."
        read -p "Press Enter to continue..."
    fi
}

# Function to handle hospital visit after death
hospitalize_player() {
    clear_screen
    echo "You have been hospitalized and are being treated..."
    read -p "Press Enter to continue..."
    health=100
    clear_screen
    echo "You are fully healed but lost $200 for the treatment."
    cash=$((cash - 200))
    if (( cash < 0 )); then
        cash=0
    fi
    read -p "Press Enter to continue..."
    clear_screen
}


#~ # Function to encounter a random event
#~ random_event() {
    #~ local event
    #~ local found_cash
    #~ local reward
    #~ event=$((RANDOM % 4))
    #~ case $event in
        #~ 0) echo "You encountered a mugger!"
           #~ if $body_armor_equipped; then
               #~ echo "Your body armor reduced the damage!"
               #~ health=$((health - 10))
               #~ body_armor_equipped=false
           #~ else
               #~ health=$((health - 20))
           #~ fi
           #~ ;;
        #~ 1) echo "You found a hidden stash of cash!"
            #~ found_cash=$((RANDOM % 100 + 50))
            #~ cash=$((cash + found_cash))
            #~ echo "You found $found_cash dollars."
            #~ ;;
        #~ 2) echo "You helped a stranded motorist and earned a reward!"
           #~ reward=$((RANDOM % 50 + 20))
           #~ cash=$((cash + reward))
           #~ echo "You received $reward dollars."
           #~ ;;
        #~ 3) echo "You got caught in a minor accident!"
            #~ health=$((health - 15))
            #~ ;;
    #~ esac
    #~ read -p "Press Enter to continue..."
    #~ clear_screen
    #~ check_health
#~ }

# Function to hire a hooker
hire_hooker() {
    echo "You are looking for a hooker in $location..."
          read -p "Press Enter to continue..."
    local hooker_cost #Use local variables
    local health_gain #Use local variables
    hooker_cost=$((RANDOM % 100 + 50))  # Random cost between $50 to $150
    health_gain=$((RANDOM % 20 + 10))  # Random health gain between 10% to 30%
    if (( cash >= hooker_cost )); then
        cash=$((cash - hooker_cost))
        health=$((health + health_gain))
        if (( health > 100 )); then
            health=100
        fi
        clear_screen
        echo "You hired a hooker for $hooker_cost dollars and gained $health_gain% health. You now have $cash dollars and $health% health."
           read -p "Press Enter to continue..."
    else
        clear_screen
        echo "Not enough cash to hire a hooker."
            read -p "Press Enter to continue..."
    fi

    clear_screen
}

# Function to buy drugs
buy_drugs() {
    clear_screen
    echo "Drug Dealer - Choose a drug to buy:"
    echo "1. Weed (10$/unit)"
    echo "2. Cocaine (50$/unit)"
    echo "3. Heroin (100$/unit)"
    echo "4. Meth (75$/unit)"
    echo "5. Back to main menu"
    read -p "Enter your choice (number): " drug_choice
    if ! [[ "$drug_choice" =~ ^[0-9]+$ ]]; then
           echo "Invalid input. Please enter a number from the menu."
            read -p "Press Enter to continue..."
           return  # Go back to menu
        fi
    read -p "Enter the amount you want to buy: " drug_amount
      if ! [[ "$drug_amount" =~ ^[0-9]+$ ]]; then
           echo "Invalid input. Please enter a number."
            read -p "Press Enter to continue..."
           return  # Go back to menu
        fi

    local cost #Use local variables

    case $drug_choice in
        1) cost=$((10 * drug_amount))
           if (( cash >= cost )); then
               cash=$((cash - cost))
               drugs["Weed"]=$((drugs["Weed"] + drug_amount))
               echo "You bought $drug_amount units of Weed."
               read -p "Press Enter to continue..."
           else
               echo "Not enough cash to buy Weed."
              read -p "Press Enter to continue..."
           fi;;
        2) cost=$((50 * drug_amount))
           if (( cash >= cost )); then
               cash=$((cash - cost))
               drugs["Cocaine"]=$((drugs["Cocaine"] + drug_amount))
               echo "You bought $drug_amount units of Cocaine."
                  read -p "Press Enter to continue..."
           else
               echo "Not enough cash to buy Cocaine."
                  read -p "Press Enter to continue..."
           fi;;
        3) cost=$((100 * drug_amount))
           if (( cash >= cost )); then
               cash=$((cash - cost))
               drugs["Heroin"]=$((drugs["Heroin"] + drug_amount))
               echo "You bought $drug_amount units of Heroin."
                  read -p "Press Enter to continue..."
           else
               echo "Not enough cash to buy Heroin."
                    read -p "Press Enter to continue..."
           fi;;
        4) cost=$((75 * drug_amount))
           if (( cash >= cost )); then
               cash=$((cash - cost))
               drugs["Meth"]=$((drugs["Meth"] + drug_amount))
               echo "You bought $drug_amount units of Meth."
                    read -p "Press Enter to continue..."
           else
               echo "Not enough cash to buy Meth."
                  read -p "Press Enter to continue..."
           fi;;
        5) clear_screen;;
        *) echo "Invalid choice.";;
    esac
    clear_screen
}

# Function to sell drugs
sell_drugs() {
    clear_screen
    echo "Drug Dealer - Choose a drug to sell:"
    echo "1. Weed"
    echo "2. Cocaine"
    echo "3. Heroin"
    echo "4. Meth"
    echo "5. Back to main menu"
    read -p "Enter your choice (number): " drug_choice
     if ! [[ "$drug_choice" =~ ^[0-9]+$ ]]; then
           echo "Invalid input. Please enter a number from the menu."
             read -p "Press Enter to continue..."
           return  # Go back to menu
        fi
    read -p "Enter the amount you want to sell: " drug_amount
    if ! [[ "$drug_amount" =~ ^[0-9]+$ ]]; then
           echo "Invalid input. Please enter a number."
            read -p "Press Enter to continue..."
           return  # Go back to menu
        fi
    case $drug_choice in
        1) if [[ -v "drugs[Weed]" ]] && (( drugs["Weed"] >= drug_amount )); then
               cash=$((cash + 15 * drug_amount))
               drugs["Weed"]=$((drugs["Weed"] - drug_amount))
               echo "You sold $drug_amount units of Weed."
                read -p "Press Enter to continue..."
           else
               echo "Not enough Weed to sell."
                  read -p "Press Enter to continue..."
           fi;;
        2) if [[ -v "drugs[Cocaine]" ]] && (( drugs["Cocaine"] >= drug_amount )); then
               cash=$((cash + 75 * drug_amount))
               drugs["Cocaine"]=$((drugs["Cocaine"] - drug_amount))
               echo "You sold $drug_amount units of Cocaine."
                   read -p "Press Enter to continue..."
           else
               echo "Not enough Cocaine to sell."
                    read -p "Press Enter to continue..."
           fi;;
        3) if [[ -v "drugs[Heroin]" ]] && (( drugs["Heroin"] >= drug_amount )); then
               cash=$((cash + 150 * drug_amount))
               drugs["Heroin"]=$((drugs["Heroin"] - drug_amount))
               echo "You sold $drug_amount units of Heroin."
                read -p "Press Enter to continue..."
           else
               echo "Not enough Heroin to sell."
                 read -p "Press Enter to continue..."
           fi;;
        4) if [[ -v "drugs[Meth]" ]] && (( drugs["Meth"] >= drug_amount )); then
               cash=$((cash + 100 * drug_amount))
               drugs["Meth"]=$((drugs["Meth"] - drug_amount))
               echo "You sold $drug_amount units of Meth."
               read -p "Press Enter to continue..."
           else
               echo "Not enough Meth to sell."
                   read -p "Press Enter to continue..."
           fi;;
        5) clear_screen;;
        *) echo "Invalid choice.";;
    esac
        clear_screen
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
            echo "$((i + 1)). $(basename "${music_files[$i]}")"
        done
       echo "press q to Stop Music"
       echo "$(( ${#music_files[@]} + 1 )). Back to Main menu"
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
              mpg123 -q "$selected_track" # Run in foreground
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
    echo "$player_name" > player_name.sav
    echo "$location" > location.sav
    echo "$cash" > cash.sav
    echo "$health" > health.sav
    echo "${guns[*]}" > guns.sav
    echo "${items[*]}" > items.sav
    for key in "${!drugs[@]}"; do
        echo "$key ${drugs[$key]}" >> drugs.sav
    done
    echo "$body_armor_equipped" > body_armor_equipped.sav
    echo "Game saved successfully."
    read -p "Press Enter to continue..."
}

# Load the game state from a file
load_game() {
    if [[ -f player_name.sav && -f location.sav && -f cash.sav && -f health.sav && -f guns.sav && -f items.sav && -f body_armor_equipped.sav  ]]; then
        # Load normal variables
            IFS=$'\n' read -r player_name < player_name.sav
            IFS=$'\n' read -r location < location.sav
            IFS=$'\n' read -r cash < cash.sav
            IFS=$'\n' read -r health < health.sav
            IFS=$'\n' read -r guns_str < guns.sav
            IFS=$'\n' read -r items_str < items.sav
            IFS=$'\n' read -r body_armor_equipped < body_armor_equipped.sav

            # Load arrays
            IFS=$' ' read -r -a guns <<< "$guns_str"
            IFS=$' ' read -r -a items <<< "$items_str"

             # Load associative array (drug array)
            declare -A drugs
           if [[ -f drugs.sav ]]; then
              while IFS=$'\n' read -r line; do
                if [[ -n "$line" ]]; then
                  IFS=$' ' read -r key value <<< "$line"
                  drugs["$key"]="$value"
                fi
              done < drugs.sav
           fi
        echo "Game loaded successfully."
         read -p "Press Enter to continue..."
    else
        echo "No saved game found."
         read -p "Press Enter to continue..."
    fi
}

# --- 4. Game Initialization and Loop ---

# Function to initialize game variables
Game_variables() {
    clear_screen
    read -p "Enter your player name: " player_name
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
    
    read -p "Enter your choice: " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
           echo "Invalid input. Please enter a number."
           sleep 2
           continue 
        fi

    case $choice in
        1)  clear
            echo "Choose a city to travel to:"
            echo "1. Los Santos (50$)"
            echo "2. San Fierro (75$)"
            echo "3. Las Venturas (100$)"
            echo "4. Vice City (150$)"
            echo "5. Liberty City (200$)"
            echo "6. Back to main menu"
            read -p "Enter your choice: " city_choice
             if ! [[ "$city_choice" =~ ^[0-9]+$ ]]; then
                   echo "Invalid input. Please enter a number."
                   sleep 2
                   continue  # Go back to menu
                fi
            case $city_choice in
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
        4)  clear # Clear the screen before showing job choices
            echo "Choose a job:"
            echo "1. Taxi Driver"
            echo "2. Delivery Driver"
            echo "3. Mechanic"
            echo "4. Security Guard"
            echo "5. Street Performer"
            echo "6. Street Racing"
            echo "7. Back to main menu"
            read -p "Enter your choice: " job_choice
            if ! [[ "$job_choice" =~ ^[0-9]+$ ]]; then
                   echo "Invalid input. Please enter a number."
                   sleep 2
                   continue  # Go back to menu
                fi
            case $job_choice in
                1) work_taxi;;
                2) work_delivery;;
                3) work_mechanic;;
                4) work_security;;
                5) work_performer;;
                6) work_race;;
                7) clear_screen;;
                *) echo "Invalid choice.";;
            esac;;
        5)  clear
            echo "Choose a criminal activity:"
            echo "1. Heist"
            echo "2. Gang war"
            echo "3. Carjack"
            echo "4. Back to main menu"
            read -p "Enter your choice: " criminal_choice
            if ! [[ "$criminal_choice" =~ ^[0-9]+$ ]]; then
                   echo "Invalid input. Please enter a number."
                   sleep 2
                   continue  # Go back to menu
                fi
            case $criminal_choice in
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
        #random_event # Added random_event in comment, It can be uncommented after the function is fixed and polished.
done
