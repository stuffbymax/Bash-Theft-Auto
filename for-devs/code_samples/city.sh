#!/bin/bash
# =============================================================================
# BTA Plugin: New City — "Carcer City"
# =============================================================================
# Name:        plugin_new_city.sh
# Author:      Your Name
# Version:     1.0.0
# Description: Adds a new city, Carcer City, with its own gangs, territories,
#              properties, and protection targets.
#              Demonstrates the complete process of adding a new city.
#
# INSTALL: Drop into plugins/
# MANUAL STEP: Add to Travel menu in bta_enhanced.sh main loop case block:
#   In echo block:   echo "8. Carcer City (\$175) |"
#   In case block:   8) travel_to 175 "Carcer City";;
# =============================================================================

[[ -n "${PLUGIN_CARCER_CITY_LOADED:-}" ]] && return
PLUGIN_CARCER_CITY_LOADED=1

# ── Extend initialize_world_data ─────────────────────────────────────────────
# We can't redefine initialize_world_data without replacing it entirely.
# Instead, we define a function that extends it, and hook it via
# the passive_bounty_encounter slot... but that's too frequent.
#
# Best approach: define a function and call it from a post-init hook.
# We use the trick of wrapping update_world_state to call our init once.

_carcer_city_initialized=false

_carcer_city_inject() {
    $_carcer_city_initialized && return
    _carcer_city_initialized=true

    # ── Territories ──────────────────────────────────────────────────────────
    territory_owner["Carcer City|Acter"]="Nines"
    territory_owner["Carcer City|Acter Industrial Estate"]="Unaffiliated"
    territory_owner["Carcer City|Staunton Plaza"]="Nines"
    territory_owner["Carcer City|Downtown Carcer"]="Unaffiliated"
    territory_owner["Carcer City|Carcer Port"]="Unaffiliated"
    territory_owner["Carcer City|Schiff Gardens"]="Hoods"
    territory_owner["Carcer City|Shantytown"]="Hoods"

    # ── District Heat ────────────────────────────────────────────────────────
    district_heat["Carcer City"]=18  # High heat city

    # ── City Reputation ──────────────────────────────────────────────────────
    city_reputation["Carcer City"]=5

    # ── Gangs ────────────────────────────────────────────────────────────────
    GANG_HOME_CITY["Nines"]="Carcer City"
    GANG_HOME_CITY["Hoods"]="Carcer City"
    GANG_HOME_CITY["Skinz"]="Carcer City"

    # ── Properties ───────────────────────────────────────────────────────────
    available_properties["CC Condemned Warehouse"]="80000:Carcer City:IllegalFront"
    available_properties["CC Scrapyard"]="120000:Carcer City:Legal"
    available_properties["CC Pawn Shop"]="60000:Carcer City:Legal"
    available_properties["CC Underground Fight Ring"]="200000:Carcer City:IllegalFront"
    available_properties["CC Snuff Films Studio"]="500000:Carcer City:IllegalFront"

    # ── Protection Targets ───────────────────────────────────────────────────
    protection_targets["CC Gas Station"]="Carcer City:90:20:0"
    protection_targets["CC Liquor Store"]="Carcer City:70:15:0"
    protection_targets["CC Diner"]="Carcer City:110:18:0"
}

# ── Override update_world_state to inject city data on first tick ─────────────
_original_update_world_state_carcer="$(declare -f update_world_state 2>/dev/null)"

update_world_state() {
    _carcer_city_inject
    # Call original behavior manually
    run_clock 0
    command -v passive_bounty_encounter &>/dev/null && passive_bounty_encounter
    command -v tick_stock_market &>/dev/null && tick_stock_market
    check_player_bounty
}

# ── Extend work_job pay ranges for new city ──────────────────────────────────
# We patch work_job by wrapping it. This is advanced — simpler to just
# document that devs should edit work_job directly.
#
# For this example, we accept that Carcer City will use the fallback
# min=10/max=40 range, which makes it a poor city for legitimate work
# (fitting for Carcer City's lore).

# ── Add drug location modifier ───────────────────────────────────────────────
# The drug market modifier for Carcer City defaults to 0 since it's not
# in the hardcoded case statements. To change this, edit buy_drugs and
# sell_drugs in bta_enhanced.sh and add:
#   "Carcer City") location_modifier=20;;
# (Carcer City has high drug demand — +20% sell prices)

# ── Carcer City Exclusive Activity ───────────────────────────────────────────
# A new crime available only in Carcer City
snuff_job() {
    [[ "$location" == "Carcer City" ]] || {
        echo "This only happens in Carcer City."; read -r -p "Press Enter..."; return
    }
    run_clock 6

    local stealth=${skills[stealth]:-1}
    local strength=${skills[strength]:-1}
    local base_chance=$(( 10 + stealth * 4 + strength * 3 ))
    (( base_chance > 75 )) && base_chance=75

    clear_screen
    echo "--- Snuff Job ---"
    echo "You've been hired for a contract. No questions asked."
    echo "The target is somewhere in Carcer City's backstreets."
    sleep 2

    local final_chance=$(apply_gun_bonus "$base_chance" "contract job")
    echo "Success chance: ${final_chance}%"
    read -r -p "Press Enter to proceed..."

    if (( RANDOM % 100 < final_chance )); then
        local payout=$(( RANDOM % 1501 + 1000 + strength * 50 ))
        cash=$(( cash + payout ))
        health=$(( health - (RANDOM % 31 + 10) ))
        echo -e "\e[1;32mContract complete.\e[0m Paid \$$payout."
        play_sfx_mpg "win_big"
        award_respect $(( RANDOM % 60 + 40 ))
        district_heat["Carcer City"]=$(( ${district_heat[Carcer City]:-0} + 15 ))
        if (( RANDOM % 2 == 0 )); then
            skills[stealth]=$(( stealth + 1 )); echo "Stealth increased!"
        fi
    else
        wanted_level=$(( wanted_level + 3 ))
        (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
        local fine=$(( RANDOM % 501 + 300 + wanted_level * 80 ))
        cash=$(( cash - fine )); (( cash < 0 )) && cash=0
        health=$(( health - (RANDOM % 41 + 20) ))
        echo -e "\e[1;31mTarget fought back. Mission failed.\e[0m Fined \$$fine."
        play_sfx_mpg "lose_big"
    fi

    check_health
    read -r -p "Press Enter..."
}

echo "[Plugin] Carcer City plugin loaded."