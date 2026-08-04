#!/bin/bash
set +H
# creator: stuffbymax (martinP)
# description: open world crime "simulator"
# ver 2.5.1
# New mechanics: Loan Shark, Black Market Auctions, Fence System,
#   Ambush System, Bounty on Player, Safe House Renting,
#   Drive-By Missions, Protection Racket, Gang Spy,
#   Training Gym, City Reputation, Wanted Level Decay,
#   Phone Contacts
# Licenses:
# Bash-Theft-Auto music © 2024 by stuffbymax - Martin Petik is licensed under CC BY 4.0
# https://creativecommons.org/licenses/by/4.0/
# code is licensed under MIT License

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


### --- Debug Functions ---
# commend it when you dont want debug features
# =============================================================================
# DEBUG SYSTEM
# =============================================================================
# Enable:  BTA_DEBUG=1 ./bta_enhanced.sh   OR   ./bta_enhanced.sh --debug
# Log:     bta_debug.log  (in BASEDIR, appended each session)
# Disable: BTA_DEBUG=0  or just don't set it
# =============================================================================

BTA_DEBUG_LOG="$BASEDIR/bta_debug.log"

# Accept --debug as first argument
if [[ "${1:-}" == "--debug" ]]; then
    BTA_DEBUG=1
    shift
fi

# Keep fd3 pointing at the real terminal so the game UI still displays,
# and tee stdout+stderr into the log file.
if [[ "${BTA_DEBUG:-0}" == "1" ]]; then
    exec 3>&1
    exec 1> >(tee -a "$BTA_DEBUG_LOG") 2>&1
fi

# --- dbg "message" ---
# Timestamped line to log only. No-op when debug is off.
dbg() {
    [[ "${BTA_DEBUG:-0}" != "1" ]] && return 0
    printf '[DBG %s] %s\n' "$(date '+%H:%M:%S')" "$*" >> "$BTA_DEBUG_LOG"
}

# --- dbg_section "title" ---
# Bold divider in the log for readability.
dbg_section() {
    [[ "${BTA_DEBUG:-0}" != "1" ]] && return 0
    {
        printf '\n%s\n' "$(printf '=%.0s' {1..60})"
        printf '  %s  [Day %s %02d:00]\n' "$*" "$game_day" "$game_hour"
        printf '%s\n' "$(printf '=%.0s' {1..60})"
    } >> "$BTA_DEBUG_LOG"
}

# --- dbg_var "VAR_NAME" ---
# Dumps a variable. Handles scalars, indexed arrays, assoc arrays.
dbg_var() {
    [[ "${BTA_DEBUG:-0}" != "1" ]] && return 0
    local var_name="$1"
    local var_type
    var_type=$(declare -p "$var_name" 2>/dev/null) || {
        printf '[DBG %s] VAR %s = <undefined>\n' "$(date '+%H:%M:%S')" "$var_name" >> "$BTA_DEBUG_LOG"
        return
    }
    printf '[DBG %s] VAR %s\n' "$(date '+%H:%M:%S')" "$var_name" >> "$BTA_DEBUG_LOG"
    if [[ "$var_type" == *"declare -A"* ]]; then
        local -n _dbg_ref="$var_name"
        for k in "${!_dbg_ref[@]}"; do
            printf '         [%s] = %s\n' "$k" "${_dbg_ref[$k]}" >> "$BTA_DEBUG_LOG"
        done
    elif [[ "$var_type" == *"declare -a"* ]]; then
        local -n _dbg_ref="$var_name"
        for i in "${!_dbg_ref[@]}"; do
            printf '         [%d] = %s\n' "$i" "${_dbg_ref[$i]}" >> "$BTA_DEBUG_LOG"
        done
    else
        local -n _dbg_ref="$var_name"
        printf '         = %s\n' "$_dbg_ref" >> "$BTA_DEBUG_LOG"
    fi
}

# --- dbg_player ---
# Full snapshot of player state.
dbg_player() {
    [[ "${BTA_DEBUG:-0}" != "1" ]] && return 0
    dbg_section "PLAYER STATE SNAPSHOT"
    dbg "name=$player_name  location=$location  cash=$cash  health=$health"
    dbg "wanted=$wanted_level  armor=$body_armor_equipped  respect=$player_respect"
    dbg "gang=$player_gang  rank=$player_gang_rank  perk_points=$perk_points"
    dbg "day=$game_day  hour=$game_hour"
    dbg "loan=$loan_amount  interest=$loan_interest  rate=$loan_rate"
    dbg "bounty=$player_bounty  hitman=$bounty_hitman_name"
    dbg "safehouse=$rented_safehouse"
    dbg_var "skills"
    dbg_var "guns"
    dbg_var "items"
    dbg_var "drugs"
    dbg_var "owned_vehicles"
    dbg_var "perks"
    dbg_var "contacts_unlocked"
}

# --- dbg_world ---
# Snapshot of world/territory state.
dbg_world() {
    [[ "${BTA_DEBUG:-0}" != "1" ]] && return 0
    dbg_section "WORLD STATE SNAPSHOT"
    dbg_var "district_heat"
    dbg_var "city_reputation"
    dbg "territory_owner entries: ${#territory_owner[@]}"
    dbg "owned_businesses entries: ${#owned_businesses[@]}"
    dbg "protection_income entries: ${#protection_income[@]}"
    dbg "world_event_log entries: ${#world_event_log[@]}"
    if [[ "$player_gang" != "None" ]]; then
        dbg_var "gang_upgrades"
        dbg_var "gang_relations"
        dbg "player_recruits count: ${#player_recruits[@]}"
    fi
}

# --- dbg_timing_start "label" / dbg_timing_end "label" ---
# Measures milliseconds between two points.
declare -A _dbg_timers=()
dbg_timing_start() {
    [[ "${BTA_DEBUG:-0}" != "1" ]] && return 0
    _dbg_timers["$1"]=$(date +%s%N)
}
dbg_timing_end() {
    [[ "${BTA_DEBUG:-0}" != "1" ]] && return 0
    local label="$1"
    local start=${_dbg_timers[$label]:-0}
    (( start == 0 )) && { dbg "TIMING [$label]: no start recorded"; return; }
    local elapsed_ms=$(( ($(date +%s%N) - start) / 1000000 ))
    dbg "TIMING [$label]: ${elapsed_ms}ms"
    unset '_dbg_timers[$label]'
}

# --- dbg_assert "condition" "message" ---
# Logs PASS or FAIL for a bash condition.
# Example: dbg_assert "(( cash >= 0 ))" "cash must never be negative"
dbg_assert() {
    [[ "${BTA_DEBUG:-0}" != "1" ]] && return 0
    if eval "$1" 2>/dev/null; then
        dbg "ASSERT PASS: $2"
    else
        dbg "ASSERT FAIL: $2  [condition: $1]"
    fi
}

# --- Session header ---
if [[ "${BTA_DEBUG:-0}" == "1" ]]; then
    {
        printf '\n%s\n' "$(printf '#%.0s' {1..60})"
        printf '# BTA DEBUG SESSION START\n'
        printf '# Date:    %s\n' "$(date)"
        printf '# Script:  %s\n' "$0"
        printf '# BASEDIR: %s\n' "$BASEDIR"
        printf '# PID:     %s\n' "$$"
        printf '# Bash:    %s\n' "$BASH_VERSION"
        printf '%s\n\n' "$(printf '#%.0s' {1..60})"
    } >> "$BTA_DEBUG_LOG"
fi

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
wanted_level=0
MAX_WANTED_LEVEL=5
declare -a owned_vehicles=()
declare -A vehicle_types=( ["Sedan"]=2000 ["Motorcycle"]=1500 ["Truck"]=2500 ["Sports Car"]=5000 )
declare -A market_conditions=()
declare -a world_event_log=()

# --- NEW: Loan Shark Variables ---
loan_amount=0          # Current outstanding loan principal
loan_interest=0        # Accumulated interest
loan_due_day=0         # Day the loan was taken (for interest compounding)
loan_enforcer_warned=false

# --- NEW: City Reputation Variables ---
declare -A city_reputation=()  # ["City Name"]=0-100

# --- NEW: Protection Racket Variables ---
declare -A protection_targets=()   # ["Business Name"]="city:weekly_income:heat_risk:days_since_paid"
declare -A protection_income=()    # ["Business Name"]=income_per_day

# --- NEW: Safe House Rental Variables ---
rented_safehouse=""         # Name of currently rented safe house city
safehouse_rent_day=0        # Day rent was last paid
SAFEHOUSE_RENT_COST=200     # Daily cost

# --- NEW: Phone Contacts Variables ---
declare -A contacts_unlocked=()  # ["contact_name"]=1 if unlocked
# contact names: "dealer" "corrupt_cop" "mechanic" "fence_king" "loan_fixer"

# --- NEW: Active Bounty on Player Variables ---
player_bounty=0             # Cash bounty on the player's head
bounty_hitman_name=""       # Name of active hitman if any

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
    ["Hawk 9 silencer"]="success_bonus=20"
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

# --- Perk Functions ---
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

# --- Police Encounter System ---
check_police_encounter() {
    (( wanted_level == 0 )) && return
    local encounter_chance=$(( wanted_level * 12 ))
    (( RANDOM % 100 >= encounter_chance )) && return

    clear_screen
    play_sfx_mpg "police_siren"
    echo -e "\e[1;31m*** POLICE ENCOUNTER! ***\e[0m"
    echo "Wanted Level: $(printf '*%.0s' $(seq 1 $wanted_level))"
    echo "------------------------------------------------"

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
            if [[ -v "perks[Street Negotiator]" ]]; then bribe=$(( bribe * 90 / 100 )); fi
            # Corrupt cop contact gives 20% discount
            if [[ -v "contacts_unlocked[corrupt_cop]" ]]; then bribe=$(( bribe * 80 / 100 )); fi
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
PAYOUT_HOUR=0

# --- Gang System ---
player_gang="None"
player_gang_rank="Outsider"
player_respect=0
declare -a player_recruits=()
max_recruits=2
declare -A gang_upgrades=()
declare -A gang_relations=()

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

# --- NEW: Black Market Auction Variables ---
declare -A current_auction=()   # ["item"] ["min_bid"] ["current_bid"] ["ends_day"]
auction_active=false

# =====================================================
# Initialize World Data
# =====================================================
initialize_world_data() {
    territory_owner=(
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
["LS Arms Manufacturing"]="600000:Los Santos:IllegalFront"
["LS Counterfeit Cash Operation"]="450000:Los Santos:IllegalFront"
["LS Diamond casino"]="92717297:Los Santos:Legal"
["SF Cyber Security Firm"]="400000:San Fierro:Legal"
["SF Investment Bank"]="850000:San Fierro:Legal"
["SF Shipping Corporation"]="500000:San Fierro:Legal"
["SF High Rise Apartments"]="320000:San Fierro:Legal"
["SF Crypto Mining Farm"]="275000:San Fierro:IllegalFront"
["SF Offshore Laundering"]="650000:San Fierro:IllegalFront"
["SF Port Smuggling Network"]="450000:San Fierro:IllegalFront"
["SF Underground Casino"]="500000:San Fierro:IllegalFront"
["LV Mega Casino"]="900000:Las Venturas:Legal"
["LV Entertainment Arena"]="650000:Las Venturas:Legal"
["LV Convention Center"]="550000:Las Venturas:Legal"
["LV Luxury Resort"]="1200000:Las Venturas:Legal"
["LV Rigged Casino"]="700000:Las Venturas:IllegalFront"
["LV Underground Betting Syndicate"]="450000:Las Venturas:IllegalFront"
["LV Counterfeit Chip Factory"]="500000:Las Venturas:IllegalFront"
["LV Smuggling Tunnel"]="600000:Las Venturas:IllegalFront"
["LV Mafia Headquarters"]="1000000:Las Venturas:IllegalFront"
["LC Wall Street Office"]="950000:Liberty City:Legal"
["LC Wall Street Office 2"]="100000:Liberty City:Legal"
["LC Shipping Terminal"]="450000:Liberty City:Legal"
["LC Media Corporation"]="800000:Liberty City:Legal"
["LC Luxury Condos"]="600000:Liberty City:Legal"
["LC Underground Arms Trade"]="550000:Liberty City:IllegalFront"
["LC International Drug Hub"]="850000:Liberty City:IllegalFront"
["LC Russian Syndicate HQ"]="950000:Liberty City:IllegalFront"
["LC Mafia Commission Office"]="1200000:Liberty City:IllegalFront"
["VC Beachfront Resort"]="750000:Vice City:Legal"
["VC Yacht Marina"]="500000:Vice City:Legal"
["VC Record Label"]="350000:Vice City:Legal"
["VC Fashion House"]="450000:Vice City:Legal"
["VC Cartel Mansion"]="900000:Vice City:IllegalFront"
["VC Offshore Drug Route"]="800000:Vice City:IllegalFront"
["VC Money Printing Operation"]="1000000:Vice City:IllegalFront"
["VC Smuggler Fleet"]="650000:Vice City:IllegalFront"
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
    world_event_log=()
    perks=()
    perk_points=0
    last_respect_milestone=0

    GANG_HOME_CITY=(
    ["Grove Street"]="Los Santos"
    ["Ballas"]="Los Santos"
    ["Vagos"]="Los Santos"
    ["Families"]="Los Santos"
    ["Lost MC"]="Blaine County"
    ["Triads"]="San Fierro"
    ["Da Nang Boys"]="San Fierro"
    ["Leone Family"]="Las Venturas"
    ["Sindacco Family"]="Las Venturas"
    ["The Commission"]="Liberty City"
    ["Colombian Cartel"]="Liberty City"
    ["Yakuza"]="Liberty City"
    ["Italian Mob"]="Liberty City"
    ["Drug Dealers"]="Liberty City"
    ["Cuban Gang"]="Vice City"
    ["Haitian Gang"]="Vice City"
    )

    player_recruits=()
    gang_upgrades=( ["safe_house"]=0 ["weapon_locker"]=0 ["smuggling_routes"]=0 )
    gang_relations=()
    apply_gang_upgrades

    # Initialize city reputations
    city_reputation=(
        ["Los Santos"]=10
        ["San Fierro"]=10
        ["Las Venturas"]=10
        ["Vice City"]=10
        ["Liberty City"]=10
        ["Blaine County"]=10
    )

    # Initialize protection targets per city
    protection_targets=(
        ["Vinewood Burger Bar"]="Los Santos:120:15:0"
        ["Downtown Pawn Shop"]="Los Santos:80:10:0"
        ["Harbor Fish Market"]="San Fierro:100:12:0"
        ["Chinatown Noodle House"]="San Fierro:90:18:0"
        ["Strip Club Lucky Ace"]="Las Venturas:200:20:0"
        ["Pawn Palace"]="Las Venturas:150:15:0"
        ["Vice Beach Bar"]="Vice City:130:14:0"
        ["Miami Ink Tattoo"]="Vice City:95:10:0"
        ["LC Deli"]="Liberty City:110:16:0"
        ["Broker Hardware"]="Liberty City:85:12:0"
    )

    # Reset new mechanic variables
    loan_amount=0
    loan_interest=0
    loan_due_day=0
    loan_enforcer_warned=false
    rented_safehouse=""
    safehouse_rent_day=0
    contacts_unlocked=()
    player_bounty=0
    bounty_hitman_name=""
    auction_active=false
    current_auction=()
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
	if [[ "$player_gang" == "None" ]]; then display_gang="N/A"; display_rank="N/A"; fi
	printf " Gang: %-20s Rank: %s\n" "$display_gang" "$display_rank"
	printf " Respect: %-16d District Heat: %s\n" "${player_respect}" "${district_heat[$location]:-0}"
	local city_rep=${city_reputation[$location]:-0}
	printf " City Rep [%s]: %-5d" "$location" "$city_rep"
	if (( loan_amount > 0 )); then
		printf " | \e[1;31mLOAN: \$%d (+ \$%d interest)\e[0m" "$loan_amount" "$loan_interest"
	fi
	printf "\n"
	if (( player_bounty > 0 )); then
		printf " \e[1;35mBOUNTY ON YOUR HEAD: \$%d\e[0m\n" "$player_bounty"
	fi
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

	# City reputation boost
	city_reputation[$location]=$(( ${city_reputation[$location]:-0} + (amount / 10) ))
	(( ${city_reputation[$location]} > 100 )) && city_reputation[$location]=100

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
		local current_rank_index=-1; local next_rank_index=-1
		for i in "${!GANG_RANK_HIERARCHY[@]}"; do
			if [[ "${GANG_RANK_HIERARCHY[$i]}" == "$player_gang_rank" ]]; then
				current_rank_index=$i; next_rank_index=$((i + 1)); break
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

# =====================================================
# NEW: City Reputation System
# =====================================================
show_city_reputation() {
	clear_screen
	echo "--- City Reputation ---"
	echo "Your reputation determines job pay bonuses, shop discounts, and NPC reactions."
	echo "==========================================="
	for city in "Los Santos" "San Fierro" "Las Venturas" "Vice City" "Liberty City" "Blaine County"; do
		local rep=${city_reputation[$city]:-0}
		local rep_label=""
		local color=""
		if (( rep >= 80 )); then rep_label="Legend"; color="\e[1;33m"
		elif (( rep >= 60 )); then rep_label="Known"; color="\e[1;32m"
		elif (( rep >= 40 )); then rep_label="Respected"; color="\e[1;36m"
		elif (( rep >= 20 )); then rep_label="Noticed"; color="\e[1;37m"
		else rep_label="Unknown"; color="\e[0;37m"; fi
		printf " %-18s Rep: %b%3d\e[0m (%s)\n" "$city" "$color" "$rep" "$rep_label"
	done
	echo "==========================================="
	echo "Benefits: 20+ = +5% job pay | 40+ = shop discount | 60+ = contact unlock hints | 80+ = feared (crime success boost)"
	read -r -p "Press Enter..."
}

get_city_rep_bonus() {
	local rep=${city_reputation[$location]:-0}
	if (( rep >= 80 )); then echo 15
	elif (( rep >= 60 )); then echo 10
	elif (( rep >= 40 )); then echo 5
	elif (( rep >= 20 )); then echo 3
	else echo 0; fi
}

# =====================================================
# NEW: Loan Shark System
# =====================================================
visit_loan_shark() {
	run_clock 1
	while true; do
		clear_screen
		echo "--- Vinnie's Loan Shop ---"
		echo "\"Money when you need it. Pain when you don't pay.\""
		echo "============================================"
		if (( loan_amount > 0 )); then
			printf " Current Loan:    \e[1;31m\$%d\e[0m\n" "$loan_amount"
			printf " Interest Owed:   \e[1;31m\$%d\e[0m\n" "$loan_interest"
			printf " Total to Repay:  \e[1;31m\$%d\e[0m\n" "$(( loan_amount + loan_interest ))"
			printf " Loan Taken Day:  %d (Today: Day %d)\n" "$loan_due_day" "$game_day"
			echo "============================================"
			echo "1. Repay loan in full"
			echo "2. Make partial payment"
			echo "3. Leave"
		else
			echo " You have no outstanding loans."
			echo "============================================"
			echo " Available Loans:"
			echo "  1. Small Loan   - \$500  (15% daily interest)"
			echo "  2. Medium Loan  - \$2000 (20% daily interest)"
			echo "  3. Large Loan   - \$5000 (25% daily interest)"
			echo "  4. Leave"
		fi
		echo "============================================"
		read -r -p "Choice: " choice
		if (( loan_amount > 0 )); then
			case "$choice" in
				1)
					local total=$(( loan_amount + loan_interest ))
					if (( cash >= total )); then
						cash=$(( cash - total ))
						echo -e "\e[1;32mLoan fully repaid! You owe nothing.\e[0m"
						play_sfx_mpg "cash_register"
						loan_amount=0; loan_interest=0; loan_due_day=0; loan_enforcer_warned=false
					else
						echo -e "\e[1;31mNot enough cash. Need \$$total.\e[0m"
					fi
					read -r -p "Press Enter..."; ;;
				2)
					read -r -p "How much to pay? \$" pay_amount
					if [[ "$pay_amount" =~ ^[1-9][0-9]*$ ]] && (( cash >= pay_amount )); then
						cash=$(( cash - pay_amount ))
						if (( pay_amount >= loan_interest )); then
							pay_amount=$(( pay_amount - loan_interest ))
							loan_interest=0
							loan_amount=$(( loan_amount - pay_amount ))
							(( loan_amount < 0 )) && loan_amount=0
						else
							loan_interest=$(( loan_interest - pay_amount ))
						fi
						echo "Payment made. Remaining: \$$(( loan_amount + loan_interest ))"
						play_sfx_mpg "cash_register"
						if (( loan_amount == 0 && loan_interest == 0 )); then
							echo -e "\e[1;32mLoan fully cleared!\e[0m"
							loan_due_day=0; loan_enforcer_warned=false
						fi
					else
						echo "Invalid amount or not enough cash."
					fi
					read -r -p "Press Enter...";;
				3) return;;
				*) echo "Invalid."; sleep 1;;
			esac
		else
			case "$choice" in
				1) take_loan 500 15;;
				2) take_loan 2000 20;;
				3) take_loan 5000 25;;
				4) return;;
				*) echo "Invalid."; sleep 1;;
			esac
		fi
	done
}

take_loan() {
	local amount=$1
	local rate=$2
	if (( loan_amount > 0 )); then
		echo "You already have an outstanding loan. Repay it first."; read -r -p "Press Enter..."; return
	fi
	echo "You're borrowing \$$amount at ${rate}% daily interest."
	echo "Miss payments and Vinnie will send someone to collect."
	read -r -p "Confirm? (y/n): " confirm
	if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
		loan_amount=$amount
		loan_interest=0
		loan_due_day=$game_day
		# Store rate in interest as a note (we'll compound daily)
		# We use a tag in loan_due_day: store rate*100 in high bits isn't clean
		# So store rate as a global
		loan_rate=$rate
		cash=$(( cash + amount ))
		echo -e "\e[1;32mCash received. Don't be late.\e[0m"
		play_sfx_mpg "cash_register"
	else
		echo "Smart choice."
	fi
	read -r -p "Press Enter..."
}

loan_rate=15  # global, updated when loan taken

process_loan_interest() {
	# Called each day rollover
	if (( loan_amount <= 0 )); then return; fi
	local daily_interest=$(( loan_amount * loan_rate / 100 ))
	loan_interest=$(( loan_interest + daily_interest ))
	echo -e "\e[1;31mLoan interest accrued: +\$$daily_interest (Total owed: \$$(( loan_amount + loan_interest )))\e[0m"

	# Enforcer visit if overdue > 3 days and total is large
	local days_overdue=$(( game_day - loan_due_day ))
	if (( days_overdue >= 3 && !loan_enforcer_warned )); then
		loan_enforcer_warned=true
		echo -e "\e[1;31m*** A MESSAGE FROM VINNIE ***\e[0m"
		echo "\"You're getting sloppy with payments. My boys will be in touch.\""
		play_sfx_mpg "police_siren"
	fi
	if (( days_overdue >= 5 )); then
		enforcer_visit
	fi
}

enforcer_visit() {
	clear_screen
	play_sfx_mpg "police_siren"
	echo -e "\e[1;31m*** LOAN ENFORCER ARRIVES! ***\e[0m"
	echo "Two heavies from Vinnie's crew show up at your door..."
	echo "\"Vinnie says you've been avoiding payments. Time to settle up.\""
	echo "-----------------------------------------------------"
	local total_owed=$(( loan_amount + loan_interest ))
	echo "1. Pay what you have now  (\$${cash} available)"
	echo "2. Fight them off          (Dangerous)"
	echo "3. Run                     (They'll be back, angrier)"
	read -r -p "Choice: " choice
	case "$choice" in
		1)
			local payment=$cash
			cash=0
			if (( payment >= total_owed )); then
				cash=$(( payment - total_owed ))
				loan_amount=0; loan_interest=0; loan_due_day=0; loan_enforcer_warned=false
				echo -e "\e[1;32mPaid off in full. They leave.\e[0m"
			else
				loan_interest=$(( total_owed - payment ))
				loan_amount=$(( loan_amount > 0 ? loan_amount : 0 ))
				echo "Partial payment accepted. They'll be back."
			fi
			play_sfx_mpg "cash_register";;
		2)
			local strength=${skills[strength]:-1}
			local fight_chance=$(( 30 + strength * 5 ))
			echo "You square up to the enforcers!"; sleep 1
			if (( RANDOM % 100 < fight_chance )); then
				echo -e "\e[1;32mYou fought them off! They retreat for now.\e[0m"
				health=$(( health - (RANDOM % 20 + 15) ))
				play_sfx_mpg "win"
				# They'll still come back, loan persists
			else
				local damage=$(( RANDOM % 30 + 25 ))
				health=$(( health - damage ))
				local taken=$(( cash / 2 ))
				cash=$(( cash - taken ))
				loan_interest=$(( loan_interest - taken )); (( loan_interest < 0 )) && loan_interest=0
				echo -e "\e[1;31mThey beat you badly and took \$$taken.\e[0m"
				play_sfx_mpg "lose"
			fi;;
		3)
			echo "You slip out the back. They make note of it."
			health=$(( health - 5 ))
			loan_interest=$(( loan_interest + 200 ))
			echo "Extra \$200 added to your debt for the trouble.";;
	esac
	check_health
	read -r -p "Press Enter..."
}

# =====================================================
# NEW: Black Market Auction
# =====================================================
visit_auction_house() {
	run_clock 1
	# Generate a new auction if none is active or it's expired
	if ! $auction_active || (( game_day > current_auction["ends_day"] )); then
		generate_new_auction
	fi

	while true; do
		clear_screen
		echo "--- Underground Auction House ---"
		echo "\"Only the highest bidder walks out with the prize.\""
		echo "================================================="
		if $auction_active; then
			printf " Item:         \e[1;33m%s\e[0m\n" "${current_auction[item]}"
			printf " Description:  %s\n" "${current_auction[desc]}"
			printf " Min Bid:      \e[1;31m\$%d\e[0m\n" "${current_auction[min_bid]}"
			printf " Current Bid:  \e[1;32m\$%d\e[0m\n" "${current_auction[current_bid]}"
			printf " Auction Ends: Day %d (Today: Day %d)\n" "${current_auction[ends_day]}" "$game_day"
			printf " Your Cash:    \$%d\n" "$cash"
			echo "================================================="
			echo "1. Place a Bid"
			echo "2. Check other lots (refresh auction)"
			echo "3. Leave"
		else
			echo " No active auctions right now. Check back tomorrow."
			echo "================================================="
			echo "1. Leave"
		fi
		read -r -p "Choice: " choice
		if ! $auction_active; then
			return
		fi
		case "$choice" in
			1)
				local min_next=$(( current_auction[current_bid] + 50 ))
				echo "Minimum bid: \$$min_next"
				read -r -p "Your bid: \$" bid
				if ! [[ "$bid" =~ ^[1-9][0-9]*$ ]]; then echo "Invalid."; sleep 1; continue; fi
				if (( bid < min_next )); then echo "Bid too low."; sleep 1; continue; fi
				if (( bid > cash )); then echo "Not enough cash."; sleep 1; continue; fi
				# Simulate competing bidder
				local rival_bid=$(( current_auction[current_bid] + RANDOM % 200 + 50 ))
				current_auction[current_bid]=$bid
				if (( rival_bid > bid && rival_bid <= cash * 2 )); then
					echo "Another bidder raises to \$$rival_bid!"
					current_auction[current_bid]=$rival_bid
					read -r -p "Outbid! Try again? (Enter to go back to menu)"
				else
					# Player wins
					cash=$(( cash - bid ))
					auction_active=false
					echo -e "\e[1;32m*** YOU WON THE AUCTION! ***\e[0m"
					echo "You paid \$$bid for: ${current_auction[item]}"
					apply_auction_reward "${current_auction[item]}"
					play_sfx_mpg "win_big"
					read -r -p "Press Enter..."
					return
				fi;;
			2)
				generate_new_auction
				echo "New lot available."
				sleep 1;;
			3) return;;
			*) echo "Invalid."; sleep 1;;
		esac
	done
}

generate_new_auction() {
	local -a auction_items=(
		"Silenced Ghost Sniper:A military-grade suppressed sniper rifle:gun:2500"
		"Armoured SUV:A bulletproof vehicle:vehicle:4000"
		"Police Scanner:Reduces police encounter chance:item:1500"
		"Stolen Diamonds:Fence for big profit:sellable:3000"
		"Fake Passport Set:Clears all wanted levels:item:3500"
		"Experimental Body Armor:Provides double armor durability:item:2000"
		"Cartel Drug Cache:500 units of Cocaine:drug:5000"
		"Rare Sports Car:A very fast stolen vehicle:vehicle:6000"
		"Hitman Contract:Take out a rival gang for 200 Respect:contract:4500"
		"Gold Brick:Raw gold, fence for \$2000:sellable:1800"
	)
	local pick="${auction_items[RANDOM % ${#auction_items[@]}]}"
	IFS=':' read -r auc_name auc_desc auc_type auc_val <<< "$pick"
	current_auction=()
	current_auction["item"]="$auc_name"
	current_auction["desc"]="$auc_desc"
	current_auction["type"]="$auc_type"
	current_auction["value"]="$auc_val"
	current_auction["min_bid"]=$(( auc_val * 60 / 100 ))
	current_auction["current_bid"]=$(( auc_val * 60 / 100 ))
	current_auction["ends_day"]=$(( game_day + 2 ))
	auction_active=true
}

apply_auction_reward() {
	local item_name="$1"
	case "$item_name" in
		"Silenced Ghost Sniper")
			guns+=("Ghost Sniper"); echo "Ghost Sniper added to your arsenal.";;
		"Armoured SUV"|"Rare Sports Car")
			owned_vehicles+=("Sports Car"); echo "Vehicle added to your garage.";;
		"Police Scanner")
			items+=("Police Scanner"); echo "Police Scanner added to inventory. Reduces police encounters.";;
		"Stolen Diamonds"|"Gold Brick")
			items+=("Stolen Goods"); items+=("Stolen Goods")
			echo "Valuables added to inventory. Find a fence to sell them.";;
		"Fake Passport Set")
			items+=("Fake ID"); items+=("Fake ID")
			echo "Two Fake IDs added to inventory.";;
		"Experimental Body Armor")
			body_armor_equipped=true; echo "Advanced Body Armor equipped.";;
		"Cartel Drug Cache")
			drugs["Cocaine"]=$(( ${drugs["Cocaine"]:-0} + 500 ))
			echo "500 units of Cocaine added to inventory.";;
		"Hitman Contract")
			award_respect 200; echo "Contract executed. +200 Respect.";;
		*) echo "Item acquired: $item_name";;
	esac
}

# =====================================================
# NEW: Fence System
# =====================================================
visit_fence() {
	run_clock 1
	clear_screen
	echo "--- Ray's Chop Shop & Fencing ---"
	echo "\"I don't ask where it came from. You don't ask what I do with it.\""
	echo "==========================================================="

	# Fence vehicles
	local fence_income=0
	local sold_something=false

	echo ""
	echo "--- Vehicles ---"
	if (( ${#owned_vehicles[@]} == 0 )); then
		echo " No vehicles to fence."
	else
		local i=1
		for v in "${owned_vehicles[@]}"; do
			local fence_val=0
			case "$v" in
				"Sedan") fence_val=800;;
				"Motorcycle") fence_val=600;;
				"Truck") fence_val=1000;;
				"Sports Car") fence_val=2000;;
				*) fence_val=500;;
			esac
			# Reduce value if heat is high
			local heat=${district_heat[$location]:-0}
			if (( heat > 15 )); then fence_val=$(( fence_val * 70 / 100 )); echo " (High heat reduces price)"; fi
			# Mechanic contact gives 20% more
			if [[ -v "contacts_unlocked[mechanic]" ]]; then fence_val=$(( fence_val * 120 / 100 )); fi
			printf " %d. %-15s - Fence for \$%d\n" "$i" "$v" "$fence_val"
			((i++))
		done
		printf " %d. Leave vehicles\n" "$i"
		read -r -p "Sell which vehicle? (number or leave): " vchoice
		if [[ "$vchoice" =~ ^[0-9]+$ ]] && (( vchoice >= 1 && vchoice < i )); then
			local vidx=$(( vchoice - 1 ))
			local sold_v="${owned_vehicles[$vidx]}"
			local val=0
			case "$sold_v" in
				"Sedan") val=800;; "Motorcycle") val=600;; "Truck") val=1000;; "Sports Car") val=2000;; *) val=500;;
			esac
			local heat=${district_heat[$location]:-0}
			if (( heat > 15 )); then val=$(( val * 70 / 100 )); fi
			if [[ -v "contacts_unlocked[mechanic]" ]]; then val=$(( val * 120 / 100 )); fi
			owned_vehicles=("${owned_vehicles[@]:0:$vidx}" "${owned_vehicles[@]:$((vidx+1))}")
			cash=$(( cash + val ))
			echo -e "\e[1;32mFenced $sold_v for \$$val.\e[0m"
			play_sfx_mpg "cash_register"
			sold_something=true
		fi
	fi

	echo ""
	echo "--- Stolen Goods ---"
	local goods_count=0
	local new_items=()
	for item in "${items[@]}"; do
		if [[ "$item" == "Stolen Goods" ]]; then
			((goods_count++))
		else
			new_items+=("$item")
		fi
	done
	if (( goods_count > 0 )); then
		local goods_price=$(( goods_count * (RANDOM % 51 + 75) ))
		if [[ -v "contacts_unlocked[fence_king]" ]]; then goods_price=$(( goods_price * 130 / 100 )); fi
		printf " You have %d units of stolen goods. Fence all for \$%d?\n" "$goods_count" "$goods_price"
		read -r -p "(y/n): " gconfirm
		if [[ "$gconfirm" == "y" || "$gconfirm" == "Y" ]]; then
			items=("${new_items[@]}")
			cash=$(( cash + goods_price ))
			echo -e "\e[1;32mFenced stolen goods for \$$goods_price.\e[0m"
			play_sfx_mpg "cash_register"
			sold_something=true
		fi
	else
		echo " No stolen goods in inventory."
	fi

	if ! $sold_something; then echo ""; echo "Nothing sold."; fi
	read -r -p "Press Enter..."
}

# =====================================================
# NEW: Ambush System (called during travel)
# =====================================================
check_travel_ambush() {
	# Only triggers if wanted level >= 2 or there's a bounty, and random chance
	local ambush_chance=0
	(( wanted_level >= 2 )) && ambush_chance=$(( ambush_chance + wanted_level * 8 ))
	(( player_bounty > 0 )) && ambush_chance=$(( ambush_chance + 20 ))
	(( ambush_chance == 0 )) && return
	(( RANDOM % 100 >= ambush_chance )) && return

	# Pick an ambushing gang from rival relations
	local -a hostile=()
	for rival in "${!gang_relations[@]}"; do
		if [[ "${gang_relations[$rival]}" == "War" || "${gang_relations[$rival]}" == "Hostile" ]]; then
			hostile+=("$rival")
		fi
	done
	# Also generic street thugs
	hostile+=("Street Thugs")

	local attacker="${hostile[RANDOM % ${#hostile[@]}]}"

	clear_screen
	play_sfx_mpg "police_siren"
	echo -e "\e[1;91m*** AMBUSH! ***\e[0m"
	echo -e "The \e[1;31m${attacker}\e[0m jump you on the road between cities!"
	echo "---------------------------------------------"

	local strength=${skills[strength]:-1}
	local stealth=${skills[stealth]:-1}
	local escape_chance=$(( 35 + stealth * 5 + strength * 3 ))
	local gun_bonus=0
	for g in "${guns[@]}"; do
		if [[ -v "gun_attributes[$g]" ]]; then
			local success_bonus=0; eval "${gun_attributes[$g]}"
			(( success_bonus > gun_bonus )) && gun_bonus=$success_bonus
		fi
	done
	local fight_chance=$(( 40 + strength * 6 + gun_bonus ))
	(( fight_chance > 90 )) && fight_chance=90
	(( escape_chance > 85 )) && escape_chance=85

	echo "1. Fight back!  (Fight chance: ${fight_chance}%)"
	echo "2. Run!         (Escape chance: ${escape_chance}%)"
	echo "3. Pay them off (Cost: \$$(( RANDOM % 200 + 100 )))"
	read -r -p "Choice: " ambush_choice

	case "$ambush_choice" in
		1)
			echo "You pull out your weapon and face them!"; sleep 1
			if (( RANDOM % 100 < fight_chance )); then
				local loot=$(( RANDOM % 201 + 50 ))
				cash=$(( cash + loot ))
				health=$(( health - (RANDOM % 15 + 5) ))
				echo -e "\e[1;32mYou fought them off and took \$$loot from their pockets!\e[0m"
				award_respect $(( RANDOM % 20 + 10 ))
				play_sfx_mpg "win"
			else
				local damage=$(( RANDOM % 30 + 20 ))
				local stolen=$(( cash / 5 ))
				health=$(( health - damage ))
				cash=$(( cash - stolen )); (( cash < 0 )) && cash=0
				echo -e "\e[1;31mThey overpowered you! Lost \$$stolen and took ${damage}%% damage.\e[0m"
				play_sfx_mpg "lose"
			fi;;
		2)
			echo "You floor it and try to lose them!"; sleep 1
			if (( RANDOM % 100 < escape_chance )); then
				echo -e "\e[1;32mYou escaped! They couldn't keep up.\e[0m"
				play_sfx_mpg "win"
			else
				local damage=$(( RANDOM % 20 + 10 ))
				health=$(( health - damage ))
				echo -e "\e[1;31mThey caught you before you could escape!\e[0m"
				local stolen=$(( cash / 8 ))
				cash=$(( cash - stolen )); (( cash < 0 )) && cash=0
				echo "Lost \$$stolen and took ${damage}%% damage."
				play_sfx_mpg "lose"
			fi;;
		3|*)
			local payoff=$(( RANDOM % 200 + 100 ))
			if (( cash >= payoff )); then
				cash=$(( cash - payoff ))
				echo -e "\e[1;32mYou threw some cash and they let you go.\e[0m"
			else
				echo "Not enough cash! They take everything."
				cash=0
				health=$(( health - 15 ))
			fi;;
	esac
	check_health
	read -r -p "Press Enter..."
}

# =====================================================
# NEW: Bounty on Player System
# =====================================================
check_player_bounty() {
	# Bounty grows when wanted level is high
	if (( wanted_level >= 4 && player_bounty == 0 )); then
		player_bounty=$(( RANDOM % 1001 + 500 ))
		bounty_hitman_name="${HITMAN_NAMES[RANDOM % ${#HITMAN_NAMES[@]}]}"
		clear_screen
		echo -e "\e[1;35m*** BOUNTY PLACED ON YOUR HEAD! ***\e[0m"
		echo "Word has spread. A bounty of \$$player_bounty has been placed on you."
		echo "Hitman \"$bounty_hitman_name\" has taken the contract."
		play_sfx_mpg "police_siren"
		read -r -p "Press Enter..."
	fi

	# If bounty active, chance of hitman encounter
	if (( player_bounty > 0 )); then
		if (( RANDOM % 100 < 20 )); then
			hitman_encounter
		fi
	fi
}

declare -a HITMAN_NAMES=("El Diablo" "The Ghost" "Iron Mike" "Serpentine" "Cold Carlo" "The Wraith" "Big Sal")

hitman_encounter() {
	clear_screen
	play_sfx_mpg "police_siren"
	echo -e "\e[1;35m*** HITMAN ENCOUNTER! ***\e[0m"
	echo -e "\"$bounty_hitman_name\" has found you in $location."
	echo "This professional is here to collect on your bounty of \$$player_bounty."
	echo "---------------------------------------------------"

	local strength=${skills[strength]:-1}
	local stealth=${skills[stealth]:-1}
	local gun_bonus=0
	for g in "${guns[@]}"; do
		if [[ -v "gun_attributes[$g]" ]]; then
			local success_bonus=0; eval "${gun_attributes[$g]}"
			(( success_bonus > gun_bonus )) && gun_bonus=$success_bonus
		fi
	done
	local fight_chance=$(( 25 + strength * 6 + gun_bonus ))
	(( fight_chance > 80 )) && fight_chance=80

	echo "1. Fight the hitman (${fight_chance}% chance)"
	echo "2. Bribe them off   (\$$(( player_bounty * 2 )) - double the bounty)"
	echo "3. Use a disguise   (requires Fake ID)"
	read -r -p "Choice: " hchoice
	case "$hchoice" in
		1)
			echo "You draw your weapon..."; sleep 1
			if (( RANDOM % 100 < fight_chance )); then
				echo -e "\e[1;32mYou took down the hitman! The bounty is lifted.\e[0m"
				player_bounty=0; bounty_hitman_name=""
				health=$(( health - (RANDOM % 25 + 15) ))
				award_respect $(( RANDOM % 50 + 30 ))
				play_sfx_mpg "win_big"
			else
				local damage=$(( RANDOM % 40 + 30 ))
				health=$(( health - damage ))
				echo -e "\e[1;31mThe hitman is skilled. You barely survived (-${damage}%% health).\e[0m"
				play_sfx_mpg "lose_big"
			fi;;
		2)
			local bribe=$(( player_bounty * 2 ))
			if (( cash >= bribe )); then
				cash=$(( cash - bribe ))
				player_bounty=0; bounty_hitman_name=""
				echo -e "\e[1;32mThey took the money and walked. Contract cancelled.\e[0m"
				play_sfx_mpg "cash_register"
			else
				echo "Not enough cash. They attack!"
				health=$(( health - (RANDOM % 35 + 20) ))
				play_sfx_mpg "lose"
			fi;;
		3)
			local has_id=false; local id_idx=-1
			for idx in "${!items[@]}"; do
				if [[ "${items[$idx]}" == "Fake ID" ]]; then has_id=true; id_idx=$idx; break; fi
			done
			if $has_id; then
				items=("${items[@]:0:$id_idx}" "${items[@]:$((id_idx+1))}")
				player_bounty=0; bounty_hitman_name=""
				echo -e "\e[1;32mYou flashed a fake ID. They walked past, confused.\e[0m"
				play_sfx_mpg "win"
			else
				echo -e "\e[1;31mNo Fake ID! They see right through you.\e[0m"
				health=$(( health - (RANDOM % 30 + 20) ))
				play_sfx_mpg "lose"
			fi;;
	esac
	check_health
	read -r -p "Press Enter..."
}

clear_bounty_via_contact() {
	if [[ -v "contacts_unlocked[corrupt_cop]" ]]; then
		local cost=1000
		if (( cash >= cost && player_bounty > 0 )); then
			cash=$(( cash - cost ))
			player_bounty=0; bounty_hitman_name=""
			echo -e "\e[1;32mCorrupt cop cleared your bounty for \$$cost.\e[0m"
			play_sfx_mpg "cash_register"
		else
			echo "Need \$$cost and an active bounty."
		fi
		read -r -p "Press Enter..."
	fi
}

# =====================================================
# NEW: Safe House Renting
# =====================================================
rent_safe_house() {
	run_clock 1
	clear_screen
	echo "--- Safe House Rentals ---"
	echo "Rent a safe house in your current city to lay low, recover health, and reduce wanted level."
	echo "Daily cost: \$$SAFEHOUSE_RENT_COST"
	echo "========================================"
	if [[ "$rented_safehouse" == "$location" ]]; then
		echo -e "You currently rent a safe house in \e[1;32m${location}\e[0m."
		echo "(Rented since Day $safehouse_rent_day)"
		echo ""
		echo "1. Use safe house (recover, reduce wanted)"
		echo "2. Give up safe house"
		echo "3. Back"
	else
		if [[ -n "$rented_safehouse" ]]; then
			echo -e "You have a safe house in \e[1;33m${rented_safehouse}\e[0m."
			echo "You can only rent one at a time."
			echo ""
			echo "1. Rent here instead (costs \$$SAFEHOUSE_RENT_COST, cancels old one)"
			echo "2. Back"
		else
			echo "No safe house currently rented."
			echo ""
			echo "1. Rent a safe house here (\$$SAFEHOUSE_RENT_COST/day)"
			echo "2. Back"
		fi
	fi
	echo "========================================"
	read -r -p "Choice: " sfchoice
	case "$sfchoice" in
		1)
			if [[ "$rented_safehouse" == "$location" ]]; then
				# Use the safe house
				run_clock 8
				local cost=$(( SAFEHOUSE_RENT_COST * 1 ))
				if (( cash >= cost )); then
					cash=$(( cash - cost ))
					health=100; body_armor_equipped=false
					if (( wanted_level > 0 )); then
						wanted_level=$(( wanted_level - 2 ))
						(( wanted_level < 0 )) && wanted_level=0
					fi
					echo -e "\e[1;32mYou laid low at the safe house.\e[0m"
					echo "Health restored to 100%. Wanted level reduced by 2."
					echo "Cost: \$$cost"
					play_sfx_mpg "heal"
				else
					echo "Not enough cash to pay the daily rent (\$$cost)."
				fi
			else
				if (( cash >= SAFEHOUSE_RENT_COST )); then
					cash=$(( cash - SAFEHOUSE_RENT_COST ))
					rented_safehouse="$location"
					safehouse_rent_day=$game_day
					echo -e "\e[1;32mSafe house secured in $location!\e[0m"
					play_sfx_mpg "cash_register"
				else
					echo "Not enough cash (\$$SAFEHOUSE_RENT_COST needed)."
				fi
			fi;;
		2)
			if [[ "$rented_safehouse" == "$location" ]]; then
				rented_safehouse=""
				echo "Safe house given up."
			else
				return
			fi;;
		3) return;;
	esac
	read -r -p "Press Enter..."
}

# =====================================================
# NEW: Drive-By Mission
# =====================================================
drive_by_mission() {
	run_clock 2
	if [[ "$player_gang" == "None" ]]; then
		echo "You need to be in a gang to order a drive-by."; read -r -p "Press Enter..."; return
	fi
	if (( ${#owned_vehicles[@]} == 0 )); then
		echo "You need a vehicle to do a drive-by."; read -r -p "Press Enter..."; return
	fi
	if (( ${#guns[@]} == 0 )); then
		echo "You need a weapon for this."; read -r -p "Press Enter..."; return
	fi

	# Find a rival territory in this city
	local -a rival_keys=()
	for key in "${!territory_owner[@]}"; do
		local city="${key%|*}"; local owner="${territory_owner[$key]}"
		if [[ "$city" == "$location" && "$owner" != "$player_gang" && "$owner" != "Unaffiliated" ]]; then
			rival_keys+=("$key")
		fi
	done
	if (( ${#rival_keys[@]} == 0 )); then
		echo "No rival gang territories to hit in this city."; read -r -p "Press Enter..."; return
	fi

	local target_key="${rival_keys[RANDOM % ${#rival_keys[@]}]}"
	local target_gang="${territory_owner[$target_key]}"
	local target_district="${target_key#*|}"

	clear_screen
	echo "--- Drive-By Mission ---"
	echo -e "Target: \e[1;31m${target_gang}\e[0m controlled \e[1;33m${target_district}\e[0m"
	echo "A quick hit to weaken their grip before a full war."
	echo "Success weakens the target district — future gang wars there will be easier."
	echo ""

	local driving=${skills[driving]:-1}
	local gun_bonus=0
	for g in "${guns[@]}"; do
		if [[ -v "gun_attributes[$g]" ]]; then
			local success_bonus=0; eval "${gun_attributes[$g]}"
			(( success_bonus > gun_bonus )) && gun_bonus=$success_bonus
		fi
	done
	local success_chance=$(( 45 + driving * 4 + gun_bonus / 2 ))
	(( success_chance > 90 )) && success_chance=90
	echo "Success chance: ${success_chance}%"
	read -r -p "Execute the drive-by? (y/n): " confirm
	[[ "$confirm" != "y" && "$confirm" != "Y" ]] && return

	echo "You peel out in your vehicle, windows down..."; sleep 1

	if (( RANDOM % 100 < success_chance )); then
		echo -e "\e[1;32mDrive-by successful!\e[0m Sprayed their corner. They're rattled."
		# Store a district weakness flag — future war there gets +15% bonus
		district_heat["$target_district_drivebyweakened"]=$(( game_day + 3 ))
		health=$(( health - (RANDOM % 10 + 5) ))
		wanted_level=$(( wanted_level + 1 ))
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		district_heat["$location"]=$(( ${district_heat[$location]:-0} + 8 ))
		award_respect $(( RANDOM % 30 + 15 ))
		play_sfx_mpg "win"
		if (( RANDOM % 3 == 0 )); then
			skills[driving]=$(( driving + 1 ))
			echo "Your driving skill increased!"
		fi
	else
		echo -e "\e[1;31mThey were ready for you.\e[0m Shots fired back at your car!"
		health=$(( health - (RANDOM % 25 + 15) ))
		wanted_level=$(( wanted_level + 2 ))
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		echo "Took damage and heat went up."
		play_sfx_mpg "lose"
	fi
	check_health
	read -r -p "Press Enter..."
}

# =====================================================
# NEW: Protection Racket
# =====================================================
manage_protection_racket() {
	run_clock 1
	while true; do
		clear_screen
		echo "--- Protection Racket ---"
		echo "Extort local businesses for weekly income."
		echo "Push too hard and they'll report you."
		echo "======================================================="
		# Show local targets
		local -a local_targets=()
		for biz in "${!protection_targets[@]}"; do
			local details="${protection_targets[$biz]}"
			local biz_city weekly heat days_paid
			IFS=':' read -r biz_city weekly heat days_paid <<< "$details"
			if [[ "$biz_city" == "$location" ]]; then
				local current_income=${protection_income[$biz]:-0}
				local status="Not Extorted"
				if (( current_income > 0 )); then status="\e[1;32mPaying (\$${current_income}/day)\e[0m"; fi
				printf " %-28s | Weekly max: \$%d | Heat risk: %d%%\n" "$biz" "$weekly" "$heat"
				printf "   Status: %b\n" "$status"
				local_targets+=("$biz")
			fi
		done
		if (( ${#local_targets[@]} == 0 )); then
			echo " No extortion targets in this city."
		fi
		echo "======================================================="
		echo "1. Extort a business  2. Raise pressure  3. Back"
		read -r -p "Choice: " choice
		case "$choice" in
			1)
				echo ""
				local i=1
				for biz in "${local_targets[@]}"; do
					local current_income=${protection_income[$biz]:-0}
					if (( current_income == 0 )); then
						printf " %d. %s\n" "$i" "$biz"
						((i++))
					fi
				done
				if (( i == 1 )); then echo "All local businesses already paying."; read -r -p "Press Enter..."; continue; fi
				printf " %d. Back\n" "$i"
				read -r -p "Which to extort? " echoice
				if [[ "$echoice" =~ ^[0-9]+$ ]] && (( echoice >= 1 && echoice < i )); then
					local idx=0; local count=0
					for biz in "${local_targets[@]}"; do
						local ci=${protection_income[$biz]:-0}
						if (( ci == 0 )); then
							(( count++ ))
							if (( count == echoice )); then
								start_extortion "$biz"
								break
							fi
						fi
					done
				fi;;
			2)
				echo ""
				local i=1
				local paying_targets=()
				for biz in "${local_targets[@]}"; do
					if (( ${protection_income[$biz]:-0} > 0 )); then
						printf " %d. %s (\$%d/day)\n" "$i" "$biz" "${protection_income[$biz]}"
						paying_targets+=("$biz")
						((i++))
					fi
				done
				if (( i == 1 )); then echo "No businesses currently paying."; read -r -p "Press Enter..."; continue; fi
				printf " %d. Back\n" "$i"
				read -r -p "Raise pressure on which? " rchoice
				if [[ "$rchoice" =~ ^[0-9]+$ ]] && (( rchoice >= 1 && rchoice < i )); then
					local target_biz="${paying_targets[$((rchoice-1))]}"
					raise_protection_pressure "$target_biz"
				fi;;
			3) return;;
			*) echo "Invalid."; sleep 1;;
		esac
	done
}

start_extortion() {
	local biz="$1"
	local details="${protection_targets[$biz]}"
	local biz_city weekly heat days_paid
	IFS=':' read -r biz_city weekly heat days_paid <<< "$details"

	local charisma=${skills[charisma]:-1}
	local strength=${skills[strength]:-1}
	local success_chance=$(( 50 + charisma * 5 + strength * 3 ))
	(( success_chance > 90 )) && success_chance=90
	local initial_income=$(( weekly / 7 ))

	echo "You approach $biz with a 'business offer'..."
	sleep 1
	if (( RANDOM % 100 < success_chance )); then
		protection_income["$biz"]=$initial_income
		echo -e "\e[1;32mThey agreed to pay \$${initial_income}/day for your 'protection'.\e[0m"
		play_sfx_mpg "cash_register"
		award_respect $(( RANDOM % 10 + 5 ))
	else
		echo -e "\e[1;31mThey refused! And may have called the police.\e[0m"
		wanted_level=$(( wanted_level + 1 ))
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		play_sfx_mpg "police_siren"
	fi
	read -r -p "Press Enter..."
}

raise_protection_pressure() {
	local biz="$1"
	local details="${protection_targets[$biz]}"
	local biz_city weekly heat days_paid
	IFS=':' read -r biz_city weekly heat days_paid <<< "$details"

	echo "You lean on $biz for more money..."
	sleep 1
	if (( RANDOM % 100 < heat )); then
		echo -e "\e[1;31mThey snapped and called the cops!\e[0m"
		wanted_level=$(( wanted_level + 2 ))
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		protection_income["$biz"]=0
		echo "They've stopped paying. Too much heat."
		play_sfx_mpg "police_siren"
	else
		local old_income=${protection_income[$biz]:-0}
		local new_income=$(( old_income + weekly / 14 ))
		protection_income["$biz"]=$new_income
		echo -e "\e[1;32mThey caved. Now paying \$${new_income}/day.\e[0m"
		play_sfx_mpg "cash_register"
	fi
	read -r -p "Press Enter..."
}

collect_protection_income() {
	local total=0
	for biz in "${!protection_income[@]}"; do
		local income=${protection_income[$biz]:-0}
		if (( income > 0 )); then
			total=$(( total + income ))
			# Random chance business stops paying
			if (( RANDOM % 100 < 5 )); then
				protection_income["$biz"]=0
				world_event_log+=("[Day $game_day] A business you were extorting in ${location} stopped paying.")
			fi
		fi
	done
	echo "Protection income collected: \$$total"
	cash=$(( cash + total ))
}

# =====================================================
# NEW: Gang Spy
# =====================================================
send_gang_spy() {
	run_clock 2
	if [[ "$player_gang" == "None" ]]; then
		echo "You need to be in a gang to use this."; read -r -p "Press Enter..."; return
	fi

	clear_screen
	echo "--- Gang Intelligence ---"
	echo "Spend \$500 to gather intel on a rival gang's territory strength."
	echo "This gives you a strategic advantage before gang wars."
	echo "==========================================="

	local -a rivals_in_city=()
	for key in "${!territory_owner[@]}"; do
		local city="${key%|*}"; local owner="${territory_owner[$key]}"
		if [[ "$city" == "$location" && "$owner" != "$player_gang" && "$owner" != "Unaffiliated" ]]; then
			local already=false
			for r in "${rivals_in_city[@]}"; do [[ "$r" == "$owner" ]] && already=true; done
			$already || rivals_in_city+=("$owner")
		fi
	done

	if (( ${#rivals_in_city[@]} == 0 )); then
		echo "No rivals with territory in this city to spy on."; read -r -p "Press Enter..."; return
	fi

	local i=1
	for gang in "${rivals_in_city[@]}"; do
		printf " %d. Spy on %s\n" "$i" "$gang"; ((i++))
	done
	printf " %d. Back\n" "$i"
	read -r -p "Choice: " schoice

	if [[ "$schoice" == "$i" ]] || ! [[ "$schoice" =~ ^[0-9]+$ ]]; then return; fi
	if (( schoice < 1 || schoice > ${#rivals_in_city[@]} )); then echo "Invalid."; sleep 1; return; fi

	local target_gang="${rivals_in_city[$((schoice-1))]}"
	local spy_cost=500
	if (( cash < spy_cost )); then echo "Not enough cash (\$$spy_cost needed)."; read -r -p "Press Enter..."; return; fi

	cash=$(( cash - spy_cost ))
	echo "You send an informant into ${target_gang} territory..."; sleep 2

	local stealth=${skills[stealth]:-1}
	local success_chance=$(( 60 + stealth * 5 ))
	if (( RANDOM % 100 < success_chance )); then
		local gang_strength=$(calculate_gang_strength "$target_gang")
		local territory_count=0
		for key in "${!territory_owner[@]}"; do
			[[ "${territory_owner[$key]}" == "$target_gang" ]] && ((territory_count++))
		done
		echo -e "\e[1;32mIntel received!\e[0m"
		echo "-----------------------------------"
		echo "Gang: $target_gang"
		echo "Territory held in $location: $territory_count districts"
		echo "Estimated strength: $gang_strength"
		if (( gang_strength < 30 )); then echo "Assessment: WEAK — Good time to attack."
		elif (( gang_strength < 60 )); then echo "Assessment: MODERATE — Prepare carefully."
		else echo "Assessment: STRONG — Risky. Build up first."; fi
		echo "-----------------------------------"
		play_sfx_mpg "win"
	else
		echo -e "\e[1;31mYour spy was made! They sent a message back.\e[0m"
		wanted_level=$(( wanted_level + 1 ))
		(( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		play_sfx_mpg "police_siren"
	fi
	read -r -p "Press Enter..."
}

# =====================================================
# NEW: Training Gym
# =====================================================
visit_gym() {
	run_clock 3
	clear_screen
	echo "--- Fleece Gym ---"
	echo "\"No pain, no gain.\""
	printf " Your Cash: \$%d\n" "$cash"
	echo "============================================"
	echo " Train a specific skill directly."
	echo ""
	printf " 1. Strength  (Lv %d) - \$300  (Fight better, carry more)\n" "${skills[strength]:-1}"
	printf " 2. Driving   (Lv %d) - \$250  (Races, escapes, carjacking)\n" "${skills[driving]:-1}"
	printf " 3. Stealth   (Lv %d) - \$350  (Robberies, burglaries)\n" "${skills[stealth]:-1}"
	printf " 4. Charisma  (Lv %d) - \$200  (Jobs, negotiation, diplomacy)\n" "${skills[charisma]:-1}"
	printf " 5. Drug Deal (Lv %d) - \$400  (Better drug prices)\n" "${skills[drug_dealer]:-1}"
	echo " 6. Back"
	echo "============================================"
	read -r -p "Choice: " gchoice
	local skill_name="" cost=0
	case "$gchoice" in
		1) skill_name="strength"; cost=300;;
		2) skill_name="driving"; cost=250;;
		3) skill_name="stealth"; cost=350;;
		4) skill_name="charisma"; cost=200;;
		5) skill_name="drug_dealer"; cost=400;;
		6) return;;
		*) echo "Invalid."; sleep 1; return;;
	esac
	# City rep gives discount at gym
	local rep_discount=$(( ${city_reputation[$location]:-0} / 10 ))
	cost=$(( cost - rep_discount ))
	echo "Training $skill_name. Cost: \$$cost (Rep discount: \$$rep_discount)"
	if (( cash >= cost )); then
		cash=$(( cash - cost ))
		skills[$skill_name]=$(( ${skills[$skill_name]:-1} + 1 ))
		echo -e "\e[1;32mTraining complete!\e[0m $skill_name is now level ${skills[$skill_name]}."
		play_sfx_mpg "win"
	else
		echo "Not enough cash."
	fi
	read -r -p "Press Enter..."
}

# =====================================================
# NEW: Phone Contacts System
# =====================================================
manage_phone_contacts() {
	run_clock 0
	while true; do
		clear_screen
		echo "--- Phone Contacts ---"
		echo "Unlock contacts through gameplay. Each provides unique benefits."
		echo "========================================================"
		# Show all contacts and their status
		declare -A contact_info=(
			["dealer"]="The Plug|Unlock: Complete 10 drug deals|Benefit: 15%% better drug prices"
			["corrupt_cop"]="Officer Bent|Unlock: Bribe police 5 times or have 40+ city rep|Benefit: 20%% cheaper bribes, clear bounties for \$1000"
			["mechanic"]="Wrench|Unlock: Own 3+ vehicles or have 60+ city rep|Benefit: 20%% more from fencing vehicles"
			["fence_king"]="The Broker|Unlock: Fence goods 5 times or have 50+ city rep|Benefit: 30%% more from stolen goods"
			["loan_fixer"]="Mr. Clean|Unlock: Repay a loan fully|Benefit: 10%% lower loan interest rates"
		)
		for contact in "dealer" "corrupt_cop" "mechanic" "fence_king" "loan_fixer"; do
			local info="${contact_info[$contact]}"
			local cname="${info%%|*}"; info="${info#*|}"; local cunlock="${info%%|*}"; local cbenefit="${info#*|}"
			if [[ -v "contacts_unlocked[$contact]" ]]; then
				printf " \e[1;32m[UNLOCKED]\e[0m %-16s - %s\n" "$cname" "$cbenefit"
			else
				printf " \e[1;31m[LOCKED  ]\e[0m %-16s - Unlock: %s\n" "$cname" "$cunlock"
			fi
		done
		echo "========================================================"
		echo "Contacts are unlocked automatically when conditions are met."
		echo "1. Call a contact  B. Back"
		read -r -p "Choice: " cchoice
		case "$cchoice" in
			1)
				if (( ${#contacts_unlocked[@]} == 0 )); then
					echo "No contacts unlocked yet. Keep grinding."; sleep 2; continue
				fi
				echo ""; local i=1; local -a unlocked_list=()
				for c in "dealer" "corrupt_cop" "mechanic" "fence_king" "loan_fixer"; do
					if [[ -v "contacts_unlocked[$c]" ]]; then
						local info="${contact_info[$c]}"
						local cname="${info%%|*}"
						printf " %d. %s\n" "$i" "$cname"
						unlocked_list+=("$c"); ((i++))
					fi
				done
				printf " %d. Back\n" "$i"
				read -r -p "Call: " callchoice
				if [[ "$callchoice" =~ ^[0-9]+$ ]] && (( callchoice >= 1 && callchoice < i )); then
					call_contact "${unlocked_list[$((callchoice-1))]}"
				fi;;
			'b'|'B') return;;
			*) sleep 1;;
		esac
	done
}

call_contact() {
	local contact="$1"
	clear_screen
	case "$contact" in
		"dealer")
			echo "--- The Plug ---"
			echo "\"I got the good stuff. No stretching.\""
			echo "Passive: 15% better sell prices on all drugs."
			echo "Active: Get a tip on current high-demand drug."
			local demand_drug=("Weed" "Cocaine" "Heroin" "Meth")
			local tip="${demand_drug[RANDOM % ${#demand_drug[@]}]}"
			echo "Tip: \"${tip} is hot right now. Sell fast.\"";;
		"corrupt_cop")
			echo "--- Officer Bent ---"
			echo "\"Don't worry. I was never here.\""
			echo "1. Clear active bounty (\$1000)"
			echo "2. Reduce wanted level by 2 (\$500)"
			echo "3. Just hang up"
			read -r -p "Choice: " choice
			case "$choice" in
				1) clear_bounty_via_contact;;
				2)
					if (( cash >= 500 )); then
						cash=$(( cash - 500 ))
						wanted_level=$(( wanted_level - 2 ))
						(( wanted_level < 0 )) && wanted_level=0
						echo "Wanted level reduced."
						play_sfx_mpg "cash_register"
					else
						echo "Not enough cash."
					fi;;
			esac;;
		"mechanic")
			echo "--- Wrench ---"
			echo "\"You got a car that needs disappearing? I know a guy.\""
			echo "Passive: 20% more cash when fencing vehicles."
			echo "Active: Repair your vehicle (reduces heat by 3)"
			district_heat["$location"]=$(( ${district_heat[$location]:-0} - 3 ))
			(( ${district_heat[$location]} < 0 )) && district_heat["$location"]=0
			echo "Heat reduced by 3 in $location.";;
		"fence_king")
			echo "--- The Broker ---"
			echo "\"Quality merchandise always finds a buyer.\""
			echo "Passive: 30% more from stolen goods at the fence."
			echo "Active: Tips on what's valuable right now."
			echo "Tip: \"Stolen electronics are worth double this week.\"";;
		"loan_fixer")
			echo "--- Mr. Clean ---"
			echo "\"Debt's a prison. I have the key.\""
			echo "Passive: Lower interest on loans."
			if (( loan_amount > 0 )); then
				local forgive=$(( loan_interest / 4 ))
				loan_interest=$(( loan_interest - forgive ))
				echo "He pulled some strings. Interest reduced by \$$forgive."
			else
				echo "\"No active loan? Come back when you need me.\""
			fi;;
	esac
	read -r -p "Press Enter..."
}

# Check and unlock contacts based on conditions
check_contact_unlocks() {
	# Count drug deal completions, police bribes, fence visits via flags
	# We track these via global counters updated in the relevant functions
	local rep=${city_reputation[$location]:-0}

	if [[ ! -v "contacts_unlocked[corrupt_cop]" ]] && (( rep >= 40 )); then
		contacts_unlocked["corrupt_cop"]=1
		world_event_log+=("[Day $game_day] New contact unlocked: Officer Bent (Corrupt Cop)")
	fi
	if [[ ! -v "contacts_unlocked[mechanic]" ]] && (( ${#owned_vehicles[@]} >= 3 || rep >= 60 )); then
		contacts_unlocked["mechanic"]=1
		world_event_log+=("[Day $game_day] New contact unlocked: Wrench (Mechanic)")
	fi
	if [[ ! -v "contacts_unlocked[fence_king]" ]] && (( rep >= 50 )); then
		contacts_unlocked["fence_king"]=1
		world_event_log+=("[Day $game_day] New contact unlocked: The Broker (Fence King)")
	fi
	if [[ ! -v "contacts_unlocked[loan_fixer]" ]] && (( loan_amount == 0 && loan_due_day > 0 )); then
		contacts_unlocked["loan_fixer"]=1
		world_event_log+=("[Day $game_day] New contact unlocked: Mr. Clean (Loan Fixer)")
	fi
}

# =====================================================
# NEW: Wanted Level Decay (called in run_clock)
# =====================================================
apply_wanted_decay() {
	# Every 4 in-game hours clean, decay wanted level by 1
	if (( wanted_level > 0 )); then
		# Only decay if not in active crime session — use a simple counter
		wanted_level=$(( wanted_level - 1 ))
		if (( wanted_level < 0 )); then wanted_level=0; fi
		if (( wanted_level == 0 )); then
			echo -e "\e[1;32mYou've gone quiet. Police have lost interest.\e[0m"
		else
			echo -e "Heat cooling down. Wanted level: $(printf '*%.0s' $(seq 1 $wanted_level) 2>/dev/null || echo $wanted_level)"
		fi
	fi
}

# =====================================================
# Clock & World State
# =====================================================
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

	# Safe house rent
	if [[ -n "$rented_safehouse" ]]; then
		upkeep_cost=$(( upkeep_cost + SAFEHOUSE_RENT_COST ))
		echo "Safe house rent: -\$$SAFEHOUSE_RENT_COST"
	fi

	# Collect protection income
	collect_protection_income

	local total_income=$((territory_income + business_income))
	local net_change=$((total_income - upkeep_cost))
	cash=$((cash + net_change))

	echo "Territory Income:   \$${territory_income}"
	echo "Business Income:    \$${business_income}"
	echo "-----------------------------------"
	echo "Total Gross Income:  \$${total_income}"
	echo "Recruit Upkeep:     -\$${upkeep_cost}"
	echo "-----------------------------------"
	if (( net_change >= 0 )); then
		echo -e "Net Daily Profit:   \e[1;32m\$${net_change}\e[0m"
	else
		echo -e "Net Daily Loss:     \e[1;31m\$${net_change}\e[0m"
	fi
	echo "-----------------------------------"

	# Process loan interest
	process_loan_interest

	for city_name in "${!district_heat[@]}"; do
		if (( ${district_heat[$city_name]} > 0 )); then
			district_heat[$city_name]=$(( ${district_heat[$city_name]} - 1 ))
		fi
	done
	echo "The heat has cooled down slightly across the cities."

	# Check contact unlocks
	check_contact_unlocks

	read -r -p "Press Enter to continue..."
}

run_clock() {
	local hours_to_pass=$1
	if (( hours_to_pass == 0 )); then return; fi

	local previous_hour=$game_hour
	game_hour=$((game_hour + hours_to_pass))

	# Wanted level decay every 4 hours of clean time
	local decay_triggers=(4 8 12 16 20)
	for trigger_hour in "${decay_triggers[@]}"; do
		if (( previous_hour < trigger_hour && game_hour >= trigger_hour )); then
			apply_wanted_decay
			break
		fi
	done

	local event_trigger_points=(0 4 8 12 16 20)
	for trigger_hour in "${event_trigger_points[@]}"; do
		if (( previous_hour < trigger_hour && game_hour >= trigger_hour )) || \
		   (( previous_hour > game_hour && (previous_hour < trigger_hour || game_hour >= trigger_hour) )); then
			process_world_events
			break
		fi
	done

	while (( game_hour >= 24 )); do
		game_hour=$((game_hour - 24))
		game_day=$((game_day + 1))
		calculate_and_apply_payouts
	done
}

update_world_state() {
	run_clock 0
	command -v passive_bounty_encounter &>/dev/null && passive_bounty_encounter
	command -v tick_stock_market &>/dev/null && tick_stock_market
	# Check bounty hitman
	check_player_bounty
}

# =====================================================
# Travel
# =====================================================
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
			use_own_vehicle=true; travel_cost=0
			echo "You hop into one of your vehicles."; play_sfx_mpg "car_start"
		fi
	fi

	if $use_own_vehicle || (( cash >= travel_cost )); then
		if ! $use_own_vehicle; then
			cash=$((cash - travel_cost)); play_sfx_mpg "air"
		fi

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

		# Ambush check during travel
		check_travel_ambush

		read -r -p "Press Enter..."
	else
		echo "Not enough cash (\$$travel_cost needed) to travel to $new_location."
		read -r -p "Press Enter..."
	fi
}

# =====================================================
# Guns, Vehicles, Inventory (unchanged core, pasted)
# =====================================================
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
	echo "  4. Hawk 9 silencer (\$120) - Reliable sidearm with silencer"
	echo "--------------------------------------------"
	echo " SHOTGUNS"
	echo "  5. Striker 12    (\$250)  - Pump action"
	echo "  6. Undertaker    (\$300)  - Sawn-off, close range"
	echo "--------------------------------------------"
	echo " SUBMACHINE GUNS"
	echo "  7. Viper SMG     (\$500)  - Fast and compact"
	echo "  8. Spectre PDW   (\$600)  - Military grade"
	echo "--------------------------------------------"
	echo " RIFLES & ASSAULT"
	echo "  9. Phantom Carbine (\$700) - Versatile carbine"
	echo " 10. AR-7 Assault  (\$750)  - Full auto rifle"
	echo "--------------------------------------------"
	echo " HEAVY"
	echo " 11. Ravager LMG   (\$900)  - Light machine gun"
	echo " 12. Diamondback MG(\$1100) - Destroyer"
	echo "--------------------------------------------"
	echo " SNIPER"
	echo " 13. Ghost Sniper  (\$1000) - Long range precision"
	echo "--------------------------------------------"
	echo " 14. Leave"
	echo "--------------------------------------------"
	read -r -p "Enter your choice: " gun_choice
	[[ ! "$gun_choice" =~ ^[0-9]+$ ]] && { echo "Invalid input."; read -r -p "Press Enter..."; return; }
	case "$gun_choice" in
		1)  buy_gun "Hawk 9" 100;;
		2)  buy_gun "Rex 38" 150;;
		3)  buy_gun "Bulldog 45" 200;;
		4)  buy_gun "Hawk 9 silencer" 120;;
		5)  buy_gun "Striker 12" 250;;
		6)  buy_gun "Undertaker Sawn-off" 300;;
		7)  buy_gun "Viper SMG" 500;;
		8)  buy_gun "Spectre PDW" 600;;
		9)  buy_gun "Phantom Carbine" 700;;
		10) buy_gun "AR-7 Assault" 750;;
		11) buy_gun "Ravager LMG" 900;;
		12) buy_gun "Diamondback MG" 1100;;
		13) buy_gun "Ghost Sniper" 1000;;
		14) return;;
		*)  echo "Invalid choice."; read -r -p "Press Enter...";;
	esac
}

buy_gun() {
	local gun_name="$1"; local gun_cost="$2"
	if [[ -v "perks[Street Negotiator]" ]]; then gun_cost=$(( gun_cost * 90 / 100 )); fi
	for owned_gun in "${guns[@]}"; do
		if [[ "$owned_gun" == "$gun_name" ]]; then
			echo "Looks like you already got a $gun_name there, partner."; read -r -p "Press Enter..."; return
		fi
	done
	if (( cash >= gun_cost )); then
		play_sfx_mpg "cash_register"
		if command -v buy_animation &> /dev/null; then buy_animation "$gun_name"; fi
		cash=$((cash - gun_cost)); guns+=("$gun_name")
		echo "One $gun_name, coming right up! That'll be \$$gun_cost."
		read -r -p "Press Enter..."
	else
		echo "Sorry pal, not enough cash for the $gun_name (\$$gun_cost needed)."
		read -r -p "Press Enter..."
	fi
}

buy_vehicle() {
	run_clock 1
	local vehicle_choice=""; local i=1; local buyable_vehicles=()
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
		if [[ "$player_gang" == "None" ]]; then printf "  - Gang: N/A\n"; printf "  - Rank: N/A\n"
		else printf "  - Gang: %s\n" "$player_gang"; printf "  - Rank: %s\n" "$player_gang_rank"; fi
		printf "  - Respect: %d\n" "$player_respect"
		echo "--------------------------"
		echo " Guns:"
		if (( ${#guns[@]} > 0 )); then printf "  - %s\n" "${guns[@]}"; else echo "  (None)"; fi
		echo "--------------------------"
		echo " Items:"
		if (( ${#items[@]} > 0 )); then
			local i=1
			for item in "${items[@]}"; do printf "  %d. %s\n" "$i" "$item"; ((i++)); done
			echo "--------------------------"; echo " U. Use an item   B. Back"
		else echo "  (None)"; echo "--------------------------"; echo " B. Back"; fi
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
		for skill in "${!default_skills[@]}"; do
			printf "  - %-12s: %d\n" "$skill" "${skills[$skill]:-0}"
		done
		echo "--------------------------"
		echo " Owned Properties/Businesses:"
		if (( ${#owned_businesses[@]} > 0 )); then
			for prop in "${!owned_businesses[@]}"; do
				printf "  - %-20s (%s)\n" "$prop" "${owned_businesses[$prop]// / | }"
			done
		else echo "  (None)"; fi
		echo "--------------------------"
		echo " Protection Racket Income:"
		local p_total=0
		for biz in "${!protection_income[@]}"; do
			local inc=${protection_income[$biz]:-0}
			if (( inc > 0 )); then printf "  - %-25s \$%d/day\n" "$biz" "$inc"; p_total=$((p_total + inc)); fi
		done
		(( p_total == 0 )) && echo "  (None)"
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
				use_item "$chosen_item" $((item_num - 1));;
			b) return;;
			*) sleep 1;;
		esac
	done
}

use_item() {
	local item_name="$1"; local item_index="$2"
	case "$item_name" in
		"Health Pack")
			local heal_amount=40
			if [[ -v "perks[Back Alley Surgeon]" ]]; then heal_amount=$(( heal_amount * 125 / 100 )); fi
			local old_health=$health; health=$(( health + heal_amount ))
			(( health > 100 )) && health=100
			local actual_heal=$(( health - old_health ))
			echo -e "Used Health Pack. Restored \e[1;32m${actual_heal}%%\e[0m health."
			play_sfx_mpg "heal"
			items=("${items[@]:0:$item_index}" "${items[@]:$((item_index + 1))}");;
		"Molotov Cocktail")
			echo "You hurl the Molotov at a nearby vehicle. Chaos erupts!"
			district_heat["$location"]=$(( ${district_heat[$location]:-0} + 5 ))
			wanted_level=$(( wanted_level + 1 )); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
			play_sfx_mpg "lose"
			items=("${items[@]:0:$item_index}" "${items[@]:$((item_index + 1))}");;
		"Fake ID")
			if (( wanted_level > 0 )); then
				wanted_level=$(( wanted_level - 1 ))
				echo -e "\e[1;32mFake ID used!\e[0m The cops don't recognise you. Wanted level reduced."
				items=("${items[@]:0:$item_index}" "${items[@]:$((item_index + 1))}")
			else echo "No wanted level to reduce. ID saved."; fi;;
		"Adrenaline Shot")
			health=$(( health + 25 )); skills[strength]=$(( ${skills[strength]:-1} + 2 ))
			echo -e "\e[1;32mAdrenaline pumping!\e[0m +25 health, temporary strength boost."
			play_sfx_mpg "heal_adv"
			items=("${items[@]:0:$item_index}" "${items[@]:$((item_index + 1))}");;
		"Police Scanner")
			echo -e "\e[1;32mPolice Scanner active!\e[0m Scanning police frequencies..."
			if (( wanted_level > 0 )); then
				wanted_level=$(( wanted_level - 1 ))
				echo "Wanted level reduced by 1 (scanner picked up patrol routes)."
			fi
			# Passive — scanner is permanent until destroyed, keep in inventory
			echo "(Scanner remains in inventory — passive effect active while held)";;
		*) echo "You can't use $item_name right now.";;
	esac
	read -r -p "Press Enter..."
}

work_job() {
	local job_type="$1"
	run_clock 4
	local earnings=0 base_earnings=0 skill_bonus=0
	local min_earnings=0 max_earnings=0
	local relevant_skill_level=1 relevant_skill_name=""

	case "$location" in
		"Los Santos")   min_earnings=20;  max_earnings=70;;
		"San Fierro")   min_earnings=25;  max_earnings=80;;
		"Las Venturas") min_earnings=35;  max_earnings=110;;
		"Vice City")    min_earnings=15;  max_earnings=60;;
		"Liberty City") min_earnings=40;  max_earnings=130;;
		*)              min_earnings=10;  max_earnings=40;;
	esac
	base_earnings=$((RANDOM % (max_earnings - min_earnings + 1) + min_earnings))

	# City rep pay bonus
	local rep_bonus_pct=$(get_city_rep_bonus)
	base_earnings=$(( base_earnings + base_earnings * rep_bonus_pct / 100 ))

	case "$job_type" in
		"taxi"|"delivery")
			relevant_skill_name="driving"; relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$(( relevant_skill_level * (job_type == "delivery" ? 4 : 3) ))
			play_sfx_mpg "taxi";;
		"mechanic")
			relevant_skill_name="strength"; relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$(( relevant_skill_level * 1 )); play_sfx_mpg "mechanic";;
		"security")
			relevant_skill_name="strength"; relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$(( relevant_skill_level * 2 )); play_sfx_mpg "security";;
		"performer")
			relevant_skill_name="charisma"; relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$(( relevant_skill_level * 5 )); play_sfx_mpg "street_performer";;
		"bus_driver")
			relevant_skill_name="driving"; relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$(( relevant_skill_level * 2 )); play_sfx_mpg "bus_driving";;
		"bartender")
			relevant_skill_name="charisma"; relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$(( relevant_skill_level * 4 )); play_sfx_mpg "bar";;
		"dock_worker")
			relevant_skill_name="strength"; relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$(( relevant_skill_level * 3 )); play_sfx_mpg "dock_worker";;
		"construction")
			relevant_skill_name="strength"; relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$(( relevant_skill_level * 4 )); play_sfx_mpg "construction";;
		"chef")
			relevant_skill_name="charisma"; relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$(( relevant_skill_level * 6 )); play_sfx_mpg "food_prep";;
		"pizza delivery")
			relevant_skill_name="driving"; relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$(( relevant_skill_level * 3 )); play_sfx_mpg "pizza_delivery";;
		"street vendor")
			relevant_skill_name="charisma"; relevant_skill_level=${skills[$relevant_skill_name]:-1}
			skill_bonus=$(( relevant_skill_level * 4 )); play_sfx_mpg "street_vendor";;
		*) echo "Internal Error: Invalid Job Type '$job_type'"; return;;
	esac

	if command -v working_animation &> /dev/null; then working_animation "$job_type"
	else echo "Working as a $job_type..."; sleep 2; fi

	earnings=$((base_earnings + skill_bonus)); (( earnings < 0 )) && earnings=0
	cash=$((cash + earnings)); clear_screen
	printf "Finished your shift. You earned \$%d (Base: \$%d, Skill Bonus: \$%d, Rep Bonus: %d%%).\n" \
		"$earnings" "$base_earnings" "$skill_bonus" "$rep_bonus_pct"

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

	if command -v race_animation &> /dev/null; then race_animation
	else echo "3... 2... 1... GO!"; sleep 1; fi

	read -r -p "Press Enter for the race results..."
	local winnings=0 damage=0
	if (( RANDOM % 100 < win_chance )); then
		winnings=$((RANDOM % 151 + 100 + driving_skill * 10)); cash=$((cash + winnings))
		damage=$((RANDOM % 15 + 5))
		if $body_armor_equipped; then local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction)); body_armor_equipped=false; fi
		health=$((health - damage)); clear_screen
		printf "\e[1;32m*** YOU WON THE RACE! ***\e[0m\n"
		printf "You collected \$%d.\n" "$winnings"; printf "Took minor damage (-%d%% health).\n" "$damage"
		play_sfx_mpg "win"; award_respect $((RANDOM % 15 + 10))
		if (( RANDOM % 3 == 0 )); then skills[driving]=$((driving_skill + 1)); printf "Your \e[1;32mdriving\e[0m skill increased!\n"; fi
	else
		damage=$((RANDOM % 31 + 15))
		if $body_armor_equipped; then local armor_reduction=$((damage / 2)); damage=$((damage - armor_reduction)); body_armor_equipped=false; fi
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
	local item_cost="$1"; local item_type="$2"
	if [[ -v "perks[Street Negotiator]" ]]; then item_cost=$(( item_cost * 90 / 100 )); fi
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
				fi;;
		esac
		read -r -p "Press Enter..."
	else
		echo "Not enough cash (\$$item_cost needed)."; read -r -p "Press Enter..."
	fi
}

rob_store() {
	run_clock 2
	local stealth_skill=${skills[stealth]:-1}; local base_chance=$((15 + stealth_skill * 5))
	local rep_bonus=$(get_city_rep_bonus)
	base_chance=$(( base_chance + rep_bonus ))
	clear_screen; echo "--- Rob Store ---"
	if command -v robbing_animation &> /dev/null; then robbing_animation; else echo "Making your move..."; sleep 1; fi
	local final_success_chance=$(apply_gun_bonus "$base_chance" "robbery")
	echo "Final success chance: ${final_success_chance}%"; read -r -p "Press Enter to attempt the robbery..."
	if (( RANDOM % 100 < final_success_chance )); then
		local loot=$((RANDOM % 151 + 50 + stealth_skill * 10)); cash=$((cash + loot))
		health=$((health - (RANDOM % 16 + 5))); clear_screen
		printf "\e[1;32mSuccess!\e[0m You grabbed \$%d.\n" "$loot"; play_sfx_mpg "cash_register"
		award_respect $((RANDOM % 10 + 5)); district_heat["$location"]=$(( ${district_heat[$location]:-0} + 2 ))
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
	if command -v burglary_animation &> /dev/null; then burglary_animation; else echo "Looking for an entry point..."; sleep 1; fi
	play_sfx_mpg "burglary_stealth"
	(( base_chance < 5 )) && base_chance=5; (( base_chance > 90 )) && base_chance=90
	echo "Final success chance: ${base_chance}%"; read -r -p "Press Enter..."
	if (( RANDOM % 100 < base_chance )); then
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
	if command -v heist_animation &> /dev/null; then heist_animation; else echo "Executing the plan..."; sleep 1; fi
	local final_success_chance=$(apply_gun_bonus "$base_chance" "heist")
	echo "Final success chance: ${final_success_chance}%"; read -r -p "Press Enter..."
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
	if command -v carjacking_animation &> /dev/null; then carjacking_animation; else echo "Spotting a target..."; sleep 1; fi
	local final_success_chance=$(apply_gun_bonus "$base_chance" "carjacking")
	echo "Final success chance: ${final_success_chance}%"; read -r -p "Press Enter..."
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
	local stealth_skill=${skills[stealth]:-1}; local base_chance=$(( 30 + stealth_skill * 6 ))
	(( base_chance > 90 )) && base_chance=90
	clear_screen; echo "--- Pickpocket ---"; echo "You scan the crowd for a target..."; sleep 1
	if (( RANDOM % 100 < base_chance )); then
		local loot=$(( RANDOM % 81 + 20 + stealth_skill * 5 )); cash=$(( cash + loot ))
		echo -e "\e[1;32mSuccess!\e[0m You lifted \$$loot without them noticing."
		play_sfx_mpg "cash_register"; award_respect $(( RANDOM % 5 + 1 ))
		district_heat["$location"]=$(( ${district_heat[$location]:-0} + 1 ))
		if (( RANDOM % 4 == 0 )); then skills[stealth]=$(( stealth_skill + 1 )); echo -e "Your \e[1;32mstealth\e[0m skill increased!"; fi
	else
		local wanted_gain=1
		if [[ -v "perks[Master of Disguise]" ]]; then wanted_gain=0; fi
		wanted_level=$(( wanted_level + wanted_gain )); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_gain > 0 )); then echo -e "\e[1;31mCaught! They felt your hand.\e[0m"; play_sfx_mpg "police_siren"; fi
		local fine=$(( RANDOM % 51 + 25 + wanted_level * 15 )); cash=$(( cash - fine )); (( cash < 0 )) && cash=0
		health=$(( health - (RANDOM % 11 + 5) )); echo "Fined \$$fine and roughed up."
	fi
	check_health; read -r -p "Press Enter..."
}

mug_someone() {
	run_clock 1
	local strength_skill=${skills[strength]:-1}; local stealth_skill=${skills[stealth]:-1}
	local base_chance=$(( 25 + strength_skill * 5 + stealth_skill * 3 ))
	(( base_chance > 90 )) && base_chance=90
	clear_screen; echo "--- Mugging ---"; echo "You follow someone into a quiet alley..."; sleep 1
	local final_chance=$(apply_gun_bonus "$base_chance" "mugging")
	echo "Final success chance: ${final_chance}%"; read -r -p "Press Enter to make your move..."
	if (( RANDOM % 100 < final_chance )); then
		local loot=$(( RANDOM % 121 + 40 + strength_skill * 8 )); cash=$(( cash + loot ))
		health=$(( health - (RANDOM % 11) ))
		echo -e "\e[1;32mSuccess!\e[0m You got \$$loot."; play_sfx_mpg "cash_register"
		award_respect $(( RANDOM % 8 + 3 )); district_heat["$location"]=$(( ${district_heat[$location]:-0} + 3 ))
		if (( RANDOM % 4 == 0 )); then skills[strength]=$(( strength_skill + 1 )); echo -e "Your \e[1;32mstrength\e[0m skill increased!"; fi
	else
		local wanted_gain=1
		if [[ -v "perks[Master of Disguise]" ]]; then wanted_gain=0; fi
		wanted_level=$(( wanted_level + wanted_gain )); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		if (( wanted_gain > 0 )); then echo -e "\e[1;31mThey fought back and screamed for help!\e[0m"; play_sfx_mpg "police_siren"; fi
		local fine=$(( RANDOM % 76 + 40 + wanted_level * 20 )); cash=$(( cash - fine )); (( cash < 0 )) && cash=0
		health=$(( health - (RANDOM % 21 + 10) )); echo "Fined \$$fine and took a beating."
	fi
	check_health; read -r -p "Press Enter..."
}

arson() {
	run_clock 3
	local stealth_skill=${skills[stealth]:-1}; local base_chance=$(( 20 + stealth_skill * 5 ))
	clear_screen; echo "--- Arson ---"; echo "You scout out a target building..."; sleep 1
	echo "Final success chance: ${base_chance}%"; read -r -p "Press Enter to proceed..."
	if (( RANDOM % 100 < base_chance )); then
		local payout=$(( RANDOM % 201 + 100 + stealth_skill * 15 )); cash=$(( cash + payout ))
		echo -e "\e[1;32mSuccess!\e[0m The building goes up in flames. Insurance payout: \$$payout."
		play_sfx_mpg "win"; award_respect $(( RANDOM % 25 + 15 ))
		district_heat["$location"]=$(( ${district_heat[$location]:-0} + 10 ))
		if (( RANDOM % 3 == 0 )); then skills[stealth]=$(( stealth_skill + 1 )); echo -e "Your \e[1;32mstealth\e[0m skill increased!"; fi
	else
		wanted_level=$(( wanted_level + 2 )); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		local fine=$(( RANDOM % 301 + 200 + wanted_level * 50 )); cash=$(( cash - fine )); (( cash < 0 )) && cash=0
		health=$(( health - (RANDOM % 31 + 20) ))
		echo -e "\e[1;31mCaught in the act!\e[0m Fined \$$fine, took burn damage."; play_sfx_mpg "police_siren"
	fi
	check_health; read -r -p "Press Enter..."
}

kidnap_for_ransom() {
	run_clock 6
	local strength_skill=${skills[strength]:-1}; local charisma_skill=${skills[charisma]:-1}
	local base_chance=$(( 15 + strength_skill * 4 + charisma_skill * 2 ))
	(( base_chance > 80 )) && base_chance=80
	clear_screen; echo "--- Kidnapping for Ransom ---"; echo "High risk, high reward. You stake out a wealthy target..."; sleep 2
	local final_chance=$(apply_gun_bonus "$base_chance" "kidnapping")
	echo "Final success chance: ${final_chance}%"; read -r -p "Press Enter to attempt..."
	if (( RANDOM % 100 < final_chance )); then
		local ransom=$(( RANDOM % 1001 + 500 + strength_skill * 50 )); cash=$(( cash + ransom ))
		health=$(( health - (RANDOM % 21 + 10) ))
		echo -e "\e[1;32mSuccess!\e[0m Ransom paid: \$$ransom. Target released unharmed."
		play_sfx_mpg "win_big"; award_respect $(( RANDOM % 50 + 30 ))
		district_heat["$location"]=$(( ${district_heat[$location]:-0} + 20 ))
	else
		wanted_level=$(( wanted_level + 3 )); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		local fine=$(( RANDOM % 501 + 300 + wanted_level * 75 )); cash=$(( cash - fine )); (( cash < 0 )) && cash=0
		health=$(( health - (RANDOM % 41 + 20) ))
		echo -e "\e[1;31mOperation blown!\e[0m Fined \$$fine, wanted level spiked."; play_sfx_mpg "lose_big"
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
	local cost_reduction=$((charisma_skill * 3)); local min_cost=$((40 - cost_reduction))
	(( min_cost < 15 )) && min_cost=15; local max_cost=$((100 - cost_reduction))
	(( max_cost <= min_cost )) && max_cost=$((min_cost + 20))
	local hooker_cost=$(( RANDOM % (max_cost - min_cost + 1) + min_cost ))
	clear_screen; echo "--- Seeking Company ---"; echo "You approach someone... They quote you \$$hooker_cost."
	if (( cash >= hooker_cost )); then
		read -r -p "Accept the offer? (y/n): " accept
		if [[ "$accept" == "y" || "$accept" == "Y" ]]; then
			play_sfx_mpg "cash_register"; cash=$(( cash - hooker_cost ))
			local health_gain=$(( RANDOM % 21 + 15 )); local previous_health=$health
			health=$(( health + health_gain ))
			local max_health=100; (( previous_health > 100 )) && max_health=$previous_health
			(( health > max_health )) && health=$max_health
			local actual_gain=$((health - previous_health)); clear_screen
			printf "You paid \$%d.\n" "$hooker_cost"
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
		1) convenience_store;; 2) black_market;; 3) clothing_store;; 4) return;; *) echo "Invalid." && sleep 1;;
	esac
}

convenience_store() {
	while true; do
		clear_screen; echo "--- Convenience Store ---"
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
			1) local cost=$(( 10 - discount ))
				if (( cash >= cost )); then cash=$(( cash - cost )); health=$(( health + 10 )); (( health > 100 )) && health=100
					echo "Munching on a snack. +10% health."; play_sfx_mpg "heal"
				else echo "Not enough cash."; fi;;
			2) local cost=$(( 25 - (discount * 2) ))
				if (( cash >= cost )); then cash=$(( cash - cost )); health=$(( health + 20 )); (( health > 100 )) && health=100
					echo "Chugging an energy drink. +20% health."; play_sfx_mpg "heal"
				else echo "Not enough cash."; fi;;
			3) local cost=$(( 60 - (discount * 6) ))
				if (( cash >= cost )); then cash=$(( cash - cost )); health=$(( health + 35 )); (( health > 100 )) && health=100
					echo "Patched up with a first aid kit. +35% health."; play_sfx_mpg "heal"
				else echo "Not enough cash."; fi;;
			4) local cost=$(( 30 - (discount * 3) ))
				if (( cash >= cost )); then cash=$(( cash - cost )); items+=("Health Pack")
					echo "Health Pack added to inventory."; play_sfx_mpg "item_buy"
				else echo "Not enough cash."; fi;;
			5) return;;
			*) echo "Invalid.";;
		esac
		read -r -p "Press Enter..."
	done
}

black_market() {
	clear_screen; echo "--- Black Market ---"; echo "You find a shady dealer in a back alley..."; sleep 1
	if (( RANDOM % 10 == 0 )); then
		echo -e "\e[1;31mIt's a sting operation!\e[0m Cops everywhere!"
		wanted_level=$(( wanted_level + 2 )); (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
		play_sfx_mpg "police_siren"; read -r -p "Press Enter..."; return
	fi
	while true; do
		clear_screen; echo "--- Black Market ---"; printf " Cash: \$%d\n" "$cash"
		echo "================================"
		echo " 1. Molotov Cocktail  (\$75)  - Usable chaos item"
		echo " 2. Fake ID           (\$200) - Reduces wanted level by 1"
		echo " 3. Adrenaline Shot   (\$150) - Temp health and strength boost"
		echo " 4. Stolen Goods      (\$50)  - Sell for profit at the fence"
		echo " 5. Leave"
		echo "================================"
		read -r -p "Choice: " c
		case "$c" in
			1) if (( cash >= 75 )); then cash=$(( cash - 75 )); items+=("Molotov Cocktail")
					echo "One Molotov, wrapped in newspaper."; play_sfx_mpg "item_buy"
				else echo "Not enough cash."; fi;;
			2) if (( cash >= 200 )); then cash=$(( cash - 200 )); items+=("Fake ID")
					echo "A convincing fake. Probably."; play_sfx_mpg "item_buy"
				else echo "Not enough cash."; fi;;
			3) if (( cash >= 150 )); then cash=$(( cash - 150 )); items+=("Adrenaline Shot")
					echo "Handle with care."; play_sfx_mpg "item_buy"
				else echo "Not enough cash."; fi;;
			4) if (( cash >= 50 )); then cash=$(( cash - 50 )); items+=("Stolen Goods")
					echo "Could be worth double at the fence."; play_sfx_mpg "item_buy"
				else echo "Not enough cash."; fi;;
			5) return;;
			*) echo "Invalid.";;
		esac
		read -r -p "Press Enter..."
	done
}

clothing_store() {
	while true; do
		clear_screen; echo "--- Zip Clothing ---"; printf " Cash: \$%d\n" "$cash"
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
			1) local cost=$(( 50 - (discount * 5) ))
				if (( cash >= cost )); then cash=$(( cash - cost ))
					district_heat["$location"]=$(( ${district_heat[$location]:-0} - 2 ))
					(( ${district_heat[$location]:-0} < 0 )) && district_heat["$location"]=0
					echo "Fresh outfit. You blend in better."; play_sfx_mpg "item_buy"
				else echo "Not enough cash."; fi;;
			2) local cost=$(( 150 - (discount * 15) ))
				if (( cash >= cost )); then cash=$(( cash - cost ))
					district_heat["$location"]=$(( ${district_heat[$location]:-0} - 5 ))
					(( ${district_heat[$location]:-0} < 0 )) && district_heat["$location"]=0
					skills[charisma]=$(( ${skills[charisma]:-1} + 1 ))
					echo "Looking sharp. Charisma up, heat down."; play_sfx_mpg "item_buy"
				else echo "Not enough cash."; fi;;
			3) local cost=$(( 100 - (discount * 10) ))
				if $body_armor_equipped; then echo "You already have armor equipped."
				elif (( cash >= cost )); then cash=$(( cash - cost )); body_armor_equipped=true
					echo "Body armor strapped on."; play_sfx_mpg "item_equip"
				else echo "Not enough cash."; fi;;
			4) local cost=$(( 175 - (discount * 17) ))
				if (( cash >= cost )); then cash=$(( cash - cost ))
					if (( wanted_level > 0 )); then
						wanted_level=$(( wanted_level - 1 )); echo "Wanted level reduced. New look, new you."
					else echo "No wanted level to reduce, but you look great."; fi
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
	local current_market_price=$(( base_price + (base_price * (price_fluctuation + location_modifier) / 100) ))
	(( current_market_price < 1 )) && current_market_price=1
	local buy_multiplier=${market_conditions["buy_multiplier"]:-1.0}
	local sell_multiplier=${market_conditions["crackdown_multiplier"]:-1.0}
	if [[ -v market_conditions["demand_multiplier"] ]]; then
		sell_multiplier=$(echo "scale=2; $sell_multiplier * ${market_conditions["demand_multiplier"]}" | bc)
	fi
	# Dealer contact bonus
	if [[ -v "contacts_unlocked[dealer]" && "$action" == "sell" ]]; then
		sell_multiplier=$(echo "scale=2; $sell_multiplier * 1.15" | bc)
	fi

	if command -v drug_transaction_animation &> /dev/null; then drug_transaction_animation "$action"; fi

	if [[ "$action" == "buy" ]]; then
		local final_price=$(echo "scale=0; $current_market_price * $buy_multiplier / 1" | bc)
		(( final_price < 1 )) && final_price=1
		local cost=$((final_price * drug_amount))
		if (( cash >= cost )); then
			cash=$((cash - cost)); drugs["$drug_name"]=$(( ${drugs[$drug_name]:-0} + drug_amount ))
			printf "Bought \e[1;33m%d\e[0m units of \e[1;33m%s\e[0m for \e[1;31m\$%d\e[0m.\n" "$drug_amount" "$drug_name" "$cost"
			play_sfx_mpg "cash_register"; return 0
		else
			printf "Not enough cash. Need \$%d, you have \$%d.\n" "$cost" "$cash"; return 1
		fi
	elif [[ "$action" == "sell" ]]; then
		local current_inventory=${drugs[$drug_name]:-0}
		if (( current_inventory >= drug_amount )); then
			local price_bonus_percent=$((drug_dealer_skill * 2))
			local skill_adjusted_price=$(( current_market_price + (current_market_price * price_bonus_percent / 100) ))
			local final_price=$(echo "scale=0; $skill_adjusted_price * $sell_multiplier / 1" | bc)
			(( final_price < 1 )) && final_price=1
			local income=$((final_price * drug_amount))
			cash=$((cash + income)); drugs["$drug_name"]=$((current_inventory - drug_amount))
			printf "Sold \e[1;33m%d\e[0m units of \e[1;33m%s\e[0m for \e[1;32m\$%d\e[0m.\n" "$drug_amount" "$drug_name" "$income"
			play_sfx_mpg "cash_register"
			if (( RANDOM % 2 == 0 )); then
				skills[drug_dealer]=$((drug_dealer_skill + 1))
				printf "Your \e[1;32mdrug dealing\e[0m skill increased!\n"
			fi
			return 0
		else
			printf "Not enough %s to sell. You have %d units.\n" "$drug_name" "$current_inventory"; return 1
		fi
	fi
}

buy_drugs() {
	run_clock 1; update_market_conditions
	local drug_choice="" drug_amount=""
	declare -A drug_prices=( ["Weed"]=10 ["Cocaine"]=50 ["Heroin"]=100 ["Meth"]=75 )
	local drug_names=("Weed" "Cocaine" "Heroin" "Meth")
	clear_screen; echo "--- Drug Dealer (Buy) ---"
	printf " Location: %-15s | Cash: \$%d\n" "$location" "$cash"
	if [[ -n "${market_conditions["event_message"]}" ]]; then
		printf " \e[1;36mMarket News: %s\e[0m\n" "${market_conditions["event_message"]}"
	fi
	echo "---------------------------"
	local location_modifier=0
	case "$location" in
		"Liberty City") location_modifier=15;; "Las Venturas") location_modifier=10;; "Vice City") location_modifier=-15;;
	esac
	local i=1
	for name in "${drug_names[@]}"; do
		local base_p=${drug_prices[$name]}; local approx_p=$(( base_p + (base_p * location_modifier / 100) ))
		local buy_mult=${market_conditions["buy_multiplier"]:-1.0}
		if command -v bc &> /dev/null; then approx_p=$(echo "scale=0; $approx_p * $buy_mult / 1" | bc); fi
		(( approx_p < 1 )) && approx_p=1; printf " %d. %-10s (\~$%d/unit)\n" "$i" "$name" "$approx_p"; ((i++))
	done
	echo "---------------------------"; printf " %d. Leave\n" "$i"; echo "---------------------------"
	read -r -p "Choose drug to buy (number): " drug_choice
	if [[ "$drug_choice" == "$i" ]]; then return; fi
	if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#drug_names[@]} )); then
		echo "Invalid choice."; sleep 1; return
	fi
	local chosen_drug_name="${drug_names[$((drug_choice - 1))]}"; local chosen_drug_price="${drug_prices[$chosen_drug_name]}"
	read -r -p "Enter amount of $chosen_drug_name to buy: " drug_amount
	drug_transaction "buy" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"; read -r -p "Press Enter..."
}

sell_drugs() {
	run_clock 1; update_market_conditions
	local drug_choice="" drug_amount=""
	declare -A drug_sell_prices=( ["Weed"]=15 ["Cocaine"]=75 ["Heroin"]=150 ["Meth"]=100 )
	local drug_names=("Weed" "Cocaine" "Heroin" "Meth")
	clear_screen; echo "--- Drug Dealer (Sell) ---"
	printf " Location: %-15s | Cash: \$%d\n" "$location" "$cash"
	if [[ -n "${market_conditions["event_message"]}" ]]; then
		printf " \e[1;36mMarket News: %s\e[0m\n" "${market_conditions["event_message"]}"
	fi
	echo "--------------------------"
	local location_modifier=0
	case "$location" in
		"Liberty City") location_modifier=15;; "Las Venturas") location_modifier=10;; "Vice City") location_modifier=-15;;
	esac
	local i=1; local available_to_sell=()
	for name in "${drug_names[@]}"; do
		local inventory_amount=${drugs[$name]:-0}
		if (( inventory_amount > 0 )); then
			local base_p=${drug_sell_prices[$name]}; local dealer_skill=${skills[drug_dealer]:-1}
			local skill_bonus_p=$(( dealer_skill * 2 ))
			local approx_p=$(( base_p + (base_p * ( location_modifier + skill_bonus_p ) / 100) ))
			local sell_mult=${market_conditions["crackdown_multiplier"]:-1.0}
			if [[ -v market_conditions["demand_multiplier"] ]]; then
				if command -v bc &> /dev/null; then
					sell_mult=$(echo "scale=2; $sell_mult * ${market_conditions["demand_multiplier"]}" | bc)
				fi
			fi
			if command -v bc &> /dev/null; then approx_p=$(echo "scale=0; $approx_p * $sell_mult / 1" | bc); fi
			(( approx_p < 1 )) && approx_p=1
			printf " %d. %-10s (%d units) ~\$%d/unit\n" "$i" "$name" "$inventory_amount" "$approx_p"
			available_to_sell+=("$name"); ((i++))
		fi
	done
	if (( ${#available_to_sell[@]} == 0 )); then
		echo "--------------------------"; echo "You have no drugs to sell."; read -r -p "Press Enter to leave..."; return
	fi
	echo "--------------------------"; printf " %d. Leave\n" "$i"; echo "--------------------------"
	read -r -p "Choose drug to sell (number): " drug_choice
	if [[ "$drug_choice" == "$i" ]]; then return; fi
	if ! [[ "$drug_choice" =~ ^[0-9]+$ ]] || (( drug_choice < 1 || drug_choice > ${#available_to_sell[@]} )); then
		echo "Invalid choice."; sleep 1; return
	fi
	local chosen_drug_name="${available_to_sell[$((drug_choice - 1))]}"; local chosen_drug_price="${drug_sell_prices[$chosen_drug_name]}"
	local current_inventory=${drugs[$chosen_drug_name]}
	read -r -p "Sell how many units of $chosen_drug_name? (Max: $current_inventory): " drug_amount
	drug_transaction "sell" "$chosen_drug_name" "$chosen_drug_price" "$drug_amount"; read -r -p "Press Enter..."
}

# --- Music Player ---
stop_music() {
	if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
		echo "Stopping currently playing music..."
		kill "$music_pid" &>/dev/null; wait "$music_pid" 2>/dev/null; music_pid=""
	fi
}

play_music() {
	if ! $mpg123_available; then echo "Music playback disabled: 'mpg123' command not found."; read -r -p "Press Enter..."; return 1; fi
	local music_dir="$BASEDIR/music"; local music_files=(); local original_ifs="$IFS"
	if [[ ! -d "$music_dir" ]]; then echo "Error: Music directory '$music_dir' not found!"; read -r -p "Press Enter..."; return 1; fi
	while IFS= read -r -d $'\0' file; do music_files+=("$file"); done < <(find "$music_dir" -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.MP3" \) -print0 2>/dev/null)
	IFS="$original_ifs"
	if (( ${#music_files[@]} == 0 )); then echo "No .mp3 files found in '$music_dir'."; read -r -p "Press Enter..."; return 1; fi
	local choice_stop="s" choice_back="b" music_choice=""
	local mpg123_log="/tmp/bta_mpg123_errors.$$.log"
	while true; do
		clear_screen; echo "--- Music Player ---"; echo " Music Directory: $music_dir"; echo "----------------------------------------"
		local current_status="Stopped"
		if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
			current_status="Playing (PID: $music_pid)"
		else [[ -n "$music_pid" ]] && music_pid=""; current_status="Stopped"; fi
		echo " Status: $current_status"; echo "----------------------------------------"; echo " Available Tracks:"
		for i in "${!music_files[@]}"; do printf " %d. %s\n" $((i + 1)) "$(basename "${music_files[$i]}")"; done
		echo "----------------------------------------"; printf " [%s] Stop | [%s] Back\n" "$choice_stop" "$choice_back"
		stty echo; read -r -p "Enter choice: " music_choice
		case "$music_choice" in
			"$choice_stop"|"q")
				if [[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null; then
					kill "$music_pid" &>/dev/null; sleep 0.2; wait "$music_pid" 2>/dev/null; music_pid=""; echo "Music stopped."
				fi; stty echo; sleep 1;;
			"$choice_back"|"b") echo "Returning to game..."; sleep 1; break;;
			*)
				if [[ "$music_choice" =~ ^[0-9]+$ ]] && (( music_choice >= 1 && music_choice <= ${#music_files[@]} )); then
					local selected_track="${music_files[$((music_choice - 1))]}"
					[[ -n "$music_pid" ]] && kill -0 "$music_pid" 2>/dev/null && { kill "$music_pid" &>/dev/null; wait "$music_pid" 2>/dev/null; music_pid=""; sleep 0.2; }
					echo "--- BTA Log $(date) --- Playing: $selected_track" >> "$mpg123_log"
					mpg123 -q "$selected_track" 2>> "$mpg123_log" &
					local new_pid=$!
					sleep 0.5
					if kill -0 "$new_pid" 2>/dev/null; then music_pid=$new_pid; echo "Playback started."
					else echo "Error starting mpg123."; music_pid=""; read -r -p "Press Enter..."; fi
				else echo "Invalid."; sleep 1; fi;;
		esac
	done
}

# --- Gang System Functions ---
set_initial_gang_relations() {
	gang_relations=()
	for rival in "${!GANG_HOME_CITY[@]}"; do
		if [[ "$rival" != "$player_gang" ]]; then gang_relations["$rival"]="Hostile"; fi
	done
	if [[ "$player_gang" == "Grove Street" ]]; then gang_relations["Ballas"]="War"; gang_relations["Vagos"]="War"; fi
}

apply_gang_upgrades() {
	local safe_house_level=${gang_upgrades[safe_house]:-0}; max_recruits=$(( 2 + safe_house_level * 2 ))
}

join_or_create_gang_menu() {
	while true; do
		clear_screen; echo "--- Faction Options ---"; echo "------------------------------------------"
		echo "1. Join an Existing Faction (in this city)"
		if (( player_respect >= GANG_CREATION_RESPECT_REQ )); then
			echo -e "2. Create Your Own Faction (Req: \e[1;32m${GANG_CREATION_RESPECT_REQ}\e[0m Respect)"
		else echo -e "2. Create Your Own Faction (\e[1;31mLocked\e[0m - Requires ${GANG_CREATION_RESPECT_REQ} Respect)"; fi
		echo "3. Back"; echo "------------------------------------------"
		read -r -p "Enter your choice: " choice
		case "$choice" in
			1) join_gang_interface; if [[ "$player_gang" != "None" ]]; then break; fi;;
			2) if (( player_respect >= GANG_CREATION_RESPECT_REQ )); then create_own_gang; if [[ "$player_gang" != "None" ]]; then break; fi
				else echo "Not enough respect."; read -r -p "Press Enter..."; fi;;
			3) return;; *) echo "Invalid choice." && sleep 1;;
		esac
	done
}

show_gang_menu() {
	run_clock 0
	while true; do
		clear_screen; echo "--- Gang & Empire Management ---"
		echo "1. View Territory Map      2. Manage Businesses"
		echo "3. Initiate Gang War        4. Drive-By Mission"
		echo "5. Send Gang Spy            6. Gang Upgrades"
		if [[ "$player_gang" == "None" ]]; then
			echo "7. Join or Create a Faction"
		else
			echo "7. Manage Recruits         8. Diplomacy"
		fi
		echo "B. Back"; read -r -p "Choice: " choice
		case "$choice" in
			1) show_territory_map;; 2) manage_businesses;; 3) initiate_gang_war;;
			4) drive_by_mission;; 5) send_gang_spy;;
			6) if [[ "$player_gang" != "None" ]]; then gang_upgrades_menu; else echo "Invalid." && sleep 1; fi;;
			7) if [[ "$player_gang" == "None" ]]; then join_or_create_gang_menu; else manage_recruits_menu; fi;;
			8) if [[ "$player_gang" != "None" ]]; then diplomacy_menu; else echo "Invalid." && sleep 1; fi;;
			'b'|'B') return;; *) echo "Invalid choice." && sleep 1;;
		esac
	done
}

show_territory_map() {
	run_clock 0; clear_screen; echo "--- ${location} Territory Map ---"; echo "---------------------------------"
	local territory_found=false
	for key in "${!territory_owner[@]}"; do
		local owner="${territory_owner[$key]}"; local city="${key%|*}"; local district="${key#*|}"
		if [[ "$city" == "$location" ]]; then
			local display_owner="$owner"; territory_found=true; local color="\e[0m"
			if [[ "$owner" == "$player_gang" && "$player_gang" != "None" ]]; then color="\e[1;36m"
			elif [[ "$owner" == "Grove Street" ]]; then color="\e[1;32m"
			elif [[ "$owner" == "Ballas" || "$owner" == "Leone Family" ]]; then color="\e[1;35m"
			elif [[ "$owner" == "Vagos" || "$owner" == "Triads" ]]; then color="\e[1;33m"
			elif [[ "$owner" == "Da Nang Boys" || "$owner" == "Sindacco Family" ]]; then color="\e[1;31m"
			elif [[ "$owner" == "Unaffiliated" ]]; then color="\e[1;37m"; display_owner="Government Control"; fi
			printf "| %-20s | Owner: %b%s\e[0m\n" "$district" "$color" "$display_owner"
		fi
	done
	if ! $territory_found; then echo "No contested territories in this city."; fi
	echo "---------------------------------"; read -r -p "Press Enter to return..."
}

manage_businesses() {
	run_clock 1; clear_screen; echo "--- Business Management ---"
	echo "1. Buy New Property (in ${location})"; echo "2. Manage Owned Properties"; echo "B. Back"
	read -r -p "Choice: " choice
	case "$choice" in 1) buy_property;; 2) manage_owned_property;; 'b'|'B') return;; *) echo "Invalid." && sleep 1;; esac
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
	if (( ${#prop_keys[@]} == 0 )); then echo "No properties for sale in this city."; fi
	echo "B. Back"; read -r -p "Which property to buy? " choice
	if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#prop_keys[@]} )); then
		local index=$((choice - 1)); local prop_to_buy="${prop_keys[$index]}"
		local prop_cost="${prop_costs[$index]}"; local prop_type="${prop_types[$index]}"
		if (( cash >= prop_cost )); then
			cash=$((cash - prop_cost)); owned_businesses["$prop_to_buy"]="type=$prop_type status=Idle"
			echo "Purchased $prop_to_buy for \$${prop_cost}!"; play_sfx_mpg "cash_register"
		else echo "Not enough cash."; fi
	elif [[ "$choice" != "b" && "$choice" != "B" ]]; then echo "Invalid selection."; fi
	read -r -p "Press Enter..."
}

manage_owned_property() {
	clear_screen; echo "--- Your Properties (Global) ---"
	if (( ${#owned_businesses[@]} == 0 )); then echo "You don't own any properties."; read -r -p "Press Enter..."; return; fi
	local i=1; local -a owned_prop_keys=()
	for prop in "${!owned_businesses[@]}"; do
		printf "%d. %-25s (%s)\n" "$i" "$prop" "${owned_businesses[$prop]}"; owned_prop_keys+=("$prop"); ((i++))
	done
	echo "B. Back"; read -r -p "Select property to manage: " choice
	if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#owned_prop_keys[@]} )); then
		echo "Managing ${owned_prop_keys[$((choice-1))]}... Upgrade/production system coming soon."
	fi
	read -r -p "Press Enter..."
}

create_own_gang() {
	run_clock 1; clear_screen; echo "--- Found Your Own Gang ---"
	read -r -p "Enter the name for your new gang: " new_gang_name
	if [[ -z "$new_gang_name" || "$new_gang_name" == "None" || "$new_gang_name" == "Unaffiliated" || -v "GANG_HOME_CITY[$new_gang_name]" ]]; then
		echo "Invalid or reserved name."; read -r -p "Press Enter..."; return
	fi
	player_gang="$new_gang_name"; player_gang_rank="Boss"; set_initial_gang_relations
	play_sfx_mpg "win_big"; echo -e "\nThe \e[1;36m${player_gang}\e[0m are now on the map!"
	echo "You are their leader, rank of ${player_gang_rank}."; read -r -p "Press Enter..."
}

join_gang_interface() {
	run_clock 1
	if [[ "$player_gang" != "None" ]]; then echo "Already in $player_gang."; read -r -p "Press Enter..."; return; fi
	local i=1; local -a menu_options=(); clear_screen
	echo "--- Join a Faction in ${location} ---"; echo "------------------------------------------------"
	for gang in "${!GANG_HOME_CITY[@]}"; do
		if [[ "${GANG_HOME_CITY[$gang]}" == "$location" ]]; then
			printf " %d. Join the %s\n" "$i" "$gang"; menu_options+=("$gang"); ((i++))
		fi
	done
	if (( ${#menu_options[@]} == 0 )); then echo " No major gangs looking for recruits here."; read -r -p "Press Enter..."; return; fi
	echo "------------------------------------------------"; local back_option_number=$i
	printf " %d. Back\n" "$back_option_number"; read -r -p "Your choice: " choice
	if [[ "$choice" == "$back_option_number" ]]; then return
	elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#menu_options[@]} )); then
		local new_gang="${menu_options[$((choice-1))]}"; echo "You approach the ${new_gang} crew..."; sleep 2
		echo "'So you want to roll with us? You gotta prove yourself first.'"
		if (( cash >= 200 )); then
			echo "They ask for a \$200 'tribute'."; read -r -p "Pay the tribute? (y/n): " pay
			if [[ "$pay" == "y" || "$pay" == "Y" ]]; then
				cash=$((cash-200)); player_gang="$new_gang"; player_gang_rank="Associate"; set_initial_gang_relations
				echo "Welcome to ${player_gang}."; award_respect 100
			else echo "You walked away."; fi
		else echo "You don't have the cash to get their attention."; fi
	else echo "Invalid choice."; fi
	read -r -p "Press Enter to continue..."
}

initiate_gang_war() {
	run_clock 3
	if [[ "$player_gang" == "None" || "$player_gang_rank" == "Outsider" ]]; then
		echo "You need to be part of a gang to start a war."; read -r -p "Press Enter..."; return
	fi
	if (( ${#guns[@]} == 0 )); then echo "You need a weapon to start a gang war!"; read -r -p "Press Enter..."; return; fi

	local -a attackable_keys=(); local i=0; clear_screen
	echo "--- Select a Territory to Attack in ${location} ---"
	for key in "${!territory_owner[@]}"; do
		local city="${key%|*}"; local district="${key#*|}"; local owner="${territory_owner[$key]}"
		if [[ "$city" == "$location" && "$owner" != "$player_gang" ]]; then
			local display_owner="$owner"; local color="\e[1;31m"
			if [[ "$owner" == "Unaffiliated" ]]; then display_owner="Government Control"; color="\e[1;37m"; fi
			i=$((i + 1))
			printf " %d. Attack \e[1;33m%s\e[0m (Controlled by: %b%s\e[0m)\n" "$i" "$district" "$color" "$display_owner"
			attackable_keys+=("$key")
		fi
	done
	if (( ${#attackable_keys[@]} == 0 )); then echo "You hold all available territories in this city!"; read -r -p "Press Enter..."; return; fi
	echo "---------------------------------------------------"
	local back_option_num=$((i + 1)); echo " ${back_option_num}. Back"; read -r -p "Choose your target: " choice
	if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > back_option_num )); then
		echo "Invalid choice."; read -r -p "Press Enter..."; return
	fi
	if (( choice == back_option_num )); then return; fi

	local index=$((choice - 1))
	if [[ -z "${attackable_keys[$index]}" ]]; then echo "Internal Error."; read -r -p "Press Enter..."; return; fi

	local target_key="${attackable_keys[$index]}"; local rival_gang="${territory_owner[$target_key]}"
	local target_district="${target_key#*|}"

	clear_screen; echo -e "About to start a war for \e[1;33m${target_district}\e[0m in ${location}."
	read -r -p "Are you ready to fight? (y/n) " confirm
	if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then echo "You back off."; read -r -p "Press Enter..."; return; fi

	local recruit_bonus=0
	for recruit in "${player_recruits[@]}"; do
		local _ str _; IFS=':' read -r _ str _ <<< "$recruit"; recruit_bonus=$((recruit_bonus + str))
	done
	local locker_level=${gang_upgrades[weapon_locker]:-0}; local locker_bonus=$((locker_level * 2))
	local total_bonus=$((recruit_bonus + locker_bonus))
	if (( total_bonus > 0 )); then echo "Crew bonus: \e[1;32m+${total_bonus}%\e[0m"; fi

	if command -v gang_war_animation &> /dev/null; then gang_war_animation; else echo "Bullets start flying!"; sleep 1; fi

	local wave=1; local success=true
	local num_waves=$(( RANDOM % 2 + 2 ))
	if [[ "$rival_gang" != "Unaffiliated" ]]; then num_waves=3; fi

	while (( wave <= num_waves )); do
		echo "--- WAVE ${wave} ---"; local strength_skill=${skills[strength]:-1}
		local success_chance=$(( 60 + strength_skill*3 - wave*10 + total_bonus ))
		if (( RANDOM % 100 < success_chance )); then
			echo "You fought them off! (Chance: ${success_chance}%)"
			local wave_damage=$(( RANDOM % (5 * wave) + 5)); health=$((health - wave_damage))
			echo "Took ${wave_damage}%% damage."; if ! check_health; then success=false; break; fi
			((wave++)); sleep 1
		else
			echo "Overwhelmed! (Chance: ${success_chance}%)"; health=$((health - (RANDOM % 20 + 15))); success=false; break
		fi
		if (( RANDOM % 2 == 0 )); then
			wanted_level=$((wanted_level + 1)); echo -e "\e[1;31mPolice attention! Wanted level up!\e[0m"; play_sfx_mpg "police_siren"
			if (( wanted_level >= 3 )); then echo "SWAT moving in! War is over!"; success=false; break; fi
		fi
	done

	if $success; then
		clear_screen; echo -e "\e[1;32m*** VICTORY! ***\e[0m"
		echo -e "You control \e[1;33m${target_district}\e[0m for the ${player_gang}!"
		territory_owner["$target_key"]="$player_gang"; award_respect $((RANDOM % 150 + 100))
		district_heat["$location"]=$(( ${district_heat[$location]:-0} + 20 )); play_sfx_mpg "win_big"
	else
		clear_screen; echo -e "\e[1;31m--- DEFEAT! ---\e[0m"
		echo "You were forced to retreat."
		player_respect=$((player_respect - 50)); ((player_respect < 0)) && player_respect=0; echo "Lost 50 Respect."
		play_sfx_mpg "lose_big"
	fi
	check_health; read -r -p "Press Enter..."
}

manage_recruits_menu() {
	run_clock 1
	local recruit_names=("Spike" "Knuckles" "Ghost" "Tiny" "Whisper" "Shadow" "Rico" "Vinnie")
	while true; do
		clear_screen; echo "--- Manage Recruits ---"; echo "Recruits: ${#player_recruits[@]} / ${max_recruits}"; echo "-----------------------------------"
		if (( ${#player_recruits[@]} == 0 )); then echo " You have no recruits."; else
			for recruit in "${player_recruits[@]}"; do
				local name str upkeep; IFS=':' read -r name str upkeep <<< "$recruit"
				printf " - %-10s (Strength: %d, Upkeep: \$%d/day)\n" "$name" "$str" "$upkeep"
			done
		fi
		echo "-----------------------------------"; echo "1. Hire New Recruit  2. Back"
		read -r -p "Choice: " choice
		case "$choice" in
			1)
				if (( ${#player_recruits[@]} < max_recruits )); then
					local hire_cost=$((RANDOM % 501 + 500))
					if [[ -v "perks[Charismatic Leader]" ]]; then hire_cost=$(( hire_cost * 75 / 100 )); fi
					if (( cash >= hire_cost )); then
						cash=$((cash - hire_cost)); local name=${recruit_names[RANDOM % ${#recruit_names[@]}]}
						local str=$((RANDOM % 4 + 2)); local upkeep=$((str * 25))
						if [[ -v "perks[Charismatic Leader]" ]]; then upkeep=$(( upkeep * 75 / 100 )); fi
						player_recruits+=("${name}:${str}:${upkeep}")
						echo "Hired ${name} for \$${hire_cost}."; play_sfx_mpg "cash_register"
					else echo "Not enough cash (cost ~\$${hire_cost})."; fi
				else echo "Can't hire more. Upgrade your Safe House."; fi
				read -r -p "Press Enter...";;
			2) return;; *) echo "Invalid." && sleep 1;;
		esac
	done
}

gang_upgrades_menu() {
	run_clock 1
	declare -A UPGRADE_COSTS=( ["safe_house"]="5000 15000 40000" ["weapon_locker"]="10000 25000 50000" ["smuggling_routes"]="20000 50000 100000" )
	declare -A UPGRADE_DESCS=( ["safe_house"]="Increases max recruits (+2 per level)" ["weapon_locker"]="Passive bonus in gang wars (+2% per level)" ["smuggling_routes"]="Increases income from illegal businesses (+\$100/day per level)" )
	while true; do
		clear_screen; echo "--- Gang Upgrades ---"; echo "--------------------------------------------------------"
		local i=1; local -a upgrade_keys=("safe_house" "weapon_locker" "smuggling_routes")
		for key in "${upgrade_keys[@]}"; do
			local level=${gang_upgrades[$key]:-0}; local costs=(${UPGRADE_COSTS[$key]}); local desc=${UPGRADE_DESCS[$key]}
			local readable_key; readable_key=$(tr '_' ' ' <<< "$key" | awk '{for(j=1;j<=NF;j++) $j=toupper(substr($j,1,1)) substr($j,2)} 1')
			printf " %d. %-20s (Level %d)\n" "$i" "$readable_key" "$level"
			echo "    - ${desc}"
			if (( level < ${#costs[@]} )); then printf "    - Next Level Cost: \e[1;31m\$%d\e[0m\n" "${costs[$level]}"; else echo -e "    - \e[1;32mMAX LEVEL\e[0m"; fi
			((i++))
		done
		echo "--------------------------------------------------------"; echo "$i. Back"
		read -r -p "Purchase upgrade (number): " choice
		if [[ "$choice" == "$i" ]]; then return
		elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice < i )); then
			local key="${upgrade_keys[$((choice-1))]}"; local level=${gang_upgrades[$key]:-0}; local costs=(${UPGRADE_COSTS[$key]})
			if (( level < ${#costs[@]} )); then
				local cost=${costs[$level]}
				if (( cash >= cost )); then
					cash=$((cash - cost)); gang_upgrades[$key]=$((level + 1)); apply_gang_upgrades
					echo "Upgrade purchased!"; play_sfx_mpg "cash_register"
				else echo "Not enough cash (\$$cost needed)."; fi
			else echo "Already max level."; fi
			read -r -p "Press Enter..."
		else echo "Invalid." && sleep 1; fi
	done
}

diplomacy_menu() {
	run_clock 1
	while true; do
		clear_screen; echo "--- Diplomacy ---"; echo "-------------------------------------------------------------------"
		for rival in "${!gang_relations[@]}"; do
			local status="${gang_relations[$rival]}"; local color="\e[0m"
			case "$status" in "War") color="\e[1;35m";; "Hostile") color="\e[1;31m";; "Neutral") color="\e[1;33m";; esac
			printf " - %-20s Status: %b%s\e[0m\n" "$rival" "$color" "$status"
		done
		echo "-------------------------------------------------------------------"; local menu_idx=1; local -a hostile_gangs=()
		for rival in "${!gang_relations[@]}"; do
			if [[ "${gang_relations[$rival]}" == "Hostile" ]]; then
				printf " %d. Offer Tribute to the %s\n" "$menu_idx" "$rival"; hostile_gangs+=("$rival"); ((menu_idx++))
			fi
		done
		if (( ${#hostile_gangs[@]} == 0 )); then echo " No active diplomatic actions available."; fi
		echo "-------------------------------------------------------------------"; echo "B. Back"
		read -r -p "Choice: " choice
		if [[ "$choice" == "B" || "$choice" == "b" ]]; then return
		elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice > 0 && choice <= ${#hostile_gangs[@]} )); then
			local target_gang="${hostile_gangs[$((choice-1))]}"; local tribute_cost=10000
			echo "Tribute to ${target_gang} costs \$${tribute_cost}."; read -r -p "Sure? (y/n): " confirm
			if [[ "$confirm" == "y" && "$cash" -ge "$tribute_cost" ]]; then
				cash=$((cash - tribute_cost)); local charisma_skill=${skills[charisma]:-1}
				local success_chance=$(( 30 + charisma_skill * 5 )); echo "They consider your offer... (${success_chance}%)"; sleep 2
				if (( RANDOM % 100 < success_chance )); then
					echo -e "\e[1;32mRelations now Neutral.\e[0m"; gang_relations["$target_gang"]="Neutral"
				else echo -e "\e[1;31mFailed!\e[0m They took your money and laughed."; fi
			elif [[ "$confirm" == "y" ]]; then echo "Not enough cash."; else echo "Cancelled."; fi
			read -r -p "Press Enter..."
		else echo "Invalid." && sleep 1; fi
	done
}

# --- Gambling Den ---
gambling_den() {
	if [[ "$location" != "Las Venturas" ]]; then
		echo "Gambling dens are only available in Las Venturas."; read -r -p "Press Enter..."; return
	fi
	run_clock 1
	while true; do
		clear_screen; echo "--- The Lucky Snake Casino ---"; printf " Cash: \$%d\n" "$cash"
		echo "=============================="
		echo "1. Slot Machine   (\$25 bet)"
		echo "2. Dice Roll      (custom bet)"
		echo "3. High/Low Cards (custom bet)"
		echo "4. Leave"
		echo "=============================="
		read -r -p "Choice: " choice
		case "$choice" in 1) gamble_slots;; 2) gamble_dice;; 3) gamble_cards;; 4) return;; *) echo "Invalid." && sleep 1;; esac
	done
}

gamble_slots() {
	local bet=25
	if (( cash < bet )); then echo "Need \$$bet to play slots."; read -r -p "Press Enter..."; return; fi
	cash=$(( cash - bet ))
	local symbols=("CHERRY" "LEMON" "BELL" "BAR" "SEVEN" "SKULL")
	local r1=${symbols[RANDOM % ${#symbols[@]}]}; local r2=${symbols[RANDOM % ${#symbols[@]}]}; local r3=${symbols[RANDOM % ${#symbols[@]}]}
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
	local player_roll=$(( RANDOM % 6 + 1 + RANDOM % 6 + 1 )); local house_roll=$(( RANDOM % 6 + 1 + RANDOM % 6 + 1 ))
	echo "You rolled: $player_roll  |  House rolled: $house_roll"
	if (( player_roll > house_roll )); then
		local win=$(( bet * 2 )); cash=$(( cash + win ))
		echo -e "\e[1;32mYou win! +\$$bet\e[0m"; play_sfx_mpg "win"
	elif (( player_roll == house_roll )); then
		cash=$(( cash + bet )); echo -e "\e[1;33mTie — bet returned.\e[0m"
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
	local player_card=$(( RANDOM % 13 + 1 )); local house_card=$(( RANDOM % 13 + 1 ))
	cash=$(( cash - bet ))
	echo ""; echo "1. Higher   2. Lower"; read -r -p "Will the house card be higher or lower than yours ($player_card)? " hl
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

# =====================================================
# Save / Load System
# =====================================================
save_game() {
	run_clock 0
	local save_path="$BASEDIR/$SAVE_DIR"
	mkdir -p "$save_path" || { echo "Error: Could not create save directory."; return 1; }
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
		echo "perk_points@@@$perk_points"
		echo "last_milestone@@@$last_respect_milestone"
		echo "loan_amount@@@$loan_amount"
		echo "loan_interest@@@$loan_interest"
		echo "loan_due_day@@@$loan_due_day"
		echo "loan_rate@@@$loan_rate"
		echo "loan_enforcer_warned@@@$loan_enforcer_warned"
		echo "safehouse@@@$rented_safehouse"
		echo "safehouse_day@@@$safehouse_rent_day"
		echo "player_bounty@@@$player_bounty"
		echo "bounty_hitman@@@$bounty_hitman_name"
		echo "auction_active@@@$auction_active"
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

	save_assoc_array() {
		local file_path="$1"; shift; declare -n arr_ref="$1"; : > "$file_path"
		for key in "${!arr_ref[@]}"; do printf "%s@@@%s\n" "$key" "${arr_ref[$key]}" >> "$file_path"; done
	}
	save_assoc_array "$save_path/skills.sav" "skills"
	save_assoc_array "$save_path/drugs.sav" "drugs"
	save_assoc_array "$save_path/territory.sav" "territory_owner"
	save_assoc_array "$save_path/businesses.sav" "owned_businesses"
	save_assoc_array "$save_path/upgrades.sav" "gang_upgrades"
	save_assoc_array "$save_path/relations.sav" "gang_relations"
	save_assoc_array "$save_path/city_rep.sav" "city_reputation"
	save_assoc_array "$save_path/protection.sav" "protection_income"
	save_assoc_array "$save_path/contacts.sav" "contacts_unlocked"
	save_assoc_array "$save_path/perks.sav" "perks"

	command -v bounty_save_extra &>/dev/null && bounty_save_extra
	command -v economy_save_extra &>/dev/null && economy_save_extra

	echo "Game saved successfully."; read -r -p "Press Enter..."
}

load_game() {
	local save_path="$BASEDIR/$SAVE_DIR"
	if [[ ! -f "$save_path/player.sav" ]]; then echo "Error: Save file not found."; return 1; fi
	echo "Loading game..."; initialize_world_data

	while IFS= read -r line || [[ -n "$line" ]]; do
		[[ -z "$line" ]] && continue
		local key="${line%%@@@*}"; local value="${line#*@@@}"
		case "$key" in
			"name") player_name="$value";; "location") location="$value";; "cash") cash="$value";;
			"health") health="$value";; "armor") body_armor_equipped="$value";; "wanted") wanted_level="$value";;
			"gang") player_gang="$value";; "rank") player_gang_rank="$value";; "respect") player_respect="$value";;
			"perk_points") perk_points="$value";; "last_milestone") last_respect_milestone="$value";;
			"loan_amount") loan_amount="$value";; "loan_interest") loan_interest="$value";;
			"loan_due_day") loan_due_day="$value";; "loan_rate") loan_rate="$value";;
			"loan_enforcer_warned") loan_enforcer_warned="$value";;
			"safehouse") rented_safehouse="$value";; "safehouse_day") safehouse_rent_day="$value";;
			"player_bounty") player_bounty="$value";; "bounty_hitman") bounty_hitman_name="$value";;
			"auction_active") auction_active="$value";;
		esac
	done < "$save_path/player.sav"

	if [[ -f "$save_path/time.sav" ]]; then
		while IFS= read -r line || [[ -n "$line" ]]; do
			[[ -z "$line" ]] && continue
			local key="${line%%@@@*}"; local value="${line#*@@@}"
			case "$key" in "day") game_day="$value";; "hour") game_hour="$value";; esac
		done < "$save_path/time.sav"
	fi

	load_indexed_array() {
		local file_path="$1"; shift; declare -n arr_ref="$1"; arr_ref=()
		if [[ -f "$file_path" ]]; then while IFS= read -r line; do [[ -n "$line" ]] && arr_ref+=("$line"); done < "$file_path"; fi
	}
	load_indexed_array "$save_path/guns.sav" "guns"
	load_indexed_array "$save_path/items.sav" "items"
	load_indexed_array "$save_path/vehicles.sav" "owned_vehicles"
	load_indexed_array "$save_path/recruits.sav" "player_recruits"
	load_indexed_array "$save_path/log.sav" "world_event_log"

	load_assoc_array() {
		local file_path="$1"; shift; declare -n arr_ref="$1"; arr_ref=()
		if [[ -f "$file_path" ]]; then
			while IFS= read -r line || [[ -n "$line" ]]; do
				[[ -n "$line" ]] && local key="${line%%@@@*}" && local value="${line#*@@@}" && arr_ref["$key"]="$value"
			done < "$file_path"
		fi
	}
	load_assoc_array "$save_path/skills.sav" "skills"
	load_assoc_array "$save_path/drugs.sav" "drugs"
	load_assoc_array "$save_path/territory.sav" "territory_owner"
	load_assoc_array "$save_path/businesses.sav" "owned_businesses"
	load_assoc_array "$save_path/upgrades.sav" "gang_upgrades"
	load_assoc_array "$save_path/relations.sav" "gang_relations"
	load_assoc_array "$save_path/city_rep.sav" "city_reputation"
	load_assoc_array "$save_path/protection.sav" "protection_income"
	load_assoc_array "$save_path/contacts.sav" "contacts_unlocked"
	load_assoc_array "$save_path/perks.sav" "perks"

	command -v bounty_load_extra &>/dev/null && bounty_load_extra
	command -v economy_load_extra &>/dev/null && economy_load_extra

	apply_gang_upgrades
	echo "Game loaded successfully."; read -r -p "Press Enter..."
	return 0
}

remove_save_files() { rm -f "$BASEDIR/$SAVE_DIR"/*.sav &> /dev/null; }

Game_variables() {
	clear_screen; read -r -p "Enter your player name: " player_name
	[[ -z "$player_name" ]] && player_name="toolazytowritename"
	play_sfx_mpg "new_game"; location="Los Santos"; cash=500; health=100
	guns=(); items=(); owned_vehicles=(); wanted_level=0; body_armor_equipped=false
	declare -A drugs; for key in "${!default_drugs[@]}"; do drugs["$key"]=${default_drugs[$key]}; done
	declare -A skills; for key in "${!default_skills[@]}"; do skills["$key"]=${default_skills[$key]}; done
	game_day=1; game_hour=8; player_gang="None"; player_gang_rank="Outsider"; player_respect=0
	perk_points=0; last_respect_milestone=0; loan_amount=0; loan_interest=0; loan_due_day=0
	loan_rate=15; loan_enforcer_warned=false; rented_safehouse=""; safehouse_rent_day=0
	contacts_unlocked=(); player_bounty=0; bounty_hitman_name=""
	auction_active=false; current_auction=()
	initialize_world_data
	echo "Welcome to Bash Theft Auto, $player_name!"
	if [[ "$player_name" == "test" ]]; then cash=999999; player_respect=5000; fi
	echo "Starting in $location with \$${cash} and ${health}%% health."
	read -r -p "Press Enter to begin..."
}

run_initial_menu() {
	while true; do
		clear_screen; echo "=== Bash Theft Auto ==="; echo "      Main Menu"; echo "---------------------"
		echo "1. New Game"; echo "2. Load Game"; echo "3. Exit Game"; echo "---------------------"
		stty echo; read -r -p "Enter your choice: " initial_choice
		case "$initial_choice" in
			1) read -r -p "Start new game? This deletes any existing save. (y/n): " confirm
				if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then remove_save_files; Game_variables; return 0
				else echo "New game cancelled."; sleep 1; fi;;
			2) if load_game; then return 0; else sleep 1; fi;;
			3) cleanup_and_exit;; *) echo "Invalid choice."; sleep 1;;
		esac
	done
}

# --- World Event System ---
show_news_feed() {
	clear_screen; echo "--- World News & Rumors ---"
	if (( ${#world_event_log[@]} == 0 )); then echo "The streets are quiet... for now."
	else
		for (( i=${#world_event_log[@]}-1; i>=0; i-- )); do echo -e "${world_event_log[i]}"; done
	fi
	echo "---------------------------"; read -r -p "Press Enter to return..."
}

calculate_gang_strength() {
	local gang_name="$1"; local strength=0
	if [[ "$gang_name" == "Unaffiliated" ]]; then echo 15; return; fi
	local territory_count=0
	for key in "${!territory_owner[@]}"; do
		[[ "${territory_owner[$key]}" == "$gang_name" ]] && ((territory_count++))
	done
	strength=$(( territory_count * 10 ))
	if [[ "$gang_name" == "$player_gang" ]]; then
		local recruit_bonus=0
		for recruit in "${player_recruits[@]}"; do
			local _ str _; IFS=':' read -r _ str _ <<< "$recruit"; recruit_bonus=$((recruit_bonus + str * 2))
		done
		local locker_level=${gang_upgrades[weapon_locker]:-0}; local locker_bonus=$((locker_level * 5))
		strength=$(( strength + recruit_bonus + locker_bonus ))
	fi
	echo $strength
}

handle_player_territory_defense() {
	local attacker_gang="$1"; local target_key="$2"
	local city="${target_key%|*}"; local district="${target_key#*|}"
	clear_screen; play_sfx_mpg "police_siren"
	echo -e "\e[1;91m*** INCOMING ATTACK! ***\e[0m"
	echo -e "The \e[1;31m${attacker_gang}\e[0m are attacking your territory in \e[1;33m${district}\e[0m!"
	echo "1. Lead the defense personally!  2. Let your crew handle it."
	read -r -p "Choice: " defense_choice
	local player_gang_strength=$(calculate_gang_strength "$player_gang")
	local attacker_strength=$(calculate_gang_strength "$attacker_gang")
	local success=false
	case "$defense_choice" in
		1)
			echo "You rush to the scene!"; sleep 2
			local success_chance=$(( 60 + player_gang_strength - attacker_strength ))
			(( success_chance < 10 )) && success_chance=10; (( success_chance > 90 )) && success_chance=90
			if (( RANDOM % 100 < success_chance )); then success=true; else health=$((health - (RANDOM % 30 + 10))); fi;;
		2)
			echo "You trust your crew..."; sleep 2
			local success_chance=$(( 40 + player_gang_strength - attacker_strength ))
			(( success_chance < 5 )) && success_chance=5; (( success_chance > 80 )) && success_chance=80
			if (( RANDOM % 100 < success_chance )); then success=true; fi;;
		*)
			echo "You hesitated! Your crew was unprepared."; sleep 2; success=false;;
	esac
	if $success; then
		clear_screen; echo -e "\e[1;32m*** DEFENSE SUCCESSFUL! ***\e[0m"
		echo "You repelled the ${attacker_gang}'s attack on ${district}!"
		award_respect $((RANDOM % 50 + 25)); play_sfx_mpg "win"
	else
		clear_screen; echo -e "\e[1;31m--- TERRITORY LOST! ---\e[0m"
		echo "The ${attacker_gang} have seized ${district}!"; territory_owner["$target_key"]="$attacker_gang"
		player_respect=$((player_respect - 75)); ((player_respect < 0)) && player_respect=0
		echo "You lost 75 Respect."; play_sfx_mpg "lose_big"; check_health
	fi
	read -r -p "Press Enter to continue..."
}

process_world_events() {
	local event_chance=25
	(( RANDOM % 100 >= event_chance )) && return
	local -a ai_gangs=()
	for gang in "${!GANG_HOME_CITY[@]}"; do [[ "$gang" != "$player_gang" ]] && ai_gangs+=("$gang"); done
	(( ${#ai_gangs[@]} == 0 )) && return
	local attacker_gang="${ai_gangs[RANDOM % ${#ai_gangs[@]}]}"
	local attacker_home_city="${GANG_HOME_CITY[$attacker_gang]}"
	local -a potential_targets=()
	for key in "${!territory_owner[@]}"; do
		local city="${key%|*}"
		if [[ "$city" == "$attacker_home_city" && "${territory_owner[$key]}" != "$attacker_gang" ]]; then
			potential_targets+=("$key")
		fi
	done
	(( ${#potential_targets[@]} == 0 )) && return
	local target_key="${potential_targets[RANDOM % ${#potential_targets[@]}]}"
	local defender_gang="${territory_owner[$target_key]}"
	if [[ "$defender_gang" == "$player_gang" ]]; then handle_player_territory_defense "$attacker_gang" "$target_key"; return; fi
	local attacker_strength=$(calculate_gang_strength "$attacker_gang")
	local defender_strength=$(calculate_gang_strength "$defender_gang")
	local city="${target_key%|*}"; local district="${target_key#*|}"
	local log_msg=""
	if (( attacker_strength + (RANDOM % 30 - 15) > defender_strength )); then
		if [[ "$defender_gang" == "Unaffiliated" ]]; then
			log_msg="[Day $game_day] NEWS: The \e[1;31m${attacker_gang}\e[0m took \e[1;33m${district}\e[0m from government forces in ${city}!"
		else
			log_msg="[Day $game_day] NEWS: The \e[1;31m${attacker_gang}\e[0m took \e[1;33m${district}\e[0m from the \e[1;32m${defender_gang}\e[0m in ${city}!"
		fi
		territory_owner["$target_key"]="$attacker_gang"
	else
		if [[ "$defender_gang" == "Unaffiliated" ]]; then
			log_msg="[Day $game_day] RUMOR: Move by \e[1;31m${attacker_gang}\e[0m on \e[1;33m${district}\e[0m was thwarted by police."
		else
			log_msg="[Day $game_day] RUMOR: \e[1;32m${defender_gang}\e[0m defended \e[1;33m${district}\e[0m from the \e[1;31m${attacker_gang}\e[0m."
		fi
	fi
	world_event_log+=("$log_msg")
	if (( ${#world_event_log[@]} > 20 )); then world_event_log=("${world_event_log[@]:1}"); fi
}

# =====================================================
# Main Execution & Loop
# =====================================================
if ! run_initial_menu; then echo "Exiting."; exit 1; fi

while true; do
	update_world_state
	check_police_encounter
	check_health && clear_screen || clear_screen

	echo "--- Actions ---"
	echo "1.  Travel          | 2.  Buy Guns"
	echo "3.  Buy Vehicle     | 4.  Inventory"
	echo "5.  Work (Legal)    | 6.  Work (Crime)"
	echo "7.  Sell Drugs      | 8.  Buy Drugs"
	echo "9.  Hire Hooker     | 10. Visit Hospital"
	echo "11. Street Race     | 12. Gambling Den"
	echo "13. Visit Shops     | 14. Training Gym"
	echo "---  NEW MECHANICS  ---"
	echo "15. Loan Shark      | 16. Auction House"
	echo "17. Fence Goods     | 18. Protection Racket"
	echo "19. Safe House      | 20. Phone Contacts"
	echo "21. City Reputation |"
	echo "---  GANG & EMPIRE  ---"
	echo "G.  Gang Menu       |"
	echo "------------------------------------------------------------"
	echo "S.  Save Game       | L.  Load Game    | N.  News Feed"
	echo "M.  Music Player    | A.  About        | P.  Perks"
	echo "X.  Exit Game       |"
	echo "------------------------------------------------------------"
	stty echo; read -r -p "Enter your choice: " choice
	choice_lower=$(echo "$choice" | tr '[:upper:]' '[:lower:]')

	case "$choice_lower" in
		1)
			clear_screen; echo "--- Travel Agency ---"
			echo "1. Los Santos (\$50) | 2. San Fierro (\$75) | 3. Las Venturas (\$100)"
			echo "4. Vice City (\$150) | 5. Liberty City (\$200) | 6. Blaine County (\$80)"
			echo "7. Stay Here"
			read -r -p "Enter choice: " city_choice
			case "$city_choice" in
				1) travel_to 50 "Los Santos";; 2) travel_to 75 "San Fierro";;
				3) travel_to 100 "Las Venturas";; 4) travel_to 150 "Vice City";;
				5) travel_to 200 "Liberty City";; 6) travel_to 80 "Blaine County";; 7) ;; *) echo "Invalid." && sleep 1;;
			esac;;
		2) buy_guns;;
		3) buy_vehicle;;
		4) show_inventory;;
		5)
			clear_screen; echo "--- Honest Work ---"
			echo "1. Taxi Driver    | 2. Delivery Driver"
			echo "3. Mechanic       | 4. Security Guard"
			echo "5. Performer      | 6. Bus Driver"
			echo "7. Bartender      | 8. Dock Worker"
			echo "9. Construction   | 10. Chef"
			echo "11. Pizza Delivery | 12. Street Vendor"
			echo "13. Back"
			read -r -p "Enter choice: " job_choice
			case "$job_choice" in
				1) work_job "taxi";; 2) work_job "delivery";; 3) work_job "mechanic";;
				4) work_job "security";; 5) work_job "performer";; 6) work_job "bus_driver";;
				7) work_job "bartender";; 8) work_job "dock_worker";; 9) work_job "construction";;
				10) work_job "chef";; 11) work_job "pizza delivery";; 12) work_job "street vendor";;
				13) ;; *) echo "Invalid." && sleep 1;;
			esac;;
		6)
			clear_screen; echo "--- Criminal Activities ---"
			echo "1. Rob Store    | 2. Carjack"
			echo "3. Burglary     | 4. Heist"
			echo "5. Pickpocket   | 6. Mug Someone"
			echo "7. Arson        | 8. Kidnap for Ransom"
			echo "9. Back"
			read -r -p "Enter choice: " criminal_choice
			case "$criminal_choice" in
				1) rob_store;; 2) carjack;; 3) burglary;; 4) heist;;
				5) pickpocket;; 6) mug_someone;; 7) arson;; 8) kidnap_for_ransom;;
				9) ;; *) echo "Invalid." && sleep 1;;
			esac;;
		7) sell_drugs;;
		8) buy_drugs;;
		9) hire_hooker;;
		10) visit_hospital;;
		11) street_race;;
		12) gambling_den;;
		13) visit_shop;;
		14) visit_gym;;
		15) visit_loan_shark;;
		16) visit_auction_house;;
		17) visit_fence;;
		18) manage_protection_racket;;
		19) rent_safe_house;;
		20) manage_phone_contacts;;
		21) show_city_reputation;;
		'g') show_gang_menu;;
		's') save_game;;
		'l')
			read -r -p "Load game? Unsaved progress will be lost. (y/n): " confirm
			if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then load_game; fi;;
		'n') show_news_feed;;
		'm') play_music;;
		'a') about_music_sfx;;
		'p') manage_perks;;
		'x')
			read -r -p "Are you sure you want to exit? (y/n): " confirm
			if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then cleanup_and_exit; fi;;
		*)
			echo "Invalid choice '$choice'."; sleep 1;;
	esac
done
cleanup_and_exit

