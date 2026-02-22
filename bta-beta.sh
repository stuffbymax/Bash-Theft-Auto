#!/bin/bash
set +H
# creator: stuffbymax (martinP)
# description: open world crime "simulator"
# ver 2.4.4 - beta release
# Licenses:
# Bash-Theft-Auto music © 2024 by stuffbymax - Martin Petik is licensed under CC BY 4.0
# https://creativecommons.org/licenses/by/4.0/
# code is licensed under MIT License

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
MUSIC_DIR="music" 
declare -A gun_attributes=()
music_pid=""
wanted_level=0 # Player's current wanted level (0-5 stars)
MAX_WANTED_LEVEL=5
declare -a owned_vehicles=() # Array to store names of owned vehicles
declare -A vehicle_types=( ["Sedan"]=2000 ["Motorcycle"]=1500 ["Truck"]=2500 ["Sports Car"]=5000 ) # Name=Price
declare -A market_conditions=() # Stores current event modifiers ["crackdown_multiplier", "demand_multiplier", "event_message"]
declare -a world_event_log=() # Log for AI gang activities

# --- Perk System ---
declare -A perks=()
declare -A perk_costs=( ["Street Negotiator"]=1 ["Back Alley Surgeon"]=1 ["Grease Monkey"]=1 ["Master of Disguise"]=2 ["Professional Driver"]=2 ["Charismatic Leader"]=3 )
declare -A perk_descriptions=(
    ["Street Negotiator"]="Get a 10% discount at all shops."
    ["Back Alley Surgeon"]="Gain 25% more health from Health Packs."
    ["Grease Monkey"]="Repair vehicles for free at any owned business."
    ["Master of Disguise"]="Reduce wanted level gain from crimes by 1."
    ["Professional Driver"]="Significantly increases win chance in street races."
    ["Charismatic Leader"]="Recruits cost 25% less to hire and have lower upkeep."
)
declare -a TIER_1_PERKS=("Street Negotiator" "Back Alley Surgeon" "Grease Monkey")
declare -a TIER_2_PERKS=("Master of Disguise" "Professional Driver")
declare -a TIER_3_PERKS=("Charismatic Leader")
perk_points=0
last_respect_milestone=0

gun_attributes=(
    ["Hawk 9"]="success_bonus=5"
    ["Striker 12"]="success_bonus=10"
    ["Viper SMG"]="success_bonus=15"
    ["AR-7 Assault"]="success_bonus=20"
    ["Ghost Sniper"]="success_bonus=25"
    ["Rex 38"]="success_bonus=7"
    ["Bulldog 45"]="success_bonus=12"
    ["Spectre PDW"]="success_bonus=18"
    ["Ravager LMG"]="success_bonus=22"
    ["Diamondback MG"]="success_bonus=28"
    ["Phantom Carbine"]="success_bonus=16"
    ["Undertaker Sawn-off"]="success_bonus=8"
)
# perk functions
manage_perks() {
    clear_screen
    while true; do
        clear_screen
        echo "--- Perk System ---"
        printf " Available Perk Points: \e[1;95m%d\e[0m\n" "$perk_points"
        echo " (Earn points by gaining Respect milestones every 1000 Respect)"
        echo "================================================================"
        echo " TIER 1 (Cost: 1 point)"
        for perk in "${TIER_1_PERKS[@]}"; do
            if [[ -v "perks[$perk]" ]]; then
                printf "  \e[1;32m[OWNED]\e[0m %-25s - %s\n" "$perk" "${perk_descriptions[$perk]}"
            else
                printf "  \e[1;33m[%d pt ]\e[0m %-25s - %s\n" "${perk_costs[$perk]}" "$perk" "${perk_descriptions[$perk]}"
            fi
        done
        echo "----------------------------------------------------------------"
        echo " TIER 2 (Cost: 2 points)"
        for perk in "${TIER_2_PERKS[@]}"; do
            if [[ -v "perks[$perk]" ]]; then
                printf "  \e[1;32m[OWNED]\e[0m %-25s - %s\n" "$perk" "${perk_descriptions[$perk]}"
            else
                printf "  \e[1;33m[%d pts]\e[0m %-25s - %s\n" "${perk_costs[$perk]}" "$perk" "${perk_descriptions[$perk]}"
            fi
        done
        echo "----------------------------------------------------------------"
        echo " TIER 3 (Cost: 3 points)"
        for perk in "${TIER_3_PERKS[@]}"; do
            if [[ -v "perks[$perk]" ]]; then
                printf "  \e[1;32m[OWNED]\e[0m %-25s - %s\n" "$perk" "${perk_descriptions[$perk]}"
            else
                printf "  \e[1;33m[%d pts]\e[0m %-25s - %s\n" "${perk_costs[$perk]}" "$perk" "${perk_descriptions[$perk]}"
            fi
        done
        echo "================================================================"
        echo "Enter perk name to buy it, or B to go back."
        read -r -p "Choice: " choice
        if [[ "$choice" == "b" || "$choice" == "B" ]]; then return; fi

        if [[ -v "perk_costs[$choice]" ]]; then
            if [[ -v "perks[$choice]" ]]; then
                echo "You already own the $choice perk."
            elif (( perk_points >= perk_costs[$choice] )); then
                perk_points=$(( perk_points - perk_costs[$choice] ))
                perks["$choice"]=1
                echo -e "\e[1;32mPerk unlocked: ${choice}!\e[0m"
                play_sfx_mpg "win_big"
            else
                echo "Not enough perk points (need ${perk_costs[$choice]}, have ${perk_points})."
            fi
        else
            echo "Invalid perk name. Type the exact name shown."
        fi
        read -r -p "Press Enter..."
    done
}

# police encounter system
check_police_encounter() {
    (( wanted_level == 0 )) && return
    local encounter_chance=$(( wanted_level * 12 ))
    (( RANDOM % 100 >= encounter_chance )) && return

    clear_screen
    play_sfx_mpg "police_siren"
    echo -e "\e[1;31m*** POLICE ENCOUNTER! ***\e[0m"
    echo "Wanted Level: $(printf '*%.0s' $(seq 1 $wanted_level))"
    echo "------------------------------------------------"

    local outcome_roll=$(( RANDOM % 100 ))
    local escape_chance=$(( 40 + ${skills[stealth]:-1} * 5 + ${skills[driving]:-1} * 3 ))
    (( escape_chance > 85 )) && escape_chance=85

    echo "1. Run for it!    (Escape chance: ${escape_chance}%)"
    echo "2. Bribe them.    (Cost: \$$(( wanted_level * 150 )))"
    echo "3. Surrender.     (Fine + jail time)"
    read -r -p "Choice: " police_choice

    case "$police_choice" in
        1)
            echo "You bolt down the alley..."; sleep 1
            if (( RANDOM % 100 < escape_chance )); then
                echo -e "\e[1;32mYou lost them! Nice moves.\e[0m"
                if (( RANDOM % 3 == 0 )); then
                    wanted_level=$(( wanted_level - 1 ))
                    echo "Wanted level decreased."
                fi
                play_sfx_mpg "win"
            else
                local damage=$(( RANDOM % 20 + 10 + wanted_level * 5 ))
                health=$(( health - damage ))
                local fine=$(( RANDOM % 100 + wanted_level * 75 ))
                cash=$(( cash - fine )); (( cash < 0 )) && cash=0
                wanted_level=$(( wanted_level + 1 ))
                (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
                echo -e "\e[1;31mThey caught you! Took ${damage}%% damage and fined \$${fine}.\e[0m"
                play_sfx_mpg "lose"
            fi
            ;;
        2)
            local bribe=$(( wanted_level * 150 ))
            if [[ -v "perks[Street Negotiator]" ]]; then
                bribe=$(( bribe * 90 / 100 ))
            fi
            if (( cash >= bribe )); then
                cash=$(( cash - bribe ))
                wanted_level=$(( wanted_level - 1 ))
                (( wanted_level < 0 )) && wanted_level=0
                echo -e "\e[1;32mOfficer pockets the cash and looks the other way. Wanted level reduced.\e[0m"
                play_sfx_mpg "cash_register"
            else
                echo -e "\e[1;31mNot enough cash for the bribe (\$$bribe needed). They arrest you!\e[0m"
                local fine=$(( RANDOM % 200 + wanted_level * 100 ))
                cash=$(( cash - fine )); (( cash < 0 )) && cash=0
                wanted_level=0; health=$(( health - 10 ))
                echo "Fined \$$fine and released. Wanted level cleared."
                play_sfx_mpg "lose"
            fi
            ;;
        3|*)
            echo "You put your hands up..."; sleep 1
            local fine=$(( RANDOM % 150 + wanted_level * 80 ))
            local time_lost=$(( wanted_level * 2 ))
            cash=$(( cash - fine )); (( cash < 0 )) && cash=0
            wanted_level=0
            run_clock $time_lost
            echo -e "Fined \e[1;31m\$$fine\e[0m and held for ${time_lost} hours. Wanted level cleared."
            play_sfx_mpg "lose"
            ;;
    esac
    check_health
    read -r -p "Press Enter..."
}

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
# =====================================================
# LOS SANTOS (San Andreas - 3D Universe)
# =====================================================
["Los Santos|Ganton"]="Grove Street"
["Los Santos|Idlewood"]="Ballas"
["Los Santos|Jefferson"]="Ballas"
["Los Santos|East Los Santos"]="Vagos"
["Los Santos|Las Colinas"]="Vagos"
["Los Santos|Los Flores"]="Vagos"
["Los Santos|Glen Park"]="Ballas"
["Los Santos|Playa del Seville"]="Grove Street"
["Los Santos|Temple"]="Ballas"
["Los Santos|Willowfield"]="Ballas"
["Los Santos|El Corona"]="Vagos"
["Los Santos|Little Mexico"]="Vagos"
["Los Santos|Commerce"]="Unaffiliated"
["Los Santos|Market"]="Unaffiliated"
["Los Santos|Pershing Square"]="Unaffiliated"
["Los Santos|Downtown Los Santos"]="Unaffiliated"
["Los Santos|Mulholland"]="Unaffiliated"
["Los Santos|Mulholland Intersection"]="Unaffiliated"
["Los Santos|Rodeo"]="Unaffiliated"
["Los Santos|Richman"]="Unaffiliated"
["Los Santos|Vinewood"]="Unaffiliated"
["Los Santos|Verdant Bluffs"]="Grove Street"
["Los Santos|Marina"]="Unaffiliated"
["Los Santos|Santa Maria Beach"]="Unaffiliated"
["Los Santos|Verona Beach"]="Unaffiliated"
["Los Santos|Ocean Docks"]="Unaffiliated"
["Los Santos|Los Santos International Airport"]="Unaffiliated"

# =====================================================
# SAN FIERRO (3D Universe)
# =====================================================
["San Fierro|Downtown"]="Unaffiliated"
["San Fierro|Financial District"]="Unaffiliated"
["San Fierro|Chinatown"]="Triads"
["San Fierro|Garcia"]="Triads"
["San Fierro|Doherty"]="Unaffiliated"
["San Fierro|Easter Basin"]="Da Nang Boys"
["San Fierro|Easter Bay Airport"]="Unaffiliated"
["San Fierro|Hashbury"]="Unaffiliated"
["San Fierro|Queens"]="Unaffiliated"
["San Fierro|Paradiso"]="Unaffiliated"
["San Fierro|Juniper Hill"]="Unaffiliated"
["San Fierro|Battery Point"]="Unaffiliated"
["San Fierro|Ocean Flats"]="Unaffiliated"
["San Fierro|Avispa Country Club"]="Unaffiliated"

# =====================================================
# LAS VENTURAS (3D Universe)
# =====================================================
["Las Venturas|The Strip"]="Leone Family"
["Las Venturas|Come-A-Lot"]="Leone Family"
["Las Venturas|Roca Escalante"]="Sindacco Family"
["Las Venturas|Redsands East"]="Unaffiliated"
["Las Venturas|Redsands West"]="Unaffiliated"
["Las Venturas|Old Venturas Strip"]="Unaffiliated"
["Las Venturas|Whitewood Estates"]="Unaffiliated"
["Las Venturas|Prickle Pine"]="Unaffiliated"
["Las Venturas|Creek"]="Unaffiliated"
["Las Venturas|Blackfield"]="Unaffiliated"
["Las Venturas|Blackfield Chapel"]="Unaffiliated"
["Las Venturas|Randolph Industrial Estate"]="Unaffiliated"
["Las Venturas|Las Venturas Airport"]="Unaffiliated"

# =====================================================
# LIBERTY CITY (GTA III - 3D Universe)
# =====================================================
["Liberty City|Portland"]="Leone Family"
["Liberty City|Portland Harbor"]="Leone Family"
["Liberty City|Saint Mark's"]="Leone Family"
["Liberty City|Chinatown"]="Triads"
["Liberty City|Red Light District"]="Diablos"
["Liberty City|Hepburn Heights"]="Diablos"
["Liberty City|Callahan Point"]="Unaffiliated"
["Liberty City|Staunton Island"]="Yakuza"
["Liberty City|Torrington"]="Yakuza"
["Liberty City|Newport"]="Unaffiliated"
["Liberty City|Fort Staunton"]="Yakuza"
["Liberty City|Shoreside Vale"]="Unaffiliated"
["Liberty City|Cedar Grove"]="Colombian Cartel"
["Liberty City|Wichita Gardens"]="Unaffiliated"
["Liberty City|Francis International Airport"]="Unaffiliated"

# =====================================================
# LIBERTY CITY (GTA IV - HD Universe)
# =====================================================
["Liberty City|Broker"]="Unaffiliated"
["Liberty City|Dukes"]="Unaffiliated"
["Liberty City|Bohan"]="Unaffiliated"
["Liberty City|Algonquin"]="Unaffiliated"
["Liberty City|Alderney"]="Unaffiliated"
["Liberty City|Hove Beach"]="Russian Mob"
["Liberty City|Little Italy"]="Italian Mob"
["Liberty City|Northwood"]="Drug Dealers"
["Liberty City|South Bohan"]="Drug Dealers"
["Liberty City|Star Junction"]="Unaffiliated"
["Liberty City|Middle Park"]="Unaffiliated"
["Liberty City|The Triangle"]="Unaffiliated"

# =====================================================
# VICE CITY (3D Universe)
# =====================================================
["Vice City|Ocean Beach"]="Unaffiliated"
["Vice City|Washington Beach"]="Unaffiliated"
["Vice City|Vice Point"]="Unaffiliated"
["Vice City|Downtown"]="Unaffiliated"
["Vice City|Little Havana"]="Cuban Gang"
["Vice City|Little Haiti"]="Haitian Gang"
["Vice City|Starfish Island"]="Unaffiliated"
["Vice City|Prawn Island"]="Unaffiliated"
["Vice City|Leaf Links"]="Unaffiliated"
["Vice City|Escobar International Airport"]="Unaffiliated"
["Vice City|Viceport"]="Unaffiliated"

# =====================================================
# LOS SANTOS (GTA V - HD Universe)
# =====================================================
["Los Santos|Pillbox Hill"]="Unaffiliated"
["Los Santos|Mission Row"]="Unaffiliated"
["Los Santos|Textile City"]="Unaffiliated"
["Los Santos|Legion Square"]="Unaffiliated"
["Los Santos|Burton"]="Unaffiliated"
["Los Santos|Rockford Hills"]="Unaffiliated"
["Los Santos|Alta"]="Unaffiliated"
["Los Santos|Hawick"]="Unaffiliated"
["Los Santos|West Vinewood"]="Unaffiliated"
["Los Santos|East Vinewood"]="Unaffiliated"
["Los Santos|Little Seoul"]="Unaffiliated"
["Los Santos|Strawberry"]="Families"
["Los Santos|Davis"]="Families"
["Los Santos|Chamberlain Hills"]="Families"
["Los Santos|Rancho"]="Families"
["Los Santos|La Mesa"]="Vagos"
["Los Santos|Cypress Flats"]="Vagos"
["Los Santos|El Burro Heights"]="Vagos"
["Los Santos|Murrieta Heights"]="Unaffiliated"
["Los Santos|Elysian Island"]="Unaffiliated"
["Los Santos|Banning"]="Unaffiliated"
["Los Santos|Vespucci"]="Unaffiliated"
["Los Santos|Vespucci Canals"]="Unaffiliated"
["Los Santos|Del Perro"]="Unaffiliated"
["Los Santos|Pacific Bluffs"]="Unaffiliated"
["Los Santos|Morningwood"]="Unaffiliated"
["Los Santos|Richman Glen"]="Unaffiliated"
["Los Santos|Mirror Park"]="Unaffiliated"
["Los Santos|Vinewood Hills"]="Unaffiliated"
["Los Santos|Port of Los Santos"]="Unaffiliated"
["Los Santos|Los Santos International Airport (HD)"]="Unaffiliated"

# =====================================================
# BLAINE COUNTY (HD Universe)
# =====================================================
["Blaine County|Sandy Shores"]="Lost MC"
["Blaine County|Grapeseed"]="Unaffiliated"
["Blaine County|Paleto Bay"]="Unaffiliated"
["Blaine County|Harmony"]="Unaffiliated"
["Blaine County|Grand Senora Desert"]="Unaffiliated"
["Blaine County|Alamo Sea"]="Unaffiliated"
["Blaine County|Mount Chiliad"]="Unaffiliated"
["Blaine County|Fort Zancudo"]="Military"
["Blaine County|Zancudo River"]="Unaffiliated"
)
    district_heat=(
        ["Los Santos"]=10 ["San Fierro"]=5 ["Las Venturas"]=15 ["Liberty City"]=20 ["Vice City"]=5
    )
    available_properties=(
# =====================================================
# LOS SANTOS – EXPANSION
# =====================================================
["LS Luxury Car Showroom"]="350000:Los Santos:Legal"
["LS Film Studio"]="500000:Los Santos:Legal"
["LS Recording Studio"]="275000:Los Santos:Legal"
["LS Private Security Firm"]="220000:Los Santos:Legal"
["LS Import Export Garage"]="300000:Los Santos:Legal"
["LS Real Estate Agency"]="180000:Los Santos:Legal"
["LS Tech Campus"]="750000:Los Santos:Legal"

["LS Cocaine Lockup"]="325000:Los Santos:IllegalFront"
["LS Money Laundering Office"]="400000:Los Santos:IllegalFront"
["LS Underground Fight Club"]="150000:Los Santos:IllegalFront"
["LS Human Trafficking Ring"]="500000:Los Santos:IllegalFront"
["LS Arms Manufacturing"]="600000:Los Santos:IllegalFront"

# =====================================================
# SAN FIERRO – EXPANSION
# =====================================================
["SF Cyber Security Firm"]="400000:San Fierro:Legal"
["SF Investment Bank"]="850000:San Fierro:Legal"
["SF Shipping Corporation"]="500000:San Fierro:Legal"
["SF High Rise Apartments"]="320000:San Fierro:Legal"

["SF Crypto Mining Farm"]="275000:San Fierro:IllegalFront"
["SF Offshore Laundering"]="650000:San Fierro:IllegalFront"
["SF Port Smuggling Network"]="450000:San Fierro:IllegalFront"
["SF Underground Casino"]="500000:San Fierro:IllegalFront"

# =====================================================
# LAS VENTURAS – EXPANSION
# =====================================================
["LV Mega Casino"]="900000:Las Venturas:Legal"
["LV Entertainment Arena"]="650000:Las Venturas:Legal"
["LV Convention Center"]="550000:Las Venturas:Legal"
["LV Luxury Resort"]="1200000:Las Venturas:Legal"

["LV Rigged Casino"]="700000:Las Venturas:IllegalFront"
["LV Underground Betting Syndicate"]="450000:Las Venturas:IllegalFront"
["LV Counterfeit Chip Factory"]="500000:Las Venturas:IllegalFront"
["LV Mafia Headquarters"]="1000000:Las Venturas:IllegalFront"

# =====================================================
# LIBERTY CITY – EXPANSION
# =====================================================
["LC Wall Street Office"]="950000:Liberty City:Legal"
["LC Shipping Terminal"]="450000:Liberty City:Legal"
["LC Media Corporation"]="800000:Liberty City:Legal"
["LC Luxury Condos"]="600000:Liberty City:Legal"

["LC Underground Arms Trade"]="550000:Liberty City:IllegalFront"
["LC International Drug Hub"]="850000:Liberty City:IllegalFront"
["LC Russian Syndicate HQ"]="950000:Liberty City:IllegalFront"
["LC Mafia Commission Office"]="1200000:Liberty City:IllegalFront"

["LC Illegal Gun Shop 1"]="120000:Liberty City:IllegalFront"
["LC Illegal Gun Shop 2"]="135000:Liberty City:IllegalFront"
["LC Underground Gun Market"]="200000:Liberty City:IllegalFront"
["LC Black Market Firearms"]="250000:Liberty City:IllegalFront"
["LC Arms Dealer Safehouse"]="300000:Liberty City:IllegalFront"
# =====================================================
# VICE CITY – EXPANSION
# =====================================================
["VC Beachfront Resort"]="750000:Vice City:Legal"
["VC Yacht Marina"]="500000:Vice City:Legal"
["VC Record Label"]="350000:Vice City:Legal"
["VC Fashion House"]="450000:Vice City:Legal"

["VC Cartel Mansion"]="900000:Vice City:IllegalFront"
["VC Offshore Drug Route"]="800000:Vice City:IllegalFront"
["VC Money Printing Operation"]="1000000:Vice City:IllegalFront"
["VC Smuggler Fleet"]="650000:Vice City:IllegalFront"

# =====================================================
# BLAINE COUNTY – EXPANSION
# =====================================================
["BC Oil Field"]="600000:Blaine County:Legal"
["BC Wind Farm"]="350000:Blaine County:Legal"
["BC Private Airfield"]="500000:Blaine County:Legal"
["BC Ranch Estate"]="275000:Blaine County:Legal"

["BC Cartel Safehouse"]="450000:Blaine County:IllegalFront"
["BC Desert Drug Pipeline"]="700000:Blaine County:IllegalFront"
["BC Illegal Weapons Bunker"]="800000:Blaine County:IllegalFront"
["BC Biker Gang Compound"]="650000:Blaine County:IllegalFront"
    )
    owned_businesses=()
    world_event_log=() # Clear the log on new game
    perks=() # Clear perks on new game
    perk_points=0
    last_respect_milestone=0
    # 
    GANG_HOME_CITY=(
    # =========================
    # LOS SANTOS
    # =========================
    ["Grove Street"]="Los Santos"
    ["Ballas"]="Los Santos"
    ["Vagos"]="Los Santos"
    ["Families"]="Los Santos"
    ["Los Santos Triads"]="Los Santos"
    ["Da Hood Crew"]="Los Santos"

    # =========================
    # BLAINE COUNTY (HD Universe)
    # =========================
    ["Lost MC"]="Blaine County"
    ["Rednecks"]="Blaine County"
    ["Blaine Outlaws"]="Blaine County"

    # =========================
    # SAN FIERRO
    # =========================
    ["Triads"]="San Fierro"
    ["Da Nang Boys"]="San Fierro"
    ["San Fierro Families"]="San Fierro"

    # =========================
    # LAS VENTURAS
    # =========================
    ["Leone Family"]="Las Venturas"
    ["Sindacco Family"]="Las Venturas"
    ["Vercetti Crew"]="Las Venturas"
    ["Mafia Syndicate"]="Las Venturas"

    # =========================
    # LIBERTY CITY
    # =========================
    ["The Commission"]="Liberty City"
    ["Triads"]="Liberty City"
    ["East Island Posse"]="Liberty City"
    ["Pegorino Family"]="Liberty City"
    ["Ierse Maffia"]="Liberty City"
    ["Ancelotti Family"]="Liberty City"
    ["Lupisella Family"]="Liberty City"
    ["Russische Bratva"]="Liberty City"
    ["Colombian Cartel"]="Liberty City"
    ["Yakuza"]="Liberty City"
    ["Italian Mob"]="Liberty City"
    ["Drug Dealers"]="Liberty City"

    # =========================
    # VICE CITY
    # =========================
    ["Cuban Gang"]="Vice City"
    ["Haitian Gang"]="Vice City"
    ["Cartel"]="Vice City"
    ["Vice City Triads"]="Vice City"
    ["Street Runners"]="Vice City"
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
    echo "# On Arch Linux: sudo pacman -S mpg123                    #"
    echo "# On macOS with Homebrew: brew install mpg123             #"
    echo "# You can still play the game, but it will be silent.     #"
	echo "###########################################################"
	read -r -p "Press Enter to continue without sound..."
	mpg123_available=false
fi
if ! command -v bc &> /dev/null; then
	echo "###############################################################################"
	echo "# Warning: 'bc' command not found.                                            #"
	echo "# Advanced drug market calculations require bc.                               #"
	echo "# On Debian/Ubuntu: sudo apt install bc                                       #"
    echo "# On Arch Linux: sudo pacman -S bc                                            #"
    echo "# On macOS with Homebrew: brew install bc                                     #"
    echo "# You can still play the game, but drug market calculations will be basic.    #"
	echo "###############################################################################"
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
	echo "          |       About       |          "
	echo "-----------------------------------------"
	echo ""
	echo "Music and some SFX © 2024 by stuffbymax - Martin Petik"
	echo "Licensed under CC BY 4.0:"
	echo "https://creativecommons.org/licenses/by/4.0/"
	echo "for more information check the Creators.md in /sfx"
	echo ""
	echo "Full game code is licensed under the MIT License."
	echo "https://raw.githubusercontent.com/stuffbymax/Bash-Theft-Auto/refs/heads/main/LICENSE"
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

    # Check for perk point award
    local current_milestone=$(( player_respect / 1000 ))
    if (( current_milestone > last_respect_milestone )); then
        local points_earned=$(( current_milestone - last_respect_milestone ))
        perk_points=$(( perk_points + points_earned ))
        last_respect_milestone=$current_milestone
        echo -e "\n\e[1;95m*** PERK POINT EARNED! ***\e[0m"
        echo "You gained ${points_earned} Perk Point(s). You now have ${perk_points}."
        play_sfx_mpg "win_big"
    fi

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
        local upkeep; IFS=':' read -r _ _ upkeep <<< "$recruit"
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

run_clock() {
    local hours_to_pass=$1
    if (( hours_to_pass == 0 )); then return; fi
    
    local previous_hour=$game_hour
    game_hour=$((game_hour + hours_to_pass))

    # Trigger world events for every 4-hour block that passes
    local event_trigger_points=(0 4 8 12 16 20)
    for trigger_hour in "${event_trigger_points[@]}"; do
        if (( previous_hour < trigger_hour && game_hour >= trigger_hour )) || ( ((previous_hour > game_hour)) && (previous_hour < trigger_hour || game_hour >= trigger_hour) ); then
            process_world_events
            break # Only trigger once per action
        fi
    done

    # Check for day rollovers and trigger daily events
    while (( game_hour >= 24 )); do
        game_hour=$((game_hour - 24))
        game_day=$((game_day + 1))
        calculate_and_apply_payouts
    done
}

update_world_state() {
    # This function is now the main entry point for world simulation
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
    printf "Your Cash: \$%d\n" "$cash"
    echo "--------------------------------------------"
    echo " PISTOLS"
    echo "  1. Hawk 9        (\$100)  - Reliable sidearm"
    echo "  2. Rex 38        (\$150)  - Hard-hitting revolver"
    echo "  3. Bulldog 45    (\$200)  - Heavy duty handgun"
    echo "--------------------------------------------"
    echo " SHOTGUNS"
    echo "  4. Striker 12    (\$250)  - Pump action"
    echo "  5. Undertaker    (\$300)  - Sawn-off, close range"
    echo "--------------------------------------------"
    echo " SUBMACHINE GUNS"
    echo "  6. Viper SMG     (\$500)  - Fast and compact"
    echo "  7. Spectre PDW   (\$600)  - Military grade"
    echo "--------------------------------------------"
    echo " RIFLES & ASSAULT"
    echo "  8. Phantom Carbine (\$700) - Versatile carbine"
    echo "  9. AR-7 Assault  (\$750)  - Full auto rifle"
    echo "--------------------------------------------"
    echo " HEAVY"
    echo " 10. Ravager LMG   (\$900)  - Light machine gun"
    echo " 11. Diamondback MG(\$1100) - Destroyer"
    echo "--------------------------------------------"
    echo " SNIPER"
    echo " 12. Ghost Sniper  (\$1000) - Long range precision"
    echo "--------------------------------------------"
    echo " 13. Leave"
    echo "--------------------------------------------"
    read -r -p "Enter your choice: " gun_choice
    [[ ! "$gun_choice" =~ ^[0-9]+$ ]] && { echo "Invalid input."; read -r -p "Press Enter..."; return; }
    case "$gun_choice" in
        1)  buy_gun "Hawk 9" 100;;
        2)  buy_gun "Rex 38" 150;;
        3)  buy_gun "Bulldog 45" 200;;
        4)  buy_gun "Striker 12" 250;;
        5)  buy_gun "Undertaker Sawn-off" 300;;
        6)  buy_gun "Viper SMG" 500;;
        7)  buy_gun "Spectre PDW" 600;;
        8)  buy_gun "Phantom Carbine" 700;;
        9)  buy_gun "AR-7 Assault" 750;;
        10) buy_gun "Ravager LMG" 900;;
        11) buy_gun "Diamondback MG" 1100;;
        12) buy_gun "Ghost Sniper" 1000;;
        13) return;;
        *)  echo "Invalid choice."; read -r -p "Press Enter...";;
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
    while true; do
        clear_screen; echo "--- Inventory & Stats ---"
        printf " Cash: \$%d\n" "$cash"; printf " Health: %d%%\n" "$health"
        echo "--------------------------"
        echo " Gang Affiliation:"
        if [[ "$player_gang" == "None" ]]; then
            printf "  - Gang: N/A\n"; printf "  - Rank: N/A\n"
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
        if (( ${#items[@]} > 0 )); then
            local i=1
            for item in "${items[@]}"; do
                printf "  %d. %s\n" "$i" "$item"; ((i++))
            done
            echo "--------------------------"
            echo " U. Use an item   B. Back"
        else
            echo "  (None)"
            echo "--------------------------"
            echo " B. Back"
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
        echo " Vehicles:"
        if (( ${#owned_vehicles[@]} > 0 )); then printf "  - %s\n" "${owned_vehicles[@]}"; else echo "  (None)"; fi
        echo "--------------------------"
        echo " Skills:"
        for skill in "${!default_skills[@]}"; do
            printf "  - %-12s: %d\n" "$skill" "${skills[$skill]:-0}"
        done
        echo "--------------------------"
        echo " Owned Properties/Businesses:"
        if (( ${#owned_businesses[@]} > 0 )); then
            for prop in "${!owned_businesses[@]}"; do
                printf "  - %-20s (%s)\n" "$prop" "${owned_businesses[$prop]// / | }"
            done
        else
            echo "  (None)"
        fi
        echo "--------------------------"
        read -r -p "Choice: " inv_choice
        case "${inv_choice,,}" in
            u)
                if (( ${#items[@]} == 0 )); then echo "No items to use."; sleep 1; continue; fi
                read -r -p "Enter item number to use: " item_num
                if ! [[ "$item_num" =~ ^[0-9]+$ ]] || (( item_num < 1 || item_num > ${#items[@]} )); then
                    echo "Invalid."; sleep 1; continue
                fi
                local chosen_item="${items[$((item_num - 1))]}"
                use_item "$chosen_item" $((item_num - 1))
                ;;
            b) return;;
            *) sleep 1;;
        esac
    done
}

use_item() {
    local item_name="$1"
    local item_index="$2"
    case "$item_name" in
        "Health Pack")
            local heal_amount=40
            if [[ -v "perks[Back Alley Surgeon]" ]]; then
                heal_amount=$(( heal_amount * 125 / 100 ))
            fi
            local old_health=$health
            health=$(( health + heal_amount ))
            (( health > 100 )) && health=100
            local actual_heal=$(( health - old_health ))
            echo -e "Used Health Pack. Restored \e[1;32m${actual_heal}%%\e[0m health."
            play_sfx_mpg "heal"
            # Remove the used item
            items=("${items[@]:0:$item_index}" "${items[@]:$((item_index + 1))}")
            ;;
        "Molotov Cocktail")
            echo "You hurl the Molotov at a nearby vehicle. Chaos erupts!"
            district_heat["$location"]=$(( ${district_heat[$location]:-0} + 5 ))
            wanted_level=$(( wanted_level + 1 ))
            (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
            play_sfx_mpg "lose"
            items=("${items[@]:0:$item_index}" "${items[@]:$((item_index + 1))}")
            ;;
        "Fake ID")
            if (( wanted_level > 0 )); then
                wanted_level=$(( wanted_level - 1 ))
                echo -e "\e[1;32mFake ID used!\e[0m The cops don't recognise you. Wanted level reduced."
                items=("${items[@]:0:$item_index}" "${items[@]:$((item_index + 1))}")
            else
                echo "No wanted level to reduce. ID saved."
            fi
            ;;
        "Adrenaline Shot")
            health=$(( health + 25 ))
            skills[strength]=$(( ${skills[strength]:-1} + 2 ))
            echo -e "\e[1;32mAdrenaline pumping!\e[0m +25 health, temporary strength boost."
            play_sfx_mpg "heal_adv"
            items=("${items[@]:0:$item_index}" "${items[@]:$((item_index + 1))}")
            ;;
        *)
            echo "You can't use $item_name right now."
            ;;
    esac
    read -r -p "Press Enter..."
}

work_job() {
	local job_type="$1"
    run_clock 4
	local earnings=0 base_earnings=0 skill_bonus=0; local min_earnings=0 max_earnings=0
	local relevant_skill_level=1 relevant_skill_name=""
    case "$location" in
        "Los Santos")   min_earnings=20;    max_earnings=70;;
        "San Fierro")   min_earnings=25;    max_earnings=80;;
        "Las Venturas") min_earnings=35;    max_earnings=110;;
        "Vice City")    min_earnings=15;    max_earnings=60;;
        "Liberty City") min_earnings=40;    max_earnings=130;;
        *)              min_earnings=10;    max_earnings=40;;
    esac
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
        "bartender")
            relevant_skill_name="charisma"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 4))
            play_sfx_mpg "bar"
            ;;
        "dock_worker")
            relevant_skill_name="strength"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 3))
            play_sfx_mpg "dock_worker"
            ;;
        "construction")
            relevant_skill_name="strength"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 4))
            play_sfx_mpg "construction"
            ;;
        "chef")
            relevant_skill_name="charisma"
            relevant_skill_level=${skills[$relevant_skill_name]:-1}
            skill_bonus=$((relevant_skill_level * 6))
            play_sfx_mpg "street_performer"
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
    if [[ -v "perks[Professional Driver]" ]]; then base_win_chance=60; fi
	local win_chance=$(( base_win_chance + driving_skill * 5 )); (( win_chance > 95 )) && win_chance=95
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
    if [[ -v "perks[Street Negotiator]" ]]; then
        item_cost=$(( item_cost * 90 / 100 )) # 10% discount
    fi

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
        local wanted_gain=1
        if [[ -v "perks[Master of Disguise]" ]]; then wanted_gain=0; fi
		wanted_level=$((wanted_level + wanted_gain)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
        if (( wanted_gain > 0 )); then echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"; fi
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
        local wanted_gain=1
        if [[ -v "perks[Master of Disguise]" ]]; then wanted_gain=0; fi
		wanted_level=$((wanted_level + wanted_gain)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_gain > 0 )); then echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"; fi
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
        local wanted_gain=2
        if [[ -v "perks[Master of Disguise]" ]]; then wanted_gain=1; fi
		wanted_level=$((wanted_level + wanted_gain)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_gain > 0 )); then echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"; fi
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
        local wanted_gain=1
        if [[ -v "perks[Master of Disguise]" ]]; then wanted_gain=0; fi
		wanted_level=$((wanted_level + wanted_gain)); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_gain > 0 )); then echo -e "\e[1;31mWanted Level Increased!\e[0m"; play_sfx_mpg "police_siren"; fi
		local fine=$((RANDOM % 76 + 25 + wanted_level * 20)); cash=$((cash - fine)); (( cash < 0 )) && cash=0
		health=$((health - (RANDOM % 26 + 10 + wanted_level * 6))); clear_screen
		printf "\e[1;31mFailed!\e[0m The owner fought back.\n"; printf "You were fined \$%d and took damage.\n" "$fine"
	fi
	check_health; read -r -p "Press Enter..."
}

pickpocket() {
    run_clock 1
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$(( 30 + stealth_skill * 6 ))
    (( base_chance > 90 )) && base_chance=90
    clear_screen; echo "--- Pickpocket ---"
    echo "You scan the crowd for a target..."; sleep 1
    if (( RANDOM % 100 < base_chance )); then
        local loot=$(( RANDOM % 81 + 20 + stealth_skill * 5 ))
        cash=$(( cash + loot ))
        echo -e "\e[1;32mSuccess!\e[0m You lifted \$$loot without them noticing."
        play_sfx_mpg "cash_register"
        award_respect $(( RANDOM % 5 + 1 ))
        district_heat["$location"]=$(( ${district_heat[$location]:-0} + 1 ))
        if (( RANDOM % 4 == 0 )); then
            skills[stealth]=$(( stealth_skill + 1 ))
            echo -e "Your \e[1;32mstealth\e[0m skill increased!"
        fi
    else
        local wanted_gain=1
        if [[ -v "perks[Master of Disguise]" ]]; then wanted_gain=0; fi
        wanted_level=$(( wanted_level + wanted_gain ))
        (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
        if (( wanted_gain > 0 )); then
            echo -e "\e[1;31mCaught! They felt your hand.\e[0m"
            play_sfx_mpg "police_siren"
        fi
        local fine=$(( RANDOM % 51 + 25 + wanted_level * 15 ))
        cash=$(( cash - fine )); (( cash < 0 )) && cash=0
        health=$(( health - (RANDOM % 11 + 5) ))
        echo "Fined \$$fine and roughed up."
    fi
    check_health; read -r -p "Press Enter..."
}

mug_someone() {
    run_clock 1
    local strength_skill=${skills[strength]:-1}
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$(( 25 + strength_skill * 5 + stealth_skill * 3 ))
    (( base_chance > 90 )) && base_chance=90
    clear_screen; echo "--- Mugging ---"
    echo "You follow someone into a quiet alley..."; sleep 1
    local final_chance=$(apply_gun_bonus "$base_chance" "mugging")
    echo "Final success chance: ${final_chance}%"
    read -r -p "Press Enter to make your move..."
    if (( RANDOM % 100 < final_chance )); then
        local loot=$(( RANDOM % 121 + 40 + strength_skill * 8 ))
        cash=$(( cash + loot ))
        health=$(( health - (RANDOM % 11) ))
        echo -e "\e[1;32mSuccess!\e[0m You got \$$loot."
        play_sfx_mpg "cash_register"
        award_respect $(( RANDOM % 8 + 3 ))
        district_heat["$location"]=$(( ${district_heat[$location]:-0} + 3 ))
        if (( RANDOM % 4 == 0 )); then
            skills[strength]=$(( strength_skill + 1 ))
            echo -e "Your \e[1;32mstrength\e[0m skill increased!"
        fi
    else
        local wanted_gain=1
        if [[ -v "perks[Master of Disguise]" ]]; then wanted_gain=0; fi
        wanted_level=$(( wanted_level + wanted_gain ))
        (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
        if (( wanted_gain > 0 )); then
            echo -e "\e[1;31mThey fought back and screamed for help!\e[0m"
            play_sfx_mpg "police_siren"
        fi
        local fine=$(( RANDOM % 76 + 40 + wanted_level * 20 ))
        cash=$(( cash - fine )); (( cash < 0 )) && cash=0
        health=$(( health - (RANDOM % 21 + 10) ))
        echo "Fined \$$fine and took a beating."
    fi
    check_health; read -r -p "Press Enter..."
}

arson() {
    run_clock 3
    local stealth_skill=${skills[stealth]:-1}
    local base_chance=$(( 20 + stealth_skill * 5 ))
    clear_screen; echo "--- Arson ---"
    echo "You scout out a target building..."; sleep 1
    echo "Final success chance: ${base_chance}%"
    read -r -p "Press Enter to proceed..."
    if (( RANDOM % 100 < base_chance )); then
        local payout=$(( RANDOM % 201 + 100 + stealth_skill * 15 ))
        cash=$(( cash + payout ))
        echo -e "\e[1;32mSuccess!\e[0m The building goes up in flames. Insurance payout: \$$payout."
        play_sfx_mpg "win"
        award_respect $(( RANDOM % 25 + 15 ))
        district_heat["$location"]=$(( ${district_heat[$location]:-0} + 10 ))
        if (( RANDOM % 3 == 0 )); then
            skills[stealth]=$(( stealth_skill + 1 ))
            echo -e "Your \e[1;32mstealth\e[0m skill increased!"
        fi
    else
        wanted_level=$(( wanted_level + 2 ))
        (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
        local fine=$(( RANDOM % 301 + 200 + wanted_level * 50 ))
        cash=$(( cash - fine )); (( cash < 0 )) && cash=0
        health=$(( health - (RANDOM % 31 + 20) ))
        echo -e "\e[1;31mCaught in the act!\e[0m Fined \$$fine, took burn damage."
        play_sfx_mpg "police_siren"
    fi
    check_health; read -r -p "Press Enter..."
}

kidnap_for_ransom() {
    run_clock 6
    local strength_skill=${skills[strength]:-1}
    local charisma_skill=${skills[charisma]:-1}
    local base_chance=$(( 15 + strength_skill * 4 + charisma_skill * 2 ))
    (( base_chance > 80 )) && base_chance=80
    clear_screen; echo "--- Kidnapping for Ransom ---"
    echo "High risk, high reward. You stake out a wealthy target..."; sleep 2
    local final_chance=$(apply_gun_bonus "$base_chance" "kidnapping")
    echo "Final success chance: ${final_chance}%"
    read -r -p "Press Enter to attempt..."
    if (( RANDOM % 100 < final_chance )); then
        local ransom=$(( RANDOM % 1001 + 500 + strength_skill * 50 ))
        cash=$(( cash + ransom ))
        health=$(( health - (RANDOM % 21 + 10) ))
        echo -e "\e[1;32mSuccess!\e[0m Ransom paid: \$$ransom. Target released unharmed."
        play_sfx_mpg "win_big"
        award_respect $(( RANDOM % 50 + 30 ))
        district_heat["$location"]=$(( ${district_heat[$location]:-0} + 20 ))
    else
        wanted_level=$(( wanted_level + 3 ))
        (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
        local fine=$(( RANDOM % 501 + 300 + wanted_level * 75 ))
        cash=$(( cash - fine )); (( cash < 0 )) && cash=0
        health=$(( health - (RANDOM % 41 + 20) ))
        echo -e "\e[1;31mOperation blown!\e[0m Fined \$$fine, wanted level spiked."
        play_sfx_mpg "lose_big"
    fi
    check_health; read -r -p "Press Enter..."
}

hospitalize_player() {
    run_clock 8
	local hospital_bill=200
	if [[ -v "perks[Street Negotiator]" ]]; then hospital_bill=$((hospital_bill * 90 / 100)); fi
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

# shops

visit_shop() {
    run_clock 1
    clear_screen
    echo "--- Street Shops in ${location} ---"
    echo "1. Convenience Store   (food, basic items)"
    echo "2. Black Market        (illegal goods, risky)"
    echo "3. Clothing Store      (disguises, armor)"
    echo "4. Back"
    read -r -p "Choice: " shop_choice
    case "$shop_choice" in
        1) convenience_store;;
        2) black_market;;
        3) clothing_store;;
        4) return;;
        *) echo "Invalid." && sleep 1;;
    esac
}

convenience_store() {
    while true; do
        clear_screen
        echo "--- Convenience Store ---"
        printf " Cash: \$%d  |  Health: %d%%\n" "$cash" "$health"
        echo "================================"
        echo " 1. Snack          (\$10)  - Restore 10% health"
        echo " 2. Energy Drink   (\$25)  - Restore 20% health"
        echo " 3. First Aid Kit  (\$60)  - Restore 35% health"
        echo " 4. Health Pack    (\$30)  - Usable item, +40% health"
        echo " 5. Leave"
        echo "================================"
        read -r -p "Choice: " c
        local discount=1
        if [[ -v "perks[Street Negotiator]" ]]; then discount=0; fi
        case "$c" in
            1)
                local cost=$(( 10 - discount ))
                if (( cash >= cost )); then
                    cash=$(( cash - cost ))
                    health=$(( health + 10 ))
                    (( health > 100 )) && health=100
                    echo "Munching on a snack. +10% health."
                    play_sfx_mpg "heal"
                else echo "Not enough cash."; fi;;
            2)
                local cost=$(( 25 - (discount * 2) ))
                if (( cash >= cost )); then
                    cash=$(( cash - cost ))
                    health=$(( health + 20 ))
                    (( health > 100 )) && health=100
                    echo "Chugging an energy drink. +20% health."
                    play_sfx_mpg "heal"
                else echo "Not enough cash."; fi;;
            3)
                local cost=$(( 60 - (discount * 6) ))
                if (( cash >= cost )); then
                    cash=$(( cash - cost ))
                    health=$(( health + 35 ))
                    (( health > 100 )) && health=100
                    echo "Patched up with a first aid kit. +35% health."
                    play_sfx_mpg "heal"
                else echo "Not enough cash."; fi;;
            4)
                local cost=$(( 30 - (discount * 3) ))
                if (( cash >= cost )); then
                    cash=$(( cash - cost ))
                    items+=("Health Pack")
                    echo "Health Pack added to inventory."
                    play_sfx_mpg "item_buy"
                else echo "Not enough cash."; fi;;
            5) return;;
            *) echo "Invalid.";;
        esac
        read -r -p "Press Enter..."
    done
}

black_market() {
    clear_screen
    echo "--- Black Market ---"
    echo "You find a shady dealer in a back alley..."
    sleep 1
    # Random chance the dealer is actually a cop
    if (( RANDOM % 10 == 0 )); then
        echo -e "\e[1;31mIt's a sting operation!\e[0m Cops everywhere!"
        wanted_level=$(( wanted_level + 2 ))
        (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
        play_sfx_mpg "police_siren"
        read -r -p "Press Enter..."; return
    fi
    while true; do
        clear_screen
        echo "--- Black Market ---"
        printf " Cash: \$%d\n" "$cash"
        echo "================================"
        echo " 1. Molotov Cocktail  (\$75)  - Usable chaos item"
        echo " 2. Fake ID           (\$200) - Reduces wanted level by 1"
        echo " 3. Adrenaline Shot   (\$150) - Temp health and strength boost"
        echo " 4. Stolen Goods      (\$50)  - Sell for profit elsewhere"
        echo " 5. Leave"
        echo "================================"
        read -r -p "Choice: " c
        case "$c" in
            1)
                if (( cash >= 75 )); then
                    cash=$(( cash - 75 ))
                    items+=("Molotov Cocktail")
                    echo "One Molotov, wrapped in newspaper."
                    play_sfx_mpg "item_buy"
                else echo "Not enough cash."; fi;;
            2)
                if (( cash >= 200 )); then
                    cash=$(( cash - 200 ))
                    items+=("Fake ID")
                    echo "A convincing fake. Probably."
                    play_sfx_mpg "item_buy"
                else echo "Not enough cash."; fi;;
            3)
                if (( cash >= 150 )); then
                    cash=$(( cash - 150 ))
                    items+=("Adrenaline Shot")
                    echo "Handle with care."
                    play_sfx_mpg "item_buy"
                else echo "Not enough cash."; fi;;
            4)
                if (( cash >= 50 )); then
                    cash=$(( cash - 50 ))
                    items+=("Stolen Goods")
                    echo "Could be worth double if you find the right buyer."
                    play_sfx_mpg "item_buy"
                else echo "Not enough cash."; fi;;
            5) return;;
            *) echo "Invalid.";;
        esac
        read -r -p "Press Enter..."
    done
}

clothing_store() {
    while true; do
        clear_screen
        echo "--- Zip Clothing ---"
        printf " Cash: \$%d\n" "$cash"
        echo "================================"
        echo " 1. Street Clothes    (\$50)  - Reduce heat by 2"
        echo " 2. Business Suit     (\$150) - Reduce heat by 5, +charisma"
        echo " 3. Body Armor        (\$100) - Equip armor (if not equipped)"
        echo " 4. Disguise Kit      (\$175) - Reduce wanted level by 1"
        echo " 5. Leave"
        echo "================================"
        local discount=0
        if [[ -v "perks[Street Negotiator]" ]]; then discount=1; fi
        read -r -p "Choice: " c
        case "$c" in
            1)
                local cost=$(( 50 - (discount * 5) ))
                if (( cash >= cost )); then
                    cash=$(( cash - cost ))
                    district_heat["$location"]=$(( ${district_heat[$location]:-0} - 2 ))
                    (( ${district_heat[$location]:-0} < 0 )) && district_heat["$location"]=0
                    echo "Fresh outfit. You blend in better."
                    play_sfx_mpg "item_buy"
                else echo "Not enough cash."; fi;;
            2)
                local cost=$(( 150 - (discount * 15) ))
                if (( cash >= cost )); then
                    cash=$(( cash - cost ))
                    district_heat["$location"]=$(( ${district_heat[$location]:-0} - 5 ))
                    (( ${district_heat[$location]:-0} < 0 )) && district_heat["$location"]=0
                    skills[charisma]=$(( ${skills[charisma]:-1} + 1 ))
                    echo "Looking sharp. Charisma up, heat down."
                    play_sfx_mpg "item_buy"
                else echo "Not enough cash."; fi;;
            3)
                local cost=$(( 100 - (discount * 10) ))
                if $body_armor_equipped; then
                    echo "You already have armor equipped."
                elif (( cash >= cost )); then
                    cash=$(( cash - cost ))
                    body_armor_equipped=true
                    echo "Body armor strapped on."
                    play_sfx_mpg "item_equip"
                else echo "Not enough cash."; fi;;
            4)
                local cost=$(( 175 - (discount * 17) ))
                if (( cash >= cost )); then
                    cash=$(( cash - cost ))
                    if (( wanted_level > 0 )); then
                        wanted_level=$(( wanted_level - 1 ))
                        echo "Wanted level reduced. New look, new you."
                    else
                        echo "No wanted level to reduce, but you look great."
                    fi
                    play_sfx_mpg "item_buy"
                else echo "Not enough cash."; fi;;
            5) return;;
            *) echo "Invalid.";;
        esac
        read -r -p "Press Enter..."
    done
}


drug_transaction() {
	local action="$1" drug_name="$2" base_price="$3" drug_amount="$4"
	local drug_dealer_skill=${skills[drug_dealer]:-1}
	if ! [[ "$drug_amount" =~ ^[1-9][0-9]*$ ]]; then echo "Invalid amount '$drug_amount'."; return 1; fi
	local price_fluctuation=$(( RANDOM % 21 - 10 ))
    local location_modifier=0
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

# --- Music Player Functions ---
stop_music() {
    if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
        echo "Stopping currently playing music..."
        kill "$music_pid" &>/dev/null
        wait "$music_pid" 2>/dev/null
        music_pid=""
    fi
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
        local owner="${territory_owner[$key]}"
        local city="${key%|*}"
        local district="${key#*|}"
        if [[ "$city" == "$location" ]]; then
            local display_owner="$owner"
            territory_found=true; local color="\e[0m"
            if [[ "$owner" == "$player_gang" && "$player_gang" != "None" ]]; then color="\e[1;36m"
            elif [[ "$owner" == "Grove Street" ]]; then color="\e[1;32m"
            elif [[ "$owner" == "Ballas" || "$owner" == "Leone Family" ]]; then color="\e[1;35m"
            elif [[ "$owner" == "Vagos" || "$owner" == "Triads" ]]; then color="\e[1;33m"
            elif [[ "$owner" == "Da Nang Boys" || "$owner" == "Sindacco Family" ]]; then color="\e[1;31m"
            elif [[ "$owner" == "Unaffiliated" ]]; then color="\e[1;37m"; display_owner="Government Control";
            else color="\e[1;37m"; fi
            printf "| %-20s | Owner: %b%s\e[0m\n" "$district" "$color" "$display_owner"
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
            if [[ "$pay" == "y" || "$pay" == "Y" ]]; then
                cash=$((cash-200)); player_gang="$new_gang"; player_gang_rank="Associate"; set_initial_gang_relations
                echo "You've paid your dues. Welcome to ${player_gang}."; award_respect 100
            else echo "You walked away. They won't be asking again."; fi
        else echo "You don't even have the cash to get their attention. Come back later."; fi
    else echo "Invalid choice."; fi
    read -r -p "Press Enter to continue..."
}

initiate_gang_war() {
    run_clock 3
    if [[ "$player_gang" == "None" || "$player_gang_rank" == "Outsider" ]]; then
        echo "You need to be part of a gang to start a war."; read -r -p "Press Enter..."; return
    fi
    if (( ${#guns[@]} == 0 )); then
        echo "You need a weapon to start a gang war!"; read -r -p "Press Enter..."; return
    fi

    local -a attackable_keys=()
    local i=0
    clear_screen
    echo "--- Select a Territory to Attack in ${location} ---"
    for key in "${!territory_owner[@]}"; do
        local city="${key%|*}"
        local district="${key#*|}"
        local owner="${territory_owner[$key]}"
        
        if [[ "$city" == "$location" && "$owner" != "$player_gang" ]]; then
            local display_owner="$owner"
            local color="\e[1;31m"
            if [[ "$owner" == "Unaffiliated" ]]; then
                display_owner="Government Control"
                color="\e[1;37m"
            fi
            # BUG FIX: Correctly increment the counter 'i' before printing.
            i=$((i + 1))
            printf " %d. Attack \e[1;33m%s\e[0m (Controlled by: %b%s\e[0m)\n" "$i" "$district" "$color" "$display_owner"
            attackable_keys+=("$key")
        fi
    done

    if (( ${#attackable_keys[@]} == 0 )); then
        echo "You hold all available territories in this city!"; read -r -p "Press Enter..."; return
    fi
    echo "---------------------------------------------------"
    local back_option_num=$((i + 1)); echo " ${back_option_num}. Back"; echo "---------------------------------------------------"
    read -r -p "Choose your target: " choice

    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > back_option_num )); then
        echo "Invalid choice."; read -r -p "Press Enter..."; return
    fi
    if (( choice == back_option_num )); then return; fi

    local index=$((choice - 1))
    if [[ -z "${attackable_keys[$index]}" ]]; then
        echo "Internal Error: Invalid territory key selected."
        read -r -p "Press Enter..."; return
    fi
    
    local target_key="${attackable_keys[$index]}"
    local rival_gang="${territory_owner[$target_key]}"
    local target_district="${target_key#*|}"

    clear_screen; echo -e "You are about to start a war for \e[1;33m${target_district}\e[0m in ${location}."
    if [[ "$rival_gang" != "Unaffiliated" ]]; then
        echo -e "It's controlled by the \e[1;31m${rival_gang}\e[0m."
    else
        echo "It's currently under government control, ripe for the taking."
    fi
    read -r -p "Are you ready to fight? (y/n) " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "You back off for now."; read -r -p "Press Enter..."; return
    fi

    local recruit_bonus=0; for recruit in "${player_recruits[@]}"; do local _ str _; IFS=':' read -r _ str _ <<< "$recruit"; recruit_bonus=$((recruit_bonus + str)); done
    local locker_level=${gang_upgrades[weapon_locker]:-0}; local locker_bonus=$((locker_level * 2)); local total_bonus=$((recruit_bonus + locker_bonus))
    if (( total_bonus > 0 )); then echo "Your crew gives you an edge: Recruits (+${recruit_bonus}%) + Weapon Locker (+${locker_bonus}%) = \e[1;32m+${total_bonus}%\e[0m"; fi
    
    if command -v gang_war_animation &> /dev/null; then gang_war_animation; else echo "Bullets start flying!"; sleep 1; fi
    
    if [[ "$rival_gang" != "Unaffiliated" ]]; then
        echo "The streets clear as the first wave of ${rival_gang} members arrive..."; sleep 2
    else
        echo "You move in to assert your dominance over the area..."; sleep 2
    fi
    local wave=1; local success=true
    local num_waves=$(( $RANDOM % 2 + 2 ))
    if [[ "$rival_gang" != "Unaffiliated" ]]; then num_waves=3; fi

    while (( wave <= num_waves )); do
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
        clear_screen; echo -e "\e[1;31m--- DEFEAT! ---\e[0m"
        if [[ "$rival_gang" == "Unaffiliated" ]]; then
            echo "You were forced to retreat. The area is too hot and remains under government control."
        else
            echo "You were forced to retreat. The ${rival_gang} hold their turf."
        fi
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

# gambling 

gambling_den() {
    if [[ "$location" != "Las Venturas" ]]; then
        echo "Gambling dens are only available in Las Venturas."
        read -r -p "Press Enter..."; return
    fi
    run_clock 1
    while true; do
        clear_screen
        echo "--- The Lucky Snake Casino ---"
        printf " Cash: \$%d\n" "$cash"
        echo "=============================="
        echo "1. Slot Machine   (\$25 bet)"
        echo "2. Dice Roll      (custom bet)"
        echo "3. High/Low Cards (custom bet)"
        echo "4. Leave"
        echo "=============================="
        read -r -p "Choice: " choice
        case "$choice" in
            1) gamble_slots;;
            2) gamble_dice;;
            3) gamble_cards;;
            4) return;;
            *) echo "Invalid." && sleep 1;;
        esac
    done
}

gamble_slots() {
    local bet=25
    if (( cash < bet )); then echo "Need \$$bet to play slots."; read -r -p "Press Enter..."; return; fi
    cash=$(( cash - bet ))
    local symbols=("CHERRY" "LEMON" "BELL" "BAR" "SEVEN" "SKULL")
    local r1=${symbols[RANDOM % ${#symbols[@]}]}
    local r2=${symbols[RANDOM % ${#symbols[@]}]}
    local r3=${symbols[RANDOM % ${#symbols[@]}]}
    echo ""; echo "  [ $r1 | $r2 | $r3 ]"; echo ""
    if [[ "$r1" == "$r2" && "$r2" == "$r3" ]]; then
        if [[ "$r1" == "SEVEN" ]]; then
            local win=$(( bet * 20 )); cash=$(( cash + win ))
            echo -e "\e[1;33m*** JACKPOT! TRIPLE SEVENS! +\$$win ***\e[0m"; play_sfx_mpg "win_big"
        elif [[ "$r1" == "SKULL" ]]; then
            local lose=$(( bet * 2 )); cash=$(( cash - lose )); (( cash < 0 )) && cash=0
            echo -e "\e[1;31m*** TRIPLE SKULL! You lose an extra \$$lose! ***\e[0m"; play_sfx_mpg "lose"
        else
            local win=$(( bet * 5 )); cash=$(( cash + win ))
            echo -e "\e[1;32mTriple match! +\$$win\e[0m"; play_sfx_mpg "win"
        fi
    elif [[ "$r1" == "$r2" || "$r2" == "$r3" || "$r1" == "$r3" ]]; then
        local win=$(( bet * 2 )); cash=$(( cash + win ))
        echo -e "\e[1;32mTwo of a kind! +\$$win\e[0m"; play_sfx_mpg "win"
    else
        echo -e "\e[1;31mNo match. You lost \$$bet.\e[0m"; play_sfx_mpg "lose"
    fi
    read -r -p "Press Enter..."
}

gamble_dice() {
    read -r -p "Enter your bet amount: \$" bet
    if ! [[ "$bet" =~ ^[1-9][0-9]*$ ]] || (( cash < bet )); then
        echo "Invalid bet or not enough cash."; read -r -p "Press Enter..."; return
    fi
    cash=$(( cash - bet ))
    local player_roll=$(( RANDOM % 6 + 1 + RANDOM % 6 + 1 ))
    local house_roll=$(( RANDOM % 6 + 1 + RANDOM % 6 + 1 ))
    echo "You rolled: $player_roll  |  House rolled: $house_roll"
    if (( player_roll > house_roll )); then
        local win=$(( bet * 2 )); cash=$(( cash + win ))
        echo -e "\e[1;32mYou win! +\$$bet\e[0m"; play_sfx_mpg "win"
    elif (( player_roll == house_roll )); then
        cash=$(( cash + bet ))
        echo -e "\e[1;33mTie — you get your bet back.\e[0m"
    else
        echo -e "\e[1;31mHouse wins. You lost \$$bet.\e[0m"; play_sfx_mpg "lose"
    fi
    read -r -p "Press Enter..."
}

gamble_cards() {
    read -r -p "Enter your bet amount: \$" bet
    if ! [[ "$bet" =~ ^[1-9][0-9]*$ ]] || (( cash < bet )); then
        echo "Invalid bet or not enough cash."; read -r -p "Press Enter..."; return
    fi
    local player_card=$(( RANDOM % 13 + 1 ))
    local house_card=$(( RANDOM % 13 + 1 ))
    cash=$(( cash - bet ))
    echo ""; echo "1. Higher   2. Lower"
    read -r -p "Will the house card be higher or lower than yours ($player_card)? " hl
    echo "House drew: $house_card"
    local correct=false
    if [[ "$hl" == "1" ]] && (( house_card > player_card )); then correct=true; fi
    if [[ "$hl" == "2" ]] && (( house_card < player_card )); then correct=true; fi
    if $correct; then
        local win=$(( bet * 2 )); cash=$(( cash + win ))
        echo -e "\e[1;32mCorrect! +\$$bet\e[0m"; play_sfx_mpg "win"
    elif (( house_card == player_card )); then
        cash=$(( cash + bet )); echo -e "\e[1;33mTie — bet returned.\e[0m"
    else
        echo -e "\e[1;31mWrong call. You lost \$$bet.\e[0m"; play_sfx_mpg "lose"
    fi
    read -r -p "Press Enter..."
}

# --- Save/Load System & Game Init ---
save_game() {
    run_clock 0
    local save_path="$BASEDIR/$SAVE_DIR"
    mkdir -p "$save_path" || { echo "Error: Could not create save directory '$save_path'."; return 1; }
    echo "Saving game state..."

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
    printf '%s\n' "${world_event_log[@]}" > "$save_path/log.sav"
    
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

    # BUG FIX: Use robust parameter expansion to parse save files instead of IFS
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        local key="${line%%@@@*}"
        local value="${line#*@@@}"
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
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" ]] && continue
            local key="${line%%@@@*}"
            local value="${line#*@@@}"
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
    load_indexed_array "$save_path/log.sav" "world_event_log"

    load_assoc_array() { local file_path="$1"; shift; declare -n arr_ref="$1"; arr_ref=(); if [[ -f "$file_path" ]]; then while IFS= read -r line || [[ -n "$line" ]]; do [[ -n "$line" ]] && local key="${line%%@@@*}" && local value="${line#*@@@}" && arr_ref["$key"]="$value"; done < "$file_path"; fi; }
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
remove_save_files() { rm -f "$BASEDIR/$SAVE_DIR"/*.sav &> /dev/null; }
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

# --- World Event System ---
show_news_feed() {
    clear_screen
    echo "--- World News & Rumors ---"
    if (( ${#world_event_log[@]} == 0 )); then
        echo "The streets are quiet... for now."
    else
        # Print logs in reverse chronological order
        for (( i=${#world_event_log[@]}-1; i>=0; i-- )); do
            echo -e "${world_event_log[i]}"
        done
    fi
    echo "---------------------------"
    read -r -p "Press Enter to return..."
}

calculate_gang_strength() {
    local gang_name="$1"
    local strength=0

    if [[ "$gang_name" == "Unaffiliated" ]]; then
        echo 15 # Base strength for government control/police
        return
    fi

    local territory_count=0
    for key in "${!territory_owner[@]}"; do
        if [[ "${territory_owner[$key]}" == "$gang_name" ]]; then
            ((territory_count++))
        fi
    done
    strength=$(( territory_count * 10 ))

    if [[ "$gang_name" == "$player_gang" ]]; then
        local recruit_bonus=0
        for recruit in "${player_recruits[@]}"; do
            local _ str _; IFS=':' read -r _ str _ <<< "$recruit"
            recruit_bonus=$((recruit_bonus + str * 2))
        done
        local locker_level=${gang_upgrades[weapon_locker]:-0}
        local locker_bonus=$((locker_level * 5))
        strength=$(( strength + recruit_bonus + locker_bonus ))
    fi
    echo $strength
}

handle_player_territory_defense() {
    local attacker_gang="$1"
    local target_key="$2"
    local city="${target_key%|*}"
    local district="${target_key#*|}"

    clear_screen
    play_sfx_mpg "police_siren"
    echo -e "\e[1;91m*** INCOMING ATTACK! ***\e[0m"
    echo -e "The \e[1;31m${attacker_gang}\e[0m are making a move on your territory in \e[1;33m${district}\e[0m!"
    echo "------------------------------------------------"
    echo "How do you want to respond?"
    echo "1. Lead the defense personally! (Higher success chance)"
    echo "2. Let your crew handle it. (Risky)"
    read -r -p "Choice: " defense_choice

    local player_gang_strength=$(calculate_gang_strength "$player_gang")
    local attacker_strength=$(calculate_gang_strength "$attacker_gang")
    local success=false

    case "$defense_choice" in
        1)
            echo "You rush to the scene to command your forces!"; sleep 2
            local success_chance=$(( 60 + player_gang_strength - attacker_strength ))
            (( success_chance < 10 )) && success_chance=10; (( success_chance > 90 )) && success_chance=90
            if (( RANDOM % 100 < success_chance )); then success=true; else health=$((health - (RANDOM % 30 + 10))); fi
            ;;
        2)
            echo "You trust your crew to handle the threat..."; sleep 2
            local success_chance=$(( 40 + player_gang_strength - attacker_strength ))
            (( success_chance < 5 )) && success_chance=5; (( success_chance > 80 )) && success_chance=80
            if (( RANDOM % 100 < success_chance )); then success=true; fi
            ;;
        *)
            echo "You hesitated and the opportunity was lost! Your crew was unprepared."; sleep 2
            success=false
            ;;
    esac

    if $success; then
        clear_screen; echo -e "\e[1;32m*** DEFENSE SUCCESSFUL! ***\e[0m"
        echo "You successfully repelled the ${attacker_gang}'s attack on ${district}!"; award_respect $((RANDOM % 50 + 25)); play_sfx_mpg "win"
    else
        clear_screen; echo -e "\e[1;31m--- TERRITORY LOST! ---\e[0m"
        echo "The ${attacker_gang} have overwhelmed your forces and seized control of ${district}!"; territory_owner["$target_key"]="$attacker_gang"
        player_respect=$((player_respect - 75)); ((player_respect < 0)) && player_respect=0
        echo "You lost 75 Respect in the humiliating defeat."; play_sfx_mpg "lose_big"; check_health
    fi
    read -r -p "Press Enter to continue..."
}

process_world_events() {
    local event_chance=25
    if (( RANDOM % 100 >= event_chance )); then return; fi

    local -a ai_gangs=(); for gang in "${!GANG_HOME_CITY[@]}"; do if [[ "$gang" != "$player_gang" ]]; then ai_gangs+=("$gang"); fi; done
    if (( ${#ai_gangs[@]} == 0 )); then return; fi
    local attacker_gang="${ai_gangs[RANDOM % ${#ai_gangs[@]}]}"
    local attacker_home_city="${GANG_HOME_CITY[$attacker_gang]}"
    
    local -a potential_targets=(); for key in "${!territory_owner[@]}"; do local city="${key%|*}"; if [[ "$city" == "$attacker_home_city" && "${territory_owner[$key]}" != "$attacker_gang" ]]; then potential_targets+=("$key"); fi; done
    if (( ${#potential_targets[@]} == 0 )); then return; fi
    
    local target_key="${potential_targets[RANDOM % ${#potential_targets[@]}]}"
    local defender_gang="${territory_owner[$target_key]}"
    
    if [[ "$defender_gang" == "$player_gang" ]]; then handle_player_territory_defense "$attacker_gang" "$target_key"; return; fi
    
    local attacker_strength=$(calculate_gang_strength "$attacker_gang")
    local defender_strength=$(calculate_gang_strength "$defender_gang")
    
    local city="${target_key%|*}"
    local district="${target_key#*|}"
    
    local log_msg=""
    if (( attacker_strength + (RANDOM % 30 - 15) > defender_strength )); then
        if [[ "$defender_gang" == "Unaffiliated" ]]; then
            log_msg="[Day $game_day] NEWS: The \e[1;31m${attacker_gang}\e[0m have wrestled control of \e[1;33m${district}\e[0m from government forces in ${city}!"
        else
            log_msg="[Day $game_day] NEWS: The \e[1;31m${attacker_gang}\e[0m have taken \e[1;33m${district}\e[0m from the \e[1;32m${defender_gang}\e[0m in ${city}!"
        fi
        territory_owner["$target_key"]="$attacker_gang"
    else
        if [[ "$defender_gang" == "Unaffiliated" ]]; then
             log_msg="[Day $game_day] RUMOR: A move by the \e[1;31m${attacker_gang}\e[0m on \e[1;33m${district}\e[0m was thwarted by heavy police presence."
        else
            log_msg="[Day $game_day] RUMOR: The \e[1;32m${defender_gang}\e[0m successfully defended \e[1;33m${district}\e[0m from an attack by the \e[1;31m${attacker_gang}\e[0m."
        fi
    fi
    world_event_log+=("$log_msg")
    
    if (( ${#world_event_log[@]} > 15 )); then world_event_log=("${world_event_log[@]:1}"); fi
}


# --- Main Execution & Loop ---
if ! run_initial_menu; then echo "Exiting due to initial menu failure or user request."; exit 1; fi

while true; do
	update_world_state
    check_police_encounter
	check_health && clear_screen || clear_screen
	echo "--- Actions ---"
	echo "1. Travel         | 7. Sell Drugs"
	echo "2. Buy Guns       | 8. Hire Hooker"
	echo "3. Buy Vehicle    | 9. Visit Hospital"
	echo "4. Inventory      | 10. Street Race"
	echo "5. Work (Legal)   | 11. Buy Drugs" 
    echo "12. gambling      | 13. Visit Shops"
	echo "6. Work (Crime)   | G. Gang & Empire Management"
	echo "------------------------------------------------------------"
	echo "S. Save Game     | L. Load Game     | N. News Feed"
	echo "M. Music Player  | A. About         | P. Perks"
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
    echo "1. Taxi Driver    | 2. Delivery Driver"
    echo "3. Mechanic       | 4. Security Guard"
    echo "5. Performer      | 6. Bus Driver"
    echo "7. Bartender      | 8. Dock Worker"
    echo "9. Construction   | 10. Chef"
    echo "11. Back"
    read -r -p "Enter choice: " job_choice
    case "$job_choice" in
        1) work_job "taxi";;
        2) work_job "delivery";;
        3) work_job "mechanic";;
        4) work_job "security";;
        5) work_job "performer";;
        6) work_job "bus_driver";;
        7) work_job "bartender";;
        8) work_job "dock_worker";;
        9) work_job "construction";;
        10) work_job "chef";;
        11) ;;
        *) echo "Invalid." && sleep 1;;
    esac;;
6) clear_screen; echo "--- Criminal Activities ---"
    echo "1. Rob Store    | 2. Carjack"
    echo "3. Burglary     | 4. Heist"
    echo "5. Pickpocket   | 6. Mug Someone"
    echo "7. Arson        | 8. Kidnap for Ransom"
    echo "9. Back"
    read -r -p "Enter choice: " criminal_choice
    case "$criminal_choice" in
        1) rob_store;; 2) carjack;;
        3) burglary;; 4) heist;;
        5) pickpocket;; 6) mug_someone;;
        7) arson;; 8) kidnap_for_ransom;;
        9) ;;
        *) echo "Invalid." && sleep 1;;
    esac;;

		7) sell_drugs;; 8) hire_hooker;; 9) visit_hospital;; 10) street_race;; 11) buy_drugs;;
        12) gambling_den;; 13) visit_shop;;
        'g') show_gang_menu;; 's') save_game;;
		'l') read -r -p "Load game? Unsaved progress will be lost. (y/n): " confirm
			 if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then load_game; fi ;;
        'n') show_news_feed;;
		'm') play_music;; 'a') about_music_sfx;;
        'p') manage_perks;;
		'x') read -r -p "Are you sure you want to exit? (y/n): " confirm
			 if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then cleanup_and_exit; fi ;;
		*) echo "Invalid choice '$choice'."; sleep 1;;
	esac
done
cleanup_and_exit