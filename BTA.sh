#!/bin/bash

# Function to clear the screen
clear_screen() {
    clear
    echo "-----------------------------------------"
    echo "|        Bash theaft auto               |"
    echo "-----------------------------------------"
    echo "Player: $player_name   Location: $location"
    echo "Cash: $cash dollars      Health: $health%"
    echo "-----------------------------------------"
}

# Function to check if the player is alive
check_health() {
    if (( health <= 0 )); then
        echo "You have no health left! Transporting to hospital..."
        sleep 2
        hospitalize_player
    fi
}




# Function for traveling to a new location
travel_to() {
    travel_cost=$1
    new_location=$2

    if (( cash >= travel_cost )); then
        echo "Traveling to $new_location..."
        cash=$((cash - travel_cost))
        sleep 1
        location="$new_location"
        clear_screen
        echo "You have arrived at $location."
    else
        echo "Not enough cash to travel to $new_location."
        sleep 1
        clear_screen
    fi
}

# Function for buying guns
buy_guns() {
    clear_screen
    echo "Gun Store - Choose a gun to buy:"
    echo "1. Pistol ($100)"
    echo "2. Shotgun ($250)"
    echo "3. SMG ($500)"
    echo "4. Rifle ($750)"
    echo "5. Back to main menu"
    read -p "Enter your choice: " gun_choice
    case $gun_choice in
        1) if (( cash >= 100 )); then
               cash=$((cash - 100))
               guns+=("Pistol")
               echo "You bought a Pistol."
           else
               echo "Not enough cash to buy a Pistol."
           fi;;
        2) if (( cash >= 250 )); then
               cash=$((cash - 250))
               guns+=("Shotgun")
               echo "You bought a Shotgun."
           else
               echo "Not enough cash to buy a Shotgun."
           fi;;
        3) if (( cash >= 500 )); then
               cash=$((cash - 500))
               guns+=("SMG")
               echo "You bought an SMG."
           else
               echo "Not enough cash to buy an SMG."
           fi;;
        4) if (( cash >= 750 )); then
               cash=$((cash - 750))
               guns+=("Rifle")
               echo "You bought a Rifle."
           else
               echo "Not enough cash to buy a Rifle."
           fi;;
        5) clear_screen;;
        *) echo "Invalid choice.";;
    esac
    sleep 2
    clear_screen
}

# Function to show inventory
show_inventory() {
    clear_screen
    echo "Your Inventory:"
    echo "Cash: $cash dollars"
    echo "Health: $health%"
    echo "Guns: ${guns[*]}"
    echo "Items: ${items[*]}"
    read -p "Press Enter to return to main menu."
    clear_screen
}

# Function for working as a taxi driver
work_taxi() {
    echo "You are working as a taxi driver in $location..."
    sleep 2
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
}

# Function for working as a delivery driver
work_delivery() {
    echo "You are working as a delivery driver in $location..."
    sleep 2
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
}

# Function for working as a mechanic
work_mechanic() {
    echo "You are working as a mechanic in $location..."
    sleep 2
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
}

# Function for working as a security guard
work_security() {
    echo "You are working as a security guard in $location..."
    sleep 2
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
}

# Function for working as a street performer
work_performer() {
    echo "You are working as a street performer in $location..."
    sleep 2
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
}

# Function for street racing
work_race() {
    echo "You are participating in a street race in $location..."
    sleep 2
    if (( RANDOM % 2 == 0 )); then
        winnings=$((RANDOM % 200 + 100))  # Random winnings between $100 to $300
        cash=$((cash + winnings))
        damage=$((RANDOM % 20 + 10))  # Random damage between 10% to 30%
        health=$((health - damage))
        check_health
        clear_screen
        echo "You won the street race and got $winnings dollars, but lost $damage% health. You now have $cash dollars and $health% health."
    else
        damage=$((RANDOM % 40 + 20))  # Random damage between 20% to 60%
        health=$((health - damage))
        check_health
        clear_screen
        echo "You lost the street race and took $damage% damage. You now have $health% health."
    fi
}

# Function to use guns for jobs
use_guns() {
    if [[ " ${guns[*]} " == *" $1 "* ]]; then
        echo "You used your $1 for this job."
        sleep 1
    else
        echo "You don't have a $1. Job failed."
        sleep 1
    fi
}

# Function for visiting the hospital
visit_hospital() {
    clear_screen
    echo "Hospital Services:"
    echo "1. Basic Treatment ($50) - Full heal"
    echo "2. Advanced Treatment ($100) - Full heal + 10% health boost"
    echo "3. Buy Health Pack ($30) - Heal 25% health"
    echo "4. Buy Body Armor ($75) - Reduce damage by 50% in next encounter"
    echo "5 back to main menu"
    read -p "Enter your choice: " hospital_choice
    case $hospital_choice in
        1) if (( cash >= 50 )); then
               cash=$((cash - 50))
               health=100
               echo "You received basic treatment and are fully healed."
           else
               echo "Not enough cash for basic treatment."
           fi;;
        2) if (( cash >= 100 )); then
               cash=$((cash - 100))
               health=110
               echo "You received advanced treatment and are fully healed with a health boost."
           else
               echo "Not enough cash for advanced treatment."
           fi;;
        3) if (( cash >= 30 )); then
               cash=$((cash - 30))
               items+=("Health Pack")
               echo "You bought a Health Pack."
           else
               echo "Not enough cash to buy a Health Pack."
           fi;;
        4) if (( cash >= 75 )); then
               cash=$((cash - 75))
               items+=("Body Armor")
               echo "You bought Body Armor."
           else
               echo "Not enough cash to buy Body Armor."
           fi;;
           5) clear_screen;;
           
        *) echo "Invalid choice.";;
    esac
    sleep 2
    clear_screen
}

# Function for robbing a store
rob_store() {
    echo "Attempting to rob a store in $location..."
    sleep 2
    if (( RANDOM % 2 == 0 )); then
        loot=$((RANDOM % 200 + 100))  # Random loot between $100 to $300
        cash=$((cash + loot))
        damage=$((RANDOM % 30 + 10))  # Random damage between 10% to 40%
        health=$((health - damage))
        check_health
        clear_screen
        echo "You successfully robbed the store and got $loot dollars, but lost $damage% health. You now have $cash dollars and $health% health."
    else
        fine=$((RANDOM % 50 + 25))  # Random fine between $25 to $75
        cash=$((cash - fine))
        clear_screen
        echo "You got caught and fined $fine dollars. You now have $cash dollars."
    fi
}

# Function for participating in a heist
heist() {
    echo "Planning a heist in $location..."
    sleep 2
    if (( RANDOM % 3 == 0 )); then
        loot=$((RANDOM % 500 + 200))  # Random loot between $200 to $700
        cash=$((cash + loot))
        damage=$((RANDOM % 50 + 20))  # Random damage between 20% to 70%
        health=$((health - damage))
        check_health
        clear_screen
        echo "The heist was successful! You got $loot dollars, but lost $damage% health. You now have $cash dollars and $health% health."
    else
        fine=$((RANDOM % 100 + 50))  # Random fine between $50 to $150
        cash=$((cash - fine))
        clear_screen
        echo "The heist failed and you got caught, losing $fine dollars. You now have $cash dollars."
    fi
}

# Function for gang wars
gang_war() {
    echo "Starting a gang war in $location..."
    sleep 2
    if (( RANDOM % 3 == 0 )); then
        loot=$((RANDOM % 300 + 100))  # Random loot between $100 to $400
        cash=$((cash + loot))
        damage=$((RANDOM % 50 + 30))  # Random damage between 30% to 80%
        health=$((health - damage))
        check_health
        clear_screen
        echo "You won the gang war and got $loot dollars, but lost $damage% health. You now have $cash dollars and $health% health."
    else
        fine=$((RANDOM % 150 + 50))  # Random fine between $50 to $200
        cash=$((cash - fine))
        damage=$((RANDOM % 40 + 20))  # Random damage between 20% to 60%
        health=$((health - damage))
        check_health
        clear_screen
        echo "You lost the gang war, got fined $fine dollars, and lost $damage% health. You now have $cash dollars and $health% health."
    fi
}

# Function for carjacking
carjack() {
    echo "Attempting to carjack a vehicle in $location..."
    sleep 2
    if (( RANDOM % 2 == 0 )); then
        loot=$((RANDOM % 200 + 50))  # Random loot between $50 to $250
        cash=$((cash + loot))
        damage=$((RANDOM % 20 + 10))  # Random damage between 10% to 30%
        health=$((health - damage))
        check_health
        clear_screen
        echo "You successfully carjacked a vehicle and got $loot dollars, but lost $damage% health. You now have $cash dollars and $health% health."
    else
        fine=$((RANDOM % 75 + 25))  # Random fine between $25 to $100
        cash=$((cash - fine))
        clear_screen
        echo "You got caught and fined $fine dollars. You now have $cash dollars."
    fi
}

# Function to handle hospital visit after death
hospitalize_player() {
    clear_screen
    echo "You have been hospitalized and are being treated..."
    sleep 2
    health=100
    clear_screen
    echo "You are fully healed but lost $200 for the treatment."
    cash=$((cash - 200))
    if (( cash < 0 )); then
        cash=0
    fi
    sleep 2
    clear_screen
}



# Function to encounter a random event
#random_event() {
    #event=$((RANDOM % 4))
    #case $event in
        #0) echo "You encountered a mugger!"
           #if [[ " ${items[*]} " == *" Body Armor "* ]]; then
               #echo "Your body armor reduced the damage!"
               #health=$((health - 10))
               #items=("${items[@]/Body Armor}")
           #else
               #health=$((health - 20))
           #fi
           #;;
        #1) echo "You found a hidden stash of cash!"
        #   found_cash=$((RANDOM % 100 + 50))
        #   cash=$((cash + found_cash))
        #   echo "You found $found_cash dollars."
        #   ;;
        #2) echo "You helped a stranded motorist and earned a reward!"
        #   reward=$((RANDOM % 50 + 20))
        #   cash=$((cash + reward))
        #   echo "You received $reward dollars."
        #  ;;
        #3) echo "You got caught in a minor accident!"
         #  health=$((health - 15))
         #  ;;
    #esac
    #sleep 2
    #clear_screen
    #check_health
#}

# Function to save the game state to a file
save_game() {
    echo "$player_name" > savegame.txt
    echo "$location" >> savegame.txt
    echo "$cash" >> savegame.txt
    echo "$health" >> savegame.txt
    echo "${guns[*]}" >> savegame.txt
    echo "${items[*]}" >> savegame.txt
    echo "Game saved!"
}

# Function to load the game state from a file
load_game() {
    if [ -f savegame.txt ]; then
        player_name=$(sed -n '1p' savegame.txt)
        location=$(sed -n '2p' savegame.txt)
        cash=$(sed -n '3p' savegame.txt)
        health=$(sed -n '4p' savegame.txt)
        guns=($(sed -n '5p' savegame.txt))
        items=($(sed -n '6p' savegame.txt))
        echo "Game loaded!"
    else
        echo "No saved game found."
    fi
    sleep 2
    clear_screen
}

# Game variables
clear_screen
read -p "Enter your player name: " player_name
location="Los Santos"
cash=100
health=100
guns=()
items=()

clear_screen

# Main game loop
while true; do
    echo "What do you want to do?"
    echo "1. Go to another location"
    echo "2. Work for money"
    echo "3. Buy guns"
    echo "4. Show inventory"
    echo "5. Visit the hospital"
    echo "6. Commit a crime"
    echo "7. save game"
    echo "8. load"
    echo "9. Quit the game"

    read -p "Enter your choice: " choice

    case $choice in
        1) clear_screen
           echo "Choose a location:"
           echo "1. Los Santos ($20)"
           echo "2. San Fierro ($30)"
           echo "3. Las Venturas ($40)"
           echo "4. Vice City ($50)"
           echo "5. Liberty City ($60)"
           echo "6 back to main menu"
           read -p "Enter your choice: " location_choice
           case $location_choice in
               1) travel_to 20 "Los Santos";;
               2) travel_to 30 "San Fierro";;
               3) travel_to 40 "Las Venturas";;
               4) travel_to 50 "Vice City";;
               5) travel_to 60 "Liberty City";;
               6) clear_screen;;
               *) echo "Invalid location choice.";;
           esac
           ;;
        2) clear_screen
           echo "Choose a job to earn money in $location:"
           echo "1. Taxi driver"
           echo "2. Delivery driver"
           echo "3. Mechanic"
           echo "4. Security guard"
           echo "5. Street performer"
           echo "6. Street race"
           echo "7. Back to main menu"
           read -p "Enter your choice: " job_choice
           case $job_choice in
               1) work_taxi;;
               2) work_delivery;;
               3) work_mechanic;;
               4) work_security;;
               5) work_performer;;
               6) work_race;;
               7) clear_screen;;
               *) echo "Invalid job choice.";;
           esac
           ;;
        3) buy_guns;;
        4) show_inventory;;
        5) visit_hospital;;
        6) clear_screen
           echo "Choose a crime to commit in $location:"
           echo "1. Rob a store"
           echo "2. Participate in a heist"
           echo "3. Start a gang war"
           echo "4. Carjack a vehicle"
           echo "5 back to main menu"
           read -p "Enter your choice: " crime_choice
           case $crime_choice in
               1) rob_store;;
               2) heist;;
               3) gang_war;;
               4) carjack;;
               5) clear_screen;;
               *) echo "Invalid crime choice.";;
           esac
           ;;
        7) save_game
           clear_screen
           echo "saving game"
           ;;
        8) load_game
           clear_screen
           echo "loading game"
           ;;
        
        9) clear_screen
           echo "Exiting the game. Goodbye, $player_name!"
           exit 0
           ;;
        *) clear_screen
           echo "Invalid option. Please choose again."
           ;;
    esac
    #random_event
done
