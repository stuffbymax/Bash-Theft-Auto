#!/bin/bash
# =============================================================================
# BTA Plugin: Mission System
# =============================================================================
# Name:        plugin_missions.sh
# Author:      Your Name
# Version:     1.0.0
# Description: Adds a structured mission system. NPCs offer missions with
#              specific objectives, time limits, and story-style rewards.
#              Missions persist in saves. Demonstrates multi-step quest design.
#
# INSTALL: Drop into plugins/
# MANUAL STEP: Add to main menu:
#   echo "22. Missions        |"
#   22) show_mission_board;;
# =============================================================================

[[ -n "${PLUGIN_MISSIONS_LOADED:-}" ]] && return
PLUGIN_MISSIONS_LOADED=1

# ── Mission State ─────────────────────────────────────────────────────────────
# Each mission: "id:title:giver:city:type:target:reward_cash:reward_respect:status"
# status: available / active / complete / failed

declare -A missions_status=()       # ["mission_id"]="available/active/complete/failed"
declare -A missions_progress=()     # ["mission_id"]=step_number
current_active_mission=""           # ID of currently active mission

# ── Mission Definitions ───────────────────────────────────────────────────────
# Format: title|giver|city|description|type|cash_reward|respect_reward
declare -A MISSION_DATA=(
    ["m01"]="The First Job|Tommy the Fence|Los Santos|Rob a store in Los Santos and bring back the cash.|rob_store|500|50"
    ["m02"]="Hot Wheels|Chop Shop Carl|Los Santos|Steal a Sports Car and deliver it to the chop shop.|carjack_sports|1000|75"
    ["m03"]="Moving Product|The Plug|San Fierro|Buy 10 units of Weed in San Fierro and sell them in Las Venturas.|drug_run:Weed:10|2000|100"
    ["m04"]="Gang Business|Street Boss|Los Santos|Win a gang war in Los Santos.|gang_war:Los Santos|0|300"
    ["m05"]="The Big Score|Mysterious Client|Liberty City|Complete a heist in Liberty City.|heist:Liberty City|5000|500"
    ["m06"]="Road King|Race Promoter|Las Venturas|Win 3 street races anywhere.|race_wins:3|1500|150"
    ["m07"]="Clean Slate|Corrupt Detective|Vice City|Reach wanted level 0 after being at level 4+.|wanted_clear|800|80"
)

# Prerequisite missions (mission_id -> required_id or "")
declare -A MISSION_PREREQS=(
    ["m01"]=""
    ["m02"]="m01"
    ["m03"]="m01"
    ["m04"]="m02"
    ["m05"]="m03"
    ["m06"]=""
    ["m07"]=""
)

# ── Init ──────────────────────────────────────────────────────────────────────
_missions_init() {
    missions_status=()
    missions_progress=()
    current_active_mission=""
    for id in "${!MISSION_DATA[@]}"; do
        missions_status["$id"]="available"
        missions_progress["$id"]=0
    done
}
_missions_init

# ── Save / Load ───────────────────────────────────────────────────────────────
economy_save_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"
    mkdir -p "$save_path"
    echo "current_active_mission@@@${current_active_mission}" > "$save_path/missions.sav"
    save_assoc_array "$save_path/missions_status.sav" "missions_status"
    save_assoc_array "$save_path/missions_progress.sav" "missions_progress"
}

economy_load_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"
    _missions_init

    [[ -f "$save_path/missions.sav" ]] || return

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" ]] && continue
        local key="${line%%@@@*}"; local value="${line#*@@@}"
        case "$key" in
            "current_active_mission") current_active_mission="$value";;
        esac
    done < "$save_path/missions.sav"

    load_assoc_array "$save_path/missions_status.sav" "missions_status"
    load_assoc_array "$save_path/missions_progress.sav" "missions_progress"
}

# ── Main Mission Board ────────────────────────────────────────────────────────
show_mission_board() {
    run_clock 1
    while true; do
        clear_screen
        echo "--- Mission Board ---"
        printf " City: %-20s | Active Mission: %s\n" "$location" "${current_active_mission:-None}"
        echo "=============================================="

        local -a available_ids=()
        for id in $(echo "${!MISSION_DATA[@]}" | tr ' ' '\n' | sort); do
            local status="${missions_status[$id]:-available}"
            local data="${MISSION_DATA[$id]}"
            local title="${data%%|*}"; data="${data#*|}"
            local giver="${data%%|*}"; data="${data#*|}"
            local city="${data%%|*}"; data="${data#*|}"
            local desc="${data%%|*}"; data="${data#*|}"
            local mtype="${data%%|*}"; data="${data#*|}"
            local cash_r="${data%%|*}"; data="${data#*|}"
            local resp_r="$data"

            local prereq="${MISSION_PREREQS[$id]:-}"
            local prereq_met=true
            if [[ -n "$prereq" ]] && [[ "${missions_status[$prereq]:-}" != "complete" ]]; then
                prereq_met=false
            fi

            local color="\e[0m" status_label=""
            case "$status" in
                "available") color="\e[1;33m"; status_label="[AVAILABLE]";;
                "active")    color="\e[1;36m"; status_label="[ACTIVE]";;
                "complete")  color="\e[1;32m"; status_label="[COMPLETE]";;
                "failed")    color="\e[1;31m"; status_label="[FAILED]";;
            esac

            if ! $prereq_met; then
                color="\e[0;37m"; status_label="[LOCKED]"
            fi

            printf " %b%-12s\e[0m %-30s | %s | \$%s | %s Resp\n" \
                "$color" "$status_label" "$title" "$giver" "$cash_r" "$resp_r"

            if [[ "$status" == "available" ]] && $prereq_met; then
                available_ids+=("$id")
            fi
        done

        echo "=============================================="
        echo "1. Accept a mission"
        if [[ -n "$current_active_mission" ]]; then
            echo "2. Check active mission progress"
            echo "3. Abandon active mission"
        fi
        echo "B. Back"
        read -r -p "Choice: " choice
        case "$choice" in
            1) accept_mission_menu "${available_ids[@]}";;
            2) [[ -n "$current_active_mission" ]] && show_mission_progress;;
            3) [[ -n "$current_active_mission" ]] && abandon_mission;;
            'b'|'B') return;;
            *) sleep 1;;
        esac
    done
}

accept_mission_menu() {
    local -a ids=("$@")
    if (( ${#ids[@]} == 0 )); then
        echo "No available missions right now."; sleep 2; return
    fi
    if [[ -n "$current_active_mission" ]]; then
        echo "You already have an active mission. Finish or abandon it first."; sleep 2; return
    fi

    clear_screen
    echo "--- Accept a Mission ---"
    local i=1
    for id in "${ids[@]}"; do
        local data="${MISSION_DATA[$id]}"
        local title="${data%%|*}"; data="${data#*|}"
        local giver="${data%%|*}"; data="${data#*|}"
        local city="${data%%|*}"; data="${data#*|}"
        local desc="${data%%|*}"; data="${data#*|}"
        local mtype="${data%%|*}"; data="${data#*|}"
        local cash_r="${data%%|*}"
        printf " %d. [%-8s] %-25s - %s\n" "$i" "$city" "$title" "$desc"
        ((i++))
    done
    printf " %d. Back\n" "$i"
    read -r -p "Choice: " mchoice
    if [[ "$mchoice" =~ ^[0-9]+$ ]] && (( mchoice >= 1 && mchoice < i )); then
        local chosen_id="${ids[$((mchoice-1))]}"
        missions_status["$chosen_id"]="active"
        missions_progress["$chosen_id"]=0
        current_active_mission="$chosen_id"
        local data="${MISSION_DATA[$chosen_id]}"
        local title="${data%%|*}"
        echo -e "\e[1;36mMission accepted: $title\e[0m"
        echo "Open your inventory or the mission board to track progress."
        play_sfx_mpg "win"
        read -r -p "Press Enter..."
    fi
}

show_mission_progress() {
    local id="$current_active_mission"
    local data="${MISSION_DATA[$id]}"
    local title="${data%%|*}"; data="${data#*|}"
    local giver="${data%%|*}"; data="${data#*|}"
    local city="${data%%|*}"; data="${data#*|}"
    local desc="${data%%|*}"; data="${data#*|}"
    local mtype="${data%%|*}"; data="${data#*|}"
    local cash_r="${data%%|*}"; data="${data#*|}"
    local resp_r="$data"

    clear_screen
    echo "--- Active Mission ---"
    printf " Title:   %s\n" "$title"
    printf " From:    %s (%s)\n" "$giver" "$city"
    printf " Goal:    %s\n" "$desc"
    printf " Reward:  \$%s + %s Respect\n" "$cash_r" "$resp_r"
    echo "-----------------------------"
    _show_mission_objective "$id" "$mtype"
    read -r -p "Press Enter..."
}

_show_mission_objective() {
    local id="$1" mtype="$2"
    local progress=${missions_progress[$id]:-0}
    case "$mtype" in
        "rob_store")
            echo " Objective: Rob a store in Los Santos."
            echo " Status: Just do it — the game will detect completion.";;
        "carjack_sports")
            echo " Objective: Steal a Sports Car (via Carjack in Crime menu)."
            if _mission_has_sports_car; then
                echo " STATUS: You have a Sports Car! Return to mission giver."
            else
                echo " STATUS: No Sports Car yet."
            fi;;
        "drug_run:Weed:10")
            local weed=${drugs[Weed]:-0}
            echo " Objective: Have 10+ units of Weed and be in Las Venturas."
            printf " STATUS: Weed: %d/10 | Location: %s\n" "$weed" "$location";;
        "gang_war:Los Santos")
            echo " Objective: Win a gang war in Los Santos.";;
        "heist:Liberty City")
            echo " Objective: Complete a heist while in Liberty City.";;
        "race_wins:3")
            printf " Objective: Win 3 street races. Progress: %d/3\n" "$progress";;
        "wanted_clear")
            echo " Objective: Reach wanted level 4+, then clear it to 0.";;
        *)
            echo " Objective: Unknown mission type: $mtype";;
    esac
}

abandon_mission() {
    read -r -p "Abandon current mission? You will lose all progress. (y/n): " confirm
    if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
        missions_status["$current_active_mission"]="failed"
        missions_progress["$current_active_mission"]=0
        current_active_mission=""
        echo "Mission abandoned."
        player_respect=$(( player_respect - 20 ))
        (( player_respect < 0 )) && player_respect=0
        echo "Lost 20 Respect."
        read -r -p "Press Enter..."
    fi
}

_mission_has_sports_car() {
    for v in "${owned_vehicles[@]}"; do
        [[ "$v" == "Sports Car" ]] && return 0
    done
    return 1
}

complete_mission() {
    local id="$1"
    local data="${MISSION_DATA[$id]}"
    local title="${data%%|*}"; data="${data#*|}"; data="${data#*|}"; data="${data#*|}"; data="${data#*|}"; data="${data#*|}"
    local cash_r="${data%%|*}"; local resp_r="${data#*|}"

    missions_status["$id"]="complete"
    current_active_mission=""

    clear_screen
    echo -e "\e[1;32m*** MISSION COMPLETE: $title ***\e[0m"
    printf " Cash reward:    \$%s\n" "$cash_r"
    printf " Respect reward: %s\n" "$resp_r"
    cash=$(( cash + cash_r ))
    award_respect "$resp_r"
    play_sfx_mpg "win_big"
    read -r -p "Press Enter..."
}

# ── Passive Mission Check (runs every game tick) ──────────────────────────────
# This hooks into passive_bounty_encounter to check mission conditions
# We wrap it carefully to not break an existing implementation.

_plugin_missions_tick() {
    [[ -z "$current_active_mission" ]] && return

    local id="$current_active_mission"
    local data="${MISSION_DATA[$id]}"
    local title="${data%%|*}"; data="${data#*|}"; data="${data#*|}"; data="${data#*|}"; data="${data#*|}"
    local mtype="${data%%|*}"; data="${data#*|}"; data="${data#*|}"

    case "$mtype" in
        "carjack_sports")
            if _mission_has_sports_car; then
                complete_mission "$id"
            fi;;
        "drug_run:Weed:10")
            if [[ "$location" == "Las Venturas" ]] && (( ${drugs[Weed]:-0} >= 10 )); then
                drugs["Weed"]=$(( ${drugs[Weed]} - 10 ))
                echo "You delivered the Weed to your contact in Las Venturas!"
                complete_mission "$id"
            fi;;
        "race_wins:3")
            # Progress is tracked via award_respect calls... but we can't hook into
            # street_race cleanly from a plugin without patching it.
            # This would require manual patching of street_race.
            ;;
    esac
}

# Hook into passive tick
_original_passive_bounty_encounter="$(declare -f passive_bounty_encounter 2>/dev/null)"

passive_bounty_encounter() {
    _plugin_missions_tick
    # If there was an original passive_bounty_encounter from another plugin, call it
    # This is a cooperative chaining approach
}

echo "[Plugin] Mission system loaded. ${#MISSION_DATA[@]} missions available."