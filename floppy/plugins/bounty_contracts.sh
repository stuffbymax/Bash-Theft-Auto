#!/bin/bash
# =============================================================================
# Plugin: Bounty & Contract System
# File:   plugins/bounty_contracts.sh
# Author: stuffbymax / Martin Petik (plugin template)
# Ver:    1.0.0
# Desc:   Adds a bounty board, hit contracts, and a witness/informant system.
#         - Players can accept contracts to hunt down named targets for reward.
#         - Players can have bounties placed ON them by rival gangs.
#         - Informants can be bribed to lower wanted level or reveal contracts.
#         - Witness intimidation can suppress evidence and reduce heat.
# License: MIT
# =============================================================================

# --- Bounty System State ---
declare -A active_bounties=()        # ["TargetName"]="reward:difficulty:description"
declare -A contracts_on_player=()    # ["GangName"]="reward:reason"
declare -a completed_contracts=()    # Log of finished jobs
declare -A informant_cooldowns=()    # ["city"]="day_last_used"
bounty_board_last_refresh=0          # game_day of last refresh

# --- Contract Target Pool ---
# Format: "Name:Reward:Difficulty(1-5):Description:City"
declare -a CONTRACT_POOL=(
    "Vinnie Marcone:2500:2:A mid-level enforcer who skipped bail:Los Santos"
    "The Accountant:5000:3:Runs money laundering for a rival crew:San Fierro"
    "Diego Montoya:3500:3:Cartel distributor, heavily armed:Vice City"
    "Snake Eyes:1500:1:Small-time dealer who robbed the wrong people:Los Santos"
    "Oksana Volkov:7500:4:Russian arms dealer with private security:Liberty City"
    "Fat Tony Luccese:4500:3:Runs numbers for the Commission:Las Venturas"
    "Ghost:8000:4:Former special forces, now a hitman:Liberty City"
    "Lil Menace:1200:1:Gang banger with a price on his head:Los Santos"
    "The Broker:10000:5:Anonymous fixer who betrayed too many crews:San Fierro"
    "Mama Caridad:6000:4:Haitian gang matriarch, runs half of Little Haiti:Vice City"
    "Sergei Volkov:9000:5:FSB-trained assassin operating stateside:Liberty City"
    "Twitchy Pete:800:1:Snitch who talked to the feds:Los Santos"
    "Don Altobello:12000:5:Aging don who refuses to retire quietly:Las Venturas"
    "Blaze:3000:2:Arsonist for hire who went freelance:San Fierro"
    "Two-Face Rashid:4000:3:Double agent playing three gangs at once:Liberty City"
)

# --- Rival Gang Bounty Reasons ---
declare -a BOUNTY_REASONS=(
    "You took their territory"
    "You killed one of their members"
    "You robbed their stash house"
    "You humiliated their lieutenant"
    "You disrupted their supply chain"
    "You put one of their men in the hospital"
)

# =============================================================================
# BOUNTY BOARD
# =============================================================================

refresh_bounty_board() {
    # Only refresh every 3 in-game days
    if (( game_day - bounty_board_last_refresh < 3 && ${#active_bounties[@]} > 0 )); then
        return
    fi
    bounty_board_last_refresh=$game_day
    active_bounties=()

    # Pick 4-6 random contracts from the pool, filtered loosely by city
    local num_contracts=$(( RANDOM % 3 + 4 ))
    local pool_size=${#CONTRACT_POOL[@]}
    local -a used_indices=()

    local added=0
    local attempts=0
    while (( added < num_contracts && attempts < 50 )); do
        ((attempts++))
        local idx=$(( RANDOM % pool_size ))
        # Avoid duplicates
        local already_used=false
        for u in "${used_indices[@]}"; do [[ "$u" == "$idx" ]] && already_used=true && break; done
        $already_used && continue

        local entry="${CONTRACT_POOL[$idx]}"
        local name diff reward desc city
        IFS=':' read -r name reward diff desc city <<< "$entry"

        active_bounties["$name"]="${reward}:${diff}:${desc}:${city}"
        used_indices+=("$idx")
        ((added++))
    done
}

show_bounty_board() {
    run_clock 1
    refresh_bounty_board

    while true; do
        clear_screen
        echo "--- Fixer's Bounty Board ---"
        echo "Contracts available. Payment on confirmation of the job."
        echo "You are in: ${location}"
        echo "================================================================"
        printf " %-3s %-18s %-8s %-5s %-15s\n" "#" "TARGET" "REWARD" "DIFF" "LAST SEEN"
        echo "----------------------------------------------------------------"

        local i=1
        local -a board_keys=()
        for target in "${!active_bounties[@]}"; do
            local data="${active_bounties[$target]}"
            local reward diff desc city
            IFS=':' read -r reward diff desc city <<< "$data"

            local diff_stars=""
            for (( d=0; d<diff; d++ )); do diff_stars+="★"; done
            for (( d=diff; d<5; d++ )); do diff_stars+="☆"; done

            local color="\e[0m"
            (( diff >= 4 )) && color="\e[1;31m"
            (( diff == 3 )) && color="\e[1;33m"
            (( diff <= 2 )) && color="\e[1;32m"

            printf " %-3d ${color}%-18s\e[0m \e[1;32m\$%-7d\e[0m %-5s %-15s\n" \
                "$i" "$target" "$reward" "$diff_stars" "$city"
            board_keys+=("$target")
            ((i++))
        done

        echo "================================================================"
        echo " C. Check bounties on YOU"
        echo " R. Refresh board (3-day cooldown)"
        echo " B. Back to main menu"
        echo "================================================================"
        read -r -p "Select contract number to accept, or C/R/B: " choice

        case "${choice,,}" in
            b) return ;;
            r)
                bounty_board_last_refresh=0
                refresh_bounty_board
                echo "Board refreshed."; sleep 1
                ;;
            c) show_bounties_on_player ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#board_keys[@]} )); then
                    local target_name="${board_keys[$((choice-1))]}"
                    accept_contract "$target_name"
                else
                    echo "Invalid choice."; sleep 1
                fi
                ;;
        esac
    done
}

accept_contract() {
    local target_name="$1"
    local data="${active_bounties[$target_name]}"
    local reward diff desc city
    IFS=':' read -r reward diff desc city <<< "$data"

    clear_screen
    echo "--- Contract Details ---"
    echo "================================================================"
    printf " TARGET:      %s\n" "$target_name"
    printf " REWARD:      \$%d\n" "$reward"
    printf " LAST SEEN:   %s\n" "$city"
    printf " INTEL:       %s\n" "$desc"
    echo "================================================================"

    local diff_warn=""
    case "$diff" in
        1) diff_warn="\e[1;32mLow risk. Should be straightforward.\e[0m" ;;
        2) diff_warn="\e[1;32mModerate. Come prepared.\e[0m" ;;
        3) diff_warn="\e[1;33mSerious muscle. Bring firepower.\e[0m" ;;
        4) diff_warn="\e[1;31mExtremely dangerous. Multiple armed guards reported.\e[0m" ;;
        5) diff_warn="\e[1;35mSuicide mission. Only the best survive.\e[0m" ;;
    esac
    echo -e " RISK LEVEL:  ${diff_warn}"
    echo "================================================================"

    if [[ "$city" != "$location" ]]; then
        echo -e "\e[1;33mWarning:\e[0m Target is in ${city}. You are in ${location}."
        echo "You'll need to travel there first."
    fi

    read -r -p "Accept this contract? (y/n): " confirm
    [[ "$confirm" != "y" && "$confirm" != "Y" ]] && return

    execute_contract "$target_name" "$reward" "$diff" "$city"
}

execute_contract() {
    local target_name="$1"
    local reward="$2"
    local diff="$3"
    local target_city="$4"

    run_clock $(( diff * 2 ))

    clear_screen
    echo "--- Executing Contract: ${target_name} ---"
    echo "You track down your target..."
    sleep 1

    # Need a gun for contracts
    if (( ${#guns[@]} == 0 )); then
        echo -e "\e[1;31mYou have no weapons!\e[0m The target spots you unarmed and escapes."
        echo "Contract failed. Come back armed."
        read -r -p "Press Enter..."; return
    fi

    # Calculate success based on skills, guns, difficulty
    local stealth_skill=${skills[stealth]:-1}
    local strength_skill=${skills[strength]:-1}
    local base_chance=$(( 70 - diff * 10 + stealth_skill * 3 + strength_skill * 2 ))
    (( base_chance < 10 )) && base_chance=10
    (( base_chance > 90 )) && base_chance=90

    # Gun bonus
    local gun_bonus=0
    local best_gun_bonus=0
    for gun in "${guns[@]}"; do
        if [[ -v "gun_attributes[$gun]" ]]; then
            local success_bonus=0
            eval "${gun_attributes[$gun]}"
            (( success_bonus > best_gun_bonus )) && best_gun_bonus=$success_bonus
        fi
    done
    gun_bonus=$best_gun_bonus
    local final_chance=$(( base_chance + gun_bonus / 2 ))
    (( final_chance > 95 )) && final_chance=95

    echo "Locating target... tracking movements..."
    sleep 1

    # Multi-stage: approach, confront, escape
    local approach_roll=$(( RANDOM % 100 ))
    local confrontation_roll=$(( RANDOM % 100 ))

    echo ""
    if (( approach_roll < final_chance )); then
        echo -e "\e[1;32mApproach successful.\e[0m You get close without being detected."
        sleep 1

        if (( confrontation_roll < final_chance )); then
            # SUCCESS
            local damage=$(( RANDOM % (diff * 8) + diff * 3 ))
            if $body_armor_equipped; then
                damage=$(( damage / 2 ))
                body_armor_equipped=false
                echo "Your armor absorbed some of the fight."
            fi
            health=$(( health - damage ))

            echo -e "\e[1;32m*** CONTRACT COMPLETE ***\e[0m"
            echo "Target neutralised. You took ${damage}% damage in the struggle."
            echo ""

            cash=$(( cash + reward ))
            echo -e "Reward collected: \e[1;32m\$${reward}\e[0m"

            # Bonus loot roll
            if (( RANDOM % 3 == 0 )); then
                local bonus_loot=$(( RANDOM % 300 + 100 ))
                cash=$(( cash + bonus_loot ))
                echo -e "You found \e[1;33m\$${bonus_loot}\e[0m on the target. Nice bonus."
            fi

            # Skill gain
            if (( RANDOM % 2 == 0 )); then
                skills[stealth]=$(( ${skills[stealth]:-1} + 1 ))
                echo -e "Your \e[1;32mstealth\e[0m skill increased!"
            fi
            if (( RANDOM % 2 == 0 )); then
                skills[strength]=$(( ${skills[strength]:-1} + 1 ))
                echo -e "Your \e[1;32mstrength\e[0m skill increased!"
            fi

            award_respect $(( diff * 30 + RANDOM % 50 ))
            play_sfx_mpg "win_big"

            # Remove from board, add to completed log
            unset "active_bounties[$target_name]"
            completed_contracts+=("${target_name}:\$${reward}:Day ${game_day}")

            # High difficulty contracts raise wanted level slightly
            if (( diff >= 4 )); then
                wanted_level=$(( wanted_level + 1 ))
                (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
                echo -e "\e[1;31mThe hit attracted police attention. Wanted level increased.\e[0m"
            fi

        else
            # Target fought back hard
            echo -e "\e[1;31mThe target was tipped off!\e[0m"
            echo "They came out guns blazing. You barely escaped."
            local damage=$(( RANDOM % 30 + 20 + diff * 5 ))
            health=$(( health - damage ))
            wanted_level=$(( wanted_level + 1 ))
            (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
            echo "Took ${damage}% damage. Wanted level increased."
            play_sfx_mpg "lose"
        fi
    else
        # Blown approach
        echo -e "\e[1;31mYou were spotted before getting close!\e[0m"
        echo "The target bolted. Contract is still open but you're burned for today."
        local damage=$(( RANDOM % 20 + 10 ))
        health=$(( health - damage ))
        wanted_level=$(( wanted_level + 1 ))
        (( wanted_level > MAX_WANTED_LEVEL )) && wanted_level=$MAX_WANTED_LEVEL
        echo "Took ${damage}% damage fleeing the scene."
        play_sfx_mpg "lose"
    fi

    check_health
    read -r -p "Press Enter..."
}

# =============================================================================
# BOUNTIES ON THE PLAYER
# =============================================================================

check_and_generate_player_bounty() {
    # Called after criminal activities — rival gangs may put a price on you
    [[ "$player_gang" == "None" ]] && return
    (( RANDOM % 100 >= 15 )) && return  # 15% chance on trigger

    local -a rival_gangs=()
    for gang in "${!gang_relations[@]}"; do
        local rel="${gang_relations[$gang]}"
        [[ "$rel" == "War" || "$rel" == "Hostile" ]] && rival_gangs+=("$gang")
    done
    (( ${#rival_gangs[@]} == 0 )) && return

    local placing_gang="${rival_gangs[RANDOM % ${#rival_gangs[@]}]}"
    [[ -v "contracts_on_player[$placing_gang]" ]] && return  # Already have one from them

    local bounty_val=$(( RANDOM % 2001 + 1000 + wanted_level * 200 ))
    local reason="${BOUNTY_REASONS[RANDOM % ${#BOUNTY_REASONS[@]}]}"

    contracts_on_player["$placing_gang"]="${bounty_val}:${reason}"

    world_event_log+=("[Day $game_day] \e[1;35mWARNING:\e[0m The \e[1;31m${placing_gang}\e[0m have put a \e[1;33m\$${bounty_val}\e[0m bounty on YOUR head. Reason: ${reason}.")
    echo -e "\n\e[1;35m*** BOUNTY PLACED ON YOU ***\e[0m"
    echo -e "The \e[1;31m${placing_gang}\e[0m are offering \e[1;33m\$${bounty_val}\e[0m for your head."
    echo "Reason: ${reason}"
    echo "Be careful out there."
    play_sfx_mpg "police_siren"
    sleep 2
}

show_bounties_on_player() {
    clear_screen
    echo "--- Bounties On Your Head ---"
    if (( ${#contracts_on_player[@]} == 0 )); then
        echo "Nobody has a price on your head. Stay lucky."
    else
        echo "The following factions want you dead:"
        echo "================================================"
        local total=0
        for gang in "${!contracts_on_player[@]}"; do
            local val reason
            IFS=':' read -r val reason <<< "${contracts_on_player[$gang]}"
            printf " \e[1;31m%-20s\e[0m \$%-8d %s\n" "$gang" "$val" "$reason"
            total=$(( total + val ))
        done
        echo "================================================"
        printf " Total on your head: \e[1;31m\$%d\e[0m\n" "$total"
        echo ""
        echo "Options to clear a bounty:"
        echo " - Pay it off through the Fixer (costs the bounty amount)"
        echo " - Complete diplomatic tribute in the Gang menu"
        echo " - Lay low (wanted level 0 for 5+ days may cause them to drop it)"
        echo ""
        local i=1
        local -a bounty_gangs=()
        for gang in "${!contracts_on_player[@]}"; do
            local val reason
            IFS=':' read -r val reason <<< "${contracts_on_player[$gang]}"
            printf " %d. Pay off \e[1;31m%s\e[0m bounty (\$%d)\n" "$i" "$gang" "$val"
            bounty_gangs+=("$gang")
            ((i++))
        done
        echo " B. Back"
        read -r -p "Choice: " pay_choice
        if [[ "$pay_choice" =~ ^[0-9]+$ ]] && (( pay_choice >= 1 && pay_choice <= ${#bounty_gangs[@]} )); then
            local target_gang="${bounty_gangs[$((pay_choice-1))]}"
            local val reason
            IFS=':' read -r val reason <<< "${contracts_on_player[$target_gang]}"
            if (( cash >= val )); then
                cash=$(( cash - val ))
                unset "contracts_on_player[$target_gang]"
                echo -e "\e[1;32mBounty paid off.\e[0m The ${target_gang} call off their hunters."
                play_sfx_mpg "cash_register"
            else
                echo "Not enough cash to pay off this bounty (\$${val} needed)."
            fi
        fi
    fi
    read -r -p "Press Enter..."
}

passive_bounty_encounter() {
    # Called periodically — if bounties exist, there's a chance of an ambush
    (( ${#contracts_on_player[@]} == 0 )) && return
    (( RANDOM % 100 >= 20 )) && return  # 20% chance per check

    local -a bounty_gangs=("${!contracts_on_player[@]}")
    local attacking_gang="${bounty_gangs[RANDOM % ${#bounty_gangs[@]}]}"
    local val reason
    IFS=':' read -r val reason <<< "${contracts_on_player[$attacking_gang]}"

    clear_screen
    play_sfx_mpg "police_siren"
    echo -e "\e[1;91m*** AMBUSH! ***\e[0m"
    echo -e "Hunters hired by the \e[1;31m${attacking_gang}\e[0m have found you!"
    echo "They've been tracking you for the \$${val} bounty."
    echo "================================================"
    echo "1. Fight them off"
    echo "2. Run for it"
    echo "3. Try to bribe them"
    read -r -p "Choice: " ambush_choice

    local strength_skill=${skills[strength]:-1}
    local stealth_skill=${skills[stealth]:-1}

    case "$ambush_choice" in
        1)
            local fight_chance=$(( 40 + strength_skill * 5 ))
            (( ${#guns[@]} > 0 )) && fight_chance=$(( fight_chance + 20 ))
            if (( RANDOM % 100 < fight_chance )); then
                local damage=$(( RANDOM % 25 + 10 ))
                health=$(( health - damage ))
                echo -e "\e[1;32mYou fought them off!\e[0m Took ${damage}% damage."
                if (( RANDOM % 3 == 0 )); then
                    unset "contracts_on_player[$attacking_gang]"
                    echo "The surviving hunters reported back. ${attacking_gang} dropped the bounty."
                fi
                award_respect $(( RANDOM % 20 + 10 ))
                play_sfx_mpg "win"
            else
                local damage=$(( RANDOM % 35 + 20 ))
                health=$(( health - damage ))
                echo -e "\e[1;31mOverwhelmed!\e[0m Took ${damage}% damage escaping."
                play_sfx_mpg "lose"
            fi
            ;;
        2)
            local run_chance=$(( 35 + stealth_skill * 6 ))
            if (( RANDOM % 100 < run_chance )); then
                echo -e "\e[1;32mYou lost them in the streets!\e[0m"
                play_sfx_mpg "win"
            else
                local damage=$(( RANDOM % 20 + 15 ))
                health=$(( health - damage ))
                echo -e "\e[1;31mThey caught up to you!\e[0m Took ${damage}% damage."
                play_sfx_mpg "lose"
            fi
            ;;
        3)
            local bribe_cost=$(( val / 3 ))
            if (( cash >= bribe_cost )); then
                cash=$(( cash - bribe_cost ))
                echo -e "\e[1;32mYou paid \$${bribe_cost} to the hunters.\e[0m They walk away... for now."
                echo "The bounty is still active, but you bought yourself time."
                play_sfx_mpg "cash_register"
            else
                echo "You don't have enough cash (\$${bribe_cost} needed)."
                local damage=$(( RANDOM % 30 + 15 ))
                health=$(( health - damage ))
                echo -e "\e[1;31mThey attacked anyway!\e[0m Took ${damage}% damage."
                play_sfx_mpg "lose"
            fi
            ;;
    esac

    check_health
    read -r -p "Press Enter..."
}

# =============================================================================
# INFORMANT SYSTEM
# =============================================================================

visit_informant() {
    run_clock 1
    clear_screen
    echo "--- Street Informant ---"
    echo "A shady contact who knows things — for the right price."
    echo "================================================"

    local last_used=${informant_cooldowns[$location]:-0}
    if (( game_day - last_used < 2 )); then
        echo "Your informant in ${location} needs time to cool down."
        echo "Come back in $(( 2 - (game_day - last_used) )) day(s)."
        read -r -p "Press Enter..."; return
    fi

    local charisma_skill=${skills[charisma]:-1}
    echo "1. Buy intel on active contracts   (\$300)"
    echo "2. Have them suppress evidence     (\$500)  - Reduce wanted level by 1-2"
    echo "3. Get a tip on rival gang moves   (\$400)  - Reveals upcoming world event"
    echo "4. Witness intimidation            (\$600)  - Clear one wanted star guaranteed"
    echo "5. Leave"
    echo "================================================"
    printf " Your charisma skill (%d) may reduce costs.\n" "$charisma_skill"
    read -r -p "Choice: " info_choice

    local discount=$(( charisma_skill * 15 ))

    case "$info_choice" in
        1)
            local cost=$(( 300 - discount ))
            (( cost < 100 )) && cost=100
            if (( cash >= cost )); then
                cash=$(( cash - cost ))
                informant_cooldowns["$location"]=$game_day
                echo "Paying \$${cost} for contract intel..."
                sleep 1
                echo ""
                echo "--- INTEL REPORT ---"
                # Reveal details about active contracts
                if (( ${#active_bounties[@]} == 0 )); then
                    refresh_bounty_board
                fi
                local count=0
                for target in "${!active_bounties[@]}"; do
                    local data="${active_bounties[$target]}"
                    local reward diff desc city
                    IFS=':' read -r reward diff desc city <<< "$data"
                    echo -e " \e[1;33m${target}\e[0m — \$${reward} — ${city}"
                    echo "   \"${desc}\""
                    echo "   Difficulty rating: ${diff}/5"
                    echo ""
                    (( ++count >= 3 )) && break
                done
                [[ $count -eq 0 ]] && echo "Board is empty right now. Check back after the next refresh."
                play_sfx_mpg "cash_register"
            else echo "Not enough cash."; fi
            ;;
        2)
            local cost=$(( 500 - discount ))
            (( cost < 200 )) && cost=200
            if (( cash >= cost )); then
                cash=$(( cash - cost ))
                informant_cooldowns["$location"]=$game_day
                local reduction=$(( RANDOM % 2 + 1 ))
                wanted_level=$(( wanted_level - reduction ))
                (( wanted_level < 0 )) && wanted_level=0
                echo -e "Evidence suppressed. Wanted level reduced by \e[1;32m${reduction}\e[0m."
                play_sfx_mpg "cash_register"
            else echo "Not enough cash (\$${cost} needed)."; fi
            ;;
        3)
            local cost=$(( 400 - discount ))
            (( cost < 150 )) && cost=150
            if (( cash >= cost )); then
                cash=$(( cash - cost ))
                informant_cooldowns["$location"]=$game_day
                echo "Your informant leans in and whispers..."
                sleep 1
                echo ""
                # Show a preview of what process_world_events might do
                local -a ai_gangs=()
                for gang in "${!GANG_HOME_CITY[@]}"; do
                    [[ "$gang" != "$player_gang" ]] && ai_gangs+=("$gang")
                done
                if (( ${#ai_gangs[@]} > 0 )); then
                    local random_gang="${ai_gangs[RANDOM % ${#ai_gangs[@]}]}"
                    local random_city="${GANG_HOME_CITY[$random_gang]}"
                    echo -e "\"Word is, the \e[1;31m${random_gang}\e[0m are making moves in \e[1;33m${random_city}\e[0m."
                    echo " They've been recruiting and their boys are itching for a fight."
                    echo -e " You might want to reinforce your positions there before it's too late.\""
                else
                    echo "\"Things are quiet. Nobody is making a move right now.\""
                fi
                play_sfx_mpg "cash_register"
            else echo "Not enough cash (\$${cost} needed)."; fi
            ;;
        4)
            local cost=$(( 600 - discount ))
            (( cost < 250 )) && cost=250
            if (( cash >= cost )); then
                if (( wanted_level == 0 )); then
                    echo "You have no wanted level. Save your money."
                else
                    cash=$(( cash - cost ))
                    informant_cooldowns["$location"]=$game_day
                    wanted_level=$(( wanted_level - 1 ))
                    (( wanted_level < 0 )) && wanted_level=0
                    echo -e "\e[1;32mWitness dealt with.\e[0m Wanted level reduced by 1."
                    play_sfx_mpg "cash_register"
                fi
            else echo "Not enough cash (\$${cost} needed)."; fi
            ;;
        5) return ;;
        *) echo "Invalid choice." ;;
    esac

    read -r -p "Press Enter..."
}

# =============================================================================
# COMPLETED CONTRACTS HISTORY
# =============================================================================

show_contract_history() {
    clear_screen
    echo "--- Completed Contracts ---"
    if (( ${#completed_contracts[@]} == 0 )); then
        echo "No contracts completed yet."
    else
        echo "================================================"
        for entry in "${completed_contracts[@]}"; do
            local name reward day
            IFS=':' read -r name reward day <<< "$entry"
            printf " %-20s  %-10s  %s\n" "$name" "$reward" "$day"
        done
        echo "================================================"
        printf " Total contracts completed: %d\n" "${#completed_contracts[@]}"
    fi
    read -r -p "Press Enter..."
}

# =============================================================================
# SAVE / LOAD HOOKS
# =============================================================================

bounty_save_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"
    # Save bounties on player
    : > "$save_path/bounties_on_player.sav"
    for gang in "${!contracts_on_player[@]}"; do
        printf "%s@@@%s\n" "$gang" "${contracts_on_player[$gang]}" >> "$save_path/bounties_on_player.sav"
    done
    # Save completed contracts
    printf '%s\n' "${completed_contracts[@]}" > "$save_path/completed_contracts.sav"
    # Save cooldowns
    : > "$save_path/informant_cooldowns.sav"
    for city in "${!informant_cooldowns[@]}"; do
        printf "%s@@@%s\n" "$city" "${informant_cooldowns[$city]}" >> "$save_path/informant_cooldowns.sav"
    done
}

bounty_load_extra() {
    local save_path="$BASEDIR/$SAVE_DIR"
    contracts_on_player=()
    completed_contracts=()
    informant_cooldowns=()

    if [[ -f "$save_path/bounties_on_player.sav" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" ]] && continue
            local key="${line%%@@@*}"
            local value="${line#*@@@}"
            contracts_on_player["$key"]="$value"
        done < "$save_path/bounties_on_player.sav"
    fi
    if [[ -f "$save_path/completed_contracts.sav" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && completed_contracts+=("$line")
        done < "$save_path/completed_contracts.sav"
    fi
    if [[ -f "$save_path/informant_cooldowns.sav" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" ]] && continue
            local key="${line%%@@@*}"
            local value="${line#*@@@}"
            informant_cooldowns["$key"]="$value"
        done < "$save_path/informant_cooldowns.sav"
    fi
}

# =============================================================================
# MENU INTEGRATION — adds entries to main game loop
# Called by hooking into the plugin system
# =============================================================================

# Announce plugin loaded
echo "[Plugin] Bounty & Contract System loaded."